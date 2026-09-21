--[[
	DataManager
	Save data that survives servers dying, players rejoining fast, and exploiters
	trying to inject junk into their save file.

	How it works
	  1. On join, UpdateAsync claims a session lock ({ Lock = guid, Timestamp }).
	     A lock older than SESSION_TTL seconds is considered dead and can be taken.
	  2. Every write also refreshes the lock, so a live server is never stolen.
	  3. Saves are skipped when a player did nothing (dirty flag) and share one
	     autosave timer, which keeps us far away from the DataStore budget.
	  4. On every load the file is reconciled against DataManager.defaults() and
	     sanitized: unknown pets are deleted and multipliers are recomputed from
	     the config, so a tampered save cannot inject a 1e300x pet.

	If loading fails after every retry the player is kicked instead of being
	given a fake save - losing a session feels better than losing an account.
	(Inside Studio, DataStores are often disabled, so there we play transient.)
]]

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Pets = require(ReplicatedStorage.Shared.Pets)
local Upgrades = require(ReplicatedStorage.Shared.Upgrades)
local Utils = require(ReplicatedStorage.Shared.Utils)

local Leaderstats = require(script.Parent.Leaderstats)

local DataManager = {}

local store = DataStoreService:GetDataStore(Constants.DATA.STORE, Constants.DATA.SCOPE)
local sessions: { [number]: any } = {}
local locks: { [number]: string } = {}
local dirty: { [number]: boolean } = {}
local sessionStart: { [number]: number } = {}

-- ----------------------------------------------------------------------------
-- Shape of a save file
-- ----------------------------------------------------------------------------

function DataManager.defaults(): any
	return {
		Version = 2,
		Coins = Constants.START.COINS,
		Power = Constants.START.POWER,
		Rebirths = Constants.START.REBIRTHS,
		Upgrades = { Click = 1, Sell = 1, Auto = 1, Luck = 1 },
		Pets = {}, -- { { Id, Name, Egg, HatchedAt } }
		Equipped = {}, -- pet ids
		Index = {}, -- pet name -> true
		IndexClaimed = {}, -- egg name -> true
		CodesRedeemed = {}, -- CODE -> true
		Receipts = {}, -- purchase id -> true (never grant a product twice)
		Quests = {},
		QuestDay = "",
		QuestRerolls = 0,
		Daily = { Day = "", Streak = 0 },
		Stats = {
			Clicks = 0,
			Sales = 0,
			Hatches = 0,
			Upgrades = 0,
			TotalEarned = 0,
			PlaySeconds = 0,
		},
		LuckBoost = { Amount = 0, Until = 0 },
		OfflineSeconds = 0,
		LastSeen = os.time(),
	}
end

-- ----------------------------------------------------------------------------
-- Cleanup helpers
-- ----------------------------------------------------------------------------

local function safeNumber(value: any, fallback: number): number
	if type(value) ~= "number" or value ~= value then
		return fallback
	end
	if value == math.huge or value == -math.huge then
		return fallback
	end
	return math.clamp(value, 0, Constants.LIMITS.MAX_NUMBER)
end

local function safeCount(value: any, fallback: number): number
	return math.floor(safeNumber(value, fallback))
end

-- Fills in anything a save file is missing (new fields, renamed fields, nil holes).
local function reconcile(target: any, template: any): any
	if type(target) ~= "table" then
		target = {}
	end
	for key, value in pairs(template) do
		if type(value) == "table" then
			target[key] = reconcile(target[key], value)
		elseif target[key] == nil or type(target[key]) ~= type(value) then
			target[key] = value
		end
	end
	return target
end

-- Rebuilds pets, equipped lists and upgrades from the shipped config.
local function sanitize(data: any): any
	data.Rebirths = math.min(safeCount(data.Rebirths, 0), 1000)
	data.Coins = safeNumber(data.Coins, 0)
	data.Power = safeNumber(data.Power, 0)
	data.OfflineSeconds = math.clamp(safeNumber(data.OfflineSeconds, 0), 0, Constants.OFFLINE.MAX_SECONDS)

	for _, trackId in ipairs(Upgrades.Order) do
		local track = Upgrades.get(trackId)
		data.Upgrades[trackId] = Upgrades.clampLevel(track, data.Upgrades[trackId])
	end

	local ownedIds: { [string]: boolean } = {}
	local cleanPets = {}
	if type(data.Pets) == "table" then
		for _, pet in ipairs(data.Pets) do
			if type(pet) == "table" and type(pet.Name) == "string" then
				local definition = Pets.get(pet.Name)
				if definition then
					local id = if type(pet.Id) == "string" and #pet.Id >= 4 then pet.Id else Utils.newId()
					if not ownedIds[id] then
						ownedIds[id] = true
						table.insert(cleanPets, {
							Id = id,
							Name = definition.Name,
							Egg = if type(pet.Egg) == "string" then pet.Egg else "Unknown",
							HatchedAt = safeCount(pet.HatchedAt, os.time()),
						})
					end
				end
			end
			if #cleanPets >= Constants.LIMITS.MAX_PETS then
				break
			end
		end
	end
	data.Pets = cleanPets

	local cleanEquipped = {}
	if type(data.Equipped) == "table" then
		for _, id in ipairs(data.Equipped) do
			if type(id) == "string" and ownedIds[id] and #cleanEquipped < Constants.REBIRTH.SLOTS_MAX then
				table.insert(cleanEquipped, id)
			end
		end
	end
	data.Equipped = cleanEquipped

	local cleanIndex = {}
	for petName in pairs(data.Index or {}) do
		if Pets.get(petName) then
			cleanIndex[petName] = true
		end
	end
	data.Index = cleanIndex

	local cleanClaims = {}
	for eggName in pairs(data.IndexClaimed or {}) do
		if Pets.getEgg(eggName) or eggName == "__final" then
			cleanClaims[eggName] = true
		end
	end
	data.IndexClaimed = cleanClaims

	local cleanCodes = {}
	for code in pairs(data.CodesRedeemed or {}) do
		if type(code) == "string" and #code <= Constants.LIMITS.MAX_CODE_LENGTH then
			cleanCodes[code] = true
		end
	end
	data.CodesRedeemed = cleanCodes

	local cleanReceipts = {}
	for receipt in pairs(data.Receipts or {}) do
		if type(receipt) == "string" and #receipt <= 120 then
			cleanReceipts[receipt] = true
		end
	end
	data.Receipts = cleanReceipts

	for key, value in pairs(DataManager.defaults().Stats) do
		data.Stats[key] = safeCount(data.Stats[key], value)
	end

	data.Daily.Streak = math.clamp(safeCount(data.Daily.Streak, 0), 0, 3650)
	data.QuestRerolls = math.clamp(safeCount(data.QuestRerolls, 0), 0, Constants.QUEST.FREE_REROLLS + 5)
	data.LuckBoost.Amount = math.clamp(safeNumber(data.LuckBoost.Amount, 0), 0, Constants.LUCK.MAX_ACTIVE)
	data.LuckBoost.Until = safeCount(data.LuckBoost.Until, 0)

	if type(data.Quests) ~= "table" then
		data.Quests = {}
	end

	return data
end

-- ----------------------------------------------------------------------------
-- Load / save
-- ----------------------------------------------------------------------------

local function claimSession(player: Player): (any, string?, string?)
	local key = tostring(player.UserId)
	local lockId = HttpService:GenerateGUID(false)
	local failure = "unknown error"

	for attempt = 1, Constants.DATA.LOAD_RETRIES do
		local ok, response = pcall(function()
			return store:UpdateAsync(key, function(current)
				if current then
					local session = current.Session
					if type(session) == "table" and type(session.Lock) == "string" and session.Lock ~= lockId then
						local age = os.time() - (tonumber(session.Timestamp) or 0)
						if age < Constants.DATA.SESSION_TTL then
							error("session is still active on another server")
						end
					end
					current.Session = { Lock = lockId, Timestamp = os.time() }
					current.LastSeen = os.time()
					return current
				end

				local fresh = DataManager.defaults()
				fresh.Session = { Lock = lockId, Timestamp = os.time() }
				return fresh
			end)
		end)

		if ok and type(response) == "table" then
			return response, lockId, nil
		end

		failure = tostring(response)
		if attempt < Constants.DATA.LOAD_RETRIES then
			task.wait(2 + attempt)
		end
	end

	return nil, nil, failure
end

--[[
	Loads (or creates) a player's data.
	Returns the session table, or nil when the player was kicked.
]]
function DataManager.load(player: Player): any
	if sessions[player.UserId] then
		return sessions[player.UserId]
	end

	local raw, lockId, failure = claimSession(player)

	if not raw then
		if RunService:IsStudio() then
			warn(`[DataManager] Studio mode without DataStores ({failure}) - playing transient`)
			local transient = sanitize(reconcile({}, DataManager.defaults()))
			transient.IsTransient = true
			sessions[player.UserId] = transient
			sessionStart[player.UserId] = os.time()
			player:SetAttribute("Transient", true)
			return transient
		end

		warn(`[DataManager] load failed for {player.Name}: {failure}`)
		player:Kick("Could not load your save.\nPlease rejoin in about a minute.")
		return nil
	end

	-- Offline income is computed here (we know LastSeen) and granted by GameService.
	local away = math.clamp(os.time() - (tonumber(raw.LastSeen) or os.time()), 0, Constants.OFFLINE.MAX_SECONDS)

	local data = sanitize(reconcile(raw, DataManager.defaults()))
	data.Session = nil
	data.IsTransient = false
	data.OfflineSeconds = if away >= Constants.OFFLINE.MIN_SECONDS then away else 0

	sessions[player.UserId] = data
	locks[player.UserId] = lockId
	sessionStart[player.UserId] = os.time()
	return data
end

function DataManager.isLoaded(player: Player): boolean
	return sessions[player.UserId] ~= nil
end

function DataManager.data(player: Player): any
	return sessions[player.UserId]
end

function DataManager.markDirty(player: Player)
	dirty[player.UserId] = true
end

--[[
	Saves one player. `release` also clears the session lock so a fast rejoin
	never has to wait for the lock to expire.
]]
function DataManager.save(player: Player, release: boolean?): boolean
	local data = sessions[player.UserId]
	if not data then
		return false
	end
	if data.IsTransient then
		return false
	end

	local userId = player.UserId
	local lockId = locks[userId]

	-- Track playtime once per save.
	data.Stats.PlaySeconds += math.max(0, os.time() - (sessionStart[userId] or os.time()))
	sessionStart[userId] = os.time()
	data.LastSeen = os.time()

	local payload = Utils.deepCopy(data)
	payload.IsTransient = nil
	if release then
		payload.Session = nil
	else
		payload.Session = { Lock = lockId, Timestamp = os.time() }
	end

	local ok, err = pcall(function()
		store:UpdateAsync(tostring(userId), function(current)
			if not release and type(current) == "table" then
				local session = current.Session
				if type(session) == "table" and type(session.Lock) == "string" and session.Lock ~= lockId then
					error("session lock was taken over - refusing to overwrite")
				end
			end
			return payload
		end)
	end)

	if not ok then
		warn(`[DataManager] save failed for {player.Name}: {err}`)
		return false
	end

	dirty[userId] = nil
	return true
end

-- Used by BindToClose and by the player-removing handler.
-- Starts every save in parallel, then waits (bounded) until they finish.
function DataManager.saveAll(release: boolean?)
	local threads = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local data = sessions[player.UserId]
		if data and not data.IsTransient then
			table.insert(threads, task.spawn(function()
				DataManager.save(player, release)
			end))
		end
	end

	local deadline = os.clock() + 20
	while #threads > 0 and os.clock() < deadline do
		local running = false
		for _, thread in ipairs(threads) do
			if coroutine.status(thread) ~= "dead" then
				running = true
				break
			end
		end
		if not running then
			break
		end
		task.wait(0.2)
	end
end

function DataManager.release(player: Player)
	DataManager.save(player, true)
	sessions[player.UserId] = nil
	locks[player.UserId] = nil
	dirty[player.UserId] = nil
	sessionStart[player.UserId] = nil
end

function DataManager.startAutosave()
	task.spawn(function()
		while true do
			task.wait(Constants.DATA.AUTOSAVE)
			for _, player in ipairs(Players:GetPlayers()) do
				if dirty[player.UserId] then
					task.spawn(function()
						DataManager.save(player)
					end)
				end
			end
		end
	end)
end

-- ----------------------------------------------------------------------------
-- Accessors used by every service
-- ----------------------------------------------------------------------------

function DataManager.get(player: Player, key: string): any
	local data = sessions[player.UserId]
	if not data then
		return nil
	end
	return data[key]
end

function DataManager.set(player: Player, key: string, value: any)
	local data = sessions[player.UserId]
	if not data then
		return
	end
	data[key] = value
	dirty[player.UserId] = true
end

-- Adds (or subtracts, with a negative amount) without ever going below zero.
function DataManager.add(player: Player, key: string, amount: number): number
	local data = sessions[player.UserId]
	if not data then
		return 0
	end
	local current = safeNumber(data[key], 0)
	local updated = math.clamp(current + (amount or 0), 0, Constants.LIMITS.MAX_NUMBER)
	data[key] = updated
	dirty[player.UserId] = true
	return updated
end

function DataManager.canAfford(player: Player, amount: number): boolean
	local data = sessions[player.UserId]
	return data ~= nil and data.Coins >= (amount or math.huge)
end

-- Spends coins if the player has them. Returns true when the purchase went through.
function DataManager.spend(player: Player, amount: number): boolean
	local data = sessions[player.UserId]
	if not data then
		return false
	end
	local cost = safeNumber(amount or math.huge, math.huge)
	if data.Coins < cost then
		return false
	end
	data.Coins -= cost
	dirty[player.UserId] = true
	return true
end

-- ----------------------------------------------------------------------------
-- Replication (attributes + leaderstats)
-- ----------------------------------------------------------------------------

--[[
	Pushes the raw numbers to the client. Economy.publish() wraps this and adds
	the derived values (luck, power per click, slots...).
]]
function DataManager.publish(player: Player)
	local data = sessions[player.UserId]
	if not data then
		return
	end

	local coins = math.floor(data.Coins)
	local power = math.floor(data.Power)

	player:SetAttribute("Coins", coins)
	player:SetAttribute("Power", power)
	player:SetAttribute("Rebirths", data.Rebirths)
	player:SetAttribute("RebirthMultiplier", Constants.rebirthMultiplier(data.Rebirths))
	player:SetAttribute("TotalEarned", math.floor(data.Stats.TotalEarned))
	player:SetAttribute("PetCount", #data.Pets)

	Leaderstats.update(player, "Coins", coins)
	Leaderstats.update(player, "Power", power)
	Leaderstats.update(player, "Rebirths", data.Rebirths)
	Leaderstats.update(player, "Pets", #data.Pets)
end

return DataManager
