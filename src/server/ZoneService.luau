local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataManager = require(script.Parent.DataManager)
local Zones = require(ReplicatedStorage.Shared.Zones)

local ZoneService = {}

local Events = ReplicatedStorage:WaitForChild("Events")
local UnlockZoneEvent = Events:WaitForChild("UnlockZoneEvent")
local ZoneChangedEvent = Events:WaitForChild("ZoneChangedEvent")

function ZoneService.unlockNext(player)
	local unlocked = DataManager.get(player, "UnlockedZones")
	local nextZoneIndex = #unlocked + 1
	local nextZone = Zones[nextZoneIndex]

	if nextZone then
		local coins = DataManager.get(player, "Coins")
		if coins >= nextZone.UnlockCost then
			DataManager.increment(player, "Coins", -nextZone.UnlockCost)
			table.insert(unlocked, nextZone.Name)
			DataManager.set(player, "UnlockedZones", unlocked)

			-- Automatically move to the new zone
			ZoneService.setCurrentZone(player, nextZone.Name)
			ZoneService.updateVisuals(player)
			return true
		end
	end
	return false
end

function ZoneService.updateVisuals(player)
	local unlocked = DataManager.get(player, "UnlockedZones")
	local hasZone2 = false
	for _, name in ipairs(unlocked) do
		if name == "Zone 2" then
			hasZone2 = true
			break
		end
	end

	if hasZone2 then
		local gate = workspace:FindFirstChild("Gate")
		if gate then
			gate.CanCollide = false
			gate.Transparency = 1
		end
	end
end

function ZoneService.setCurrentZone(player, zoneName)
	local unlocked = DataManager.get(player, "UnlockedZones")
	local isUnlocked = false
	for _, name in ipairs(unlocked) do
		if name == zoneName then
			isUnlocked = true
			break
		end
	end

	if isUnlocked then
		DataManager.set(player, "CurrentZone", zoneName)
		ZoneChangedEvent:FireClient(player, zoneName)
	end
end

function ZoneService.getMultiplier(player)
	local currentZoneName = DataManager.get(player, "CurrentZone")
	for _, zone in ipairs(Zones) do
		if zone.Name == currentZoneName then
			return zone.Multiplier
		end
	end
	return 1
end

UnlockZoneEvent.OnServerEvent:Connect(function(player)
	ZoneService.unlockNext(player)
end)

return ZoneService
