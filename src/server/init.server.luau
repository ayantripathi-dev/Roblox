local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Leaderstats = require(script.Leaderstats)
local GameService = require(script.GameService)
local MarketplaceManager = require(script.MarketplaceManager)

local Events = ReplicatedStorage:WaitForChild("Events")
local ClickEvent = Events:WaitForChild("ClickEvent")
local RebirthEvent = Events:WaitForChild("RebirthEvent")
local UpgradeEvent = Events:WaitForChild("UpgradeEvent")
local PetHatchEvent = Events:WaitForChild("PetHatchEvent")

local PetService = require(script.PetService)
local DataManager = require(script.DataManager)
local Upgrades = require(ReplicatedStorage.Shared.Upgrades)

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
	local data = DataManager.get(player, "Upgrades")
	local currentLevel = data[upgradeType]
	local nextLevel = currentLevel + 1

	if Upgrades[upgradeType][nextLevel] then
		local cost = Upgrades[upgradeType][nextLevel].Cost
		local coins = DataManager.get(player, "Coins")
		if coins >= cost then
			DataManager.increment(player, "Coins", -cost)
			data[upgradeType] = nextLevel
			DataManager.set(player, "Upgrades", data)
			Leaderstats.update(player, "Coins", DataManager.get(player, "Coins"))
		end
	end
end)

PetHatchEvent.OnServerEvent:Connect(function(player)
	PetService.hatch(player)
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
