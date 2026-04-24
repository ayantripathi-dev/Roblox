local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Leaderstats = require(script.Leaderstats)
local GameService = require(script.GameService)
local MarketplaceManager = require(script.MarketplaceManager)
local PetService = require(script.PetService)
local ZoneService = require(script.ZoneService)
local DataManager = require(script.DataManager)
local Upgrades = require(ReplicatedStorage.Shared.Upgrades)

local Events = ReplicatedStorage:WaitForChild("Events")
local ClickEvent = Events:WaitForChild("ClickEvent")
local RebirthEvent = Events:WaitForChild("RebirthEvent")
local UpgradeEvent = Events:WaitForChild("UpgradeEvent")
local PetHatchFunction = Events:WaitForChild("PetHatchFunction")
local PetEquipEvent = Events:WaitForChild("PetEquipEvent")
local RequestDataEvent = Events:WaitForChild("RequestDataEvent")
local UnlockZoneEvent = Events:WaitForChild("UnlockZoneEvent")

Players.PlayerAdded:Connect(function(player)
	Leaderstats.initialize(player)
end)

ClickEvent.OnServerEvent:Connect(function(player)
	GameService.handleClick(player)
end)

RebirthEvent.OnServerEvent:Connect(function(player)
	GameService.handleRebirth(player)
end)

UpgradeEvent.OnServerEvent:Connect(function(player, upgradeType)
	local upgradesData = DataManager.get(player, "Upgrades")
	local currentLevel = upgradesData[upgradeType]
	local nextLevel = currentLevel + 1

	if Upgrades[upgradeType] and Upgrades[upgradeType][nextLevel] then
		local cost = Upgrades[upgradeType][nextLevel].Cost
		local coins = DataManager.get(player, "Coins")
		if coins >= cost then
			DataManager.increment(player, "Coins", -cost)
			upgradesData[upgradeType] = nextLevel
			DataManager.set(player, "Upgrades", upgradesData)
			Leaderstats.update(player, "Coins", DataManager.get(player, "Coins"))
			RequestDataEvent:FireClient(player, {
				Upgrades = upgradesData,
				Pets = DataManager.get(player, "Pets"),
				EquippedPets = DataManager.get(player, "EquippedPets"),
				UnlockedZones = DataManager.get(player, "UnlockedZones")
			})
		end
	end
end)

PetHatchFunction.OnServerInvoke = function(player, eggType)
	local pet = PetService.hatch(player, eggType)
	if pet then
		Leaderstats.update(player, "Coins", DataManager.get(player, "Coins"))
		return pet
	end
	return nil
end

PetEquipEvent.OnServerEvent:Connect(function(player, petId, equip)
	local success = false
	if equip then
		success = PetService.equipPet(player, petId)
	else
		success = PetService.unequipPet(player, petId)
	end

	if success then
		RequestDataEvent:FireClient(player, {
			Upgrades = DataManager.get(player, "Upgrades"),
			Pets = DataManager.get(player, "Pets"),
			EquippedPets = DataManager.get(player, "EquippedPets"),
			UnlockedZones = DataManager.get(player, "UnlockedZones")
		})
	end
end)

UnlockZoneEvent.OnServerEvent:Connect(function(player, zoneName)
	if ZoneService.unlock(player, zoneName) then
		RequestDataEvent:FireClient(player, {
			Upgrades = DataManager.get(player, "Upgrades"),
			Pets = DataManager.get(player, "Pets"),
			EquippedPets = DataManager.get(player, "EquippedPets"),
			UnlockedZones = DataManager.get(player, "UnlockedZones")
		})
	end
end)

RequestDataEvent.OnServerEvent:Connect(function(player)
	RequestDataEvent:FireClient(player, {
		Upgrades = DataManager.get(player, "Upgrades"),
		Pets = DataManager.get(player, "Pets"),
		EquippedPets = DataManager.get(player, "EquippedPets"),
		UnlockedZones = DataManager.get(player, "UnlockedZones")
	})
end)

-- Sell part logic
local Workspace = game:GetService("Workspace")
local SellPart = Workspace:WaitForChild("SellPart")

SellPart.Touched:Connect(function(hit)
	local character = hit.Parent
	local player = Players:GetPlayerFromCharacter(character)
	if player then
		GameService.handleSell(player)
	end
end)

print("Server initialized.")
