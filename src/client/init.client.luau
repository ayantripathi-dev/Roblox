local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HUD = require(script.HUD)
local PetFollow = require(script.PetFollow)
local ClickEffect = require(script.ClickEffect)

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
PetFollow.init()

clickButton.MouseButton1Click:Connect(function()
	ClickEvent:FireServer()
end)

Events:WaitForChild("PowerGainedEvent").OnClientEvent:Connect(function(amount)
	ClickEffect.create(amount)
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

local unlockZoneButton = Instance.new("TextButton")
unlockZoneButton.Name = "UnlockZoneButton"
unlockZoneButton.Size = UDim2.new(0, 200, 0, 50)
unlockZoneButton.Position = UDim2.new(0.5, -100, 0, 160)
unlockZoneButton.Text = "Unlock Next Zone"
unlockZoneButton.Parent = mainHUD:WaitForChild("HUDFrame")

unlockZoneButton.MouseButton1Click:Connect(function()
	Events.UnlockZoneEvent:FireServer()
end)

Events:WaitForChild("PetEquippedEvent").OnClientEvent:Connect(function(equippedPets)
	PetFollow.updatePets(equippedPets)
end)

print("Client initialized.")
