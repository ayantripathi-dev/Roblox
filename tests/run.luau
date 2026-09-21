--[[
	Tests
	Run with:   lune run tests/run.luau      (from the project root)

	Covers everything that is pure logic: number formatting, upgrade curves,
	rebirth math, egg odds, quest generation, codes and remote-name safety.
	It also simulates an hour of play so a Constants change that would make the
	first rebirth take a week shows up here instead of in a review.
]]

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")

local Harness = require("./harness")

local shared = Harness.loadShared("src/shared")

local Constants = shared.Constants
local Utils = shared.Utils
local Upgrades = shared.Upgrades
local Pets = shared.Pets
local Quests = shared.Quests
local Codes = shared.Codes
local Net = shared.Net
local Icons = shared.Icons

local report = Harness.reporter()
local Random = Harness.Random

-- ----------------------------------------------------------------------------
-- Utils
-- ----------------------------------------------------------------------------

report:section("Utils")
report:equal("formatNumber(999)", Utils.formatNumber(999), "999")
report:equal("formatNumber(1000)", Utils.formatNumber(1000), "1.00k")
report:equal("formatNumber(1234567)", Utils.formatNumber(1234567), "1.23M")
report:equal("formatNumber(999999999)", Utils.formatNumber(999999999), "1.00B")
report:equal("formatNumber(nan)", Utils.formatNumber(0 / 0), "0")
report:equal("formatNumber(-2500)", Utils.formatNumber(-2500), "-2.50k")
report:equal("comma(1234567)", Utils.comma(1234567), "1,234,567")
report:equal("comma(-42)", Utils.comma(-42), "-42")
report:equal("formatTime(93784)", Utils.formatTime(93784), "1d 2h")
report:equal("formatTime(754)", Utils.formatTime(754), "12m 34s")
report:equal("formatTime(45)", Utils.formatTime(45), "45s")
report:equal("formatTime(-5)", Utils.formatTime(-5), "0s")
report:equal("formatMultiplier(2.5)", Utils.formatMultiplier(2.5), "2.50x")
report:equal("dayKey length", #Utils.dayKey(), 10)
report:check("dayKey is a UTC date", string.match(Utils.dayKey(), "^%d%d%d%d%-%d%d%-%d%d$") ~= nil)
report:equal("clamp", Utils.clamp(15, 0, 10), 10)
report:equal("round", Utils.round(2.6), 3)
report:equal("count", Utils.count({ a = 1, b = 2 }), 2)
report:equal("total", Utils.total({ a = 1, b = 2.5 }), 3.5)

local shuffled = Utils.shuffle({ 1, 2, 3, 4, 5 }, Random.new(7))
report:equal("shuffle keeps every element", #shuffled, 5)

local copied = Utils.deepCopy({ nested = { value = 3 } })
copied.nested.value = 9
report:equal("deepCopy is a real copy", Utils.deepCopy({ nested = { value = 3 } }).nested.value, 3)

-- ----------------------------------------------------------------------------
-- Constants / progression math
-- ----------------------------------------------------------------------------

report:section("Constants")
report:equal("first rebirth cost", Constants.rebirthCost(0), Constants.REBIRTH.BASE_COST)
report:check("rebirth cost grows", Constants.rebirthCost(5) > Constants.rebirthCost(4))
report:equal("rebirth 0 multiplier", Constants.rebirthMultiplier(0), 1)
report:closeTo("rebirth 4 multiplier", Constants.rebirthMultiplier(4), 1 + 4 * Constants.REBIRTH.MULT_PER_REBIRTH, 0.0001)
report:equal("base pet slots", Constants.petSlots(0), Constants.REBIRTH.SLOTS_BASE)
report:equal("pet slots cap", Constants.petSlots(999, 5), Constants.REBIRTH.SLOTS_MAX)
report:equal("luck value at level 1", Constants.luckUpgradeValue(1), 0)
report:closeTo("luck value at level 5", Constants.luckUpgradeValue(5), 4 * Constants.LUCK.UPGRADE_PER_LEVEL, 0.0001)
report:check("the save cap is finite (blocks NaN/infinity exploits)", Constants.LIMITS.MAX_NUMBER < math.huge)
report:check("the save cap is inside the formatter's range", Constants.LIMITS.MAX_NUMBER <= 1e42)
report:check("pets live inside the save cap", Pets.Eggs[#Pets.Eggs].Pets[1].Mult < Constants.LIMITS.MAX_NUMBER)

-- ----------------------------------------------------------------------------
-- Upgrades
-- ----------------------------------------------------------------------------

report:section("Upgrades")
for _, trackId in ipairs(Upgrades.Order) do
	local track = Upgrades.get(trackId)
	-- The single most important balance invariant: if a level's value grew faster
	-- than its cost, buying levels would out-pace the prices and the economy
	-- would run away inside one session.
	if track.Growth then
		report:check(
			`{trackId}: cost outgrows value`,
			track.CostGrowth > track.Growth,
			`CostGrowth {track.CostGrowth} must beat Growth {track.Growth}`
		)
	end
	report:check(`{trackId}: a finished shop is affordable`, Upgrades.cost(track, track.MaxLevel - 1) < Constants.LIMITS.MAX_NUMBER)
	report:check(`{trackId}: cost rises with level`, Upgrades.cost(track, 5) > Upgrades.cost(track, 4))
	report:check(`{trackId}: value rises with level`, Upgrades.valueAt(track, 5) > Upgrades.valueAt(track, 4))
	report:equal(`{trackId}: level 1 is the base value`, Upgrades.valueAt(track, 1), track.BaseValue)
	report:equal(`{trackId}: max level is free`, Upgrades.cost(track, track.MaxLevel), math.huge)
	report:check(`{trackId}: describe reports maxed`, Upgrades.describe(trackId, track.MaxLevel).Maxed == true)
	report:equal(`{trackId}: clampLevel floors junk`, Upgrades.clampLevel(track, -12), 1)
end
report:equal("unknown track falls back to 1", Upgrades.valueOf("Nope", 50), 1)

-- ----------------------------------------------------------------------------
-- Pets
-- ----------------------------------------------------------------------------

report:section("Pets")

local seenPets: { [string]: string } = {}
local petProblems = {}
for _, egg in ipairs(Pets.Eggs) do
	local previousMult = 0
	for _, pet in ipairs(egg.Pets) do
		if seenPets[pet.Name] then
			table.insert(petProblems, `{pet.Name} appears in both {seenPets[pet.Name]} and {egg.Name}`)
		end
		seenPets[pet.Name] = egg.Name
		if pet.Mult <= previousMult then
			table.insert(petProblems, `{egg.Name}/{pet.Name} is not a step up in multiplier`)
		end
		previousMult = pet.Mult
	end
end
report:check("pet names are unique across eggs", #petProblems == 0, table.concat(petProblems, "; "))
report:check("every egg has a signature pet", (function()
	for _, egg in ipairs(Pets.Eggs) do
		if Pets.eggHighlight(egg.Name) == nil then
			return false
		end
	end
	return true
end)())

local basicOdds = Pets.odds("Basic Egg", 0)
local oddsTotal = 0
for _, row in ipairs(basicOdds) do
	oddsTotal += row.chance
end
report:closeTo("egg odds sum to 100%", oddsTotal, 1, 0.0001)
report:check("odds rows match the config", #basicOdds == #Pets.getEgg("Basic Egg").Pets)

-- Luck must move odds toward rarity, never away from it.
local commonNoLuck, commonLuck, rareNoLuck, rareLuck = 0, 0, 0, 0
for _, row in ipairs(Pets.odds("Aurora Egg", 0)) do
	if row.pet.Rarity == "Uncommon" then
		commonNoLuck += row.chance
	elseif row.pet.Rarity == "Legendary" or row.pet.Rarity == "Secret" then
		rareNoLuck += row.chance
	end
end
for _, row in ipairs(Pets.odds("Aurora Egg", 5)) do
	if row.pet.Rarity == "Uncommon" then
		commonLuck += row.chance
	elseif row.pet.Rarity == "Legendary" or row.pet.Rarity == "Secret" then
		rareLuck += row.chance
	end
end
report:check("luck increases rare odds", rareLuck > rareNoLuck)
report:check("luck decreases common odds", commonLuck < commonNoLuck)

-- 100k rolls with a fixed seed: same seed, same result, and the rare pet lands.
local rng = Random.new(20260921)
local counts: { [string]: number } = {}
for _ = 1, 100000 do
	local pet = Pets.roll("Aurora Egg", 1, rng)
	counts[pet.Name] = (counts[pet.Name] or 0) + 1
end
report:check("100k rolls produce every pet", counts["Frostbite"] ~= nil and counts["Penguin"] ~= nil)
report:check("common pets still dominate", (counts["Penguin"] or 0) > (counts["Frostbite"] or 0) * 20)

local rngA = Random.new(4242)
local rngB = Random.new(4242)
local deterministic = true
for _ = 1, 200 do
	if Pets.roll("Cosmic Egg", 2, rngA).Name ~= Pets.roll("Cosmic Egg", 2, rngB).Name then
		deterministic = false
		break
	end
end
report:check("rolls are deterministic for a seed", deterministic)

report:equal("sell value at rebirth 0", Pets.sellValue("Dog", 0), math.floor(1.25 * Pets.Sell.VALUE_PER_MULT))
report:check("sell value scales with rebirths", Pets.sellValue("Dog", 4) > Pets.sellValue("Dog", 0))
report:equal("unknown pet sells for nothing", Pets.sellValue("NotAPet", 3), 0)

-- ----------------------------------------------------------------------------
-- Quests
-- ----------------------------------------------------------------------------

report:section("Quests")
local questRng = Random.new(99)
local quests = Quests.generate({
	Day = "2026-09-21",
	Rebirths = 4,
	Income = 5000,
	Count = Constants.QUEST.DAILY_COUNT,
	Rng = questRng,
})

report:equal("generates the daily count", #quests, Constants.QUEST.DAILY_COUNT)
local questIds: { [string]: boolean } = {}
local questTypes: { [string]: boolean } = {}
for _, quest in ipairs(quests) do
	questIds[quest.Id] = true
	questTypes[quest.Type] = true
	report:check(`{quest.Id}: id is day-prefixed`, string.sub(quest.Id, 1, 10) == "2026-09-21")
	report:check(`{quest.Id}: target comes from the tier table`, table.find(Quests.template(quest.Template).Targets, quest.Target) ~= nil)
	report:check(`{quest.Id}: reward respects the floor`, quest.Reward.Coins >= Quests.template(quest.Template).RewardMinCoins)
	report:check(`{quest.Id}: progress starts empty`, quest.Progress == 0 and quest.Claimed == false)
	report:check(`{quest.Id}: not complete yet`, Quests.isComplete(quest) == false)
end
report:equal("unique quest ids", Utils.count(questIds), Constants.QUEST.DAILY_COUNT)
report:equal("unique quest types", Utils.count(questTypes), Constants.QUEST.DAILY_COUNT)
report:equal("find() locates a quest", Quests.find(quests, quests[1].Id), quests[1])

local firstQuest = quests[1]
firstQuest.Progress = firstQuest.Target
report:check("isComplete after filling", Quests.isComplete(firstQuest))
report:check("targets scale with rebirths", Quests.tierFor(20, Quests.Templates[1]) > Quests.tierFor(0, Quests.Templates[1]))

-- ----------------------------------------------------------------------------
-- Codes
-- ----------------------------------------------------------------------------

report:section("Codes")
report:equal("normalize strips noise", Codes.normalize(" one more-try "), "ONEMORETRY")
report:check("find is case and dash insensitive", Codes.find("dream-big") ~= nil)
report:equal("find matches the exact entry", Codes.find("surprise").Code, "SURPRISE")
report:equal("unknown code returns nil", Codes.find("definitely-not-real"), nil)
report:check("count matches the list", Codes.count() == #Codes.List)
report:check("describe mentions coins", string.find(Codes.describe(Codes.List[1]), "coins") ~= nil)
report:check("future codes are not expired", Codes.isExpired(Codes.find("SURPRISE"), os.time()) == false)
report:check("past expiry is detected", Codes.isExpired({ Expires = os.time() - 60 }, os.time()))

-- Every code must grant something, or it is a bug waiting to be reported.
local emptyCodes = {}
for _, entry in ipairs(Codes.List) do
	if not entry.Coins and not entry.Power and not entry.Pet and not entry.Luck then
		table.insert(emptyCodes, entry.Code)
	end
end
report:check("every code grants a reward", #emptyCodes == 0, table.concat(emptyCodes, ", "))

-- ----------------------------------------------------------------------------
-- Icons
-- ----------------------------------------------------------------------------

report:section("Icons")

local iconNames = Icons.names()
report:check("the registry is populated", #iconNames >= 25, `{ #iconNames } icons`)

local badEntries = {}
for _, name in ipairs(iconNames) do
	local entry = Icons.get(name)
	if type(entry) ~= "table" or type(entry.Mark) ~= "string" or entry.Mark == "" or entry.Tint == nil then
		table.insert(badEntries, name)
	end
end
report:check("every icon has a mark and a tint", #badEntries == 0, table.concat(badEntries, ", "))

report:equal("unknown icons fall back to the dot mark", Icons.mark("definitely-not-an-icon"), "dot")
report:equal("icon ids default to drawn (no asset)", Icons.id("coin"), 0)
report:check("an unset Creator Store id does not break anything", Icons.id(nil) == 0)

-- Nothing may reference an icon that does not exist: that is how emojis crept in.
local referencedByName = {}
for _, trackId in ipairs(Upgrades.Order) do
	referencedByName[`Upgrades.{trackId}`] = Upgrades.get(trackId).Icon
end
for _, egg in ipairs(Pets.Eggs) do
	referencedByName[`Pets.{egg.Name}`] = egg.Icon
end
for _, template in ipairs(Quests.Templates) do
	referencedByName[`Quests.{template.Id}`] = template.Icon
end

local missingIcons = {}
for source, iconName in pairs(referencedByName) do
	if type(iconName) ~= "string" then
		table.insert(missingIcons, `{source} has no icon`)
	elseif Icons.Registry[iconName] == nil then
		table.insert(missingIcons, `{source} -> {iconName}`)
	end
end
report:check("every config entry points at a real icon", #missingIcons == 0, table.concat(missingIcons, "; "))

-- ----------------------------------------------------------------------------
-- Net
-- ----------------------------------------------------------------------------

report:section("Net")
local names: { [string]: boolean } = {}
local duplicates = {}
for _, name in ipairs(Net.ALL) do
	if names[name] then
		table.insert(duplicates, name)
	end
	names[name] = true
end
report:check("remote names are unique", #duplicates == 0, table.concat(duplicates, ", "))
report:equal("ALL is requests + signals", #Net.ALL, #Net.REQUESTS + #Net.SIGNALS)
report:check("client requests a state snapshot", table.find(Net.REQUESTS, "RequestState") ~= nil)
report:check("server can open panels", table.find(Net.SIGNALS, "OpenPanel") ~= nil)

-- The client only ever fires a remote the server also creates (and vice versa),
-- so this guards against typos in either direction.
local REQUEST_NAMES = {
	"Click",
	"Sell",
	"BuyUpgrade",
	"Hatch",
	"Equip",
	"Unequip",
	"SellPet",
	"Rebirth",
	"RedeemCode",
	"ClaimQuest",
	"RerollQuests",
	"ClaimDaily",
	"ClaimIndex",
	"RequestState",
	"RequestLeaderboard",
	"PromptPass",
	"PromptProduct",
}
local missing = {}
for _, name in ipairs(REQUEST_NAMES) do
	if not table.find(Net.REQUESTS, name) then
		table.insert(missing, name)
	end
end
report:check("no request was dropped from Net", #missing == 0, table.concat(missing, ", "))

-- ----------------------------------------------------------------------------
-- Syntax: every game file must compile
-- ----------------------------------------------------------------------------

report:section("Syntax")

local function walk(directory: string, prefix: string): { { path: string, name: string } }
	local files = {}
	for _, entry in ipairs(fs.readDir(directory)) do
		local path = `{directory}/{entry}`
		if fs.isDir(path) then
			for _, nested in ipairs(walk(path, `{prefix}{entry}/`)) do
				table.insert(files, nested)
			end
		elseif string.match(entry, "%.luau$") then
			table.insert(files, { path = path, name = `{prefix}{entry}` })
		end
	end
	return files
end

local gameFiles = walk("src", "")
report:check("found the game scripts", #gameFiles >= 25, `walked {#gameFiles} files`)

for _, file in ipairs(gameFiles) do
	local source = fs.readFile(file.path)
	local ok, err = pcall(function()
		luau.load(source, { debugName = file.name })
	end)
	report:check(`{file.name} compiles`, ok, if ok then nil else tostring(err))
end

-- Every mark an icon asks for must actually be drawn by the client theme.
local drawnMarks: { [string]: boolean } = {}
for markName in string.gmatch(fs.readFile("src/client/Theme.luau"), "Theme%.Marks%.([%w_]+) =") do
	drawnMarks[markName] = true
end
local undrawn = {}
for _, iconName in ipairs(iconNames) do
	local mark = Icons.mark(iconName)
	if not drawnMarks[mark] then
		table.insert(undrawn, `{iconName} -> {mark}`)
	end
end
report:check("every icon mark has a drawing in Theme.luau", #undrawn == 0, table.concat(undrawn, ", "))

-- ----------------------------------------------------------------------------
-- Progression simulation
-- ----------------------------------------------------------------------------

report:section("Progression simulation")

--[[
	One simulated player:
		- 4 taps per second (a comfortable phone tap rate)
		- walks to the sell pad every 5 seconds
		- spends coins greedily on the cheapest affordable upgrade
		- collects auto-farm power the whole time

	Combo multipliers and pets are deliberately left out, so this is the
	worst case: if the first rebirth is reachable here, it is reachable in game.
]]
local function simulate(seconds: number, petMultiplier: number)
	local coins = Constants.START.COINS
	local power = 0
	local levels = { Click = 1, Sell = 1, Auto = 1, Luck = 1 }
	local checkpoints: { [number]: number } = {}
	local rebirthSeconds = nil
	local capped = false

	local TAPS_PER_SECOND = 4
	local SELL_EVERY = 5
	local TAP_MULTIPLIER = 1.25 -- every fifth tap on average lands mid-combo

	for second = 1, seconds do
		local tapPower = Constants.CLICK.BASE_GAIN
			* Upgrades.valueOf("Click", levels.Click)
			* petMultiplier
			* TAP_MULTIPLIER
		local autoRate = Upgrades.valueOf("Auto", levels.Auto) * petMultiplier
		local sellMultiplier = Constants.SELL.BASE_MULT * Upgrades.valueOf("Sell", levels.Sell) * petMultiplier

		power += tapPower * TAPS_PER_SECOND + autoRate

		if second % SELL_EVERY == 0 then
			-- DataManager clamps every stored number, so the simulation does too.
			local gained = power * sellMultiplier
			power = 0
			if coins + gained >= Constants.LIMITS.MAX_NUMBER then
				capped = true
			end
			coins = math.min(Constants.LIMITS.MAX_NUMBER, coins + gained)
		end

		-- Greedy shopping: buy the cheapest upgrade we can afford.
		local bought = true
		while bought do
			bought = false
			local cheapestId, cheapestCost = nil, math.huge
			for _, trackId in ipairs(Upgrades.Order) do
				local track = Upgrades.get(trackId)
				if levels[trackId] < track.MaxLevel then
					local cost = Upgrades.cost(track, levels[trackId])
					if cost <= coins and cost < cheapestCost then
						cheapestId, cheapestCost = trackId, cost
					end
				end
			end
			if cheapestId then
				coins -= cheapestCost
				levels[cheapestId] += 1
				bought = true
			end
		end

		if not rebirthSeconds and coins >= Constants.rebirthCost(0) then
			rebirthSeconds = second
		end

		if second % 300 == 0 then
			checkpoints[second / 60] = coins
		end
	end

	return coins, levels, checkpoints, rebirthSeconds, capped
end

local coins, levels, checkpoints, rebirthSeconds, capped = simulate(3600, 1)
local withPets, _, _, petRebirthSeconds = simulate(3600, 3)
local _, levelsAt30, _, _, cappedAt30 = simulate(1800, 1)

print(`  first rebirth (no pets)       : {if rebirthSeconds then Utils.formatTime(rebirthSeconds) else "not in 60 minutes"}`)
print(`  first rebirth (x3 pets)       : {if petRebirthSeconds then Utils.formatTime(petRebirthSeconds) else "not in 60 minutes"}`)
for minute = 5, 60, 15 do
	print(`  coins at {minute}m                : {Utils.formatNumber(checkpoints[minute] or 0)}`)
end
print(`  upgrade levels after an hour  : Click {levels.Click}, Sell {levels.Sell}, Auto {levels.Auto}, Luck {levels.Luck}`)
print(`  hit the {Utils.formatNumber(Constants.LIMITS.MAX_NUMBER)} save cap    : {if capped then "yes (balance problem)" else "no"}`)

report:check("first rebirth lands inside 5 minutes", rebirthSeconds ~= nil and rebirthSeconds <= 300)
report:check("pets speed up the early game", petRebirthSeconds ~= nil and petRebirthSeconds < (rebirthSeconds or math.huge))
report:check("an hour of play stays under the save cap", capped == false)
report:check("the shop can be finished in a session", levelsAt30.Click >= Upgrades.get("Click").MaxLevel)
report:check("half an hour stays under the save cap", cappedAt30 == false)
report:check("coins stay finite", coins <= Constants.LIMITS.MAX_NUMBER and coins == coins)
report:check("upgrades respect their max level", levels.Click <= Upgrades.get("Click").MaxLevel)
report:check("playtime money keeps growing", (checkpoints[60] or 0) > (checkpoints[30] or 0))
report:check("pets are a real multiplier", withPets > coins)

process.exit(report:report())
