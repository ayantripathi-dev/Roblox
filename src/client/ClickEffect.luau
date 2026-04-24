local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local player = Players.LocalPlayer

local ClickEffect = {}

function ClickEffect.show(amount)
	local playerGui = player:WaitForChild("PlayerGui")
	local mainHUD = playerGui:WaitForChild("MainHUD")

	local label = Instance.new("TextLabel")
	label.Text = "+" .. amount
	label.Size = UDim2.new(0, 50, 0, 20)
	label.Position = UDim2.new(0.5, math.random(-50, 50), 0.5, math.random(-50, 50))
	label.TextColor3 = Color3.new(0, 1, 0)
	label.BackgroundTransparency = 1
	label.Parent = mainHUD

	local goal = {
		Position = label.Position - UDim2.new(0, 0, 0.1, 0),
		TextTransparency = 1
	}

	local info = TweenInfo.new(1)
	local tween = TweenService:Create(label, info, goal)

	tween:Play()
	tween.Completed:Connect(function()
		label:Destroy()
	end)
end

return ClickEffect
