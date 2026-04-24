local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataManager = require(script.Parent.DataManager)
local PetsConfig = require(ReplicatedStorage.Shared.Pets)
local HttpService = game:GetService("HttpService")

local PetService = {}

function PetService.hatch(player, eggType)
	eggType = eggType or "Basic"
	local eggData = PetsConfig.Eggs[eggType]
	if not eggData then return nil end

	local coins = DataManager.get(player, "Coins")
	if coins >= eggData.Cost then
		DataManager.increment(player, "Coins", -eggData.Cost)

		-- Weighted random selection
		local totalWeight = 0
		for _, pet in ipairs(eggData.Pets) do
			totalWeight += pet.Weight
		end

		local random = math.random(1, totalWeight)
		local currentWeight = 0
		local chosenPet = nil

		for _, pet in ipairs(eggData.Pets) do
			currentWeight += pet.Weight
			if random <= currentWeight then
				chosenPet = pet
				break
			end
		end

		if chosenPet then
			local pets = DataManager.get(player, "Pets") or {}
			local newPet = {
				Id = HttpService:GenerateGUID(),
				Name = chosenPet.Name,
				Multiplier = chosenPet.Multiplier,
				Rarity = chosenPet.Rarity
			}
			table.insert(pets, newPet)
			DataManager.set(player, "Pets", pets)
			return newPet
		end
	end
	return nil
end

function PetService.getEquippedMultiplier(player)
	local equipped = DataManager.get(player, "EquippedPets") or {}
	local multiplier = 1
	local pets = DataManager.get(player, "Pets") or {}

	for _, petId in ipairs(equipped) do
		for _, pet in ipairs(pets) do
			if pet.Id == petId then
				multiplier += (pet.Multiplier - 1)
				break
			end
		end
	end
	return multiplier
end

function PetService.equipPet(player, petId)
	local pets = DataManager.get(player, "Pets") or {}
	local equipped = DataManager.get(player, "EquippedPets") or {}

	local exists = false
	for _, pet in ipairs(pets) do
		if pet.Id == petId then
			exists = true
			break
		end
	end
	if not exists then return false end

	for _, id in ipairs(equipped) do
		if id == petId then return false end
	end

	if #equipped < PetsConfig.Settings.MaxEquipped then
		table.insert(equipped, petId)
		DataManager.set(player, "EquippedPets", equipped)
		return true
	end
	return false
end

function PetService.unequipPet(player, petId)
	local equipped = DataManager.get(player, "EquippedPets") or {}
	for i, id in ipairs(equipped) do
		if id == petId then
			table.remove(equipped, i)
			DataManager.set(player, "EquippedPets", equipped)
			return true
		end
	end
	return false
end

return PetService
