--[[
	PetService
	Everything about pets: hatching, equipping, selling, granting (codes, index
	rewards, daily streak) and telling the client what to render.

	The server owns every pet. The client only ever receives copies, so a pet's
	multiplier can never be edited from a script executor - DataManager rebuilds
	pets from the config on every load anyway.
]]

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Pets = require(ReplicatedStorage.Shared.Pets)
local Utils = require(ReplicatedStorage.Shared.Utils)

local DataManager = require(script.Parent.DataManager)
local Economy = require(script.Parent.Economy)
local Notifier = require(script.Parent.Notifier)

local PetService = {}

-- ----------------------------------------------------------------------------
-- Helpers
-- ----------------------------------------------------------------------------

function PetService.info(pet: any, equipped: boolean, rebirths: number?): any
	local definition = Pets.get(pet.Name)
	return {
		Id = pet.Id,
		Name = pet.Name,
		Egg = pet.Egg,
		Rarity = if definition then definition.Rarity else "Common",
		Mult = if definition then definition.Mult else 1,
		Equipped = equipped,
		HatchedAt = pet.HatchedAt or 0,
		SellValue = Pets.sellValue(pet.Name, rebirths or 0),
	}
end

-- Full pet list + equipped id set, in the shape the client panels expect.
function PetService.listFor(player: Player): any
	local data = DataManager.data(player)
	if not data then
		return { Pets = {}, Equipped = {} }
	end

	local equipped: { [string]: boolean } = {}
	for _, id in ipairs(data.Equipped) do
		equipped[id] = true
	end

	local pets = {}
	for _, pet in ipairs(data.Pets) do
		table.insert(pets, PetService.info(pet, equipped[pet.Id] == true, data.Rebirths))
	end

	return { Pets = pets, Equipped = Utils.deepCopy(data.Equipped) }
end

local function ownedBy(player: Player, petId: string): any
	local data = DataManager.data(player)
	if not data then
		return nil
	end
	for _, pet in ipairs(data.Pets) do
		if pet.Id == petId then
			return pet
		end
	end
	return nil
end

local function isEquipped(data: any, petId: string): boolean
	for _, id in ipairs(data.Equipped) do
		if id == petId then
			return true
		end
	end
	return false
end

-- Non-secret pets discovered in one egg, plus the total needed.
local function indexProgress(data: any, egg: any): (number, number)
	local found, required = 0, 0
	for _, pet in ipairs(egg.Pets) do
		if pet.Rarity == "Secret" then
			continue
		end
		required += 1
		if data.Index[pet.Name] then
			found += 1
		end
	end
	return found, required
end

-- ----------------------------------------------------------------------------
-- Hatching
-- ----------------------------------------------------------------------------

--[[
	Hatch 1 or Pets.Settings.HatchMultiSize eggs. Returns
	{ Results, Best, IsNew, Spent, Egg } or (nil, reason).
]]
function PetService.hatch(player: Player, eggName: string, count: number?): (any, string?)
	local data = DataManager.data(player)
	if not data then
		return nil, "Your data is still loading"
	end

	local egg = Pets.getEgg(eggName)
	if not egg then
		return nil, "Unknown egg"
	end

	if data.Rebirths < egg.RebirthRequired then
		return nil, `Requires {egg.RebirthRequired} rebirth(s)`
	end

	local amount = math.clamp(math.floor(count or 1), 1, Pets.Settings.HatchMultiSize)
	if #data.Pets + amount > Constants.LIMITS.MAX_PETS then
		return nil, "Pet inventory is full - sell a few pets first"
	end

	local totalCost = egg.Cost * amount
	if not DataManager.spend(player, totalCost) then
		return nil, `You need {Utils.comma(totalCost)} coins`
	end

	local luck = Economy.luck(player)
	local rng = Random.new()
	local results = {}
	local best = nil
	local anyNew = false

	for _ = 1, amount do
		local definition = Pets.roll(egg.Name, luck, rng)
		if not definition then
			break
		end

		local pet = {
			Id = Utils.newId(),
			Name = definition.Name,
			Egg = egg.Name,
			HatchedAt = os.time(),
		}
		table.insert(data.Pets, pet)

		local isNew = data.Index[definition.Name] ~= true
		if isNew then
			data.Index[definition.Name] = true
			anyNew = true
		end

		local info = {
			Id = pet.Id,
			Name = definition.Name,
			Egg = egg.Name,
			Rarity = definition.Rarity,
			Mult = definition.Mult,
			Equipped = false,
			HatchedAt = pet.HatchedAt,
			SellValue = Pets.sellValue(definition.Name, data.Rebirths),
			IsNew = isNew,
		}
		table.insert(results, info)

		if best == nil or Pets.rank(definition.Rarity) > Pets.rank(best.Rarity) then
			best = info
		end
	end

	data.Stats.Hatches += #results
	DataManager.markDirty(player)
	Economy.publish(player)

	if best and best.IsNew and best.Rarity ~= "Common" then
		Notifier.toast(player, `NEW: {best.Name}!`, "gold", "star")
	end

	-- Let the player know an egg's index just became claimable.
	for _, scanEgg in ipairs(Pets.Eggs) do
		if scanEgg.Name == egg.Name and not data.IndexClaimed[scanEgg.Name] then
			local found, required = indexProgress(data, scanEgg)
			if found >= required and required > 0 then
				Notifier.toast(player, `{scanEgg.Name} index complete - claim your reward!`, "gold", "rank")
			end
		end
	end

	return {
		Results = results,
		Best = best,
		IsNew = anyNew,
		Spent = totalCost,
		Egg = egg.Name,
	}, nil
end

-- ----------------------------------------------------------------------------
-- Equipping
-- ----------------------------------------------------------------------------

function PetService.equip(player: Player, petId: string): (boolean, string?)
	local data = DataManager.data(player)
	if not data then
		return false, "Your data is still loading"
	end

	local pet = ownedBy(player, petId)
	if not pet then
		return false, "You do not own that pet"
	end
	if isEquipped(data, petId) then
		return false, "Already equipped"
	end

	local slots = Economy.petSlots(player)
	if #data.Equipped >= slots then
		return false, `All {slots} pet slots are full - unequip one first`
	end

	table.insert(data.Equipped, petId)
	DataManager.markDirty(player)
	Economy.publish(player)
	PetService.publishFollowers(player)
	return true, nil
end

function PetService.unequip(player: Player, petId: string): (boolean, string?)
	local data = DataManager.data(player)
	if not data then
		return false, "Your data is still loading"
	end

	for index, id in ipairs(data.Equipped) do
		if id == petId then
			table.remove(data.Equipped, index)
			DataManager.markDirty(player)
			Economy.publish(player)
			PetService.publishFollowers(player)
			return true, nil
		end
	end
	return false, "That pet is not equipped"
end

-- ----------------------------------------------------------------------------
-- Selling / granting
-- ----------------------------------------------------------------------------

function PetService.sell(player: Player, petId: string): (number?, string?)
	local data = DataManager.data(player)
	if not data then
		return nil, "Your data is still loading"
	end

	for index, pet in ipairs(data.Pets) do
		if pet.Id == petId then
			local value = Pets.sellValue(pet.Name, data.Rebirths)
			table.remove(data.Pets, index)
			PetService.unequip(player, petId)
			DataManager.add(player, "Coins", value)
			DataManager.markDirty(player)
			Economy.publish(player)
			return value, nil
		end
	end
	return nil, "You do not own that pet"
end

--[[
	Grants a pet by name (codes, index rewards, daily streak).
	Returns the pet info table, or nil when the name is unknown / inventory is full.
]]
function PetService.grant(player: Player, petName: string, eggName: string?): any
	local data = DataManager.data(player)
	if not data then
		return nil
	end
	local definition = Pets.get(petName)
	if not definition then
		return nil
	end
	if #data.Pets >= Constants.LIMITS.MAX_PETS then
		return nil
	end

	local pet = {
		Id = Utils.newId(),
		Name = definition.Name,
		Egg = eggName or "Special",
		HatchedAt = os.time(),
	}
	table.insert(data.Pets, pet)

	local isNew = data.Index[definition.Name] ~= true
	if isNew then
		data.Index[definition.Name] = true
	end
	data.Stats.Hatches += 1
	DataManager.markDirty(player)
	Economy.publish(player)

	return {
		Id = pet.Id,
		Name = definition.Name,
		Egg = pet.Egg,
		Rarity = definition.Rarity,
		Mult = definition.Mult,
		Equipped = false,
		HatchedAt = pet.HatchedAt,
		SellValue = Pets.sellValue(definition.Name, data.Rebirths),
		IsNew = isNew,
	}
end

function PetService.countOwned(player: Player, petName: string): number
	local data = DataManager.data(player)
	if not data then
		return 0
	end
	local total = 0
	for _, pet in ipairs(data.Pets) do
		if pet.Name == petName then
			total += 1
		end
	end
	return total
end

-- ----------------------------------------------------------------------------
-- Follower replication
-- ----------------------------------------------------------------------------

--[[
	Publishes the equipped pets as a JSON attribute. Followers are pure visuals,
	so this is the whole "multiplayer pets" feature: every client renders every
	player's pets from this attribute.
]]
function PetService.publishFollowers(player: Player)
	local data = DataManager.data(player)
	if not data then
		return
	end

	local byId = {}
	for _, pet in ipairs(data.Pets) do
		byId[pet.Id] = pet
	end

	local list = {}
	for _, id in ipairs(data.Equipped) do
		local pet = byId[id]
		if pet then
			local definition = Pets.get(pet.Name)
			if definition then
				table.insert(list, {
					Name = definition.Name,
					Rarity = definition.Rarity,
					Mult = definition.Mult,
				})
			end
		end
	end

	player:SetAttribute("PetFollowers", HttpService:JSONEncode(list))
end

-- Kept for backwards compatibility with older code that asked PetService.
function PetService.getEquippedMultiplier(player: Player): number
	return Economy.petMultiplier(player)
end

return PetService
