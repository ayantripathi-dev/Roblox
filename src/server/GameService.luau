local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataManager = require(script.Parent.DataManager)
local Leaderstats = require(script.Parent.Leaderstats)
local Constants = require(ReplicatedStorage.Shared.Constants)

local GameService = {}

function GameService.handleClick(player)
	local rebirths = DataManager.get(player, "Rebirths") or 0
	local gain = Constants.CLICK_POWER_GAIN * (rebirths + 1)

	DataManager.increment(player, "Power", gain)
	Leaderstats.update(player, "Power", DataManager.get(player, "Power"))
end

function GameService.handleSell(player)
	local power = DataManager.get(player, "Power") or 0
	if power > 0 then
		local rebirths = DataManager.get(player, "Rebirths") or 0
		local multiplier = 1 -- Can be influenced by gamepasses

		-- Check for marketplace influence (simple placeholder check)
		-- if MarketplaceManager.hasDoubleCoins(player) then multiplier = 2 end

		local coinsGain = power * multiplier
		DataManager.increment(player, "Coins", coinsGain)
		DataManager.set(player, "Power", 0)

		Leaderstats.update(player, "Coins", DataManager.get(player, "Coins"))
		Leaderstats.update(player, "Power", 0)
	end
end

function GameService.handleRebirth(player)
	local rebirths = DataManager.get(player, "Rebirths") or 0
	local cost = Constants.REBIRTH_COST_BASE * (Constants.REBIRTH_COST_MULTIPLIER ^ rebirths)
	local coins = DataManager.get(player, "Coins") or 0

	if coins >= cost then
		DataManager.increment(player, "Coins", -cost)
		DataManager.increment(player, "Rebirths", 1)
		DataManager.set(player, "Power", 0)

		Leaderstats.update(player, "Coins", DataManager.get(player, "Coins"))
		Leaderstats.update(player, "Rebirths", DataManager.get(player, "Rebirths"))
		Leaderstats.update(player, "Power", 0)
	end
end

return GameService
