local UpgradeController = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Network = ReplicatedStorage.Network
local GetUpgradeDataEvent = Network:WaitForChild("GetUpgradeData")
local BuyUpgradeEvent = Network:WaitForChild("BuyUpgrade")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local FormatNumber = require(ReplicatedStorage.Shared.Utils.FormatNumber)

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local MainUI = playerGui:WaitForChild("MainUI")

local isProcessing = false

function UpgradeController:Init() end

function UpgradeController:Start()
	local UpgradeFrame = MainUI:WaitForChild("UpgradeFrame")
	local CloseBtn = UpgradeFrame:WaitForChild("CloseBtn")
	local ScrollContainer = UpgradeFrame:WaitForChild("ScrollContainer")
	local CardTemplate = ScrollContainer:WaitForChild("CardTemplate")

	local npc = Workspace:WaitForChild("UpgradeNPC", 10)
	if not npc then return end
	local prompt = npc:WaitForChild("ProximityPrompt")

	-- Map untuk menyimpan UI card yang sudah digenerate
	local generatedCards = {}

	local function UpdateCardUI(card, upgradeType, currentLvl, playerRebirth)
		local config = GameConfig.Upgrades[upgradeType]
		local isMax = currentLvl >= config.MaxLevel

		card.LevelLabel.Text = "Level: " .. currentLvl .. " / " .. config.MaxLevel

		-- DYNAMIC FORMATTING
		local currentDisplay = ""
		local nextDisplay = ""
		local usePercent = config.Tiers[1].BonusPercent ~= nil

		if usePercent then
			local currentBonus = currentLvl > 0 and (config.Tiers[currentLvl].BonusPercent * 100) or 0
			currentDisplay = "+" .. currentBonus .. "%"

			if not isMax and config.Tiers[currentLvl + 1] then 
				local nextBonus = config.Tiers[currentLvl + 1].BonusPercent * 100
				nextDisplay = "+" .. nextBonus .. "%" 
			end
		else
			local currentMulti = currentLvl > 0 and config.Tiers[currentLvl].Multiplier or 1.0
			currentDisplay = currentMulti .. "x"

			if not isMax and config.Tiers[currentLvl + 1] then 
				nextDisplay = config.Tiers[currentLvl + 1].Multiplier .. "x" 
			end
		end

		if isMax then
			card.MultiLabel.Text = "Current: " .. currentDisplay .. "\nNext: MAXED OUT"
			card.BuyBtn.Text = "MAXED"
			card.BuyBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
		else
			local nextTier = config.Tiers[currentLvl + 1]
			if nextTier then
				local cost = nextTier.Cost
				local reqRebirth = nextTier.RebirthReq

				card.MultiLabel.Text = "Current: " .. currentDisplay .. "\nNext: " .. nextDisplay

				if playerRebirth < reqRebirth then
					card.BuyBtn.Text = "LOCKED\n(Req Rebirth " .. reqRebirth .. ")"
					card.BuyBtn.BackgroundColor3 = Color3.fromRGB(200, 150, 0)
				else
					card.BuyBtn.Text = "UPGRADE\n$" .. FormatNumber.Format(cost)
					card.BuyBtn.BackgroundColor3 = Color3.fromRGB(85, 255, 127)
				end
			end
		end
	end

	local function HandlePurchase(upgradeType, btn)
		if isProcessing then return end
		if btn.Text == "MAXED" or string.match(btn.Text, "LOCKED") then return end 

		isProcessing = true
		local originalText = btn.Text
		local originalColor = btn.BackgroundColor3
		btn.Text = "..."

		-- Gunakan pcall agar UI tidak freeze jika server error
		local success, msg, newUpgradeData = BuyUpgradeEvent:InvokeServer(upgradeType)

		if success and newUpgradeData then
			btn.BackgroundColor3 = Color3.fromRGB(50, 200, 50)
			btn.Text = "SUCCESS!"
			task.wait(0.5)

			local _, rLvl = GetUpgradeDataEvent:InvokeServer()
			local newLevel = newUpgradeData[upgradeType .. "Level"] or 0

			UpdateCardUI(btn.Parent, upgradeType, newLevel, rLvl or 0)
		else
			btn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
			btn.Text = msg or "Failed"
			task.wait(1)

			-- Kembalikan tombol ke state normal
			local data, rLvl = GetUpgradeDataEvent:InvokeServer()
			if data then
				local currentLevel = data[upgradeType .. "Level"] or 0
				UpdateCardUI(btn.Parent, upgradeType, currentLevel, rLvl or 0)
			end
		end

		isProcessing = false
	end

	local function RefreshUI()
		local upgradeData, rLvl = GetUpgradeDataEvent:InvokeServer()
		if not upgradeData then return end
		rLvl = rLvl or 0

		for upgradeType, config in pairs(GameConfig.Upgrades) do
			local card = generatedCards[upgradeType]
			if not card then
				card = CardTemplate:Clone()
				card.Name = upgradeType .. "Card"
				card.TitleLabel.Text = config.Name

				-- 🔥 FIX: Berikan warna default kuning jika config.Color dihapus
				card.TitleLabel.TextColor3 = config.Color or Color3.fromRGB(255, 200, 0)

				card.Visible = true
				card.Parent = ScrollContainer

				card.BuyBtn.MouseButton1Click:Connect(function()
					HandlePurchase(upgradeType, card.BuyBtn)
				end)

				generatedCards[upgradeType] = card
			end

			-- 🔥 FIX: Nil-safe untuk level upgrade (Default 0 jika belum ada data)
			local currentLevel = upgradeData[upgradeType .. "Level"] or 0
			UpdateCardUI(card, upgradeType, currentLevel, rLvl)
		end
	end

	prompt.Triggered:Connect(function()
		RefreshUI()
		UpgradeFrame.Visible = true
	end)

	CloseBtn.MouseButton1Click:Connect(function()
		UpgradeFrame.Visible = false
	end)
end

return UpgradeController