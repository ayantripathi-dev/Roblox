local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataManager = require(script.Parent.DataManager)

local Leaderstats = {}

function Leaderstats.initialize(player)
	local data = DataManager.loadData(player)
	if not data then
		player:Kick("Data failed to load. Please rejoin.")
		return
	end

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local coins = Instance.new("IntValue")
	coins.Name = "Coins"
	coins.Value = data.Coins
	coins.Parent = leaderstats

	local power = Instance.new("IntValue")
	power.Name = "Power"
	power.Value = data.Power
	power.Parent = leaderstats

	local rebirths = Instance.new("IntValue")
	rebirths.Name = "Rebirths"
	rebirths.Value = data.Rebirths
	rebirths.Parent = leaderstats
end

function Leaderstats.update(player, key, value)
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local stat = leaderstats:FindFirstChild(key)
		if stat then
			stat.Value = value
		end
	end
end

return Leaderstats
