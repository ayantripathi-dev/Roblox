local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HUD = require(script.HUD)
local PetInventory = require(script.PetInventory)
local UpgradeMenu = require(script.UpgradeMenu)
local ClickEffect = require(script.ClickEffect)
local PetFollow = require(script.PetFollow)

local Events = ReplicatedStorage:WaitForChild("Events")
local ClickEvent = Events:WaitForChild("ClickEvent")
local RebirthEvent = Events:WaitForChild("RebirthEvent")
local PetHatchFunction = Events:WaitForChild("PetHatchFunction")
local UnlockZoneEvent = Events:WaitForChild("UnlockZoneEvent")
local RequestDataEvent = Events:WaitForChild("RequestDataEvent")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local mainHUD = playerGui:WaitForChild("MainHUD")

local function setupUI()
	local hudFrame = mainHUD:WaitForChild("HUDFrame")
	hudFrame.Size = UDim2.new(0, 200, 0, 100)
	hudFrame.Position = UDim2.new(0, 10, 0, 10)
	hudFrame.BackgroundTransparency = 0.5

	local powerLabel = hudFrame:WaitForChild("PowerLabel")
	powerLabel.Size = UDim2.new(1, 0, 0.5, 0)
	powerLabel.TextScaled = true

	local coinsLabel = hudFrame:WaitForChild("CoinsLabel")
	coinsLabel.Size = UDim2.new(1, 0, 0.5, 0)
	coinsLabel.Position = UDim2.new(0, 0, 0.5, 0)
	coinsLabel.TextScaled = true

	local buttons = mainHUD:WaitForChild("Buttons")
	local clickButton = buttons:WaitForChild("ClickButton")
	clickButton.Size = UDim2.new(0, 200, 0, 50)
	clickButton.Position = UDim2.new(0.5, -100, 0.8, 0)
	clickButton.BackgroundColor3 = Color3.fromRGB(0, 178, 0)
	clickButton.TextScaled = true

	local rebirthButton = buttons:WaitForChild("RebirthButton")
	rebirthButton.Size = UDim2.new(0, 150, 0, 40)
	rebirthButton.Position = UDim2.new(0.5, -75, 0.8, 60)
	rebirthButton.BackgroundColor3 = Color3.fromRGB(178, 0, 178)
	rebirthButton.TextScaled = true

	local upgradeButton = buttons:WaitForChild("UpgradeButton")
	upgradeButton.Size = UDim2.new(0, 100, 0, 40)
	upgradeButton.Position = UDim2.new(1, -110, 0.9, 0)
	upgradeButton.BackgroundColor3 = Color3.fromRGB(178, 178, 0)
	upgradeButton.TextScaled = true

	local petButton = buttons:WaitForChild("PetButton")
	petButton.Size = UDim2.new(0, 100, 0, 40)
	petButton.Position = UDim2.new(1, -110, 0.9, -50)
	petButton.BackgroundColor3 = Color3.fromRGB(0, 178, 178)
	petButton.TextScaled = true

	local autoToggle = buttons:WaitForChild("AutoClickToggle")
	autoToggle.Size = UDim2.new(0, 100, 0, 40)
	autoToggle.Position = UDim2.new(0, 10, 0.9, 0)
	autoToggle.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
	autoToggle.TextScaled = true

	local petInv = mainHUD:WaitForChild("PetInventory")
	petInv.Size = UDim2.new(0, 400, 0, 300)
	petInv.Position = UDim2.new(0.5, -200, 0.5, -150)
	petInv.Visible = false
	petInv:WaitForChild("Title").Size = UDim2.new(1, 0, 0, 50)
	petInv.Title.TextScaled = true

	local upgMenu = mainHUD:WaitForChild("UpgradeMenu")
	upgMenu.Size = UDim2.new(0, 300, 0, 400)
	upgMenu.Position = UDim2.new(0.5, -150, 0.5, -200)
	upgMenu.Visible = false
	upgMenu:WaitForChild("Title").Size = UDim2.new(1, 0, 0, 50)
	upgMenu.Title.TextScaled = true
end

setupUI()

HUD.init()
PetInventory.init()
UpgradeMenu.init()
PetFollow.init()

local buttons = mainHUD:WaitForChild("Buttons")
local clickButton = buttons:WaitForChild("ClickButton")
local rebirthButton = buttons:WaitForChild("RebirthButton")
local upgradeButton = buttons:WaitForChild("UpgradeButton")
local petButton = buttons:WaitForChild("PetButton")
local autoToggle = buttons:WaitForChild("AutoClickToggle")

clickButton.MouseButton1Click:Connect(function()
	ClickEvent:FireServer()
	ClickEffect.show(1)
end)

rebirthButton.MouseButton1Click:Connect(function()
	RebirthEvent:FireServer()
end)

upgradeButton.MouseButton1Click:Connect(function()
	UpgradeMenu.toggle()
end)

petButton.MouseButton1Click:Connect(function()
	PetInventory.toggle()
end)

local autoClickOn = false
autoToggle.MouseButton1Click:Connect(function()
	autoClickOn = not autoClickOn
	autoToggle.Text = "AUTO: " .. (autoClickOn and "ON" or "OFF")
	autoToggle.BackgroundColor3 = autoClickOn and Color3.fromRGB(0, 200, 0) or Color3.fromRGB(100, 100, 100)
end)

task.spawn(function()
	while true do
		if autoClickOn then
			ClickEvent:FireServer()
			ClickEffect.show(1)
		end
		task.wait(0.5)
	end
end)

-- Workspace logic
local Workspace = game:GetService("Workspace")
local HatchArea = Workspace:WaitForChild("HatchArea")
local Zone2 = Workspace:WaitForChild("Zone2")
local Gate = Zone2:WaitForChild("Gate")
local GoldEggArea = Zone2:WaitForChild("GoldEggArea")

local hatchDebounce = false
HatchArea.Touched:Connect(function(hit)
	if hit.Parent == player.Character and not hatchDebounce then
		hatchDebounce = true
		local pet = PetHatchFunction:InvokeServer("Basic")
		if pet then
			print("Hatched: " .. pet.Name)
			RequestDataEvent:FireServer()
		end
		task.wait(1)
		hatchDebounce = false
	end
end)

GoldEggArea.Touched:Connect(function(hit)
	if hit.Parent == player.Character and not hatchDebounce then
		hatchDebounce = true
		local pet = PetHatchFunction:InvokeServer("Golden")
		if pet then
			print("Hatched Golden: " .. pet.Name)
			RequestDataEvent:FireServer()
		end
		task.wait(1)
		hatchDebounce = false
	end
end)

Gate.Touched:Connect(function(hit)
	if hit.Parent == player.Character then
		UnlockZoneEvent:FireServer("Zone2")
	end
end)

RequestDataEvent.OnClientEvent:Connect(function(data)
	if data.UnlockedZones and data.UnlockedZones.Zone2 then
		Gate.CanCollide = false
		Gate.Transparency = 0.9
	end
	if data.EquippedPets then
		PetFollow.updatePets(data.EquippedPets, data.Pets)
	end
end)

print("Client initialized.")
