local SummonController = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Network = ReplicatedStorage.Network
local RequestSummon = Network:WaitForChild("RequestSummon")
local GetOwnedBooks = Network:WaitForChild("GetOwnedBooks")
local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local FormatNumber = require(ReplicatedStorage.Shared.Utils.FormatNumber)

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local CurrentBook = ""
local isAutoSkip = false
local isAutoRoll = false

function SummonController:Init() end

function SummonController:Start()
	local mainUI = playerGui:WaitForChild("MainUI")
	local hud = mainUI:WaitForChild("SummonHUD")

	local leftBar = hud:WaitForChild("LeftBar")
	local bookBtn = leftBar:WaitForChild("BookBtn")
	local bookMenu = hud:WaitForChild("BookMenu")

	local bottomBar = hud:WaitForChild("BottomBar")
	local summonBtn = bottomBar:WaitForChild("SummonBtn")
	local equippedLabel = bottomBar:WaitForChild("EquippedLabel")
	local skipBtn = bottomBar:WaitForChild("AutoSkipBtn")
	local rollBtn = bottomBar:WaitForChild("AutoRollBtn")

	local resultUI = hud:WaitForChild("ResultUI")
	local rarityText = resultUI:WaitForChild("RarityText")
	local nameText = resultUI:WaitForChild("NameText")
	local chanceText = resultUI:WaitForChild("ChanceText")

	local isMenuOpen = false

	local function refreshBookMenu()
		for _, child in ipairs(bookMenu.List:GetChildren()) do
			if child:IsA("Frame") then child:Destroy() end
		end

		local ownedBooks = GetOwnedBooks:InvokeServer()
		if not ownedBooks then return end

		local hasAnyBook = false

		for _, cfg in ipairs(GameConfig.Books) do
			local stock = ownedBooks[cfg.Name] or 0
			if stock > 0 then
				hasAnyBook = true
				local card = bookMenu.CardTemplate:Clone()
				card.Name = cfg.Name
				card.Visible = true
				card.BookName.Text = cfg.Name .. " Book"
				card.BookStock.Text = "Owned: " .. stock
				card.Parent = bookMenu.List

				if CurrentBook == cfg.Name then
					card.EquipBtn.Text = "SELECTED"
					card.EquipBtn.BackgroundColor3 = Color3.fromRGB(226, 192, 115)
					card.EquipBtn.TextColor3 = Color3.fromRGB(30, 30, 35)
				end

				card.EquipBtn.MouseButton1Click:Connect(function()
					CurrentBook = cfg.Name
					equippedLabel.Text = CurrentBook .. " Book"
					refreshBookMenu()
				end)
			end
		end

		if not hasAnyBook then
			equippedLabel.Text = "No Books Owned!"
			CurrentBook = ""
		end

		if CurrentBook ~= "" and ownedBooks[CurrentBook] <= 0 then
			CurrentBook = ""
			equippedLabel.Text = "Select a Book"
			refreshBookMenu()
		end
	end

	bookBtn.MouseButton1Click:Connect(function()
		isMenuOpen = not isMenuOpen
		local targetPos = isMenuOpen and UDim2.new(0, 80, 0.5, -160) or UDim2.new(0, -300, 0.5, -160)
		local tweenInfo = TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
		TweenService:Create(bookMenu, tweenInfo, {Position = targetPos}):Play()

		if isMenuOpen then refreshBookMenu() end
	end)

	skipBtn.MouseButton1Click:Connect(function()
		isAutoSkip = not isAutoSkip
		skipBtn.Text = isAutoSkip and "AUTO SKIP\nON" or "AUTO SKIP\nOFF"
		skipBtn.TextColor3 = isAutoSkip and Color3.fromRGB(85, 255, 127) or Color3.fromRGB(150, 150, 150)
	end)

	rollBtn.MouseButton1Click:Connect(function()
		isAutoRoll = not isAutoRoll
		rollBtn.Text = isAutoRoll and "AUTO ROLL\nON" or "AUTO ROLL\nOFF"
		rollBtn.TextColor3 = isAutoRoll and Color3.fromRGB(85, 255, 127) or Color3.fromRGB(150, 150, 150)
	end)

	local function playSummonAnimation(baddieData)
		if isAutoSkip then return end

		bottomBar.Visible = false
		resultUI.Visible = true

		-- Set Texts
		rarityText.Text = string.upper(baddieData.Rarity)
		local tColor = GameConfig.Tiers[baddieData.Rarity].Color or Color3.fromRGB(255,255,255)
		rarityText.TextColor3 = tColor

		nameText.Text = baddieData.Name
		chanceText.Text = "1 in " .. FormatNumber.Format(baddieData.Chance)

		-- Reset Positions & Transparency
		rarityText.TextTransparency = 1
		rarityText.UIStroke.Transparency = 1
		rarityText.Position = UDim2.new(0, 0, 0.45, 0)

		nameText.TextTransparency = 1
		nameText.UIStroke.Transparency = 1
		nameText.Position = UDim2.new(0, 0, 0.6, 0)

		chanceText.TextTransparency = 1
		chanceText.Position = UDim2.new(0, 0, 0.85, 0)

		-- Animate IN
		local tiIn = TweenInfo.new(0.5, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out)
		TweenService:Create(rarityText, tiIn, {TextTransparency = 0, Position = UDim2.new(0, 0, 0.35, 0)}):Play()
		TweenService:Create(rarityText.UIStroke, tiIn, {Transparency = 0}):Play()

		task.wait(0.1)
		TweenService:Create(nameText, tiIn, {TextTransparency = 0, Position = UDim2.new(0, 0, 0.5, 0)}):Play()
		TweenService:Create(nameText.UIStroke, tiIn, {Transparency = 0}):Play()

		task.wait(0.1)
		TweenService:Create(chanceText, tiIn, {TextTransparency = 0, Position = UDim2.new(0, 0, 0.75, 0)}):Play()

		task.wait(1.5)

		-- Animate OUT
		local tiOut = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		TweenService:Create(rarityText, tiOut, {TextTransparency = 1, Position = UDim2.new(0, 0, 0.25, 0)}):Play()
		TweenService:Create(rarityText.UIStroke, tiOut, {Transparency = 1}):Play()

		TweenService:Create(nameText, tiOut, {TextTransparency = 1, Position = UDim2.new(0, 0, 0.4, 0)}):Play()
		TweenService:Create(nameText.UIStroke, tiOut, {Transparency = 1}):Play()

		local outAnim = TweenService:Create(chanceText, tiOut, {TextTransparency = 1, Position = UDim2.new(0, 0, 0.65, 0)})
		outAnim:Play()

		outAnim.Completed:Wait()

		resultUI.Visible = false
		bottomBar.Visible = true
	end

	local isSummoning = false
	summonBtn.MouseButton1Click:Connect(function()
		if isSummoning or CurrentBook == "" then return end
		isSummoning = true
		summonBtn.Text = "..."

		-- RequestSummon dipanggil ke server (di sini server memasukkan ke hotbar secara diam-diam)
		local success, resultData, sisaBuku = RequestSummon:InvokeServer(CurrentBook)

		if success then
			if isMenuOpen then refreshBookMenu() end

			-- Tunggu animasi selesai DULU
			playSummonAnimation(resultData)

			-- SETELAH animasi selesai, BARU paksa Hotbar bawah untuk refresh agar muncul!
			playerGui:SetAttribute("ForceHotbarRefresh", not playerGui:GetAttribute("ForceHotbarRefresh"))
		else
			equippedLabel.Text = resultData 
			task.wait(1)
			equippedLabel.Text = CurrentBook ~= "" and (CurrentBook .. " Book") or "No Book Selected"
		end

		summonBtn.Text = "SUMMON"
		isSummoning = false
	end)
end

return SummonController