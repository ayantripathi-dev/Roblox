--[[
	init.client
	Boots the interface and connects the server to it.

	The flow:
		1. wait for the server's remote set (Net)
		2. wait until our save is live (the Coins attribute appears)
		3. build the HUD, the panels and the follower renderer
		4. route every signal to the piece of UI that renders it

	The client never invents game state: it renders player attributes and
	StateSnapshots. That is why two players always see the same numbers.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)

local Followers = require(script.Followers)
local HUD = require(script.HUD)
local Panels = require(script.Panels)

local player = Players.LocalPlayer

-- ----------------------------------------------------------------------------
-- 1-2. Wait for the server
-- ----------------------------------------------------------------------------

local remotes = Net.waitForAll()

local function request(name: string, ...)
	local remote = remotes[name]
	if remote then
		remote:FireServer(...)
	end
end

local startedAt = os.clock()
while player:GetAttribute("Coins") == nil do
	if os.clock() - startedAt > 12 then
		-- Save never arrived: ask the server for a fresh snapshot and keep waiting.
		request("RequestState")
		startedAt = os.clock()
	end
	task.wait(0.15)
end

-- ----------------------------------------------------------------------------
-- 3. Build the interface
-- ----------------------------------------------------------------------------

local followers = Followers.new()

local hub = {
	request = request,
	openPanel = nil, -- assigned right after the panels exist
	getFollowers = function()
		return followers
	end,
}

local hud = HUD.build(hub)
local panels = Panels.build(hud.gui, hub)
hub.openPanel = function(name: string)
	panels:open(name)
end

hud:setLoading(player:GetAttribute("Loading") == true)

-- ----------------------------------------------------------------------------
-- 4. Signals -> UI
-- ----------------------------------------------------------------------------

local handlers = {}

local warnedTransient = false

handlers.StateSnapshot = function(payload: any)
	hud:setLoading(false)
	panels:setSnapshot(payload)
	if payload.Transient and not warnedTransient then
		warnedTransient = true
		hud:toast({ Text = "Studio mode: DataStores are off, this save will not persist", Kind = "bad", Icon = "alert" })
	end
end

handlers.Notify = function(payload: any)
	hud:toast(payload)
end

handlers.Reward = function(payload: any)
	hud:reward(payload)
end

handlers.HatchResult = function(payload: any)
	hud:hatch(payload)
end

handlers.SaleResult = function(payload: any)
	hud:sale(payload)
end

handlers.Celebrate = function(payload: any)
	hud:celebrate(payload)
end

handlers.OfflineReward = function(payload: any)
	hud:offline(payload)
end

handlers.QuestUpdate = function(payload: any)
	panels:setQuestState(payload.Quests, payload.RerollsLeft)
end

handlers.LeaderboardData = function(payload: any)
	panels:setLeaderboard(payload)
end

handlers.OpenPanel = function(panelName: any)
	if type(panelName) == "string" then
		panels:open(panelName)
	end
end

for name, handler in pairs(handlers) do
	local remote = remotes[name]
	if remote then
		remote.OnClientEvent:Connect(function(payload)
			local ok, err = pcall(handler, payload)
			if not ok then
				warn(`[Client] {name} handler failed: {err}`)
			end
		end)
	else
		warn(`[Client] missing remote: {name}`)
	end
end

-- The loading overlay also listens to the attribute, because the very first
-- snapshot can arrive before this script even runs.
player:GetAttributeChangedSignal("Loading"):Connect(function()
	hud:setLoading(player:GetAttribute("Loading") == true)
end)

-- ----------------------------------------------------------------------------
-- Startup requests
-- ----------------------------------------------------------------------------

request("RequestState")
request("RequestLeaderboard")
hud:toast({ Text = "Tap the cube (or the big TAP button) to start earning!", Kind = "info", Icon = "tap" })

print("[Client] SuperSimulator UI ready")
