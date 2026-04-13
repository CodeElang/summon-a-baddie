local ShopController = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local MarketplaceService = game:GetService("MarketplaceService")

local Network = ReplicatedStorage.Network
local GetShopDataEvent = Network:WaitForChild("GetShopData")
local BuyBookEvent = Network:WaitForChild("BuyBook")
local FormatNumber = require(ReplicatedStorage.Shared.Utils.FormatNumber)
local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

function ShopController:Init() end

function ShopController:Start()
	local mainUI = playerGui:WaitForChild("MainUI")
	local shopFrame = mainUI:WaitForChild("ShopFrame")
	local closeBtn = shopFrame:WaitForChild("CloseBtn")
	local scrollContainer = shopFrame:WaitForChild("ScrollContainer")
	local cardTemplate = shopFrame:WaitForChild("CardTemplate")
	local timerLabel = shopFrame:WaitForChild("TimerLabel")

	scrollContainer.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scrollContainer.CanvasSize = UDim2.new(0, 0, 0, 0)
	scrollContainer.ScrollBarThickness = 6

	local nextRestockTime = 0
	local isShopOpen = false
	local isPurchasing = false -- Mencegah spam click yang bisa membuat server lag

	local function RenderShop(shopData, pRebirth, nextRestock)
		-- Bersihkan kartu lama (Event koneksi akan otomatis terhapus oleh Garbage Collector Luau)
		for _, child in ipairs(scrollContainer:GetChildren()) do
			if child:IsA("Frame") then child:Destroy() end
		end

		nextRestockTime = nextRestock

		for i, slot in ipairs(shopData.Slots) do
			local card = cardTemplate:Clone()
			card.Name = string.format("%02d_Slot", i)
			card.Visible = true
			card.ItemName.Text = slot.Name .. " Book"
			card.Parent = scrollContainer

			local btnContainer = card:FindFirstChild("Frame")
			local buy1Btn = btnContainer:FindFirstChild("Buy1Btn")
			local buyAllBtn = btnContainer:FindFirstChild("BuyAllBtn")
			local buyRobuxBtn = btnContainer:FindFirstChild("BuyRobuxBtn")

			-- Cari config buku yang sesuai dari Single Source of Truth
			local bookConfig = nil
			for _, cfg in ipairs(GameConfig.Books) do
				if cfg.Name == slot.Name then
					bookConfig = cfg
					break
				end
			end

			-- 🔥 FIX: Penanganan tombol Robux yang aman dari data Config baru
			local robuxPrice = (bookConfig and bookConfig.RobuxPrice) or 0
			local productId  = (bookConfig and bookConfig.ProductId)  or 0

			if buyRobuxBtn then
				if productId > 0 and robuxPrice > 0 then
					buyRobuxBtn.Visible = true
					buyRobuxBtn.Text = "R$ " .. robuxPrice
					buyRobuxBtn.MouseButton1Click:Connect(function()
						MarketplaceService:PromptProductPurchase(Players.LocalPlayer, productId)
					end)
				else
					-- Sembunyikan tombol jika buku ini tidak dijual pakai Robux
					buyRobuxBtn.Visible = false
				end
			end

			local function updateCardUI()
				local rebirthReq = slot.RebirthReq or 0
				local isLocked   = pRebirth < rebirthReq
				local hasStock   = slot.Stock > 0

				if bookConfig and card:FindFirstChild("LuckLabel") then
					-- Kalikan 100, lalu bulatkan untuk UI
					local cleanPercentage = math.floor((bookConfig.LuckBuff * 100) + 0.5) 
					card.LuckLabel.Text = string.format("%d%% Luck", cleanPercentage)
				end

				if isLocked then
					if hasStock then
						card.StockLabel.Text = "x" .. slot.Stock .. " (LOCKED: Rebirth " .. rebirthReq .. "+)"
						card.StockLabel.TextColor3 = Color3.fromRGB(255, 170, 0)
					else
						card.StockLabel.Text = "NO STOCK (LOCKED: Rebirth " .. rebirthReq .. "+)"
						card.StockLabel.TextColor3 = Color3.fromRGB(255, 50, 50)
					end
					if buy1Btn then buy1Btn.Visible   = false end
					if buyAllBtn then buyAllBtn.Visible = false end
				else
					if hasStock then
						card.StockLabel.Text       = "x" .. slot.Stock
						card.StockLabel.TextColor3 = Color3.fromRGB(85, 255, 127)

						if buy1Btn then 
							buy1Btn.Text = "BUY 1\n$"   .. FormatNumber.Format(slot.Price)
							buy1Btn.Visible = true 
						end
						if buyAllBtn then 
							buyAllBtn.Text = "BUY ALL\n$" .. FormatNumber.Format(slot.Price * slot.Stock)
							buyAllBtn.Visible = true 
						end
					else
						card.StockLabel.Text       = "NO STOCK"
						card.StockLabel.TextColor3 = Color3.fromRGB(255, 50, 50)
						if buy1Btn then buy1Btn.Visible   = false end
						if buyAllBtn then buyAllBtn.Visible = false end
					end
				end
			end

			updateCardUI()

			local function handlePurchase(buyMode, btn)
				if isPurchasing then return end -- Cegah spam click
				isPurchasing = true

				local originalText = btn.Text
				btn.Text = "..."

				local success, msg, newStock = BuyBookEvent:InvokeServer(i, buyMode)
				if success then
					slot.Stock = newStock
					updateCardUI()
				else
					btn.Text = msg
					task.wait(1)
					updateCardUI()
				end

				isPurchasing = false
			end

			if buy1Btn then 
				buy1Btn.MouseButton1Click:Connect(function() handlePurchase("One", buy1Btn) end)
			end
			if buyAllBtn then 
				buyAllBtn.MouseButton1Click:Connect(function() handlePurchase("All", buyAllBtn) end)
			end
		end
	end

	-- Deteksi dan sambungkan ke BookNPC di Workspace
	task.spawn(function()
		local npc = Workspace:WaitForChild("BookNPC", 10)
		if not npc then
			warn("[ShopController] ERROR: 'BookNPC' tidak ditemukan di Workspace!")
			return
		end

		local prompt = npc:WaitForChild("ProximityPrompt", 10)
		if not prompt then
			warn("[ShopController] ERROR: 'ProximityPrompt' tidak ditemukan di dalam BookNPC!")
			return
		end

		prompt.Triggered:Connect(function()
			local shopData, pRebirth, nextRestock = GetShopDataEvent:InvokeServer()
			if shopData then
				RenderShop(shopData, pRebirth, nextRestock)
				isShopOpen = true
				shopFrame.Visible = true
			end
		end)
	end)

	closeBtn.MouseButton1Click:Connect(function()
		shopFrame.Visible = false
		isShopOpen = false
	end)

	-- Loop timer restock
	task.spawn(function()
		while true do
			task.wait(1)
			if nextRestockTime > 0 then
				local timeLeft = nextRestockTime - os.time()
				if timeLeft <= 0 then
					timerLabel.Text = "Restocking..."
					if isShopOpen then
						local newShopData, newRebirth, newNextRestock = GetShopDataEvent:InvokeServer()
						if newShopData then
							RenderShop(newShopData, newRebirth, newNextRestock)
						end
					end
				else
					local minutes = math.floor(timeLeft / 60)
					local seconds = timeLeft % 60
					timerLabel.Text = string.format("%02d:%02d", minutes, seconds)
				end
			end
		end
	end)
end

return ShopController