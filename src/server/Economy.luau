--[[
	Economy
	The one place that answers "how much is this player earning?".

		powerPerClick = CLICK.BASE_GAIN * tapUpgrade * petMult * rebirthMult * combo
		sellValue     = sellUpgrade * petMult * rebirthMult * passCoins
		autoRate      = autoUpgrade * petMult * rebirthMult      (power per second)
		income        = autoRate * sellValue                     (coins per second)
		luck          = luckUpgrade + passLuck + activeBoost

	Every service asks Economy instead of doing its own math, so rebalancing
	stays in Constants and the UI is always consistent with the server.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Pets = require(ReplicatedStorage.Shared.Pets)
local Upgrades = require(ReplicatedStorage.Shared.Upgrades)

local DataManager = require(script.Parent.DataManager)
local Passes = require(script.Parent.Passes)

local Economy = {}

-- ----------------------------------------------------------------------------
-- Multipliers
-- ----------------------------------------------------------------------------

function Economy.rebirthMultiplier(player: Player): number
	return Constants.rebirthMultiplier(DataManager.get(player, "Rebirths") or 0)
end

-- Adds up every equipped pet: 1 + sum(multiplier - 1)
function Economy.petMultiplier(player: Player): number
	local data = DataManager.data(player)
	if not data then
		return 1
	end

	local byId = {}
	for _, pet in ipairs(data.Pets) do
		byId[pet.Id] = pet
	end

	local multiplier = 1
	for _, id in ipairs(data.Equipped) do
		local pet = byId[id]
		if pet then
			local definition = Pets.get(pet.Name)
			if definition then
				multiplier += (definition.Mult - 1)
			end
		end
	end
	return multiplier
end

function Economy.luck(player: Player): number
	local data = DataManager.data(player)
	if not data then
		return 0
	end

	local luck = Constants.luckUpgradeValue(data.Upgrades.Luck)
	luck += Passes.bonuses(player).Luck

	local boost = data.LuckBoost
	if type(boost) == "table" and boost.Until > os.time() then
		luck += math.max(0, boost.Amount or 0)
	end
	return luck
end

function Economy.tapPower(player: Player, comboMultiplier: number?): number
	local level = DataManager.get(player, "Upgrades").Click
	local base = Constants.CLICK.BASE_GAIN * Upgrades.valueOf("Click", level)
	return base * Economy.petMultiplier(player) * Economy.rebirthMultiplier(player) * (comboMultiplier or 1)
end

function Economy.sellMultiplier(player: Player): number
	local level = DataManager.get(player, "Upgrades").Sell
	local base = Constants.SELL.BASE_MULT * Upgrades.valueOf("Sell", level)
	return base * Economy.petMultiplier(player) * Economy.rebirthMultiplier(player) * Passes.bonuses(player).Coins
end

-- Power generated per second by the Auto-Farm upgrade.
function Economy.autoRate(player: Player): number
	local level = DataManager.get(player, "Upgrades").Auto
	return Upgrades.valueOf("Auto", level) * Economy.petMultiplier(player) * Economy.rebirthMultiplier(player)
end

-- Coins per second if the player idled forever.
function Economy.incomePerSecond(player: Player): number
	return Economy.autoRate(player) * Economy.sellMultiplier(player)
end

function Economy.petSlots(player: Player): number
	local rebirths = DataManager.get(player, "Rebirths") or 0
	return Constants.petSlots(rebirths, Passes.bonuses(player).PetSlots)
end

function Economy.comboMultiplier(comboCount: number?): number
	local steps = math.max(0, (comboCount or 1) - 1) * Constants.CLICK.COMBO_STEP
	return math.min(1 + steps, Constants.CLICK.COMBO_MAX)
end

-- ----------------------------------------------------------------------------
-- Replication
-- ----------------------------------------------------------------------------

--[[
	Single refresh entry point used after any state change:
	raw stats first (DataManager), then everything derived from them.
]]
function Economy.publish(player: Player)
	local data = DataManager.data(player)
	if not data then
		return
	end

	DataManager.publish(player)

	player:SetAttribute("Luck", math.floor(Economy.luck(player) * 100) / 100)
	player:SetAttribute("PowerPerClick", math.floor(Economy.tapPower(player)))
	player:SetAttribute("PowerPerSecond", math.floor(Economy.autoRate(player) * 10) / 10)
	player:SetAttribute("CoinsPerSecond", math.floor(Economy.incomePerSecond(player)))
	player:SetAttribute("SellMultiplier", math.floor(Economy.sellMultiplier(player) * 100) / 100)
	player:SetAttribute("PetSlots", Economy.petSlots(player))
	player:SetAttribute("PetSlotsUsed", #data.Equipped)
	player:SetAttribute("LuckBoostUntil", math.max(0, data.LuckBoost.Until or 0))
	player:SetAttribute("LuckBoostAmount", math.max(0, data.LuckBoost.Amount or 0))
	player:SetAttribute("AutoFarmRate", math.floor(Economy.autoRate(player) * 10) / 10)
	player:SetAttribute("TurboClick", Passes.bonuses(player).TurboClick)
	player:SetAttribute("IndexCount", #Economy.ownedPetNames(player))
	player:SetAttribute("UpgradeLevels", `{data.Upgrades.Click},{data.Upgrades.Sell},{data.Upgrades.Auto},{data.Upgrades.Luck}`)
end

-- Sorted list of every pet name the player has discovered.
function Economy.ownedPetNames(player: Player): { string }
	local data = DataManager.data(player)
	if not data then
		return {}
	end
	local names = {}
	for name in pairs(data.Index) do
		table.insert(names, name)
	end
	table.sort(names)
	return names
end

return Economy
