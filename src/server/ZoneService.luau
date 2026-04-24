local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataManager = require(script.Parent.DataManager)
local Leaderstats = require(script.Parent.Leaderstats)

local ZoneService = {}

local ZONES = {
	Zone2 = {
		Cost = 10000,
		GateName = "Gate"
	}
}

function ZoneService.unlock(player, zoneName)
	local zone = ZONES[zoneName]
	if not zone then return false end

	local unlockedZones = DataManager.get(player, "UnlockedZones") or {Zone1 = true}
	if unlockedZones[zoneName] then return true end

	local coins = DataManager.get(player, "Coins")
	if coins >= zone.Cost then
		DataManager.increment(player, "Coins", -zone.Cost)
		unlockedZones[zoneName] = true
		DataManager.set(player, "UnlockedZones", unlockedZones)
		Leaderstats.update(player, "Coins", DataManager.get(player, "Coins"))
		return true
	end
	return false
end

return ZoneService
