local AdminService = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local DataService = require(script.Parent.DataService)
local TycoonService = require(script.Parent.TycoonService) 
local BaddieClass = require(ReplicatedStorage.Shared.Classes.Baddie)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig) -- DITAMBAHKAN: Single Source of Truth

local NetworkFolder = ReplicatedStorage:WaitForChild("Network")
local AdminActionEvent

local ADMIN_IDS = {
	[2964250748] = true,
	[140068095] = true
}

function AdminService:Init()
	if not NetworkFolder:FindFirstChild("AdminAction") then
		AdminActionEvent = Instance.new("RemoteEvent")
		AdminActionEvent.Name = "AdminAction"
		AdminActionEvent.Parent = NetworkFolder
	else
		AdminActionEvent = NetworkFolder.AdminAction
	end

	AdminActionEvent.OnServerEvent:Connect(function(player, action, args)
		if not ADMIN_IDS[player.UserId] then
			player:Kick("Anti-Exploit: Unauthorized Access.")
			return
		end
		self:HandleAction(player, action, args)
	end)
end

function AdminService:Start()
	Players.PlayerAdded:Connect(function(player)
		if ADMIN_IDS[player.UserId] then
			local adminUI = ServerStorage:FindFirstChild("AdminPanelUI")
			if adminUI then
				local clone = adminUI:Clone()
				clone.Parent = player:WaitForChild("PlayerGui")
			end
		end
	end)
end

function AdminService:HandleAction(admin, action, args)
	local targetPlayer = args.TargetName and args.TargetName ~= "" and Players:FindFirstChild(args.TargetName) or admin
	local profile = DataService:GetProfile(targetPlayer)

	if action == "SetSpeed" then
		local hum = targetPlayer.Character and targetPlayer.Character:FindFirstChildOfClass("Humanoid")
		if hum then hum.WalkSpeed = tonumber(args.Value) or 16 end

	elseif action == "SetJump" then
		local hum = targetPlayer.Character and targetPlayer.Character:FindFirstChildOfClass("Humanoid")
		if hum then 
			hum.UseJumpPower = true
			hum.JumpPower = tonumber(args.Value) or 50 
		end

	elseif action == "GiveCash" and profile then
		profile.Data.Cash += tonumber(args.Value) or 0
		NetworkFolder.UpdateCash:FireClient(targetPlayer, profile.Data.Cash)

	elseif action == "SetLuck" and profile then
		local inputPercent = tonumber(args.Value) or 100
		profile.Data.LuckBoost = inputPercent / 100

	elseif action == "SetRebirth" and profile then
		local newLevel = tonumber(args.Value) or 0
		profile.Data.RebirthLevel = newLevel
		local plot = TycoonService:GetPlayerPlot(targetPlayer)
		if plot then TycoonService:SyncRebirthFloors(plot, newLevel) end

	elseif action == "GiveBaddie" and profile then
		local baddieName = args.Value
		local amount = tonumber(args.Amount) or 1
		local foundTier = "Common"

		-- 🔥 FIX: Gunakan GameConfig untuk mendapatkan Data yang valid
		local baddieConfigData = GameConfig.GetBaddieData(baddieName)
		if baddieConfigData then
			foundTier = baddieConfigData.Rarity
		else
			warn("Admin mencoba spawn Baddie invalid: " .. tostring(baddieName))
			return -- Abort jika baddie tidak ada di GameConfig
		end

		local validBaddies = {}
		for _, b in ipairs(profile.Data.Baddies) do
			validBaddies[b.Id] = true
		end

		for i = 1, amount do
			local uniqueId = "BD_" .. math.random(100000, 999999)
			local newBaddie = BaddieClass.new(uniqueId, baddieName, foundTier)
			table.insert(profile.Data.Baddies, newBaddie)
			validBaddies[uniqueId] = true 

			if not profile.Data.CombatHotbar then
				profile.Data.CombatHotbar = {Slot1="", Slot2="", Slot3="", Slot4="", Slot5="", Slot6="", Slot7="", Slot8=""}
			end

			-- Auto equip ke Hotbar admin (hanya sampai 8)
			for slotNum = 1, 8 do
				local slotKey = "Slot" .. tostring(slotNum)
				local currentId = profile.Data.CombatHotbar[slotKey]

				if currentId == "" or currentId == nil or not validBaddies[currentId] then
					profile.Data.CombatHotbar[slotKey] = uniqueId
					break
				end
			end
		end

		local ForceRefreshEvent = NetworkFolder:FindFirstChild("ForceClientRefresh")
		if ForceRefreshEvent then
			ForceRefreshEvent:FireClient(targetPlayer)
		end

	elseif action == "GiveBook" and profile then
		local bookType = args.Value
		local amount = tonumber(args.Amount) or 1

		-- 🔥 FIX: Validasi memastikan tipe buku benar-benar ada di GameConfig
		local isValidBook = false
		for _, b in ipairs(GameConfig.Books) do
			if b.Name == bookType then isValidBook = true break end
		end

		if isValidBook then
			profile.Data.Books[bookType] = (profile.Data.Books[bookType] or 0) + amount
		else
			warn("Admin mencoba give Buku invalid: " .. tostring(bookType))
		end

	elseif action == "Teleport" then
		local tpTarget = Players:FindFirstChild(args.Value)
		if admin.Character and tpTarget and tpTarget.Character then
			admin.Character:PivotTo(tpTarget.Character:GetPivot() * CFrame.new(0, 0, -5))
		end

	elseif action == "Morph" then
		self:MorphPlayer(admin, args.Value)

	elseif action == "ResetCash" and profile then
		profile.Data.Cash = 5000 
		NetworkFolder.UpdateCash:FireClient(targetPlayer, profile.Data.Cash)

	elseif action == "ResetRebirth" and profile then
		profile.Data.RebirthLevel = 0
		local plot = TycoonService:GetPlayerPlot(targetPlayer)
		if plot then TycoonService:SyncRebirthFloors(plot, 0) end

	elseif action == "ResetBaddies" and profile then
		profile.Data.Baddies = {}
		-- 🔥 FIX: Loop sampai 36 karena DataService kamu mensupport 36 Slot lantai
		for i = 1, 36 do profile.Data.EquippedBaddies["Slot"..i] = "" end
		targetPlayer:Kick("Admin wiped your Baddies. Please rejoin.")

	elseif action == "ResetAbilities" and profile then
		profile.Data.Upgrades.CoinLevel = 0
		profile.Data.Upgrades.LuckLevel = 0
		-- 🔥 FIX: Menghapus StockLevel, RestockLevel dll karena sudah tidak ada di DataService

		if profile.Data.ActiveBuffs then
			profile.Data.ActiveBuffs.MoneyEndsAt = 0
			profile.Data.ActiveBuffs.LuckEndsAt = 0
		end
		targetPlayer:Kick("Admin reset your Upgrades/Abilities. Please rejoin.")

	elseif action == "WipeAll" and profile then
		profile.Data.Cash = 5000
		profile.Data.LuckBoost = 1
		profile.Data.RebirthLevel = 0
		profile.Data.Baddies = {}

		profile.Data.Upgrades.CoinLevel = 0
		profile.Data.Upgrades.LuckLevel = 0

		if profile.Data.ActiveBuffs then
			profile.Data.ActiveBuffs.MoneyEndsAt = 0
			profile.Data.ActiveBuffs.LuckEndsAt = 0
		end

		-- 🔥 FIX: 36 Slot
		for i = 1, 36 do profile.Data.EquippedBaddies["Slot"..i] = "" end

		-- Reset Books
		for key, _ in pairs(profile.Data.Books) do profile.Data.Books[key] = 0 end

		targetPlayer:Kick("Admin performed a FULL WIPE. Please rejoin.")
	end
end

function AdminService:MorphPlayer(player, targetName)
	local oldChar = player.Character
	if not oldChar then return end

	local currentCFrame = oldChar:GetPivot()
	local morphModel = nil

	local targetPlayer = Players:FindFirstChild(targetName)
	if targetPlayer and targetPlayer.Character then
		oldChar:PivotTo(targetPlayer.Character:GetPivot() * CFrame.new(0, 0, -5))
		return 
	end

	local baddiesFolder = ReplicatedStorage:FindFirstChild("Baddies")
	if baddiesFolder then
		for _, tier in ipairs(baddiesFolder:GetChildren()) do
			local baddieTool = tier:FindFirstChild(targetName)
			if baddieTool and baddieTool:FindFirstChild("VisualModel") then
				morphModel = baddieTool.VisualModel:Clone()
				break
			end
		end
	end

	if morphModel then
		morphModel.Name = player.Name
		local rootPart = morphModel:FindFirstChild("HumanoidRootPart")
		if rootPart then morphModel.PrimaryPart = rootPart end

		local hum = morphModel:FindFirstChildOfClass("Humanoid")
		if not hum then
			hum = Instance.new("Humanoid")
			hum.Parent = morphModel
		end
		hum.PlatformStand = false
		hum.WalkSpeed = 16
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer

		for _, desc in ipairs(morphModel:GetDescendants()) do
			if desc:IsA("BasePart") and desc.Name ~= "HumanoidRootPart" then
				desc.Anchored = false
			end
		end

		morphModel:PivotTo(currentCFrame)
		morphModel.Parent = workspace
		player.Character = morphModel
		oldChar:Destroy() 
	end
end

return AdminService