local RebirthService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataService = require(script.Parent.DataService)
local TycoonService = require(script.Parent.TycoonService)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local NetworkFolder = ReplicatedStorage.Network
local RebirthEvent = NetworkFolder:WaitForChild("RequestRebirth")
local UpdateCashEvent = NetworkFolder:WaitForChild("UpdateCash")

local GetRebirthDataEvent

function RebirthService:Init()
	if not NetworkFolder:FindFirstChild("GetRebirthData") then
		GetRebirthDataEvent = Instance.new("RemoteFunction")
		GetRebirthDataEvent.Name = "GetRebirthData"
		GetRebirthDataEvent.Parent = NetworkFolder
	else
		GetRebirthDataEvent = NetworkFolder.GetRebirthData
	end
end

function RebirthService:Start()
	GetRebirthDataEvent.OnServerInvoke = function(player)
		local profile = DataService:GetProfile(player)
		return profile and profile.Data.RebirthLevel or 0
	end

	RebirthEvent.OnServerInvoke = function(player)
		local profile = DataService:GetProfile(player)
		if not profile then return false, "Data error!" end

		local currentLevel = profile.Data.RebirthLevel

		-- Mencegah error jika player sudah max level (Rebirth 20)
		if not GameConfig.Rebirth[currentLevel + 1] then
			return false, "Max Rebirth Reached!"
		end

		local cost = GameConfig.Rebirth[currentLevel + 1].Cost

		if profile.Data.Cash < cost then
			return false, "Not enough Cash!"
		end

		-- Reset cash, naikkan level
		profile.Data.Cash = 0
		profile.Data.RebirthLevel += 1
		local newLevel = profile.Data.RebirthLevel

		UpdateCashEvent:FireClient(player, profile.Data.Cash)

		-- Sinkronisasi lantai Tycoon (Hanya dieksekusi jika plot Tycoon eksis)
		local plot = TycoonService:GetPlayerPlot(player)
		if plot then
			TycoonService:SyncRebirthFloors(plot, newLevel)
		end

		-- Kita buat return dummy karena GameConfig.Rebirth.GetRewards sudah kamu hapus
		-- Gantinya, UI bisa langsung baca dari client GameConfig
		return true, "Rebirth successful!", { NewLevel = newLevel }
	end
end

return RebirthService