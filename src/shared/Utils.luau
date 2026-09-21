--[[
	Utils
	Small, dependency-free helpers shared by the server and the client.
	Everything here is pure Lua so it can be unit tested without Roblox.
]]

local Utils = {}

local SUFFIXES = { "", "k", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc", "Ud", "Dd" }

-- "1234567" -> "1.23M"
function Utils.formatNumber(value: number?): string
	if type(value) ~= "number" or value ~= value then
		return "0"
	end
	if value < 0 then
		return "-" .. Utils.formatNumber(-value)
	end
	if value < 1000 then
		if value % 1 == 0 then
			return tostring(math.floor(value))
		end
		return string.format("%.1f", value)
	end

	local index = math.clamp(math.floor(math.log10(value) / 3), 1, #SUFFIXES - 1)
	local scaled = value / (1000 ^ index)

	-- 999,999,999 would otherwise print as "1000M" instead of "1.00B".
	if scaled >= 999.5 and index < #SUFFIXES - 1 then
		index += 1
		scaled = value / (1000 ^ index)
	end

	local suffix = SUFFIXES[index + 1]
	if scaled >= 100 then
		return string.format("%.0f%s", scaled, suffix)
	elseif scaled >= 10 then
		return string.format("%.1f%s", scaled, suffix)
	end
	return string.format("%.2f%s", scaled, suffix)
end

-- Full number with thousands separators: 1234567 -> "1,234,567"
function Utils.comma(value: number?): string
	local text = tostring(math.floor(tonumber(value) or 0))
	local sign = ""
	if string.sub(text, 1, 1) == "-" then
		sign = "-"
		text = string.sub(text, 2)
	end
	local grouped = string.reverse(string.reverse(text):gsub("(%d%d%d)", "%1,"))
	grouped = string.gsub(grouped, "^,", "")
	return sign .. grouped
end

-- 93784 -> "1d 2h", 754 -> "12m 34s"
function Utils.formatTime(seconds: number?): string
	local total = math.max(0, math.floor(seconds or 0))
	local days = math.floor(total / 86400)
	local hours = math.floor((total % 86400) / 3600)
	local minutes = math.floor((total % 3600) / 60)
	local secs = total % 60

	if days > 0 then
		return string.format("%dd %dh", days, hours)
	elseif hours > 0 then
		return string.format("%dh %dm", hours, minutes)
	elseif minutes > 0 then
		return string.format("%dm %ds", minutes, secs)
	end
	return string.format("%ds", secs)
end

-- "1x", "2.5x", "12.34x" - used for every multiplier in the UI
function Utils.formatMultiplier(value: number?): string
	local number = tonumber(value) or 1
	if number >= 10 then
		return string.format("%.1fx", number)
	elseif number >= 1 then
		return string.format("%.2fx", number)
	end
	return string.format("%.2fx", number)
end

function Utils.round(value: number, places: number?): number
	local factor = 10 ^ (places or 0)
	return math.floor(value * factor + 0.5) / factor
end

function Utils.clamp(value: number, minimum: number, maximum: number): number
	if value < minimum then
		return minimum
	elseif value > maximum then
		return maximum
	end
	return value
end

function Utils.lerp(a: number, b: number, alpha: number): number
	return a + (b - a) * alpha
end

-- UTC calendar day, used for everything that resets daily
function Utils.dayKey(timestamp: number?): string
	return os.date("!%Y-%m-%d", timestamp or os.time())
end

function Utils.now(): number
	return os.time()
end

-- Cheap unique id (only needs to be unique inside one player's save)
function Utils.newId(): string
	local random = math.random(0, 0xFFFFFF)
	return string.format("%x%06x", math.floor(os.time()) % 0x1000000, random)
end

function Utils.count(container: { [any]: any }?): number
	local total = 0
	if type(container) == "table" then
		for _ in pairs(container) do
			total += 1
		end
	end
	return total
end

function Utils.total(container: { [any]: any }?): number
	local sum = 0
	if type(container) == "table" then
		for _, value in pairs(container) do
			if type(value) == "number" then
				sum += value
			end
		end
	end
	return sum
end

function Utils.keys(container: { [any]: any }): { any }
	local list = {}
	for key in pairs(container) do
		table.insert(list, key)
	end
	return list
end

function Utils.deepCopy(source: any): any
	if type(source) ~= "table" then
		return source
	end
	local copy = {}
	for key, value in pairs(source) do
		copy[key] = Utils.deepCopy(value)
	end
	return copy
end

-- Fisher-Yates. Pass a Roblox Random (or any object with :NextNumber()) for determinism.
function Utils.shuffle<T>(list: { T }, rng: any?): { T }
	for index = #list, 2, -1 do
		local roll = if rng then rng:NextNumber() else math.random()
		local swap = math.floor(roll * index) + 1
		swap = math.clamp(swap, 1, index)
		list[index], list[swap] = list[swap], list[index]
	end
	return list
end

function Utils.randomOf<T>(list: { T }, rng: any?): T?
	if #list == 0 then
		return nil
	end
	local roll = if rng then rng:NextNumber() else math.random()
	local index = math.clamp(math.floor(roll * #list) + 1, 1, #list)
	return list[index]
end

-- Builds the "1h 30m" style countdown used by boosts
function Utils.formatCountdown(target: number?): string
	local remaining = (target or 0) - os.time()
	if remaining <= 0 then
		return "expired"
	end
	return Utils.formatTime(remaining)
end

return Utils
