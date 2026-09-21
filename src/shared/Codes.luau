--[[
	Codes
	One list, one source of truth. Add a code by appending a line.

	Rewards you can combine:
		Coins, Power, Luck + LuckMinutes (temporary boost), Pet (grants by name)

	`Expires` is optional - use os.time({ year = 2026, month = 12, day = 31 }).
	Redeeming is validated on the server and remembered per account.
]]

local Codes = {}

Codes.List = {
	{ Code = "SURPRISE", Coins = 2500, Note = "Welcome gift" },
	{ Code = "ONEMORETRY", Coins = 15000, Luck = 1, LuckMinutes = 15, Note = "A year of trying pays off" },
	{ Code = "DREAMBIG", Coins = 60000, Power = 2500, Note = "Small boost, big momentum" },
	{ Code = "SIMU1YEAR", Coins = 250000, Luck = 2, LuckMinutes = 30, Note = "Anniversary code" },
	{ Code = "NEWWORLD", Pet = "Aurora Dragon", Note = "Grants a Legendary pet" },
	{ Code = "PRISMATIC", Coins = 1000000, Expires = os.time({ year = 2027, month = 1, day = 1 }) },
}

-- Codes are matched case-insensitively, ignoring spaces and dashes.
function Codes.normalize(text: string?): string
	if type(text) ~= "string" then
		return ""
	end
	local cleaned = string.upper(text)
	cleaned = string.gsub(cleaned, "[%s%-_]", "")
	return cleaned
end

function Codes.find(code: string?): any
	local normalized = Codes.normalize(code)
	if normalized == "" then
		return nil
	end
	for _, entry in ipairs(Codes.List) do
		if Codes.normalize(entry.Code) == normalized then
			return entry
		end
	end
	return nil
end

function Codes.isExpired(entry: any, now: number?): boolean
	if type(entry) ~= "table" or not entry.Expires then
		return false
	end
	return (now or os.time()) > entry.Expires
end

-- Used by the UI to show how many codes were shipped with the game.
function Codes.count(): number
	return #Codes.List
end

-- A short reward summary, e.g. "15,000 coins + 1 luck (15m)" / "Aurora Dragon".
function Codes.describe(entry: any): string
	if type(entry) ~= "table" then
		return "Unknown reward"
	end
	local parts = {}
	if entry.Coins then
		table.insert(parts, tostring(entry.Coins) .. " coins")
	end
	if entry.Power then
		table.insert(parts, tostring(entry.Power) .. " power")
	end
	if entry.Luck then
		table.insert(parts, "+" .. tostring(entry.Luck) .. " luck")
	end
	if entry.Pet then
		table.insert(parts, entry.Pet)
	end
	if #parts == 0 then
		return "Nothing (yet)"
	end
	return table.concat(parts, " + ")
end

return Codes
