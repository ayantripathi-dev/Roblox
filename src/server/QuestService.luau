--[[
	QuestService
	Daily quests that reset at midnight UTC.

	Quests only track, they never grant: the request layer (GameService) calls
	progress() whenever something quest-worthy happens, and Rewards handles the
	payout when the player claims.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Quests = require(ReplicatedStorage.Shared.Quests)
local Utils = require(ReplicatedStorage.Shared.Utils)

local DataManager = require(script.Parent.DataManager)
local Economy = require(script.Parent.Economy)
local Notifier = require(script.Parent.Notifier)
local Rewards = require(script.Parent.Rewards)

local QuestService = {}

-- ----------------------------------------------------------------------------
-- Daily generation
-- ----------------------------------------------------------------------------

function QuestService.generate(player: Player): { any }
	local data = DataManager.data(player)
	if not data then
		return {}
	end

	local day = Utils.dayKey()
	if data.QuestDay == day and #data.Quests > 0 then
		return data.Quests
	end

	data.QuestDay = day
	data.QuestRerolls = 0
	data.Quests = Quests.generate({
		Day = day,
		Rebirths = data.Rebirths,
		Income = Economy.incomePerSecond(player),
		Count = Constants.QUEST.DAILY_COUNT,
		Rng = Random.new(),
	})

	DataManager.markDirty(player)
	return data.Quests
end

function QuestService.ensure(player: Player)
	QuestService.generate(player)
end

function QuestService.rerollsLeft(player: Player): number
	local data = DataManager.data(player)
	if not data then
		return 0
	end
	return math.max(0, Constants.QUEST.FREE_REROLLS - (data.QuestRerolls or 0))
end

function QuestService.publish(player: Player)
	local data = DataManager.data(player)
	if not data then
		return
	end
	Notifier.quests(player, data.Quests, QuestService.rerollsLeft(player))
end

-- ----------------------------------------------------------------------------
-- Progress
-- ----------------------------------------------------------------------------

--[[
	adds `amount` to every open quest of a type. Types come from Quests.Types.
]]
function QuestService.progress(player: Player, questType: string, amount: number?)
	if not amount or amount <= 0 then
		return
	end

	local data = DataManager.data(player)
	if not data then
		return
	end

	QuestService.ensure(player)

	local changed = false
	for _, quest in ipairs(data.Quests) do
		if quest.Type == questType and not quest.Claimed and quest.Progress < quest.Target then
			quest.Progress = math.min(quest.Target, quest.Progress + amount)
			changed = true
			if quest.Progress >= quest.Target then
				Notifier.toast(player, `Quest complete: {quest.Name}!`, "good", "check")
			end
		end
	end

	if changed then
		DataManager.markDirty(player)
		QuestService.publish(player)
	end
end

-- ----------------------------------------------------------------------------
-- Claiming / rerolling
-- ----------------------------------------------------------------------------

function QuestService.claim(player: Player, questId: string): (boolean, string?)
	local data = DataManager.data(player)
	if not data then
		return false, "Your data is still loading"
	end

	QuestService.ensure(player)

	local quest = Quests.find(data.Quests, questId)
	if not quest then
		return false, "That quest is not active"
	end
	if quest.Claimed then
		return false, "Already claimed"
	end
	if not Quests.isComplete(quest) then
		return false, "Not finished yet"
	end

	quest.Claimed = true
	Rewards.celebrate(
		player,
		`{quest.Name} complete`,
		quest.Verb,
		{
			Coins = quest.Reward.Coins,
			Luck = quest.Reward.Luck,
			LuckMinutes = quest.Reward.LuckMinutes,
		},			quest.Icon or "quest"
	)

	DataManager.markDirty(player)
	QuestService.publish(player)
	return true, nil
end

function QuestService.reroll(player: Player): (boolean, string?)
	local data = DataManager.data(player)
	if not data then
		return false, "Your data is still loading"
	end

	if QuestService.rerollsLeft(player) <= 0 then
		return false, "No rerolls left today"
	end

	data.QuestRerolls += 1
	data.Quests = Quests.generate({
		Day = Utils.dayKey(),
		Rebirths = data.Rebirths,
		Income = Economy.incomePerSecond(player),
		Count = Constants.QUEST.DAILY_COUNT,
		Rng = Random.new(),
	})

	DataManager.markDirty(player)
	QuestService.publish(player)
	Notifier.toast(player, "New quests, fresh start!", "info", "reroll")
	return true, nil
end

return QuestService
