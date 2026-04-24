local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UpgradesConfig = require(ReplicatedStorage.Shared.Upgrades)
local Events = ReplicatedStorage:WaitForChild("Events")
local Players = game:GetService("Players")
local player = Players.LocalPlayer

local UpgradeMenu = {}
local mainFrame

function UpgradeMenu.init()
	local playerGui = player:WaitForChild("PlayerGui")
	local mainHUD = playerGui:WaitForChild("MainHUD")
	mainFrame = mainHUD:WaitForChild("UpgradeMenu")

	Events.RequestDataEvent.OnClientEvent:Connect(function(data)
		UpgradeMenu.refresh(data)
	end)
end

function UpgradeMenu.toggle()
	mainFrame.Visible = not mainFrame.Visible
	if mainFrame.Visible then
		Events.RequestDataEvent:FireServer()
	end
end

function UpgradeMenu.refresh(data)
	local list = mainFrame.List
	for _, child in ipairs(list:GetChildren()) do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end

	local playerUpgrades = data.Upgrades or {Power = 1, Coins = 1}

	for upgradeType, levels in pairs(UpgradesConfig) do
		local currentLevel = playerUpgrades[upgradeType]
		local nextLevelData = levels[currentLevel + 1]

		local button = Instance.new("TextButton")
		button.Name = upgradeType
		button.Size = UDim2.new(1, 0, 0, 50)

		if nextLevelData then
			button.Text = string.format("Upgrade %s to Lvl %d (Cost: %d)", upgradeType, currentLevel + 1, nextLevelData.Cost)
		else
			button.Text = upgradeType .. " (MAX LEVEL)"
		end

		button.Parent = list

		button.MouseButton1Click:Connect(function()
			Events.UpgradeEvent:FireServer(upgradeType)
		end)
	end
end

return UpgradeMenu
