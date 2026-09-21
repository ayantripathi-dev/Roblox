--[[
	Leaderstats
	The classic Roblox player list stats. DataManager pushes values in after
	every mutation, so this module stays dumb on purpose.
]]

local Leaderstats = {}

local STATS = {
	{ Key = "Coins", Name = "Coins" },
	{ Key = "Power", Name = "Power" },
	{ Key = "Rebirths", Name = "Rebirths" },
	{ Key = "Pets", Name = "Pets" },
}

-- Creates the folder + IntValues. Safe to call twice.
function Leaderstats.initialize(player: Player): Folder
	local existing = player:FindFirstChild("leaderstats")
	if existing then
		return existing :: Folder
	end

	local folder = Instance.new("Folder")
	folder.Name = "leaderstats"

	for _, stat in ipairs(STATS) do
		local value = Instance.new("IntValue")
		value.Name = stat.Name
		value.Value = 0
		value.Parent = folder
	end

	folder.Parent = player
	return folder
end

function Leaderstats.update(player: Player, key: string, value: number)
	local folder = player:FindFirstChild("leaderstats")
	if not folder then
		return
	end
	local stat = folder:FindFirstChild(key)
	if stat and stat:IsA("IntValue") then
		-- IntValue is a 64 bit integer: clamp instead of overflowing.
		stat.Value = math.clamp(math.floor(value or 0), -2147483647, 2147483647)
	end
end

return Leaderstats
