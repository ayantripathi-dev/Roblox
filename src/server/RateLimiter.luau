--[[
	RateLimiter
	Token bucket per player per action, plus a strike counter.

	Used by every remote handler: a legit player physically cannot tap faster
	than Constants.CLICK.RATE, so anything above the burst budget is either a
	laggy phone or an executor. Exploiters get ignored, then kicked.
]]

local RateLimiter = {}

local KICK_THRESHOLD = 400

local buckets: { [Player]: { [string]: { tokens: number, updated: number } } } = {}
local strikes: { [Player]: number } = {}

function RateLimiter.allow(player: Player, key: string, rate: number, burst: number?): boolean
	local playerBuckets = buckets[player]
	if not playerBuckets then
		playerBuckets = {}
		buckets[player] = playerBuckets
	end

	local capacity = burst or rate
	local bucket = playerBuckets[key]
	local now = os.clock()

	if not bucket then
		bucket = { tokens = capacity, updated = now }
		playerBuckets[key] = bucket
	end

	bucket.tokens = math.min(capacity, bucket.tokens + (now - bucket.updated) * rate)
	bucket.updated = now

	if bucket.tokens < 1 then
		return false
	end

	bucket.tokens -= 1
	return true
end

-- Counts a rejected request. Returns true when the player should be removed.
function RateLimiter.strike(player: Player, key: string?): boolean
	strikes[player] = (strikes[player] or 0) + 1
	local total = strikes[player]
	if total >= KICK_THRESHOLD then
		warn(`[RateLimiter] kicking {player.Name} after {total} rejected {key or "?"} requests`)
		return true
	end
	return false
end

function RateLimiter.strikesOf(player: Player): number
	return strikes[player] or 0
end

function RateLimiter.clear(player: Player)
	buckets[player] = nil
	strikes[player] = nil
end

--[[
	Wraps a remote handler with a rate limit.
	The handler only runs when the player is still inside the budget.
]]
function RateLimiter.guard(player: Player, key: string, rate: number, burst: number?, handler: () -> ()): boolean
	if RateLimiter.allow(player, key, rate, burst) then
		handler()
		return true
	end
	if RateLimiter.strike(player, key) then
		player:Kick("Kicked for sending too many requests.")
	end
	return false
end

return RateLimiter
