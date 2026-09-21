--[[
	LeaderboardService
	Cross-server top 50, built on an OrderedDataStore that stores each player's
	lifetime coins earned (Stats.TotalEarned).

	Reads are cached for CACHE_SECONDS so a hundred players opening the panel
	costs one DataStore call. If the DataStore is unavailable (Studio, outage)
	we fall back to a live ranking of the players in this server, so the panel
	never shows an empty box.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Utils = require(ReplicatedStorage.Shared.Utils)

local DataManager = require(script.Parent.DataManager)
local Notifier = require(script.Parent.Notifier)

local LeaderboardService = {}

local store = DataStoreService:GetOrderedDataStore(Constants.LEADERBOARD.STORE, Constants.LEADERBOARD.SCOPE)
local cache = { Rows = {}, UpdatedAt = 0, Live = false }
local nameCache: { [number]: string } = {}

local MAX_SCORE = 2147483647 -- OrderedDataStore wants 64 bit ints; stay safe

-- ----------------------------------------------------------------------------
-- Publishing
-- ----------------------------------------------------------------------------

function LeaderboardService.publish(player: Player)
	if not Constants.LEADERBOARD.ENABLED then
		return
	end

	local data = DataManager.data(player)
	if not data or data.IsTransient then
		return
	end

	local score = math.clamp(math.floor(data.Stats.TotalEarned), 0, MAX_SCORE)
	task.spawn(function()
		local ok, err = pcall(function()
			store:SetAsync(tostring(player.UserId), score)
		end)
		if not ok then
			warn(`[Leaderboard] publish failed for {player.Name}: {err}`)
		end
	end)
end

function LeaderboardService.start()
	if not Constants.LEADERBOARD.ENABLED then
		return
	end

	task.spawn(function()
		while true do
			for _, player in ipairs(Players:GetPlayers()) do
				LeaderboardService.publish(player)
			end
			task.wait(Constants.LEADERBOARD.PUBLISH_INTERVAL)
		end
	end)
end

-- ----------------------------------------------------------------------------
-- Reading
-- ----------------------------------------------------------------------------

local function resolveName(userId: number): string
	if nameCache[userId] then
		return nameCache[userId]
	end

	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)

	local resolved = if ok and type(name) == "string" then name else `Player {userId}`
	nameCache[userId] = resolved
	return resolved
end

-- Ranking of everyone currently in this server (used when DataStores are down).
local function liveRows(): { any }
	local rows = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local data = DataManager.data(player)
		table.insert(rows, {
			UserId = player.UserId,
			Name = player.DisplayName,
			Score = math.floor(if data then data.Stats.TotalEarned else 0),
		})
	end
	table.sort(rows, function(a, b)
		return a.Score > b.Score
	end)
	for index, row in ipairs(rows) do
		row.Rank = index
	end
	return rows
end

function LeaderboardService.query(): any
	local now = os.clock()
	if now - cache.UpdatedAt < Constants.LEADERBOARD.CACHE_SECONDS and cache.UpdatedAt > 0 then
		return cache
	end

	local rows = {}
	local live = false

	if Constants.LEADERBOARD.ENABLED then
		local ok, pages = pcall(function()
			return store:GetSortedAsync(false, Constants.LEADERBOARD.MAX_ROWS)
		end)

		if ok and pages then
			local okPage, page = pcall(function()
				return pages:GetCurrentPage()
			end)
			if okPage and type(page) == "table" then
				for index, entry in ipairs(page) do
					local userId = tonumber(entry.key) or 0
					table.insert(rows, {
						Rank = index,
						UserId = userId,
						Name = resolveName(userId),
						Score = tonumber(entry.value) or 0,
					})
				end
			end
		end
	end

	if #rows == 0 then
		rows = liveRows()
		live = true
	end

	cache = { Rows = rows, UpdatedAt = now, Live = live }
	return cache
end

-- Sends the (cached) board to one player, with "you" info filled in.
function LeaderboardService.handleRequest(player: Player)
	local data = DataManager.data(player)
	local myScore = math.floor(if data then data.Stats.TotalEarned else 0)
	local snapshot = LeaderboardService.query()

	local rows = {}
	local foundSelf = false
	for _, row in ipairs(snapshot.Rows) do
		local isMe = row.UserId == player.UserId
		foundSelf = foundSelf or isMe
		table.insert(rows, {
			Rank = row.Rank,
			Name = row.Name,
			Score = row.Score,
			IsMe = isMe,
		})
	end

	Notifier.leaderboard(player, {
		Rows = rows,
		Live = snapshot.Live,
		UpdatedAt = os.time(),
		MyScore = myScore,
		Ranked = foundSelf or snapshot.Live,
		Total = Constants.LEADERBOARD.MAX_ROWS,
	})
end

function LeaderboardService.invalidate()
	cache.UpdatedAt = 0
end

return LeaderboardService
