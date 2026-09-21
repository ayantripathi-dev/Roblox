--[[
	Icons
	One registry for every icon in the game. The UI, the world kiosks and every
	toast/reward payload refer to an icon by NAME - never by emoji, never by a
	hardcoded asset id spread across a dozen files.

	Each entry is:
		Name  - what you pass around ("coin", "egg", "pet", ...)
		Id    - a Creator Store / Decal image asset id. 0 means "draw it".
		Tint  - the color the icon is painted or drawn with
		Mark  - the drawn mark used when Id is 0 (see Theme.mark on the client)

	Using your own Creator Store decals
		1. Open the asset page on create.roblox.com - the id is the number in the URL
		2. Paste it as `Id` below, e.g.  Id = 1234567890
		   (an ImageLabel accepts a decal id directly, no "rbxassetid://" needed here)
	   Anything with Id == 0, or an id that fails to load, is drawn procedurally,
	   so a removed or mistyped asset can never leave a broken image in the UI -
	   it quietly falls back to the drawn mark.

	Icons.StudsTexture does the same job for the studded UI background: set it to
	a tiling studs texture id and every studded surface uses the image instead of
	the drawn studs.
]]

local Icons = {}

Icons.StudsTexture = 0 -- Creator Store id for a tileable studs texture (0 = drawn)

local DEFAULT: any = { Id = 0, Tint = Color3.fromRGB(148, 160, 186), Mark = "dot" }

Icons.Registry = {
	-- economy / core loop
	coin = { Id = 0, Tint = Color3.fromRGB(255, 199, 82), Mark = "coin" },
	power = { Id = 0, Tint = Color3.fromRGB(96, 196, 255), Mark = "bolt" },
	tap = { Id = 0, Tint = Color3.fromRGB(96, 196, 255), Mark = "arrow" },
	sell = { Id = 0, Tint = Color3.fromRGB(255, 199, 82), Mark = "cash" },
	auto = { Id = 0, Tint = Color3.fromRGB(124, 231, 158), Mark = "gear" },
	luck = { Id = 0, Tint = Color3.fromRGB(178, 112, 255), Mark = "clover" },
	upgrade = { Id = 0, Tint = Color3.fromRGB(178, 112, 255), Mark = "bars" },
	rebirth = { Id = 0, Tint = Color3.fromRGB(255, 140, 90), Mark = "spiral" },

	-- collection
	egg = { Id = 0, Tint = Color3.fromRGB(124, 231, 158), Mark = "egg" },
	-- One name per egg, so you can give each machine its own decal later.
	egg_basic = { Id = 0, Tint = Color3.fromRGB(190, 190, 205), Mark = "egg" },
	egg_aurora = { Id = 0, Tint = Color3.fromRGB(120, 214, 255), Mark = "egg" },
	egg_crystal = { Id = 0, Tint = Color3.fromRGB(160, 130, 255), Mark = "egg" },
	egg_cosmic = { Id = 0, Tint = Color3.fromRGB(110, 140, 255), Mark = "egg" },
	egg_prismatic = { Id = 0, Tint = Color3.fromRGB(255, 118, 196), Mark = "egg" },
	pet = { Id = 0, Tint = Color3.fromRGB(255, 118, 196), Mark = "paw" },
	index = { Id = 0, Tint = Color3.fromRGB(96, 196, 255), Mark = "book" },
	crown = { Id = 0, Tint = Color3.fromRGB(255, 199, 82), Mark = "crown" },

	-- meta
	quest = { Id = 0, Tint = Color3.fromRGB(124, 231, 158), Mark = "scroll" },
	daily = { Id = 0, Tint = Color3.fromRGB(255, 199, 82), Mark = "gift" },
	code = { Id = 0, Tint = Color3.fromRGB(255, 118, 196), Mark = "ticket" },
	rank = { Id = 0, Tint = Color3.fromRGB(255, 199, 82), Mark = "trophy" },
	store = { Id = 0, Tint = Color3.fromRGB(96, 196, 255), Mark = "gem" },
	gem = { Id = 0, Tint = Color3.fromRGB(150, 226, 255), Mark = "gem" },

	-- feedback
	check = { Id = 0, Tint = Color3.fromRGB(124, 231, 158), Mark = "check" },
	close = { Id = 0, Tint = Color3.fromRGB(148, 160, 186), Mark = "close" },
	reroll = { Id = 0, Tint = Color3.fromRGB(124, 231, 158), Mark = "reroll" },
	alert = { Id = 0, Tint = Color3.fromRGB(255, 112, 112), Mark = "alert" },
	lock = { Id = 0, Tint = Color3.fromRGB(104, 117, 142), Mark = "lock" },
	star = { Id = 0, Tint = Color3.fromRGB(255, 199, 82), Mark = "star" },
	clock = { Id = 0, Tint = Color3.fromRGB(146, 160, 186), Mark = "clock" },
	dot = DEFAULT,
}

function Icons.get(name: string?): any
	if type(name) ~= "string" then
		return DEFAULT
	end
	return Icons.Registry[name] or DEFAULT
end

function Icons.id(name: string?): number
	local entry = Icons.get(name)
	return if type(entry.Id) == "number" and entry.Id > 0 then entry.Id else 0
end

function Icons.tint(name: string?): Color3
	local entry = Icons.get(name)
	return entry.Tint or DEFAULT.Tint
end

function Icons.mark(name: string?): string
	local entry = Icons.get(name)
	return entry.Mark or "dot"
end

-- Every registered name, sorted. Used by the tests to catch typos.
function Icons.names(): { string }
	local list = {}
	for name in pairs(Icons.Registry) do
		if name ~= "dot" then
			table.insert(list, name)
		end
	end
	table.sort(list)
	return list
end

return Icons
