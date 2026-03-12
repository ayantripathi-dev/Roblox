local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HUD = require(script.HUD)

local Events = ReplicatedStorage:WaitForChild("Events")
local ClickEvent = Events:WaitForChild("ClickEvent")
local RebirthEvent = Events:WaitForChild("RebirthEvent")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local mainHUD = playerGui:WaitForChild("MainHUD")

local buttons = mainHUD:WaitForChild("Buttons")
local clickButton = buttons:WaitForChild("ClickButton")
local rebirthButton = buttons:WaitForChild("RebirthButton")
local upgradeButton = buttons:WaitForChild("UpgradeButton")
local petButton = buttons:WaitForChild("PetButton")

HUD.init()

clickButton.MouseButton1Click:Connect(function()
	ClickEvent:FireServer()
end)

rebirthButton.MouseButton1Click:Connect(function()
	RebirthEvent:FireServer()
end)

upgradeButton.MouseButton1Click:Connect(function()
	Events.UpgradeEvent:FireServer("Power") -- Simple toggle for demo
end)

petButton.MouseButton1Click:Connect(function()
	Events.PetHatchEvent:FireServer()
end)

print("Client initialized.")
