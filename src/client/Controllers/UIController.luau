local UIController = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local FormatNumber = require(ReplicatedStorage.Shared.Utils.FormatNumber)
local UpdateCashEvent = ReplicatedStorage.Network:WaitForChild("UpdateCash")

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

function UIController:Init() end

function UIController:Start()
	-- HILANGKAN HOTBAR BAWAAN ROBLOX!
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	end)

	local mainUI = playerGui:WaitForChild("MainUI")
	local cashHUD = mainUI:WaitForChild("CashHUD")
	local cashAmount = cashHUD:WaitForChild("Amount")

	UpdateCashEvent.OnClientEvent:Connect(function(newCashTotal)
		cashAmount.Text = FormatNumber.Format(newCashTotal)
		cashAmount.Size = UDim2.new(1, -45, 1.2, 0)
		task.wait(0.1)
		cashAmount.Size = UDim2.new(1, -45, 1, 0)
	end)
end

return UIController