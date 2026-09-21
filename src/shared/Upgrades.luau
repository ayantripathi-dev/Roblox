--[[
	Upgrades
	Four upgrade tracks, all driven by formulas instead of hand-written tables,
	so a "level 30" upgrade exists without anyone typing 30 rows.

	Cost to reach level L:    floor(BaseCost * CostGrowth ^ (L - 1))
	Value at level L:         BaseValue * Growth ^ (L - 1)   (or BaseValue + PerLevel * (L - 1))

	Balance rules of thumb (details and the simulation that checks them live in
	docs/BALANCE.md):
		- CostGrowth must stay above Growth. If value grew faster than cost, every
		  level would pay for itself instantly and the economy would run away into
		  Constants.LIMITS.MAX_NUMBER inside one session.
		- A track caps at MaxLevel, so a run ends with a finished shop and the next
		  rebirth turns it back into a 30 second shopping spree.
		- Level 30 costs roughly 1e8-1e9 coins: affordable in a first session, still
		  a reason to keep tapping.
]]

local Constants = require(script.Parent.Constants)

local Upgrades = {}

Upgrades.Tracks = {
	Click = {
		Id = "Click",
		Name = "Tap Power",
		Icon = "tap",
		Description = "More power every time you tap the cube.",
		BaseCost = 75,
		CostGrowth = 1.7,
		BaseValue = 1,
		Growth = 1.5,
		MaxLevel = 30,
		Format = "power",
		Color = Color3.fromRGB(96, 196, 255),
	},
	Sell = {
		Id = "Sell",
		Name = "Sell Value",
		Icon = "sell",
		Description = "Every sale converts more power into coins.",
		BaseCost = 150,
		CostGrowth = 1.68,
		BaseValue = 1,
		Growth = 1.45,
		MaxLevel = 30,
		Format = "mult",
		Color = Color3.fromRGB(255, 199, 82),
	},
	Auto = {
		Id = "Auto",
		Name = "Auto-Farm",
		Icon = "auto",
		Description = "Generates power every second, even while you explore.",
		BaseCost = 500,
		CostGrowth = 1.66,
		BaseValue = Constants.AUTOFARM.BASE_RATE,
		Growth = 1.42,
		MaxLevel = 30,
		Format = "rate",
		Color = Color3.fromRGB(124, 231, 158),
	},
	Luck = {
		Id = "Luck",
		Name = "Lucky",
		Icon = "luck",
		Description = "Legendary, Mythic and Secret pets become far more common.",
		BaseCost = 25000,
		CostGrowth = 1.75,
		BaseValue = 0,
		PerLevel = Constants.LUCK.UPGRADE_PER_LEVEL,
		MaxLevel = 25,
		Format = "luck",
		Color = Color3.fromRGB(197, 150, 255),
	},
}

Upgrades.Order = { "Click", "Sell", "Auto", "Luck" }

function Upgrades.get(trackId: string?): any
	return Upgrades.Tracks[trackId or ""]
end

-- Cost of the next level. Level 1 is free (the level you start at).
function Upgrades.cost(track: any, level: number?): number
	local current = math.max(1, math.floor(level or 1))
	if current >= track.MaxLevel then
		return math.huge
	end
	return math.floor(track.BaseCost * track.CostGrowth ^ (current - 1))
end

function Upgrades.valueAt(track: any, level: number?): number
	local current = math.clamp(math.floor(level or 1), 1, track.MaxLevel)
	if track.PerLevel then
		return track.BaseValue + track.PerLevel * (current - 1)
	end
	if track.Growth then
		return track.BaseValue * track.Growth ^ (current - 1)
	end
	return track.BaseValue
end

-- Value at a level, by track id. Falls back to level 1 when the id is unknown.
function Upgrades.valueOf(trackId: string?, level: number?): number
	local track = Upgrades.get(trackId)
	if not track then
		return 1
	end
	return Upgrades.valueAt(track, level)
end

-- Everything the UI needs for one row of the shop.
function Upgrades.describe(trackId: string, level: number?): any
	local track = Upgrades.get(trackId)
	if not track then
		return nil
	end
	local current = Upgrades.clampLevel(track, level)
	local maxed = current >= track.MaxLevel
	return {
		Track = track,
		Level = current,
		Value = Upgrades.valueAt(track, current),
		NextValue = if maxed then nil else Upgrades.valueAt(track, current + 1),
		Cost = if maxed then nil else Upgrades.cost(track, current),
		Maxed = maxed,
	}
end

function Upgrades.clampLevel(track: any, level: number?): number
	return math.clamp(math.floor(level or 1), 1, track.MaxLevel)
end

-- Fraction of the current level's cost you can already afford (0-1), for progress bars.
function Upgrades.affordability(track: any, level: number?, coins: number?): number
	local cost = Upgrades.cost(track, level)
	if cost == math.huge or cost <= 0 then
		return 1
	end
	return math.clamp((coins or 0) / cost, 0, 1)
end

return Upgrades
