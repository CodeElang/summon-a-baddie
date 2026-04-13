local StatsController = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local FormatNumber = require(ReplicatedStorage.Shared.Utils.FormatNumber)

local GetUpgradeDataEvent = ReplicatedStorage.Network:WaitForChild("GetUpgradeData")

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local MainUI = playerGui:WaitForChild("MainUI")

function StatsController:Init() end

function StatsController:Start()
	local StatsFrame = MainUI:WaitForChild("StatsFrame")
	local CloseBtn = StatsFrame:WaitForChild("CloseBtn")

	local LeftBar = MainUI:FindFirstChild("LeftBar", true)
	while not LeftBar do
		task.wait(0.1)
		LeftBar = MainUI:FindFirstChild("LeftBar", true)
	end

	local StatsBtn = LeftBar:WaitForChild("StatsBtn")

	local StatsContainer = StatsFrame:WaitForChild("StatsContainer")
	local CoinValueLabel = StatsContainer:WaitForChild("CoinRow"):WaitForChild("ValueLabel")
	local LuckValueLabel = StatsContainer:WaitForChild("LuckRow"):WaitForChild("ValueLabel")

	local isFetching = false

	local function UpdateStatsUI()
		if isFetching then return end
		isFetching = true

		CoinValueLabel.Text = "Loading..."
		LuckValueLabel.Text = "Loading..."

		-- Ambil Data dari Server
		local upgradeData, rLvl, adminLuckBoost = GetUpgradeDataEvent:InvokeServer()

		if not upgradeData then 
			isFetching = false
			return 
		end

		rLvl = rLvl or 0
		adminLuckBoost = adminLuckBoost or 1

		-- ==========================================
		-- 1. CALCULATE TOTAL COIN PERCENTAGE
		-- ==========================================
		-- 🔥 FIX: Mengambil data dari Hardcoded GameConfig (Mencegah Nil Error)
		local rebirthMultiplier = 1.0
		if rLvl > 0 and GameConfig.Rebirth[rLvl] then
			rebirthMultiplier = GameConfig.Rebirth[rLvl].CoinMultiplier
		end

		local currentCoinLvl = upgradeData.CoinLevel or 0
		local coinUpgradePercent = 0
		if currentCoinLvl > 0 and GameConfig.Upgrades.Coin.Tiers[currentCoinLvl] then
			-- 🔥 FIX: Dikali 100 agar 1.0 menjadi 100%
			coinUpgradePercent = GameConfig.Upgrades.Coin.Tiers[currentCoinLvl].BonusPercent * 100
		end

		local potionCoinPercent = 0 
		local petCoinPercent = 0

		local totalCoinBonusPercent = coinUpgradePercent + potionCoinPercent + petCoinPercent

		-- ==========================================
		-- 2. CALCULATE TOTAL LUCK PERCENTAGE
		-- ==========================================
		local currentLuckLvl = upgradeData.LuckLevel or 0
		local luckUpgradePercent = 0
		if currentLuckLvl > 0 and GameConfig.Upgrades.Luck.Tiers[currentLuckLvl] then
			-- 🔥 FIX: Dikali 100
			luckUpgradePercent = GameConfig.Upgrades.Luck.Tiers[currentLuckLvl].BonusPercent * 100
		end

		local potionLuckPercent = 0
		local petLuckPercent = 0

		-- Konversi base Luck (Admin) ke persentase (1 = 100%)
		local baseLuckPercent = adminLuckBoost * 100

		-- Gabungkan semua persentase Luck
		local totalLuckPercent = baseLuckPercent + luckUpgradePercent + potionLuckPercent + petLuckPercent

		-- ==========================================
		-- 3. DISPLAY ON UI
		-- ==========================================
		-- Menggunakan FormatNumber agar angka ribuan/jutaan persen terbaca rapi (misal: +1.5K%)
		CoinValueLabel.Text = "+" .. FormatNumber.Format(totalCoinBonusPercent) .. "% (Base: " .. string.format("%.1f", rebirthMultiplier) .. "x)"
		LuckValueLabel.Text = FormatNumber.Format(totalLuckPercent) .. "%"

		CoinValueLabel.TextScaled = true
		LuckValueLabel.TextScaled = true

		isFetching = false
	end

	StatsBtn.MouseButton1Click:Connect(function()
		StatsFrame.Visible = true
		UpdateStatsUI()
	end)

	CloseBtn.MouseButton1Click:Connect(function()
		StatsFrame.Visible = false
	end)
end

return StatsController