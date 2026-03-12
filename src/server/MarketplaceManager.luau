local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage.Shared.Constants)
local DataManager = require(script.Parent.DataManager)
local Leaderstats = require(script.Parent.Leaderstats)

local MarketplaceManager = {}

function MarketplaceManager.hasPass(player, passId)
	local success, result = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
	end)
	return success and result
end

-- Example of handling a Developer Product (Buy Coins)
function MarketplaceManager.processReceipt(receiptInfo)
	local player = game:GetService("Players"):GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then return Enum.ProductPurchaseDecision.NotProcessedYet end

	if receiptInfo.ProductId == Constants.MARKETPLACE.BUY_COINS_ID then
		DataManager.increment(player, "Coins", 1000)
		Leaderstats.update(player, "Coins", DataManager.get(player, "Coins"))
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	return Enum.ProductPurchaseDecision.NotProcessedYet
end

MarketplaceService.ProcessReceipt = MarketplaceManager.processReceipt

return MarketplaceManager
