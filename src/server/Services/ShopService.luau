local ShopService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataService = require(script.Parent.DataService)
local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local NetworkFolder = ReplicatedStorage:WaitForChild("Network")
local BuyBookEvent = NetworkFolder:WaitForChild("BuyBook")
local GetShopDataEvent = NetworkFolder:WaitForChild("GetShopData")
local UpdateCashEvent = NetworkFolder:WaitForChild("UpdateCash")

function ShopService:Init() end

function ShopService:Start()
	GetShopDataEvent.OnServerInvoke = function(player)
		local profile = DataService:GetProfile(player)
		if not profile then return nil end

		local currentCycle = math.floor(os.time() / 300) -- Siklus 5 menit
		local needsRegen = profile.Data.PersonalShop.Cycle ~= currentCycle

		if not needsRegen and #profile.Data.PersonalShop.Slots > 0 then
			local firstSlot = profile.Data.PersonalShop.Slots[1]
			if firstSlot and firstSlot.RebirthReq == nil then needsRegen = true end
		end

		if needsRegen then
			profile.Data.PersonalShop.Cycle = currentCycle
			profile.Data.PersonalShop.Slots = {}

			for i, bookConfig in ipairs(GameConfig.Books) do
				local baseStock = 0

			
				if bookConfig.Name == "Basic" then
					baseStock = 999
				else
				
					local chanceToSpawn = math.max(5, 100 - (bookConfig.RebirthReq * 4))
					local isInstock = (math.random(1, 100) <= chanceToSpawn)

					local maxDynamicStock = math.max(1, 10 - math.floor(bookConfig.RebirthReq / 2))
					baseStock = isInstock and math.random(1, maxDynamicStock) or 0

					
					if baseStock > 0 and bookConfig.RebirthReq <= 1 then
						baseStock = baseStock * math.random(3, 5)
					end
				end

				profile.Data.PersonalShop.Slots[i] = {
					Name        = bookConfig.Name,
					Price       = bookConfig.Price,
					Stock       = baseStock,
					RebirthReq  = bookConfig.RebirthReq
				}
			end
		end

		local nextRestock = (currentCycle + 1) * 300
		return profile.Data.PersonalShop, profile.Data.RebirthLevel, nextRestock, profile.Data.Cash
	end

	BuyBookEvent.OnServerInvoke = function(player, slotIndex, buyMode)
		local profile = DataService:GetProfile(player)
		if not profile then return false, "Data error" end

		local slotData = profile.Data.PersonalShop.Slots[slotIndex]
		if not slotData or slotData.Stock <= 0 then return false, "Out of Stock!" end

		local rebirthReq = slotData.RebirthReq or 0
		if profile.Data.RebirthLevel < rebirthReq then return false, "LOCKED!" end

		local amountToBuy = 1
		if buyMode == "All" then
			-- Cerdas: Beli maksimal sesuai dengan uang yang dimiliki (dibatasi oleh stok toko)
			amountToBuy = math.min(slotData.Stock, math.floor(profile.Data.Cash / slotData.Price))
		end
		
		if amountToBuy <= 0 then
			return false, "Not enough Cash!"
		end

		local totalPrice  = slotData.Price * amountToBuy

		if profile.Data.Cash >= totalPrice then
			profile.Data.Cash -= totalPrice
			slotData.Stock    -= amountToBuy
			profile.Data.Books[slotData.Name] = (profile.Data.Books[slotData.Name] or 0) + amountToBuy

			UpdateCashEvent:FireClient(player, profile.Data.Cash)
			return true, "Success! Bought " .. tostring(amountToBuy), slotData.Stock
		else
			-- Fallback error jika gagal
			return false, "Transaction Failed!"
		end
	end
end

return ShopService