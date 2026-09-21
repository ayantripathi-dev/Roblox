--[[
	Pets
	Eggs, pets, rarity tiers and index (collection) rewards.
	Add a new pet by appending one line to an egg - every system picks it up
	automatically: hatching, the index, the pet list, sell values and followers.

	Rarity odds for a pet:
		adjustedWeight = weight * (1 + luck * rarity.luckScale)
	so luck makes Legendary/Mythic/Secret pets dramatically more common, while
	leaving Common pets roughly where they were.
]]

local Pets = {}

Pets.RarityRank = {
	Common = 1,
	Uncommon = 2,
	Rare = 3,
	Epic = 4,
	Legendary = 5,
	Mythic = 6,
	Secret = 7,
}

Pets.Rarities = {
	Common = { Rank = 1, LuckScale = 0, Color = Color3.fromRGB(178, 190, 205), TextColor = Color3.fromRGB(120, 132, 148) },
	Uncommon = { Rank = 2, LuckScale = 0.25, Color = Color3.fromRGB(103, 214, 128), TextColor = Color3.fromRGB(62, 156, 88) },
	Rare = { Rank = 3, LuckScale = 0.5, Color = Color3.fromRGB(82, 161, 255), TextColor = Color3.fromRGB(48, 108, 200) },
	Epic = { Rank = 4, LuckScale = 0.75, Color = Color3.fromRGB(178, 112, 255), TextColor = Color3.fromRGB(128, 70, 210) },
	Legendary = { Rank = 5, LuckScale = 1, Color = Color3.fromRGB(255, 187, 64), TextColor = Color3.fromRGB(208, 138, 20) },
	Mythic = { Rank = 6, LuckScale = 1.25, Color = Color3.fromRGB(255, 92, 168), TextColor = Color3.fromRGB(206, 52, 126) },
	Secret = { Rank = 7, LuckScale = 1.5, Color = Color3.fromRGB(255, 240, 140), TextColor = Color3.fromRGB(224, 180, 40) },
}

Pets.Sell = {
	VALUE_PER_MULT = 250, -- coins per 1.0x of pet multiplier
	VALUE_PER_REBIRTH = 0.25, -- +25% sell value per rebirth
}

Pets.Settings = {
	MaxEquipped = 3, -- base slots; Constants.petSlots() raises this with rebirths and passes
	HatchMultiSize = 10, -- "Hatch x10" button size
}

Pets.Eggs = {
	{
		Name = "Basic Egg",
		Cost = 250,
		RebirthRequired = 0,
		Icon = "egg_basic",
		Color = Color3.fromRGB(190, 190, 205),
		Pets = {
			{ Name = "Dog", Rarity = "Common", Mult = 1.25, Weight = 45 },
			{ Name = "Cat", Rarity = "Common", Mult = 1.5, Weight = 30 },
			{ Name = "Bunny", Rarity = "Uncommon", Mult = 1.8, Weight = 14 },
			{ Name = "Fox", Rarity = "Uncommon", Mult = 2.4, Weight = 8 },
			{ Name = "Bee", Rarity = "Rare", Mult = 3.5, Weight = 3 },
		},
	},
	{
		Name = "Aurora Egg",
		Cost = 5000,
		RebirthRequired = 0,
		Icon = "egg_aurora",
		Color = Color3.fromRGB(120, 214, 255),
		Pets = {
			{ Name = "Penguin", Rarity = "Uncommon", Mult = 4, Weight = 30 },
			{ Name = "Snowman", Rarity = "Uncommon", Mult = 5.5, Weight = 22 },
			{ Name = "Wolf", Rarity = "Rare", Mult = 8, Weight = 16 },
			{ Name = "Owl", Rarity = "Rare", Mult = 12, Weight = 10 },
			{ Name = "Aurora Dragon", Rarity = "Legendary", Mult = 30, Weight = 3.5 },
			{ Name = "Frostbite", Rarity = "Secret", Mult = 250, Weight = 0.2 },
		},
	},
	{
		Name = "Crystal Egg",
		Cost = 75000,
		RebirthRequired = 1,
		Icon = "egg_crystal",
		Color = Color3.fromRGB(160, 130, 255),
		Pets = {
			{ Name = "Rock Golem", Rarity = "Rare", Mult = 14, Weight = 30 },
			{ Name = "Crystal Bat", Rarity = "Rare", Mult = 22, Weight = 22 },
			{ Name = "Gem Turtle", Rarity = "Epic", Mult = 34, Weight = 13 },
			{ Name = "Quartz Fox", Rarity = "Epic", Mult = 55, Weight = 8 },
			{ Name = "Diamond Dragon", Rarity = "Legendary", Mult = 140, Weight = 3 },
		},
	},
	{
		Name = "Cosmic Egg",
		Cost = 1500000,
		RebirthRequired = 3,
		Icon = "egg_cosmic",
		Color = Color3.fromRGB(70, 92, 210),
		Pets = {
			{ Name = "Alien", Rarity = "Epic", Mult = 70, Weight = 30 },
			{ Name = "Moonling", Rarity = "Epic", Mult = 110, Weight = 22 },
			{ Name = "Comet Pup", Rarity = "Legendary", Mult = 180, Weight = 13 },
			{ Name = "Star Whale", Rarity = "Legendary", Mult = 320, Weight = 8 },
			{ Name = "Nebula Dragon", Rarity = "Mythic", Mult = 900, Weight = 2 },
			{ Name = "Event Horizon", Rarity = "Secret", Mult = 9000, Weight = 0.1 },
		},
	},
	{
		Name = "Prismatic Egg",
		Cost = 40000000,
		RebirthRequired = 6,
		Icon = "egg_prismatic",
		Color = Color3.fromRGB(255, 118, 196),
		Pets = {
			{ Name = "Neon Slime", Rarity = "Legendary", Mult = 450, Weight = 30 },
			{ Name = "Rainbow Whale", Rarity = "Legendary", Mult = 950, Weight = 20 },
			{ Name = "Prism Golem", Rarity = "Mythic", Mult = 2400, Weight = 12 },
			{ Name = "Galaxy Griffin", Rarity = "Mythic", Mult = 6000, Weight = 7 },
			{ Name = "Prismatic Dragon", Rarity = "Mythic", Mult = 25000, Weight = 2.5 },
			{ Name = "The One", Rarity = "Secret", Mult = 100000, Weight = 0.05 },
		},
	},
}

-- Rewards for discovering every pet inside one egg (secrets are not required).
Pets.IndexRewards = {
	["Basic Egg"] = { Coins = 5000, Luck = 1, LuckMinutes = 15 },
	["Aurora Egg"] = { Coins = 100000, Luck = 1, LuckMinutes = 20 },
	["Crystal Egg"] = { Coins = 1500000, Luck = 2, LuckMinutes = 30 },
	["Cosmic Egg"] = { Coins = 30000000, Luck = 2, LuckMinutes = 45 },
	["Prismatic Egg"] = { Coins = 1000000000, Luck = 3, LuckMinutes = 60 },
}

-- Claiming the full index grants the ultimate pet from the Prismatic Egg.
Pets.IndexFinal = {
	Coins = 2500000000,
	Pet = "The One",
	Luck = 3,
	LuckMinutes = 60,
}

function Pets.getEgg(name: string?): any
	if type(name) ~= "string" then
		return nil
	end
	for _, egg in ipairs(Pets.Eggs) do
		if egg.Name == name then
			return egg
		end
	end
	return nil
end

function Pets.getRarity(name: string?): any
	return Pets.Rarities[name or ""]
end

function Pets.rank(rarity: string?): number
	local tier = Pets.Rarities[rarity or ""]
	return if tier then tier.Rank else 1
end

function Pets.color(rarity: string?): Color3
	local tier = Pets.Rarities[rarity or ""]
	return if tier then tier.Color else Color3.fromRGB(178, 190, 205)
end

-- Every pet definition, flat, keyed by pet name.
function Pets.all(): { [string]: any }
	local list = {}
	for _, egg in ipairs(Pets.Eggs) do
		for _, pet in ipairs(egg.Pets) do
			list[pet.Name] = pet
		end
	end
	return list
end

function Pets.get(name: string?): any
	return Pets.all()[name or ""]
end

-- True when the pet must be discovered (secrets hide until hatched).
function Pets.isSecret(petName: string?): boolean
	local pet = Pets.get(petName)
	return pet ~= nil and pet.Rarity == "Secret"
end

function Pets.adjustedWeight(pet: any, luck: number?): number
	local tier = Pets.Rarities[pet.Rarity]
	local scale = if tier then tier.LuckScale else 0
	return pet.Weight * (1 + math.max(0, luck or 0) * scale)
end

function Pets.totalWeight(egg: any, luck: number?): number
	local total = 0
	for _, pet in ipairs(egg.Pets) do
		total += Pets.adjustedWeight(pet, luck)
	end
	return total
end

--[[
	Weighted roll inside one egg. Pass a Roblox Random as `rng` for determinism.
	Returns the pet definition table.
]]
function Pets.roll(eggName: string, luck: number?, rng: any?): any
	local egg = Pets.getEgg(eggName)
	if not egg then
		return nil
	end

	local total = Pets.totalWeight(egg, luck)
	local roll = if rng then rng:NextNumber() else math.random()
	local target = roll * total
	local accumulated = 0
	local fallback = egg.Pets[1]

	for _, pet in ipairs(egg.Pets) do
		accumulated += Pets.adjustedWeight(pet, luck)
		if target <= accumulated then
			return pet
		end
		fallback = pet
	end
	return fallback
end

-- Percentage chance of each pet in an egg, for the "possible pets" UI.
function Pets.odds(eggName: string, luck: number?): { { pet: any, chance: number } }
	local egg = Pets.getEgg(eggName)
	if not egg then
		return {}
	end
	local total = Pets.totalWeight(egg, luck)
	local rows = {}
	for _, pet in ipairs(egg.Pets) do
		table.insert(rows, {
			pet = pet,
			chance = if total > 0 then Pets.adjustedWeight(pet, luck) / total else 0,
		})
	end
	return rows
end

-- The signature pet of an egg (its rarest non-secret entry) - used for art.
function Pets.eggHighlight(eggName: string): any
	local egg = Pets.getEgg(eggName)
	if not egg then
		return nil
	end
	local best = nil
	for _, pet in ipairs(egg.Pets) do
		if pet.Rarity ~= "Secret" and (best == nil or pet.Mult > best.Mult) then
			best = pet
		end
	end
	return best
end

function Pets.sellValue(petName: string, rebirths: number?): number
	local pet = Pets.get(petName)
	if not pet then
		return 0
	end
	local scale = 1 + Pets.Sell.VALUE_PER_REBIRTH * math.max(0, rebirths or 0)
	return math.floor(pet.Mult * Pets.Sell.VALUE_PER_MULT * scale)
end

return Pets
