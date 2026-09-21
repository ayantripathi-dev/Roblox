--[[
	CodeService
	Redeems codes from Codes.luau.

	Every code is validated server side and remembered per account, so the same
	code can never pay out twice - no matter what the client sends. Rate limited
	so nobody can brute force the list from an executor.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Codes = require(ReplicatedStorage.Shared.Codes)
local Constants = require(ReplicatedStorage.Shared.Constants)

local DataManager = require(script.Parent.DataManager)
local Notifier = require(script.Parent.Notifier)
local RateLimiter = require(script.Parent.RateLimiter)
local Rewards = require(script.Parent.Rewards)

local CodeService = {}

function CodeService.redeem(player: Player, rawCode: string): (boolean, string?)
	local data = DataManager.data(player)
	if not data then
		return false, "Your data is still loading"
	end

	if type(rawCode) ~= "string" or #rawCode > Constants.LIMITS.MAX_CODE_LENGTH then
		return false, "That code does not look right"
	end

	local entry = Codes.find(rawCode)
	if not entry then
		Notifier.toast(player, "Invalid code - check the spelling", "bad", "code")
		return false, "Invalid code"
	end

	if Codes.isExpired(entry) then
		Notifier.toast(player, "That code has expired", "bad", "code")
		return false, "Expired code"
	end

	local key = Codes.normalize(entry.Code)
	if data.CodesRedeemed[key] then
		Notifier.toast(player, "You already redeemed that code", "bad", "code")
		return false, "Already redeemed"
	end

	data.CodesRedeemed[key] = true

	Rewards.celebrate(player, `Code redeemed: {key}`, Codes.describe(entry), {
		Coins = entry.Coins,
		Power = entry.Power,
		Luck = entry.Luck,
		LuckMinutes = entry.LuckMinutes,
		Pet = entry.Pet,
	}, "code")

	DataManager.markDirty(player)
	return true, nil
end

--[[
	Handler used by init.server: guards against spam, then redeems.
]]
function CodeService.handle(player: Player, rawCode: string)
	RateLimiter.guard(player, "Code", 1, 3, function()
		CodeService.redeem(player, rawCode)
	end)
end

return CodeService
