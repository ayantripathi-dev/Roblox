local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataManager = require(script.Parent.DataManager)
local PetsConfig = require(ReplicatedStorage.Shared.Pets)
local HttpService = game:GetService("HttpService")

local PetService = {}

local Events = ReplicatedStorage:WaitForChild("Events")
local PetEquippedEvent = Events:WaitForChild("PetEquippedEvent")

function PetService.hatch(player)
	local coins = DataManager.get(player, "Coins")
	if coins >= PetsConfig.Settings.HatchCost then
		DataManager.increment(player, "Coins", -PetsConfig.Settings.HatchCost)

		-- Weighted random selection
		local totalWeight = 0
		for _, pet in ipairs(PetsConfig.List) do
			totalWeight += pet.Weight
		end

		local random = math.random(1, totalWeight)
		local currentWeight = 0
		local chosenPet = nil

		for _, pet in ipairs(PetsConfig.List) do
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

			-- Auto-equip if space
			local equipped = DataManager.get(player, "EquippedPets") or {}
			if #equipped < PetsConfig.Settings.MaxEquipped then
				PetService.equip(player, newPet.Id)
			end

			return newPet
		end
	end
end

function PetService.equip(player, petId)
	local pets = DataManager.get(player, "Pets") or {}
	local equipped = DataManager.get(player, "EquippedPets") or {}

	local found = false
	for _, pet in ipairs(pets) do
		if pet.Id == petId then
			found = true
			break
		end
	end

	if found then
		-- Simple logic: if already equipped, unequip. If not, equip if space.
		local index = table.find(equipped, petId)
		if index then
			table.remove(equipped, index)
		else
			if #equipped < PetsConfig.Settings.MaxEquipped then
				table.insert(equipped, petId)
			end
		end
		DataManager.set(player, "EquippedPets", equipped)

		-- Notify client of changes
		local equippedPetData = {}
		for _, id in ipairs(equipped) do
			for _, pet in ipairs(pets) do
				if pet.Id == id then
					table.insert(equippedPetData, pet)
				end
			end
		end
		PetEquippedEvent:FireClient(player, equippedPetData)
	end
end

function PetService.getEquippedMultiplier(player)
	local equipped = DataManager.get(player, "EquippedPets") or {}
	local multiplier = 1
	for _, petId in ipairs(equipped) do
		local pets = DataManager.get(player, "Pets") or {}
		for _, pet in ipairs(pets) do
			if pet.Id == petId then
				multiplier += (pet.Multiplier - 1)
			end
		end
	end
	return multiplier
end

return PetService
