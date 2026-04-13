local InventoryService = {}
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataService = require(script.Parent.DataService)
local TycoonService = require(script.Parent.TycoonService)
local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local FormatNumber = require(ReplicatedStorage.Shared.Utils.FormatNumber)

local Network = ReplicatedStorage.Network
local GetInvEvent = Network:WaitForChild("GetInventory")
local HoldEvent = Network:WaitForChild("HoldBaddie")
local AutoBestEvent = Network:WaitForChild("AutoEquipBest")
local SwapEvent = Network:WaitForChild("SwapHotbar")

local function AttachBillboard(model, targetData, tierCfg, baddieCfg)
	local head = model:FindFirstChild("Head", true) or model.PrimaryPart
	if not head then return end

	if head:FindFirstChild("Stats") then head.Stats:Destroy() end

	local chanceDisplay = "1 in " .. FormatNumber.Format(baddieCfg.Chance)
	local baseIncome = baddieCfg.Income -- FIX: BaseIncome diganti menjadi Income

	local bb = Instance.new("BillboardGui")
	bb.Name = "Stats"
	bb.Size = UDim2.new(5, 0, 2.5, 0)
	bb.StudsOffset = Vector3.new(0, 3.5, 0)
	bb.AlwaysOnTop = false
	bb.MaxDistance = 100

	local tName = Instance.new("TextLabel", bb)
	tName.Size = UDim2.new(1, 0, 0.4, 0)
	tName.BackgroundTransparency = 1
	tName.TextColor3 = Color3.fromRGB(255, 255, 255)
	tName.Font = Enum.Font.GothamBlack
	tName.TextScaled = true
	tName.Text = targetData.Name
	tName.TextStrokeTransparency = 0.2

	local tTier = Instance.new("TextLabel", bb)
	tTier.Size = UDim2.new(1, 0, 0.3, 0)
	tTier.Position = UDim2.new(0, 0, 0.4, 0)
	tTier.BackgroundTransparency = 1
	tTier.TextColor3 = tierCfg.Color
	tTier.Font = Enum.Font.GothamBold
	tTier.TextScaled = true
	tTier.Text = targetData.Rarity .. " (" .. chanceDisplay .. ")"
	tTier.TextStrokeTransparency = 0.4

	local tInc = Instance.new("TextLabel", bb)
	tInc.Size = UDim2.new(1, 0, 0.3, 0)
	tInc.Position = UDim2.new(0, 0, 0.7, 0)
	tInc.BackgroundTransparency = 1
	tInc.TextColor3 = Color3.fromRGB(85, 255, 127)
	tInc.Font = Enum.Font.GothamMedium
	tInc.TextScaled = true
	tInc.Text = "$" .. FormatNumber.Format(baseIncome) .. "/sec"
	tInc.TextStrokeTransparency = 0.5

	bb.Parent = head
end

function InventoryService:Init() end

function InventoryService:Start()

	GetInvEvent.OnServerInvoke = function(player)
		local profile = DataService:GetProfile(player)
		if not profile then return nil end

		if not profile.Data.CombatHotbar then
			profile.Data.CombatHotbar = {Slot1="", Slot2="", Slot3="", Slot4="", Slot5="", Slot6="", Slot7="", Slot8=""}
		end

		if not profile.Data.Party then
			profile.Data.Party = {Slot1="", Slot2="", Slot3="", Slot4=""}
		end

		local validBaddies = {}
		for _, b in ipairs(profile.Data.Baddies) do
			validBaddies[b.Id] = true
		end

		for i = 1, 8 do
			local slotKey = "Slot" .. tostring(i)
			local currentId = profile.Data.CombatHotbar[slotKey]
			if currentId ~= "" and currentId ~= nil and not validBaddies[currentId] then
				profile.Data.CombatHotbar[slotKey] = "" 
			end
		end

		return profile.Data.Baddies, profile.Data.EquippedBaddies, profile.Data.CombatHotbar, profile.Data.Party
	end

	HoldEvent.OnServerInvoke = function(player, baddieId)
		local profile = DataService:GetProfile(player)
		if not profile or not player.Character or not player.Character:FindFirstChild("Humanoid") then return false end

		local currentTool = player.Character:FindFirstChild("Hold_" .. baddieId)
		if currentTool then
			currentTool:Destroy()
			return true, "Unequipped"
		end

		for _, item in ipairs(player.Character:GetChildren()) do
			if item:IsA("Tool") then item:Destroy() end
		end
		if player.Backpack then
			for _, item in ipairs(player.Backpack:GetChildren()) do item:Destroy() end
		end

		local targetData = nil
		for _, b in ipairs(profile.Data.Baddies) do
			if b.Id == baddieId then targetData = b break end
		end
		if not targetData then return false end

		local tierCfg = GameConfig.Tiers[targetData.Rarity]
		local baddieCfg = GameConfig.GetBaddieData(targetData.Name)
		if not tierCfg or not baddieCfg then return false end

		local modelSource = ReplicatedStorage.Baddies:FindFirstChild(tierCfg.Folder)
		if modelSource then
			local actualTool = modelSource:FindFirstChild(targetData.Name)
			if actualTool and actualTool:IsA("Tool") then
				local cloneTool = actualTool:Clone()
				cloneTool.Name = "Hold_" .. baddieId

				local visualModel = cloneTool:FindFirstChild("VisualModel")
				if visualModel then
					for _, desc in ipairs(visualModel:GetDescendants()) do
						if desc:IsA("BasePart") then
							desc.CanCollide = false
							desc.CanQuery = false
							desc.CanTouch = false
							desc.Massless = true
							desc.Anchored = false
						elseif desc:IsA("Humanoid") then
							desc.PlatformStand = true
						end
					end

					AttachBillboard(visualModel, targetData, tierCfg, baddieCfg)

					local hum = visualModel:FindFirstChildOfClass("Humanoid")
					local idleAnim = visualModel:FindFirstChild("IdleAnim")
					if hum and idleAnim then
						local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
						task.delay(0.1, function()
							pcall(function()
								local track = animator:LoadAnimation(idleAnim)
								track.Looped = true
								track:Play()
							end)
						end)
					end
				end

				cloneTool.Parent = player.Character
				return true, "Equipped"
			end
		end
		return false
	end

	AutoBestEvent.OnServerInvoke = function(player)
		local profile = DataService:GetProfile(player)
		if not profile then return false end

		for i = 1, 34 do profile.Data.EquippedBaddies["Slot" .. i] = "" end

		local sortedBaddies = {}
		for _, b in ipairs(profile.Data.Baddies) do table.insert(sortedBaddies, b) end

		-- FIX: Sorting menggunakan data yang ada di BaddiesData
		table.sort(sortedBaddies, function(a, b)
			local bCfgA = GameConfig.GetBaddieData(a.Name)
			local incA = bCfgA and bCfgA.Income or 0

			local bCfgB = GameConfig.GetBaddieData(b.Name)
			local incB = bCfgB and bCfgB.Income or 0

			return incA > incB
		end)

		local pRebirth = profile.Data.RebirthLevel
		local maxUnlockedSlots = 12
		if pRebirth >= 20 then maxUnlockedSlots = 34 elseif pRebirth >= 10 then maxUnlockedSlots = 24 end

		local count = 1
		for _, b in ipairs(sortedBaddies) do
			if count > maxUnlockedSlots then break end
			profile.Data.EquippedBaddies["Slot" .. count] = b.Id
			count += 1
		end

		TycoonService:SyncSlots(player)
		return true
	end

	local ToggleFavEvent = Network:FindFirstChild("ToggleFavorite")
	if not ToggleFavEvent then
		ToggleFavEvent = Instance.new("RemoteFunction")
		ToggleFavEvent.Name = "ToggleFavorite"
		ToggleFavEvent.Parent = Network
	end

	ToggleFavEvent.OnServerInvoke = function(player, baddieId)
		local profile = DataService:GetProfile(player)
		if not profile then return false end

		for _, b in ipairs(profile.Data.Baddies) do
			if b.Id == baddieId then
				b.IsFavorite = not (b.IsFavorite or false)
				return true, b.IsFavorite
			end
		end
		return false
	end

	SwapEvent.OnServerInvoke = function(player, hotbarSlotNum, targetBaddieId)
		local profile = DataService:GetProfile(player)
		if not profile then return false end

		if not profile.Data.CombatHotbar then
			profile.Data.CombatHotbar = {Slot1="", Slot2="", Slot3="", Slot4="", Slot5="", Slot6="", Slot7="", Slot8=""}
		end
		if not profile.Data.Party then
			profile.Data.Party = {Slot1="", Slot2="", Slot3="", Slot4=""}
		end

		local slotKey = "Slot" .. tostring(hotbarSlotNum)
		local oldHotbarBaddieId = profile.Data.CombatHotbar[slotKey]

		if targetBaddieId == "" or targetBaddieId == nil then
			profile.Data.CombatHotbar[slotKey] = ""
		else
			local hasBaddie = false
			for _, b in ipairs(profile.Data.Baddies) do
				if b.Id == targetBaddieId then
					hasBaddie = true
					break
				end
			end
			if not hasBaddie then return false end

			local sourcePartyKey = nil
			for k, v in pairs(profile.Data.Party) do
				if v == targetBaddieId then 
					sourcePartyKey = k 
					break 
				end
			end

			for k, v in pairs(profile.Data.CombatHotbar) do
				if k ~= slotKey and v == targetBaddieId then
					profile.Data.CombatHotbar[k] = ""
				end
			end

			profile.Data.CombatHotbar[slotKey] = targetBaddieId

			if sourcePartyKey then
				profile.Data.Party[sourcePartyKey] = oldHotbarBaddieId or ""
			end
		end

		if player.Character then
			for _, item in ipairs(player.Character:GetChildren()) do
				if item:IsA("Tool") and string.sub(item.Name, 1, 5) == "Hold_" then
					local heldId = string.sub(item.Name, 6)
					local isStillInHotbar = false
					for _, v in pairs(profile.Data.CombatHotbar) do
						if v == heldId then
							isStillInHotbar = true
							break
						end
					end
					if not isStillInHotbar then
						item:Destroy()
					end
				end
			end
		end

		return true
	end
end

return InventoryService