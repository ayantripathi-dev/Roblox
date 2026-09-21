--[[
	Passes
	Gamepass ownership: checked once at join, refreshed on purchase, cached in
	memory. Every bonus the game gives a pass holder is read from here, so if you
	add a new pass you only describe it once (in Constants.MARKETPLACE.PASSES).

	Passes with Id == 0 are treated as "not configured" and simply never grant
	anything - the game stays fully playable before you sell a single pass.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)

local Passes = {}

local owned: { [number]: { [string]: boolean } } = {}

local function ownsPass(player: Player, pass: any): boolean
	if type(pass.Id) ~= "number" or pass.Id <= 0 then
		return false
	end
	local ok, result = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.Id)
	end)
	if not ok then
		warn(`[Passes] ownership check failed for {pass.Name or "?"}: {result}`)
		return false
	end
	return result == true
end

function Passes.refresh(player: Player)
	local result: { [string]: boolean } = {}
	for key, pass in pairs(Constants.MARKETPLACE.PASSES) do
		result[key] = ownsPass(player, pass)
	end
	owned[player.UserId] = result
	Passes.publish(player)
end

function Passes.has(player: Player, passKey: string): boolean
	local playerPasses = owned[player.UserId]
	return playerPasses ~= nil and playerPasses[passKey] == true
end

function Passes.isConfigured(passKey: string): boolean
	local pass = Constants.MARKETPLACE.PASSES[passKey]
	return pass ~= nil and type(pass.Id) == "number" and pass.Id > 0
end

-- All pass bonuses added up in one table.
function Passes.bonuses(player: Player): { Coins: number, Luck: number, PetSlots: number, TurboClick: boolean }
	local coins = 1
	local luck = 0
	local petSlots = 0
	local turboClick = false

	for key, pass in pairs(Constants.MARKETPLACE.PASSES) do
		if Passes.has(player, key) then
			coins *= (pass.Coins or 1)
			luck += (pass.Luck or 0)
			petSlots += (pass.PetSlots or 0)
			if pass.TurboClick then
				turboClick = true
			end
		end
	end

	return { Coins = coins, Luck = luck, PetSlots = petSlots, TurboClick = turboClick }
end

-- Mirrors pass state onto attributes so the client can show badges/hide buttons.
function Passes.publish(player: Player)
	for key in pairs(Constants.MARKETPLACE.PASSES) do
		player:SetAttribute(`Pass_{key}`, Passes.has(player, key))
	end
end

function Passes.clear(player: Player)
	owned[player.UserId] = nil
end

-- Re-check the moment Roblox tells us a purchase finished.
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
	if not purchased then
		return
	end
	for key, pass in pairs(Constants.MARKETPLACE.PASSES) do
		if pass.Id == passId then
			task.spawn(function()
				Passes.refresh(player)
				print(`[Passes] {player.Name} now owns {key}`)
			end)
			return
		end
	end
end)

return Passes
