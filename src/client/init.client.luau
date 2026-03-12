local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HUD = require(script.HUD)

local Events = ReplicatedStorage:WaitForChild("Events")
local ClickEvent = Events:WaitForChild("ClickEvent")
local RebirthEvent = Events:WaitForChild("RebirthEvent")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local mainHUD = playerGui:WaitForChild("MainHUD")

local clickButton = mainHUD:WaitForChild("ClickButton")
local rebirthButton = mainHUD:WaitForChild("RebirthButton")

HUD.init()

clickButton.MouseButton1Click:Connect(function()
	ClickEvent:FireServer()
end)

rebirthButton.MouseButton1Click:Connect(function()
	RebirthEvent:FireServer()
end)

print("Client initialized.")
