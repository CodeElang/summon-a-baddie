local UpgradeService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataService = require(script.Parent.DataService)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local NetworkFolder = ReplicatedStorage.Network
local UpdateCashEvent = NetworkFolder:WaitForChild("UpdateCash")

local GetUpgradeDataEvent
local BuyUpgradeEvent

function UpgradeService:Init()
	if not NetworkFolder:FindFirstChild("GetUpgradeData") then
		GetUpgradeDataEvent = Instance.new("RemoteFunction")
		GetUpgradeDataEvent.Name = "GetUpgradeData"
		GetUpgradeDataEvent.Parent = NetworkFolder
	else
		GetUpgradeDataEvent = NetworkFolder.GetUpgradeData
	end

	if not NetworkFolder:FindFirstChild("BuyUpgrade") then
		BuyUpgradeEvent = Instance.new("RemoteFunction")
		BuyUpgradeEvent.Name = "BuyUpgrade"
		BuyUpgradeEvent.Parent = NetworkFolder
	else
		BuyUpgradeEvent = NetworkFolder.BuyUpgrade
	end
end

function UpgradeService:Start()
	GetUpgradeDataEvent.OnServerInvoke = function(player)
		local profile = DataService:GetProfile(player)
		if not profile then return nil end
		return profile.Data.Upgrades, profile.Data.RebirthLevel, profile.Data.LuckBoost
	end

	BuyUpgradeEvent.OnServerInvoke = function(player, upgradeType)
		local profile = DataService:GetProfile(player)
		if not profile then return false, "Data Error" end

		local config = GameConfig.Upgrades[upgradeType]
		if not config then return false, "Invalid Upgrade Type!" end

		local currentLevel = profile.Data.Upgrades[upgradeType .. "Level"] or 0

		-- Validasi Max Level
		if currentLevel >= config.MaxLevel then return false, "MAX LEVEL REACHED!" end

		local nextLevel    = currentLevel + 1
		local nextTierData = config.Tiers[nextLevel]

		if not nextTierData then return false, "Tier data missing!" end

		if profile.Data.RebirthLevel < nextTierData.RebirthReq then
			return false, "REQUIRES REBIRTH " .. nextTierData.RebirthReq .. "!"
		end

		local cost = nextTierData.Cost
		if profile.Data.Cash >= cost then
			profile.Data.Cash -= cost
			profile.Data.Upgrades[upgradeType .. "Level"] = nextLevel
			UpdateCashEvent:FireClient(player, profile.Data.Cash)
			return true, "SUCCESS!", profile.Data.Upgrades
		else
			return false, "NOT ENOUGH CASH!"
		end
	end
end

return UpgradeService