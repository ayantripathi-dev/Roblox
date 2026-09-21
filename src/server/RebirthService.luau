--[[
	RebirthService
	The long-term loop. A rebirth:

		- costs Constants.rebirthCost(rebirths) coins (grows ~3.4x each time)
		- resets coins, power and every upgrade track
		- keeps pets, the index, codes, quests, daily streaks and lifetime stats
		- grants +25% permanent multiplier, pet slots every 3 rebirths, and
		  unlocks the next egg tier

	Resetting upgrades is what makes each rebirth feel like a fresh, faster run.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Pets = require(ReplicatedStorage.Shared.Pets)
local Utils = require(ReplicatedStorage.Shared.Utils)

local DataManager = require(script.Parent.DataManager)
local Economy = require(script.Parent.Economy)
local Notifier = require(script.Parent.Notifier)
local PetService = require(script.Parent.PetService)

local RebirthService = {}

function RebirthService.cost(player: Player): number
	local data = DataManager.data(player)
	return Constants.rebirthCost(if data then data.Rebirths else 0)
end

function RebirthService.canRebirth(player: Player): (boolean, number)
	local data = DataManager.data(player)
	if not data then
		return false, math.huge
	end
	local cost = Constants.rebirthCost(data.Rebirths)
	return data.Coins >= cost, cost
end

function RebirthService.eggUnlocks(player: Player, rebirths: number): { string }
	local unlocks = {}
	for _, egg in ipairs(Pets.Eggs) do
		if egg.RebirthRequired > 0 and egg.RebirthRequired <= rebirths then
			table.insert(unlocks, egg.Name)
		end
	end
	return unlocks
end

function RebirthService.rebirth(player: Player): (boolean, string?)
	local data = DataManager.data(player)
	if not data then
		return false, "Your data is still loading"
	end

	local cost = Constants.rebirthCost(data.Rebirths)
	if data.Coins < cost then
		return false, `You need {Utils.comma(cost)} coins`
	end

	local beforeEggs = RebirthService.eggUnlocks(player, data.Rebirths)
	local beforeSlots = Economy.petSlots(player)

	-- Reset the short-term progress, keep the collection.
	data.Coins = 0
	data.Power = 0
	for trackId in pairs(data.Upgrades) do
		data.Upgrades[trackId] = 1
	end
	data.LuckBoost = { Amount = 0, Until = 0 } -- boosts do not carry over

	data.Rebirths += 1

	DataManager.markDirty(player)
	Economy.publish(player)
	PetService.publishFollowers(player)

	-- What just changed?
	local newEggs = {}
	for _, eggName in ipairs(RebirthService.eggUnlocks(player, data.Rebirths)) do
		if not table.find(beforeEggs, eggName) then
			table.insert(newEggs, eggName)
		end
	end

	local slots = Economy.petSlots(player)
	local multiplier = Constants.rebirthMultiplier(data.Rebirths)

	Notifier.celebrate(player, {
		Rebirths = data.Rebirths,
		Multiplier = multiplier,
		NewEggs = newEggs,
		NewSlots = math.max(0, slots - beforeSlots),
	})

	local subtitle = `Everything now earns x{string.format("%.2f", multiplier)}`
	if #newEggs > 0 then
		subtitle = subtitle .. ` - {newEggs[1]} unlocked!`
	end

	Notifier.reward(player, {
		Title = `REBIRTH {data.Rebirths}`,
		Subtitle = subtitle,
		Icon = "rebirth",
	})

	return true, nil
end

return RebirthService
