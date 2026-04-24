local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Events = ReplicatedStorage:WaitForChild("Events")
local player = Players.LocalPlayer

local PetInventory = {}
local mainFrame

function PetInventory.init()
	local playerGui = player:WaitForChild("PlayerGui")
	local mainHUD = playerGui:WaitForChild("MainHUD")
	mainFrame = mainHUD:WaitForChild("PetInventory")
	local petList = mainFrame:WaitForChild("PetList")

	Events.RequestDataEvent.OnClientEvent:Connect(function(data)
		PetInventory.refresh(data)
	end)
end

function PetInventory.toggle()
	mainFrame.Visible = not mainFrame.Visible
	if mainFrame.Visible then
		Events.RequestDataEvent:FireServer()
	end
end

function PetInventory.refresh(data)
	local petList = mainFrame.PetList
	for _, child in ipairs(petList:GetChildren()) do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end

	local pets = data.Pets or {}
	local equipped = data.EquippedPets or {}

	for _, pet in ipairs(pets) do
		local button = Instance.new("TextButton")
		button.Name = pet.Id
		button.Size = UDim2.new(0, 80, 0, 80)

		local isEquipped = false
		for _, eqId in ipairs(equipped) do
			if eqId == pet.Id then
				isEquipped = true
				break
			end
		end

		button.Text = pet.Name .. "\n" .. (isEquipped and "[EQUIPPED]" or "")
		button.Parent = petList

		button.MouseButton1Click:Connect(function()
			Events.PetEquipEvent:FireServer(pet.Id, not isEquipped)
		end)
	end
end

return PetInventory
