local RebirthController = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local FormatNumber = require(ReplicatedStorage.Shared.Utils.FormatNumber)

local NetworkFolder = ReplicatedStorage.Network
local RebirthEvent = NetworkFolder:WaitForChild("RequestRebirth")
local GetRebirthDataEvent = NetworkFolder:WaitForChild("GetRebirthData")

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local MainUI = playerGui:WaitForChild("MainUI")

local RebirthHUD = MainUI:WaitForChild("RebirthHUD")

local LevelInfo = RebirthHUD:WaitForChild("LevelInfo")
local CostLabel = RebirthHUD:WaitForChild("CostLabel")
local ConfirmBtn = RebirthHUD:WaitForChild("ConfirmBtn")
local CloseBtn = RebirthHUD:WaitForChild("CloseBtn")

local TransitionScreen = MainUI:WaitForChild("TransitionScreen")
local TransitionText = TransitionScreen:WaitForChild("CenterText")
local TextStroke = TransitionText:WaitForChild("UIStroke")

local currentRebirthLevel = 0 
local isProcessing = false

function RebirthController:Init() end

function RebirthController:Start()
	-- Pencarian LeftBar yang aman dari Infinite Yield
	local LeftBar = MainUI:FindFirstChild("LeftBar", true)
	while not LeftBar do
		task.wait(0.1)
		LeftBar = MainUI:FindFirstChild("LeftBar", true)
	end
	local RebirthBtn = LeftBar:WaitForChild("RebirthBtn")

	RebirthBtn.MouseButton1Click:Connect(function()
		if isProcessing then return end
		currentRebirthLevel = GetRebirthDataEvent:InvokeServer() or 0
		self:UpdateUI()
		RebirthHUD.Visible = true
	end)

	CloseBtn.MouseButton1Click:Connect(function()
		RebirthHUD.Visible = false
	end)

	ConfirmBtn.MouseButton1Click:Connect(function()
		if isProcessing then return end
		if ConfirmBtn.Text == "MAXED OUT" then return end

		isProcessing = true
		ConfirmBtn.Text = "PROCESSING..."

		local success, msg = RebirthEvent:InvokeServer()

		if success then
			local nextLevel = currentRebirthLevel + 1

			TransitionText.TextTransparency = 1
			TextStroke.Transparency = 1
			TransitionText.Text = "Rebirth " .. currentRebirthLevel .. " > " .. nextLevel
			TransitionScreen.BackgroundTransparency = 1
			TransitionScreen.Visible = true

			local flashBangHit = TweenService:Create(TransitionScreen, TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 0})
			flashBangHit:Play()
			flashBangHit.Completed:Wait()

			RebirthHUD.Visible = false
			currentRebirthLevel = nextLevel

			local flashBangFade = TweenService:Create(TransitionScreen, TweenInfo.new(3, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {BackgroundTransparency = 1})
			flashBangFade:Play()

			task.wait(0.5)
			local textIn = TweenService:Create(TransitionText, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {TextTransparency = 0})
			local strokeIn = TweenService:Create(TextStroke, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Transparency = 0})
			textIn:Play()
			strokeIn:Play()

			task.wait(2)

			local textOut = TweenService:Create(TransitionText, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {TextTransparency = 1})
			local strokeOut = TweenService:Create(TextStroke, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Transparency = 1})
			textOut:Play()
			strokeOut:Play()
			textOut.Completed:Wait()

			TransitionScreen.Visible = false
		else
			ConfirmBtn.Text = msg
			ConfirmBtn.BackgroundColor3 = Color3.fromRGB(255, 80, 80)
			task.wait(1.5)
		end

		isProcessing = false
		ConfirmBtn.Text = "REBIRTH"
		ConfirmBtn.BackgroundColor3 = Color3.fromRGB(85, 255, 127)
	end)
end

function RebirthController:UpdateUI()
	local nextLevel = currentRebirthLevel + 1
	local nextConfig = GameConfig.Rebirth[nextLevel]

	local container = RebirthHUD:WaitForChild("RewardsContainer")
	for _, child in ipairs(container:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end

	-- Validasi jika pemain sudah mencapai Rebirth 20 (Max)
	if not nextConfig then
		LevelInfo.Text = "Current: " .. currentRebirthLevel .. "  >  Next: MAX"
		CostLabel.Text = "MAX REBIRTH REACHED"
		ConfirmBtn.Text = "MAXED OUT"
		ConfirmBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
		return
	end

	LevelInfo.Text = "Current: " .. currentRebirthLevel .. "  >  Next: " .. nextLevel
	CostLabel.Text = "$" .. FormatNumber.Format(nextConfig.Cost)
	ConfirmBtn.Text = "REBIRTH"
	ConfirmBtn.BackgroundColor3 = Color3.fromRGB(85, 255, 127)

	local function createRewardItem(text, iconColor)
		local frame = Instance.new("Frame", container)
		frame.Size = UDim2.new(1, 0, 0, 32)
		frame.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
		Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 6)

		local icon = Instance.new("Frame", frame)
		icon.Size = UDim2.new(0, 16, 0, 16)
		icon.Position = UDim2.new(0, 10, 0.5, 0)
		icon.AnchorPoint = Vector2.new(0, 0.5)
		icon.BackgroundColor3 = iconColor
		Instance.new("UICorner", icon).CornerRadius = UDim.new(1, 0)

		local lbl = Instance.new("TextLabel", frame)
		lbl.Size = UDim2.new(1, -40, 1, 0)
		lbl.Position = UDim2.new(0, 35, 0, 0)
		lbl.BackgroundTransparency = 1
		lbl.Text = text
		lbl.Font = Enum.Font.GothamBold
		lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
		lbl.TextScaled = true
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		Instance.new("UITextSizeConstraint", lbl).MaxTextSize = 15
	end

	-- 1. Show Coin Multiplier
	createRewardItem(string.format("%.1f", nextConfig.CoinMultiplier) .. "x Coin Multiplier", Color3.fromRGB(255, 170, 0))

	-- 2. Show Floor Unlocks
	if nextLevel == 10 then
		createRewardItem("Floor 2 Unlocked", Color3.fromRGB(170, 85, 255))
	elseif nextLevel == 20 then
		createRewardItem("Floor 3 Unlocked", Color3.fromRGB(170, 85, 255))
	end

	-- 3. Show Book Unlocks
	for _, book in ipairs(GameConfig.Books) do
		if book.RebirthReq == nextLevel then
			createRewardItem("Unlock: " .. book.Name .. " Book", Color3.fromRGB(85, 170, 255))
		end
	end

	-- 4. NEW: Scan and Show Ability Unlocks (Dikali 100 agar UI sinkron)
	for _, tierData in pairs(GameConfig.Upgrades.Coin.Tiers) do
		if tierData.RebirthReq == nextLevel then
			local displayPercent = tierData.BonusPercent * 100
			createRewardItem("Unlock: Coin Upgrade (+" .. displayPercent .. "%)", Color3.fromRGB(50, 200, 150))
		end
	end

	for _, tierData in pairs(GameConfig.Upgrades.Luck.Tiers) do
		if tierData.RebirthReq == nextLevel then
			local displayPercent = tierData.BonusPercent * 100
			createRewardItem("Unlock: Luck Upgrade (+" .. displayPercent .. "%)", Color3.fromRGB(50, 200, 150))
		end
	end
end

return RebirthController