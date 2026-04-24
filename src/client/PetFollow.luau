local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local player = Players.LocalPlayer

local PetFollow = {}
local activePets = {}

function PetFollow.init()
	RunService.RenderStepped:Connect(function()
		if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then return end
		local root = player.Character.HumanoidRootPart

		for i, petModel in ipairs(activePets) do
			local targetPos = root.Position + Vector3.new(
				math.sin(tick() + i) * 5,
				math.sin(tick() * 2) * 1,
				math.cos(tick() + i) * 5
			)
			petModel.CFrame = petModel.CFrame:Lerp(CFrame.new(targetPos, root.Position), 0.1)
		end
	end)
end

function PetFollow.updatePets(equippedData, allPets)
	-- Clear old
	for _, pet in ipairs(activePets) do
		pet:Destroy()
	end
	activePets = {}

	for _, petId in ipairs(equippedData) do
		local petData
		for _, p in ipairs(allPets) do
			if p.Id == petId then
				petData = p
				break
			end
		end

		if petData then
			local model = Instance.new("Part")
			model.Size = Vector3.new(2, 2, 2)
			model.CanCollide = false
			model.Anchored = true
			model.Color = Color3.fromHSV(math.random(), 0.5, 1)
			model.Parent = workspace

			local bg = Instance.new("BillboardGui")
			bg.Size = UDim2.new(4, 0, 1, 0)
			bg.StudsOffset = Vector3.new(0, 3, 0)
			bg.AlwaysOnTop = true
			bg.Parent = model

			local label = Instance.new("TextLabel")
			label.Size = UDim2.new(1, 0, 1, 0)
			label.BackgroundTransparency = 1
			label.Text = petData.Name
			label.TextColor3 = Color3.new(1, 1, 1)
			label.TextScaled = true
			label.Parent = bg

			table.insert(activePets, model)
		end
	end
end

return PetFollow
