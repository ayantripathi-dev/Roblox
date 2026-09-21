--[[
	Rewards
	One place to hand out anything a system can give: coins, power, temporary
	luck, pets.

		Rewards.grant(player, { Coins = 5000, Luck = 1, LuckMinutes = 15, Pet = "Aurora Dragon" })

	Returns a summary table so callers can build a popup / toast without
	re-implementing the same formatting.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)

local DataManager = require(script.Parent.DataManager)
local Economy = require(script.Parent.Economy)
local Notifier = require(script.Parent.Notifier)
local PetService = require(script.Parent.PetService)

local Rewards = {}

--[[
	Grants a reward bundle and returns
	{ Coins = n, Power = n, Luck = n, LuckMinutes = n, Pet = info?, HasAnything = bool }
]]
function Rewards.grant(player: Player, reward: any): any
	local data = DataManager.data(player)
	local summary = {
		Coins = 0,
		Power = 0,
		Luck = 0,
		LuckMinutes = 0,
		Pet = nil,
		HasAnything = false,
	}
	if not data or type(reward) ~= "table" then
		return summary
	end

	if reward.Coins and reward.Coins > 0 then
		summary.Coins = math.floor(reward.Coins)
		DataManager.add(player, "Coins", summary.Coins)
		data.Stats.TotalEarned += summary.Coins
		summary.HasAnything = true
	end

	if reward.Power and reward.Power > 0 then
		summary.Power = math.floor(reward.Power)
		DataManager.add(player, "Power", summary.Power)
		summary.HasAnything = true
	end

	if reward.Luck and reward.Luck > 0 and (reward.LuckMinutes or 0) > 0 then
		summary.Luck = reward.Luck
		summary.LuckMinutes = reward.LuckMinutes

		local boost = data.LuckBoost
		local stillActive = boost.Until > os.time()
		boost.Amount = math.clamp(
			(stillActive and boost.Amount or 0) + reward.Luck,
			0,
			Constants.LUCK.MAX_ACTIVE
		)
		-- Extend the timer instead of overwriting it, so stacking always feels good.
		boost.Until = math.max(boost.Until, os.time()) + reward.LuckMinutes * 60
		summary.HasAnything = true
	end

	if reward.Pet then
		summary.Pet = PetService.grant(player, reward.Pet, reward.PetEgg)
		if summary.Pet then
			summary.HasAnything = true
		end
	end

	DataManager.markDirty(player)
	Economy.publish(player)
	return summary
end

--[[
	Rewards + the standard celebration popup: used by codes, index rewards,
	daily streaks and quests so they all feel the same.
]]
function Rewards.celebrate(player: Player, title: string, subtitle: string?, reward: any, icon: string?)
	local summary = Rewards.grant(player, reward)
	Notifier.reward(player, {
		Title = title,
		Subtitle = subtitle,
		Icon = icon,
		Coins = summary.Coins,
		Power = summary.Power,
		Luck = summary.Luck,
		LuckMinutes = summary.LuckMinutes,
		Pet = summary.Pet,
	})
	return summary
end

return Rewards
