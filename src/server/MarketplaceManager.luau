--[[
	MarketplaceManager
	Developer products and gamepass prompts.

	Products follow Roblox's golden rules:
		1. The purchase id is written to the save file BEFORE granting anything,
		   so a crash can never double-grant the same purchase.
		2. The save is flushed immediately, not on the next autosave.
		3. Anything unexpected returns NotProcessedYet so Roblox retries later.

	Products with Id == 0 are "not configured": the UI hides them and this file
	refuses to grant them, so the game is safe to publish before setup.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Utils = require(ReplicatedStorage.Shared.Utils)

local DataManager = require(script.Parent.DataManager)
local Notifier = require(script.Parent.Notifier)
local Passes = require(script.Parent.Passes)
local Rewards = require(script.Parent.Rewards)

local MarketplaceManager = {}

local function productKeyFromId(productId: number): (string?, any)
	for key, product in pairs(Constants.MARKETPLACE.PRODUCTS) do
		if product.Id == productId and productId > 0 then
			return key, product
		end
	end
	return nil, nil
end

-- ----------------------------------------------------------------------------
-- Receipts
-- ----------------------------------------------------------------------------

function MarketplaceManager.processReceipt(receiptInfo: any): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local data = DataManager.data(player)
	if not data then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local purchaseId = tostring(receiptInfo.PurchaseId)

	-- Already handled on an earlier attempt?
	if data.Receipts[purchaseId] then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	local key, product = productKeyFromId(receiptInfo.ProductId)
	if not key or not product then
		warn(`[Marketplace] unknown product id: {receiptInfo.ProductId}`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	-- Record first, then grant. Both are saved before we answer Roblox.
	data.Receipts[purchaseId] = true
	DataManager.markDirty(player)
	DataManager.save(player)

	local reward: any = {}
	local title = product.Name or key

	if product.Coins then
		local scale = 1 + (product.ScalePerRebirth or 0) * data.Rebirths
		reward.Coins = math.floor(product.Coins * scale)
	end
	if product.Luck then
		reward.Luck = product.Luck
		reward.LuckMinutes = product.LuckMinutes or 30
	end

	Rewards.celebrate(player, title, "Thanks for supporting the game!", reward, "gem")

	-- Flush again so the granted coins survive a crash right after purchase.
	DataManager.save(player)
	print(`[Marketplace] {player.Name} bought {key}`)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

MarketplaceService.ProcessReceipt = MarketplaceManager.processReceipt

-- ----------------------------------------------------------------------------
-- Prompts (client asks, server prompts)
-- ----------------------------------------------------------------------------

function MarketplaceManager.promptPass(player: Player, passKey: string)
	local pass = Constants.MARKETPLACE.PASSES[passKey]
	if not pass or pass.Id <= 0 then
		Notifier.toast(player, "That pass is not available yet", "bad", "store")
		return
	end
	if Passes.has(player, passKey) then
		Notifier.toast(player, `You already own {pass.Name}`, "info", "store")
		return
	end
	task.spawn(function()
		local ok, err = pcall(function()
			MarketplaceService:PromptGamePassPurchase(player, pass.Id)
		end)
		if not ok then
			warn(`[Marketplace] prompt failed: {err}`)
		end
	end)
end

function MarketplaceManager.promptProduct(player: Player, productKey: string)
	local product = Constants.MARKETPLACE.PRODUCTS[productKey]
	if not product or product.Id <= 0 then
		Notifier.toast(player, "That item is not available yet", "bad", "store")
		return
	end
	task.spawn(function()
		local ok, err = pcall(function()
			MarketplaceService:PromptProductPurchase(player, product.Id)
		end)
		if not ok then
			warn(`[Marketplace] prompt failed: {err}`)
		end
	end)
end

-- Used by the UI to describe a product without hardcoding numbers twice.
function MarketplaceManager.describeProducts(player: Player): { any }
	local data = DataManager.data(player)
	local rebirths = if data then data.Rebirths else 0
	local rows = {}
	for key, product in pairs(Constants.MARKETPLACE.PRODUCTS) do
		local description = ""
		if product.Coins then
			local scale = 1 + (product.ScalePerRebirth or 0) * rebirths
			description = `{Utils.comma(math.floor(product.Coins * scale))} coins`
		elseif product.Luck then
			description = `+{product.Luck} luck for {product.LuckMinutes or 30} minutes`
		end
		table.insert(rows, {
			Key = key,
			Name = product.Name or key,
			Description = description,
			Available = product.Id > 0,
		})
	end
	table.sort(rows, function(a, b)
		return a.Name < b.Name
	end)
	return rows
end

return MarketplaceManager
