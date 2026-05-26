local Players = game:GetService("Players")
local player = Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Utils = require(ReplicatedStorage.Shared.Utils)
local HUD = {}

function HUD.init()
	local playerGui = player:WaitForChild("PlayerGui")
	local mainHUD = playerGui:WaitForChild("MainHUD")
	local hudFrame = mainHUD:WaitForChild("HUDFrame")
	local powerLabel = hudFrame:WaitForChild("PowerLabel")
	local coinsLabel = hudFrame:WaitForChild("CoinsLabel")

	local zoneLabel = Instance.new("TextLabel")
	zoneLabel.Name = "ZoneLabel"
	zoneLabel.Size = UDim2.new(0, 200, 0, 50)
	zoneLabel.Position = UDim2.new(0.5, -100, 0, 100)
	zoneLabel.Text = "Zone: Zone 1"
	zoneLabel.Parent = hudFrame

	local leaderstats = player:WaitForChild("leaderstats")
	local powerStat = leaderstats:WaitForChild("Power")
	local coinsStat = leaderstats:WaitForChild("Coins")

	local function update()
		powerLabel.Text = "Power: " .. Utils.formatNumber(powerStat.Value)
		coinsLabel.Text = "Coins: " .. Utils.formatNumber(coinsStat.Value)
	end

	powerStat.Changed:Connect(update)
	coinsStat.Changed:Connect(update)

	ReplicatedStorage:WaitForChild("Events"):WaitForChild("ZoneChangedEvent").OnClientEvent:Connect(function(zoneName)
		zoneLabel.Text = "Zone: " .. zoneName
	end)

	update()
end

return HUD
