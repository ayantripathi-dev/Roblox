--[[
	Harness
	Runs the pure shared modules (Constants, Utils, Upgrades, Pets, Quests, Codes,
	Net) outside Roblox, so the balance math can be tested in a terminal instead of
	by playing the game for an hour.

	It works by reading each .luau file and loading it with a small environment
	that fakes the two things the modules touch: `script.Parent` (the module
	folder) and the Roblox datatypes they use. Nothing that needs a real server
	(DataStores, remotes, Instances) is loaded here - those get exercised in
	Studio.

	Requires Lune: https://lune-org.github.io/docs
]]

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local Harness = {}

-- ----------------------------------------------------------------------------
-- Random: Lune has no Roblox Random, so this is a seeded Park-Miller generator.
-- Same code path the game uses (rng:NextNumber()), just deterministic.
-- ----------------------------------------------------------------------------

local Random = {}
Random.__index = Random

function Random.new(seed: number?)
	local self = setmetatable({}, Random)
	local state = math.floor(seed or os.time()) % 2147483647
	if state <= 0 then
		state += 2147483646
	end
	self.state = state
	return self
end

function Random:NextNumber(minimum: number?, maximum: number?): number
	self.state = (self.state * 16807) % 2147483647
	local value = self.state / 2147483647
	if minimum ~= nil or maximum ~= nil then
		local low = minimum or 0
		local high = maximum or 1
		return low + value * (high - low)
	end
	return value
end

function Random:NextInteger(minimum: number, maximum: number): number
	return math.floor(self:NextNumber(minimum, maximum + 1))
end

function Random:Clone()
	return Random.new(self.state)
end

Harness.Random = Random

-- ----------------------------------------------------------------------------
-- Environment shims
-- ----------------------------------------------------------------------------

local function stubService(name: string): any
	return {
		Name = name,
		ClassName = name,
		FindFirstChild = function()
			return nil
		end,
		WaitForChild = function()
			return nil
		end,
		GetChildren = function()
			return {}
		end,
	}
end

local function stubGame(): any
	return {
		GetService = function(_, name: string)
			return stubService(name)
		end,
	}
end

-- Close enough for the type checks the shared config does (Color3 comparisons).
local function typeof(value: any): string
	local kind = type(value)
	if kind == "table" then
		local meta = getmetatable(value)
		if meta and rawget(meta, "__type") then
			return rawget(meta, "__type")
		end
	end
	return kind
end--[[
	Loads every module found in `directory` (e.g. "src/shared") and returns a
table where `shared.Utils` is the loaded Utils module.

	Requires are resolved by scanning each file for `script.Parent.X` and loading
	X first, which keeps every lookup a plain table read. (Loading inside an
	__index metamethod cannot work: Lune's require yields, and Lua forbids yielding
	across a metamethod.)
]]
function Harness.loadShared(directory: string): any
	local folder: { [string]: any } = {}
	local loading: { [string]: boolean } = {}

	-- Maps a loaded module back to its name, so `require(script.Parent.Utils)`
	-- (which hands us the module table, not a path) can be resolved.
	local namesByValue: { [any]: string } = {}

	local function requireShim(target: any): any
		if type(target) == "string" then
			return require(target)
		end
		local name = namesByValue[target]
		if name then
			return folder[name]
		end
		error("a shared module required something that is not in the shared folder")
	end

	local function sourceOf(name: string): string?
		local path = `{directory}/{name}.luau`
		if not fs.isFile(path) then
			return nil
		end
		return fs.readFile(path)
	end

	local function load(name: string): any
		if folder[name] ~= nil then
			return folder[name]
		end
		if loading[name] then
			error(`circular require between shared modules: {name}`)
		end

		local source = sourceOf(name)
		if not source then
			return nil
		end

		loading[name] = true
		for dependency in string.gmatch(source, "script%.Parent%.([%w_]+)") do
			if not load(dependency) then
				error(`{name} requires {dependency}, which does not exist`)
			end
		end

		local environment = setmetatable({
			script = { Name = name, ClassName = "ModuleScript", Parent = folder },
			Color3 = roblox.Color3,
			Random = Random,
			game = stubGame(),
			typeof = typeof,
			require = requireShim,
			wait = function() end,
		}, { __index = _G })

		local chunk = luau.load(source, {
			debugName = `{directory}/{name}.luau`,
			environment = environment,
		})

		local value = chunk()
		folder[name] = value
		if value ~= nil then
			namesByValue[value] = name
		end
		loading[name] = nil
		return value
	end

	for _, entry in ipairs(fs.readDir(directory)) do
		local name = string.match(entry, "^(.-)%.luau$")
		if name then
			load(name)
		end
	end

	return folder
end

-- ----------------------------------------------------------------------------
-- Tiny test reporter
-- ----------------------------------------------------------------------------

local Reporter = {}
Reporter.__index = Reporter

function Harness.reporter()
	return setmetatable({ passed = 0, failed = 0, failures = {}, group = "" }, Reporter)
end

function Reporter:section(name: string)
	self.group = name
	print(`\n-- {name} ` .. string.rep("-", math.max(2, 46 - #name)))
end

function Reporter:check(label: string, condition: boolean, detail: string?)
	if condition then
		self.passed += 1
		print(`  ok    {label}`)
	else
		self.failed += 1
		table.insert(self.failures, `[{self.group}] {label}{if detail then ` ({detail})` else ""}`)
		print(`  FAIL  {label}` .. (if detail then `  -> {detail}` else ""))
	end
end

function Reporter:equal(label: string, actual: any, expected: any)
	local matches = actual == expected
	self:check(label, matches, if matches then nil else `expected {tostring(expected)}, got {tostring(actual)}`)
end

function Reporter:closeTo(label: string, actual: number, expected: number, tolerance: number)
	local delta = math.abs(actual - expected)
	self:check(label, delta <= tolerance, `expected {expected} +-{tolerance}, got {actual}`)
end

function Reporter:report(): number
	print(`\n{self.passed} passed, {self.failed} failed`)
	if self.failed > 0 then
		print("\nFailures:")
		for _, failure in ipairs(self.failures) do
			print(`  - {failure}`)
		end
	end
	return self.failed
end

return Harness
