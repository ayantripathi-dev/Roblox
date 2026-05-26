local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataManager = require(script.Parent.DataManager)
local Leaderstats = require(script.Parent.Leaderstats)
local PetService = require(script.Parent.PetService)
local ZoneService = require(script.Parent.ZoneService)
local Constants = require(ReplicatedStorage.Shared.Constants)
local Upgrades = require(ReplicatedStorage.Shared.Upgrades)

local GameService = {}

function GameService.handleClick(player)
	local rebirths = DataManager.get(player, "Rebirths") or 0
	local upgradeLevel = (DataManager.get(player, "Upgrades") or {Power = 1}).Power
	local upgradeMult = Upgrades.Power[upgradeLevel].Multiplier
	local petMult = PetService.getEquippedMultiplier(player)
	local zoneMult = ZoneService.getMultiplier(player)

	local gain = Constants.CLICK_POWER_GAIN * (rebirths + 1) * upgradeMult * petMult * zoneMult

	local amount = math.floor(gain)
	DataManager.increment(player, "Power", amount)
	Leaderstats.update(player, "Power", DataManager.get(player, "Power"))

	ReplicatedStorage.Events.PowerGainedEvent:FireClient(player, amount)
end

function GameService.handleSell(player)
	local power = DataManager.get(player, "Power") or 0
	if power > 0 then
		local rebirths = DataManager.get(player, "Rebirths") or 0
		local upgradeLevel = (DataManager.get(player, "Upgrades") or {Coins = 1}).Coins
		local upgradeMult = Upgrades.Coins[upgradeLevel].Multiplier
		local petMult = PetService.getEquippedMultiplier(player)
		local zoneMult = ZoneService.getMultiplier(player)

		local multiplier = upgradeMult * petMult * zoneMult

		local coinsGain = power * multiplier
		DataManager.increment(player, "Coins", math.floor(coinsGain))
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
