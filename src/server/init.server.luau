--[[
	init.server
	The boot sequence, and the only place where remote events are connected.

	Order matters:
		1. Net.ensure()          - publish the remote set the client waits for
		2. Notifier.setup()      - point every message at those remotes
		3. World.build()         - build the plaza (uses Notifier for prompts)
		4. player lifecycle      - load -> grant -> publish -> save

	Every request handler follows the same shape:
		validated argument -> RateLimiter.guard -> service -> push fresh state

	The server is authoritative at all times: the client can only ask, and every
	ask is rate limited and re-validated against save data. Changing a number in
	Constants.LUAU rebalances the whole game, because nothing here hardcodes math.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Net = require(ReplicatedStorage.Shared.Net)

local CodeService = require(script.CodeService)
local DataManager = require(script.DataManager)
local Economy = require(script.Economy)
local GameService = require(script.GameService)
local LeaderboardService = require(script.LeaderboardService)
local Leaderstats = require(script.Leaderstats)
local MarketplaceManager = require(script.MarketplaceManager)
local Notifier = require(script.Notifier)
local Passes = require(script.Passes)
local PetService = require(script.PetService)
local QuestService = require(script.QuestService)
local RateLimiter = require(script.RateLimiter)
local RebirthService = require(script.RebirthService)
local World = require(script.World)

-- ----------------------------------------------------------------------------
-- 1-3. Boot
-- ----------------------------------------------------------------------------

local remotes = Net.ensure()
Notifier.setup(remotes)
World.build()

print(`[Server] {Constants.TITLE} v{Constants.VERSION} starting`)

-- ----------------------------------------------------------------------------
-- Input validation (never trust a remote argument)
-- ----------------------------------------------------------------------------

local MAX_ID_LENGTH = 64

local function asId(value: any): string?
	if type(value) ~= "string" or #value == 0 or #value > MAX_ID_LENGTH then
		return nil
	end
	return value
end

local function asCount(value: any): number
	if type(value) ~= "number" or value ~= value then
		return 1
	end
	return math.clamp(math.floor(value), 1, 100)
end

-- ----------------------------------------------------------------------------
-- Request plumbing
-- ----------------------------------------------------------------------------

-- Wraps one remote: players whose save is still loading are ignored, so no
-- handler ever has to null-check DataManager.
local function on(name: string, handler: (Player, ...any) -> ())
	local remote = remotes[name]
	if not remote then
		warn(`[Server] no remote named {name} - skipped`)
		return
	end

	remote.OnServerEvent:Connect(function(player: Player, ...)
		if not DataManager.isLoaded(player) then
			return
		end
		handler(player, ...)
	end)
end

local function guard(player: Player, key: string, rate: number, burst: number, handler: () -> ())
	RateLimiter.guard(player, key, rate, burst, handler)
end

-- ----------------------------------------------------------------------------
-- Core loop
-- ----------------------------------------------------------------------------

on("Click", function(player: Player)
	guard(player, "Click", Constants.CLICK.RATE, Constants.CLICK.BURST, function()
		GameService.handleClick(player, "ui")
	end)
end)

on("Sell", function(player: Player)
	guard(player, "Sell", 3, 6, function()
		GameService.handleSell(player)
	end)
end)

on("BuyUpgrade", function(player: Player, trackId: any)
	local id = asId(trackId)
	if not id then
		return
	end
	guard(player, "BuyUpgrade", 10, 20, function()
		GameService.handleBuyUpgrade(player, id)
	end)
end)

-- ----------------------------------------------------------------------------
-- Pets
-- ----------------------------------------------------------------------------

on("Hatch", function(player: Player, eggName: any, count: any)
	local id = asId(eggName)
	if not id then
		return
	end
	guard(player, "Hatch", 6, 12, function()
		GameService.handleHatch(player, id, asCount(count))
	end)
end)

on("Equip", function(player: Player, petId: any)
	local id = asId(petId)
	if not id then
		return
	end
	guard(player, "Equip", 12, 24, function()
		GameService.handleEquip(player, id)
	end)
end)

on("Unequip", function(player: Player, petId: any)
	local id = asId(petId)
	if not id then
		return
	end
	guard(player, "Equip", 12, 24, function()
		GameService.handleUnequip(player, id)
	end)
end)

on("SellPet", function(player: Player, petId: any)
	local id = asId(petId)
	if not id then
		return
	end
	guard(player, "SellPet", 8, 16, function()
		GameService.handleSellPet(player, id)
	end)
end)

on("ClaimIndex", function(player: Player, eggName: any)
	local id = asId(eggName)
	if not id then
		return
	end
	guard(player, "ClaimIndex", 2, 4, function()
		GameService.handleClaimIndex(player, id)
	end)
end)

-- ----------------------------------------------------------------------------
-- Progression
-- ----------------------------------------------------------------------------

on("Rebirth", function(player: Player)
	guard(player, "Rebirth", 1, 2, function()
		local ok, reason = RebirthService.rebirth(player)
		if not ok then
			Notifier.toast(player, reason or "Rebirth failed", "bad", "rebirth")
			return
		end
		LeaderboardService.publish(player)
		GameService.pushState(player)
	end)
end)

on("ClaimQuest", function(player: Player, questId: any)
	local id = asId(questId)
	if not id then
		return
	end
	guard(player, "ClaimQuest", 4, 8, function()
		local ok, reason = QuestService.claim(player, id)
		if not ok then
			Notifier.toast(player, reason or "Cannot claim that quest", "bad", "check")
			return
		end
		GameService.pushState(player)
	end)
end)

on("RerollQuests", function(player: Player)
	guard(player, "RerollQuests", 1, 2, function()
		local ok, reason = QuestService.reroll(player)
		if not ok then
			Notifier.toast(player, reason or "No rerolls left", "bad", "reroll")
		end
	end)
end)

on("ClaimDaily", function(player: Player)
	guard(player, "ClaimDaily", 1, 2, function()
		GameService.handleClaimDaily(player)
	end)
end)

on("RedeemCode", function(player: Player, code: any)
	CodeService.handle(player, code)
end)

-- ----------------------------------------------------------------------------
-- Replication + monetization
-- ----------------------------------------------------------------------------

on("RequestState", function(player: Player)
	guard(player, "RequestState", 2, 6, function()
		GameService.pushState(player)
		QuestService.publish(player)
	end)
end)

on("RequestLeaderboard", function(player: Player)
	guard(player, "RequestLeaderboard", 1, 3, function()
		LeaderboardService.handleRequest(player)
	end)
end)

on("PromptPass", function(player: Player, passKey: any)
	local id = asId(passKey)
	if not id then
		return
	end
	guard(player, "Prompt", 1, 3, function()
		MarketplaceManager.promptPass(player, id)
	end)
end)

on("PromptProduct", function(player: Player, productKey: any)
	local id = asId(productKey)
	if not id then
		return
	end
	guard(player, "Prompt", 1, 3, function()
		MarketplaceManager.promptProduct(player, id)
	end)
end)

-- ----------------------------------------------------------------------------
-- Player lifecycle
-- ----------------------------------------------------------------------------

local function onPlayerAdded(player: Player)
	Leaderstats.initialize(player)
	player:SetAttribute("Loading", true)

	task.spawn(function()
		local data = DataManager.load(player)
		if not data then
			-- DataManager already kicked them with a readable reason.
			return
		end

		-- Everything derived from the raw save, in dependency order.
		PetService.publishFollowers(player)
		Economy.publish(player)
		QuestService.ensure(player)
		GameService.applyOfflineEarnings(player)

		-- Passes are an async web call, so they land a moment later.
		task.spawn(function()
			Passes.refresh(player)
			Economy.publish(player)
		end)

		GameService.pushState(player)
		QuestService.publish(player)

		player:SetAttribute("Loading", false)
		Notifier.toast(player, `Welcome back, {player.DisplayName}!`, "info", "star")
		Notifier.toast(player, "Codes are live - try DREAMBIG and ONEMORETRY", "gold", "code")
	end)
end

local function onPlayerRemoving(player: Player)
	GameService.clearPlayer(player)
	RateLimiter.clear(player)
	Passes.clear(player)
	-- Saves and releases the session lock so a quick rejoin never waits.
	DataManager.release(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

-- Autosave, auto-farm income, and the global leaderboard publisher.
DataManager.startAutosave()
GameService.startAutoFarm()
LeaderboardService.start()

game:BindToClose(function()
	DataManager.saveAll(true)
end)

print("[Server] ready")
