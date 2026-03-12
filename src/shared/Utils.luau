local Utils = {}

local SUFFIXES = {"", "k", "M", "B", "T", "Q"}

function Utils.formatNumber(n: number): string
	if n < 1000 then
		return tostring(n)
	end

	local index = math.floor(math.log10(n) / 3)
	local suffix = SUFFIXES[index + 1] or "e" .. tostring(index * 3)

	local value = n / (10 ^ (index * 3))
	return string.format("%.1f%s", value, suffix)
end

return Utils
