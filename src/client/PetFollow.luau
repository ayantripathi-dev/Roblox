local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PetFollow = {}
local activePets = {}

function PetFollow.init()
	local player = Players.LocalPlayer

	RunService.RenderStepped:Connect(function()
		local character = player.Character
		if not character then return end
		local rootPart = character:FindFirstChild("HumanoidRootPart")
		if not rootPart then return end

		for i, petModel in ipairs(activePets) do
			local targetPos = rootPart.Position + Vector3.new(
				math.sin(tick() + i) * 5,
				2 + math.sin(tick() * 2 + i) * 0.5,
				math.cos(tick() + i) * 5
			)
			petModel.CFrame = petModel.CFrame:Lerp(CFrame.new(targetPos, rootPart.Position), 0.1)
		end
	end)
end

function PetFollow.updatePets(pets)
	-- Clear existing
	for _, p in ipairs(activePets) do
		p:Destroy()
	end
	activePets = {}

	for _, petData in ipairs(pets) do
		local part = Instance.new("Part")
		part.Size = Vector3.new(2, 2, 2)
		part.Anchored = true
		part.CanCollide = false
		part.Parent = workspace
		part.Name = "Pet_" .. petData.Name

		-- Simple visual based on rarity
		if petData.Rarity == "Common" then
			part.Color = Color3.fromRGB(200, 200, 200)
		elseif petData.Rarity == "Legendary" then
			part.Color = Color3.fromRGB(255, 215, 0)
		else
			part.Color = Color3.fromRGB(100, 200, 255)
		end

		table.insert(activePets, part)
	end
end

return PetFollow
