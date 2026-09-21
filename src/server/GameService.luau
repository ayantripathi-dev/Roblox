--[[
	GameService
	The request layer: every player action lands here, gets validated, then
	updates DataManager and pushes fresh state to the client.

	Flow for one action:
		validate -> mutate data -> mark dirty -> Economy.publish -> notify client

	Quests are tracked here (not inside PetService) so services never depend on
	each other in a circle.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Codes = require(ReplicatedStorage.Shared.Codes)
local Constants = require(ReplicatedStorage.Shared.Constants)
local Pets = require(ReplicatedStorage.Shared.Pets)
local Quests = require(ReplicatedStorage.Shared.Quests)
local Upgrades = require(ReplicatedStorage.Shared.Upgrades)
local Utils = require(ReplicatedStorage.Shared.Utils)

local DataManager = require(script.Parent.DataManager)
local Economy = require(script.Parent.Economy)
local Notifier = require(script.Parent.Notifier)
local PetService = require(script.Parent.PetService)
local QuestService = require(script.Parent.QuestService)
local RateLimiter = require(script.Parent.RateLimiter)
local Rewards = require(script.Parent.Rewards)

local GameService = {}

local combos = setmetatable({}, { __mode = "k" }) :: { [Player]: { count: number, last: number } }
local sellCooldown = setmetatable({}, { __mode = "k" }) :: { [Player]: number }

-- ----------------------------------------------------------------------------
-- Snapshot / replication
-- ----------------------------------------------------------------------------

function GameService.totalIndexPets(): number
	local total = 0
	for _, egg in ipairs(Pets.Eggs) do
		for _, pet in ipairs(egg.Pets) do
			if pet.Rarity ~= "Secret" then
				total += 1
			end
		end
	end
	return total
end

function GameService.indexComplete(player: Player): boolean
	local data = DataManager.data(player)
	if not data then
		return false
	end
	for _, egg in ipairs(Pets.Eggs) do
		for _, pet in ipairs(egg.Pets) do
			if pet.Rarity ~= "Secret" and not data.Index[pet.Name] then
				return false
			end
		end
	end
	return true
end

function GameService.unlockedEggs(player: Player): { string }
	local data = DataManager.data(player)
	local list = {}
	if not data then
		return list
	end
	for _, egg in ipairs(Pets.Eggs) do
		if data.Rebirths >= egg.RebirthRequired then
			table.insert(list, egg.Name)
		end
	end
	return list
end

function GameService.bestUnlockedEgg(player: Player): any
	local data = DataManager.data(player)
	local best = nil
	if not data then
		return nil
	end
	for _, egg in ipairs(Pets.Eggs) do
		if data.Rebirths >= egg.RebirthRequired and (best == nil or egg.Cost > best.Cost) then
			best = egg
		end
	end
	return best
end

-- Everything the client panels need, in one payload.
function GameService.snapshot(player: Player): any
	local data = DataManager.data(player)
	if not data then
		return nil
	end

	local petList = PetService.listFor(player)
	local eggProgress = {}
	for _, egg in ipairs(Pets.Eggs) do
		local found, required = 0, 0
		for _, pet in ipairs(egg.Pets) do
			if pet.Rarity ~= "Secret" then
				required += 1
				if data.Index[pet.Name] then
					found += 1
				end
			end
		end
		table.insert(eggProgress, {
			Egg = egg.Name,
			Found = found,
			Required = required,
			Claimed = data.IndexClaimed[egg.Name] == true,
		})
	end

	return {
		Pets = petList.Pets,
		Equipped = petList.Equipped,
		Index = Utils.deepCopy(data.Index),
		IndexClaimed = Utils.deepCopy(data.IndexClaimed),
		EggProgress = eggProgress,
		IndexCount = Utils.count(data.Index),
		IndexTotal = GameService.totalIndexPets(),
		IndexComplete = GameService.indexComplete(player),
		IndexFinalClaimed = data.IndexClaimed["__final"] == true,
		Quests = Utils.deepCopy(data.Quests),
		QuestRerollsLeft = QuestService.rerollsLeft(player),
		Stats = Utils.deepCopy(data.Stats),
		Upgrades = Utils.deepCopy(data.Upgrades),
		Coins = math.floor(data.Coins),
		Power = math.floor(data.Power),
		Rebirths = data.Rebirths,
		RebirthCost = Constants.rebirthCost(data.Rebirths),
		RebirthMultiplier = Constants.rebirthMultiplier(data.Rebirths),
		Luck = Economy.luck(player),
		PowerPerClick = math.floor(Economy.tapPower(player)),
		PowerPerSecond = Economy.autoRate(player),
		CoinsPerSecond = Economy.incomePerSecond(player),
		SellMultiplier = Economy.sellMultiplier(player),
		PetSlots = Economy.petSlots(player),
		EggsUnlocked = GameService.unlockedEggs(player),
		EggsUnlockedCount = #GameService.unlockedEggs(player),
		Daily = {
			Day = data.Daily.Day,
			Streak = data.Daily.Streak,
			Claimable = data.Daily.Day ~= Utils.dayKey(),
		},
		CodesRedeemed = Utils.count(data.CodesRedeemed),
		CodesTotal = Codes.count(),
		Transient = data.IsTransient == true,
		ServerTime = os.time(),
	}
end

-- Sends a fresh snapshot to one player.
function GameService.pushState(player: Player)
	local payload = GameService.snapshot(player)
	if payload then
		Notifier.state(player, payload)
	end
end

-- ----------------------------------------------------------------------------
-- Core loop: tapping
-- ----------------------------------------------------------------------------

function GameService.handleClick(player: Player, source: string?)
	local data = DataManager.data(player)
	if not data then
		return
	end

	local now = os.clock()
	local combo = combos[player]
	if not combo or (now - combo.last) > Constants.CLICK.COMBO_WINDOW then
		combo = { count = 0, last = now }
		combos[player] = combo
	end

	combo.count += 1
	combo.last = now

	local multiplier = Economy.comboMultiplier(combo.count)
	local gain = math.max(1, math.floor(Economy.tapPower(player, multiplier)))

	DataManager.add(player, "Power", gain)
	data.Stats.Clicks += 1

	if source == "world" then
		data.Stats.WorldTaps = (data.Stats.WorldTaps or 0) + 1
	end

	DataManager.markDirty(player)
	Economy.publish(player)
	QuestService.progress(player, Quests.Types.CLICK, 1)
end

-- ----------------------------------------------------------------------------
-- Core loop: selling
-- ----------------------------------------------------------------------------

function GameService.handleSell(player: Player)
	local data = DataManager.data(player)
	if not data then
		return
	end

	if data.Power < 1 then
		Notifier.toast(player, "No power to sell - tap the cube first!", "bad", "power")
		return
	end

	local now = os.clock()
	if (sellCooldown[player] or 0) > now then
		return
	end
	sellCooldown[player] = now + Constants.SELL.COOLDOWN

	local power = math.floor(data.Power)
	local coins = math.floor(power * Economy.sellMultiplier(player))

	data.Power = 0
	DataManager.add(player, "Coins", coins)
	data.Stats.TotalEarned += coins
	data.Stats.Sales += 1

	DataManager.markDirty(player)
	Economy.publish(player)
	Notifier.sale(player, power, coins)

	QuestService.progress(player, Quests.Types.SELL, power)
	QuestService.progress(player, Quests.Types.EARN, coins)
end

-- ----------------------------------------------------------------------------
-- Upgrades
-- ----------------------------------------------------------------------------

function GameService.handleBuyUpgrade(player: Player, trackId: string)
	local track = Upgrades.get(trackId)
	if not track then
		Notifier.toast(player, "Unknown upgrade", "bad")
		return
	end

	local data = DataManager.data(player)
	if not data then
		return
	end

	local level = Upgrades.clampLevel(track, data.Upgrades[trackId])
	if level >= track.MaxLevel then
		Notifier.toast(player, `{track.Name} is already maxed out!`, "bad", track.Icon)
		return
	end

	local cost = Upgrades.cost(track, level)
	if not DataManager.spend(player, cost) then
		Notifier.toast(player, `You need {Utils.comma(cost)} coins`, "bad", "coin")
		return
	end

	data.Upgrades[trackId] = level + 1
	data.Stats.Upgrades += 1

	DataManager.markDirty(player)
	Economy.publish(player)		Notifier.toast(player, `{track.Name} upgraded to Lv{level + 1}!`, "good", track.Icon)

	QuestService.progress(player, Quests.Types.UPGRADE, 1)
	GameService.pushState(player)
end

-- ----------------------------------------------------------------------------
-- Pets (request layer in front of PetService)
-- ----------------------------------------------------------------------------

function GameService.handleHatch(player: Player, eggName: string, count: number?)
	local result, reason = PetService.hatch(player, eggName, count)
	if not result then
		Notifier.toast(player, reason or "That hatch failed", "bad", "egg")
		return
	end

	Economy.publish(player)
	Notifier.hatch(player, result)
	QuestService.progress(player, Quests.Types.HATCH, #result.Results)

	if result.IsNew then
		GameService.pushState(player)
	end
end

function GameService.handleEquip(player: Player, petId: string)
	local ok, reason = PetService.equip(player, petId)
	if not ok then
		if reason and reason ~= "Already equipped" then
			Notifier.toast(player, reason, "bad", "pet")
		end
		return
	end

	QuestService.progress(player, Quests.Types.EQUIP, 1)
	GameService.pushState(player)
end

function GameService.handleUnequip(player: Player, petId: string)
	local ok, reason = PetService.unequip(player, petId)
	if not ok then
		if reason then
			Notifier.toast(player, reason, "bad", "pet")
		end
		return
	end
	GameService.pushState(player)
end

function GameService.handleSellPet(player: Player, petId: string)
	local value, reason = PetService.sell(player, petId)
	if not value then
		Notifier.toast(player, reason or "That pet could not be sold", "bad", "pet")
		return
	end

	Notifier.toast(player, `Pet sold for {Utils.comma(value)} coins`, "info", "coin")
	GameService.pushState(player)
end

-- ----------------------------------------------------------------------------
-- Index (collection) rewards
-- ----------------------------------------------------------------------------

function GameService.handleClaimIndex(player: Player, eggName: string)
	local data = DataManager.data(player)
	if not data then
		return
	end

	if eggName == "__final" then
		if data.IndexClaimed["__final"] then
			return
		end
		if not GameService.indexComplete(player) then
			Notifier.toast(player, "Discover every pet before claiming the final reward", "bad", "index")
			return
		end
		data.IndexClaimed["__final"] = true
		Rewards.celebrate(player, "FULL INDEX COMPLETE", "You discovered every pet in the game", {
			Coins = Pets.IndexFinal.Coins,
			Pet = Pets.IndexFinal.Pet,
			PetEgg = "Prismatic Egg",
			Luck = Pets.IndexFinal.Luck,
			LuckMinutes = Pets.IndexFinal.LuckMinutes,
		}, "crown")
		DataManager.markDirty(player)
		GameService.pushState(player)
		return
	end

	local egg = Pets.getEgg(eggName)
	if not egg then
		return
	end
	if data.IndexClaimed[egg.Name] then
		return
	end

	local found, required = 0, 0
	for _, pet in ipairs(egg.Pets) do
		if pet.Rarity ~= "Secret" then
			required += 1
			if data.Index[pet.Name] then
				found += 1
			end
		end
	end

	if found < required then
		Notifier.toast(player, `{found}/{required} {egg.Name} pets discovered`, "bad", "index")
		return
	end

	data.IndexClaimed[egg.Name] = true
	local reward = Pets.IndexRewards[egg.Name] or { Coins = egg.Cost * 10 }
	Rewards.celebrate(player, `{egg.Name} complete!`, "Every pet in this egg discovered", reward, "rank")

	DataManager.markDirty(player)
	GameService.pushState(player)
end

-- ----------------------------------------------------------------------------
-- Daily streak
-- ----------------------------------------------------------------------------

function GameService.handleClaimDaily(player: Player)
	local data = DataManager.data(player)
	if not data then
		return
	end

	local today = Utils.dayKey()
	if data.Daily.Day == today then
		Notifier.toast(player, "Daily already claimed - come back tomorrow!", "bad", "daily")
		return
	end

	local yesterday = Utils.dayKey(os.time() - 86400)
	data.Daily.Streak = if data.Daily.Day == yesterday
		then math.min(data.Daily.Streak + 1, Constants.DAILY.STREAK_MAX)
		else 1
	data.Daily.Day = today

	local streak = data.Daily.Streak
	local coins = math.max(
		math.floor(Constants.DAILY.BASE_COINS * (1 + Constants.DAILY.GROWTH_PER_STREAK * (streak - 1))),
		math.floor(Economy.incomePerSecond(player) * 90)
	)

	local reward: any = { Coins = coins }
	local title = "Daily Reward"
	local subtitle = `Day {streak} streak`

	if streak >= Constants.DAILY.STREAK_MAX then
		local egg = GameService.bestUnlockedEgg(player)
		local definition = if egg then Pets.roll(egg.Name, 0, Random.new()) else nil
		if definition then
			reward.Pet = definition.Name
			reward.PetEgg = egg.Name
			title = "STREAK REWARD!"
			subtitle = `Day {streak} - free {definition.Rarity} pet`
		end
		data.Daily.Streak = 0 -- start the next 7 day cycle
	end

	Rewards.celebrate(player, title, subtitle, reward, "daily")
	DataManager.markDirty(player)
	GameService.pushState(player)
end

-- ----------------------------------------------------------------------------
-- Auto-farm + offline earnings
-- ----------------------------------------------------------------------------

function GameService.startAutoFarm()
	task.spawn(function()
		while true do
			task.wait(Constants.AUTOFARM.TICK)
			for _, player in ipairs(Players:GetPlayers()) do
				local data = DataManager.data(player)
				if data then
					local rate = Economy.autoRate(player)
					if rate > 0 then
						DataManager.add(player, "Power", rate * Constants.AUTOFARM.TICK)
						DataManager.markDirty(player)
						Economy.publish(player)
					end
				end
			end
		end
	end)
end

--[[
	Called once right after a player's data loads: pays out what their auto-farm
	would have produced while they were away (at OFFLINE.EFFICIENCY).
]]
function GameService.applyOfflineEarnings(player: Player)
	local data = DataManager.data(player)
	if not data then
		return
	end

	local seconds = data.OfflineSeconds or 0
	data.OfflineSeconds = 0
	if seconds < Constants.OFFLINE.MIN_SECONDS then
		return
	end

	local coins = math.floor(Economy.incomePerSecond(player) * seconds * Constants.OFFLINE.EFFICIENCY)
	if coins < 1 then
		return
	end

	DataManager.add(player, "Coins", coins)
	data.Stats.TotalEarned += coins
	DataManager.markDirty(player)
	Economy.publish(player)
	Notifier.offline(player, coins, seconds)
end

function GameService.clearPlayer(player: Player)
	combos[player] = nil
	sellCooldown[player] = nil
end

return GameService
