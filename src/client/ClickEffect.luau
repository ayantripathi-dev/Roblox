local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local player = Players.LocalPlayer

local ClickEffect = {}

function ClickEffect.create(amount)
	local character = player.Character
	if not character then return end
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.new(2, 0, 1, 0)
	billboard.Adornee = rootPart
	billboard.StudsOffset = Vector3.new(math.random(-2, 2), 2, math.random(-2, 2))
	billboard.Parent = character

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = "+" .. amount
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = billboard

	local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
	local tween = TweenService:Create(billboard, tweenInfo, {StudsOffset = billboard.StudsOffset + Vector3.new(0, 3, 0)})

	task.spawn(function()
		tween:Play()
		task.wait(0.5)
		for i = 0, 1, 0.1 do
			label.TextTransparency = i
			task.wait(0.05)
		end
		billboard:Destroy()
	end)
end

return ClickEffect
