local MonetizationService = {}

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService = require(script.Parent.DataService)
local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))

function MonetizationService:Init() end

function MonetizationService:Start()
	MarketplaceService.ProcessReceipt = function(receiptInfo)
		local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
		if not player then 
			return Enum.ProductPurchaseDecision.NotProcessedYet 
		end

		local profile = DataService:GetProfile(player)
		if not profile then 
			return Enum.ProductPurchaseDecision.NotProcessedYet 
		end

		local purchasedBook = nil
		for _, bookConfig in ipairs(GameConfig.Books) do
			if bookConfig.ProductId == receiptInfo.ProductId then
				purchasedBook = bookConfig
				break
			end
		end

		if purchasedBook then
			profile.Data.Books[purchasedBook.Name] += 1
			print(player.Name .. " sukses membeli " .. purchasedBook.Name .. " pakai Robux!")
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end

		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
end

return MonetizationService