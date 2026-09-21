--[[
	Quests
	Every UTC day the server generates DAILY_COUNT quests from these templates.

	Targets scale with rebirths (tier), and coin rewards are expressed in seconds
	of the player's current income, so a quest always feels worth doing - at
	rebirth 0 and at rebirth 20 alike.
]]

local Utils = require(script.Parent.Utils)

local Quests = {}

Quests.Types = {
	CLICK = "CLICK",
	SELL = "SELL",
	HATCH = "HATCH",
	UPGRADE = "UPGRADE",
	EQUIP = "EQUIP",
	EARN = "EARN",
}

Quests.Templates = {
	{
		Id = "tap",
		Type = "CLICK",
		Name = "Tap Master",
		Verb = "Tap the power cube",
		Unit = "taps",
		Icon = "tap",
		Color = Color3.fromRGB(96, 196, 255),
		Targets = { 150, 600, 2500, 10000, 40000 },
		RewardSeconds = 30,
		RewardMinCoins = 500,
	},
	{
		Id = "sell",
		Type = "SELL",
		Name = "Sellout",
		Verb = "Sell power at the sell pad",
		Unit = "power",
		Icon = "sell",
		Color = Color3.fromRGB(255, 199, 82),
		Targets = { 1000, 8000, 60000, 500000, 4000000 },
		RewardSeconds = 40,
		RewardMinCoins = 750,
	},
	{
		Id = "hatch",
		Type = "HATCH",
		Name = "Egg Hunter",
		Verb = "Hatch eggs",
		Unit = "eggs",
		Icon = "egg",
		Color = Color3.fromRGB(124, 231, 158),
		Targets = { 5, 20, 60, 150, 400 },
		RewardSeconds = 60,
		RewardMinCoins = 1000,
		RewardLuck = 1,
	},
	{
		Id = "upgrade",
		Type = "UPGRADE",
		Name = "Investor",
		Verb = "Buy upgrades",
		Unit = "upgrades",
		Icon = "upgrade",
		Color = Color3.fromRGB(178, 112, 255),
		Targets = { 3, 10, 25, 60, 120 },
		RewardSeconds = 40,
		RewardMinCoins = 800,
	},
	{
		Id = "equip",
		Type = "EQUIP",
		Name = "Dream Team",
		Verb = "Equip pets",
		Unit = "pets",
		Icon = "pet",
		Color = Color3.fromRGB(255, 92, 168),
		Targets = { 1, 3, 5, 8, 12 },
		RewardSeconds = 45,
		RewardMinCoins = 900,
		RewardLuck = 1,
	},
	{
		Id = "earn",
		Type = "EARN",
		Name = "Coin Tycoon",
		Verb = "Earn coins from sales",
		Unit = "coins",
		Icon = "coin",
		Color = Color3.fromRGB(255, 140, 90),
		Targets = { 5000, 75000, 1500000, 40000000, 1000000000 },
		RewardSeconds = 50,
		RewardMinCoins = 1200,
	},
}

function Quests.template(templateId: string?): any
	for _, template in ipairs(Quests.Templates) do
		if template.Id == templateId then
			return template
		end
	end
	return nil
end

function Quests.find(list: { any }?, questId: string?): any
	if type(list) ~= "table" then
		return nil
	end
	for _, quest in ipairs(list) do
		if quest.Id == questId then
			return quest
		end
	end
	return nil
end

function Quests.tierFor(rebirths: number?, template: any): number
	local tiers = #template.Targets
	return math.clamp(1 + math.floor(math.max(0, rebirths or 0) / 2), 1, tiers)
end

function Quests.isComplete(quest: any): boolean
	return type(quest) == "table" and quest.Progress >= quest.Target
end

--[[
	options = {
		Day = "2026-09-21",   -- used for Ids so the save file is readable
		Rebirths = number,
		Income = number,      -- coins per second, keeps rewards relevant
		Count = number?,
		Rng = Random?,
	}
]]
function Quests.generate(options): { any }
	local count = math.clamp(options.Count or 3, 1, #Quests.Templates)
	local pool = Utils.shuffle(Utils.deepCopy(Quests.Templates), options.Rng)
	local quests = {}

	for index = 1, count do
		local template = pool[index]
		local tier = Quests.tierFor(options.Rebirths, template)
		local target = template.Targets[tier]
		local rewardCoins = math.max(
			template.RewardMinCoins,
			math.floor((options.Income or 0) * template.RewardSeconds)
		)

		table.insert(quests, {
			Id = string.format("%s_%s", options.Day or Utils.dayKey(), template.Id),
			Template = template.Id,
			Type = template.Type,
			Name = template.Name,
			Verb = template.Verb,
			Unit = template.Unit,
			Emoji = template.Emoji,
			Color = template.Color,
			Tier = tier,
			Target = target,
			Progress = 0,
			Claimed = false,
			Reward = {
				Coins = rewardCoins,
				Luck = template.RewardLuck,
				LuckMinutes = if template.RewardLuck then 10 + 5 * tier else nil,
			},
		})
	end

	return quests
end

return Quests
