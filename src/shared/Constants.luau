--[[
	Constants
	All gameplay tuning lives here. Change numbers, not code, to rebalance the game.
	Every value is shared by client and server so the UI always tells the truth.

	Progression math (see docs/BALANCE.md for the full walkthrough):
		powerPerClick = CLICK.BASE_GAIN * clickUpgrade * petMult * rebirthMult * combo
		coinsPerSell = power * sellUpgrade * petMult * rebirthMult
		eggOdds       = weight * (1 + luck * rarity.luckScale)
]]

local Constants = {}

Constants.VERSION = "2.0.0"
Constants.TITLE = "SuperSimulator"

-- ----------------------------------------------------------------------------
-- Fresh account
-- ----------------------------------------------------------------------------

Constants.START = {
	COINS = 25,
	POWER = 0,
	REBIRTHS = 0,
}

-- ----------------------------------------------------------------------------
-- Core loop
-- ----------------------------------------------------------------------------

Constants.CLICK = {
	BASE_GAIN = 1,
	-- Chain taps within COMBO_WINDOW to build a combo multiplier, up to COMBO_MAX.
	COMBO_WINDOW = 1.5,
	COMBO_STEP = 0.04,
	COMBO_MAX = 3,
	-- Server-side anti-exploit budget (taps per second, plus burst allowance).
	RATE = 16,
	BURST = 48,
}

Constants.SELL = {
	BASE_MULT = 1,
	-- Touching the sell pad repeatedly will not double-pay inside this window.
	COOLDOWN = 1.5,
}

Constants.AUTOFARM = {
	BASE_RATE = 0.4, -- power per second at upgrade level 1
	TICK = 1,
}

Constants.REBIRTH = {
	BASE_COST = 25000,
	COST_GROWTH = 3.4,
	MULT_PER_REBIRTH = 0.25,
	SLOTS_BASE = 3,
	SLOTS_PER_REBIRTH = 3, -- +1 pet slot every N rebirths
	SLOTS_MAX = 10,
}

Constants.LUCK = {
	UPGRADE_PER_LEVEL = 0.25,
	-- Luck boosts stack additively and expire: data.LuckBoost = { Amount = n, Until = os.time() }
	MAX_ACTIVE = 5,
}

Constants.OFFLINE = {
	MAX_SECONDS = 8 * 60 * 60, -- cap offline income at 8 hours
	EFFICIENCY = 0.35, -- you only earn 35% of your auto-farm rate while away
	MIN_SECONDS = 90,
}

-- ----------------------------------------------------------------------------
-- Progression goals
-- ----------------------------------------------------------------------------

Constants.QUEST = {
	DAILY_COUNT = 3,
	FREE_REROLLS = 1,
}

Constants.DAILY = {
	BASE_COINS = 2500,
	GROWTH_PER_STREAK = 0.35,
	STREAK_MAX = 7, -- day 7 of a streak awards a free pet
}

Constants.LIMITS = {
	MAX_PETS = 200, -- inventory cap, keeps saves small
	-- Clamps every stored number, so a tampered client can never inject
	-- math.huge or NaN into a save. It is also the ceiling of the endgame:
	-- rebirth costs grow 3.4x each time, so this is the wall the 100,000x
	-- index pets are for. Utils.formatNumber covers up to 1e42.
	MAX_NUMBER = 1e30,
	MAX_CODE_LENGTH = 32,
}

-- ----------------------------------------------------------------------------
-- Persistence
-- ----------------------------------------------------------------------------

Constants.DATA = {
	STORE = "PlayerData_v3",
	SCOPE = "supersim",
	AUTOSAVE = 90,
	SESSION_TTL = 90, -- seconds before another server may steal a stale session lock
	LOAD_RETRIES = 5,
}

-- ----------------------------------------------------------------------------
-- Global leaderboard (OrderedDataStore, cross-server)
-- ----------------------------------------------------------------------------

Constants.LEADERBOARD = {
	ENABLED = true,
	STORE = "LifetimeCoins_v1",
	SCOPE = "supersim",
	MAX_ROWS = 50,
	PUBLISH_INTERVAL = 180,
	CACHE_SECONDS = 60,
}

-- ----------------------------------------------------------------------------
-- Monetization
-- IDs are 0 until you create the real ones on the Roblox website.
-- The UI hides / disables anything with Id == 0, so the game is fully playable
-- before you sell a single pass.
-- ----------------------------------------------------------------------------

Constants.MARKETPLACE = {
	PASSES = {
		DOUBLE_COINS = {
			Id = 0,
			Name = "x2 Coins",
			Description = "Every sale pays double, forever.",
			Coins = 2,
		},
		VIP = {
			Id = 0,
			Name = "VIP",
			Description = "+1 pet slot, +1 luck and x2 coins.",
			Coins = 2,
			Luck = 1,
			PetSlots = 1,
		},
		LUCKY = {
			Id = 0,
			Name = "Lucky",
			Description = "Legendary and Mythic pets become far more common.",
			Luck = 2,
		},
		TURBO_CLICK = {
			Id = 0,
			Name = "Turbo Tap",
			Description = "Hold the power cube to auto-tap.",
			TurboClick = true,
		},
	},
	PRODUCTS = {
		COINS_SMALL = {
			Id = 0,
			Name = "Pocket of Coins",
			Coins = 50000,
			ScalePerRebirth = 0.75,
		},
		COINS_MEDIUM = {
			Id = 0,
			Name = "Bag of Coins",
			Coins = 350000,
			ScalePerRebirth = 0.75,
		},
		COINS_LARGE = {
			Id = 0,
			Name = "Vault of Coins",
			Coins = 2500000,
			ScalePerRebirth = 0.75,
		},
		LUCK_BOOST = {
			Id = 0,
			Name = "Lucky Hour",
			Luck = 2,
			LuckMinutes = 30,
		},
	},
}

-- ----------------------------------------------------------------------------
-- Client presentation limits
-- ----------------------------------------------------------------------------

Constants.CLIENT = {
	MAX_FLOATERS = 24,
	PARTICLE_BUDGET = 3, -- 0 = off, 1 = low, 2 = medium, 3 = high
	PET_RENDER_DISTANCE = 220,
	PET_FOLLOW_SMOOTHNESS = 0.18,
}

-- ----------------------------------------------------------------------------
-- Shared pure helpers (used by both the server economy and the client UI)
-- ----------------------------------------------------------------------------

function Constants.rebirthCost(rebirths: number?): number
	local count = math.max(0, math.floor(rebirths or 0))
	return math.floor(Constants.REBIRTH.BASE_COST * Constants.REBIRTH.COST_GROWTH ^ count)
end

function Constants.rebirthMultiplier(rebirths: number?): number
	local count = math.max(0, math.floor(rebirths or 0))
	return 1 + Constants.REBIRTH.MULT_PER_REBIRTH * count
end

function Constants.petSlots(rebirths: number?, bonus: number?): number
	local count = math.max(0, math.floor(rebirths or 0))
	local slots = Constants.REBIRTH.SLOTS_BASE
		+ math.floor(count / Constants.REBIRTH.SLOTS_PER_REBIRTH)
		+ math.max(0, math.floor(bonus or 0))
	return math.min(slots, Constants.REBIRTH.SLOTS_MAX)
end

function Constants.luckUpgradeValue(level: number?): number
	return Constants.LUCK.UPGRADE_PER_LEVEL * math.max(0, (math.floor(level or 1) - 1))
end

return Constants
