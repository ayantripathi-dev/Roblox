local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Leaderstats = require(script.Leaderstats)
local GameService = require(script.GameService)
local MarketplaceManager = require(script.MarketplaceManager)

local Events = ReplicatedStorage:WaitForChild("Events")
local ClickEvent = Events:WaitForChild("ClickEvent")
local RebirthEvent = Events:WaitForChild("RebirthEvent")

Players.PlayerAdded:Connect(function(player)
	Leaderstats.initialize(player)
end)

ClickEvent.OnServerEvent:Connect(function(player)
	GameService.handleClick(player)
end)

RebirthEvent.OnServerEvent:Connect(function(player)
	GameService.handleRebirth(player)
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
