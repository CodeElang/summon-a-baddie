local TycoonService = {}

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local DataService = require(script.Parent.DataService)
local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local FormatNumber = require(ReplicatedStorage.Shared.Utils.FormatNumber)

local NetworkFolder = ReplicatedStorage.Network
local UpdateCashEvent = NetworkFolder:WaitForChild("UpdateCash")

local ForceClientRefresh = NetworkFolder:FindFirstChild("ForceClientRefresh")
if not ForceClientRefresh then
	ForceClientRefresh = Instance.new("RemoteEvent")
	ForceClientRefresh.Name = "ForceClientRefresh"
	ForceClientRefresh.Parent = NetworkFolder
end

local PlotsFolder = Workspace:WaitForChild("Plots")
local PlotOwners = {}
local UnclaimedCash = {}

function TycoonService:SyncRebirthFloors(plot, rebirthLvl)
	local f2Vis = plot:FindFirstChild("F2_Rebirth1_Visuals") or ServerStorage:FindFirstChild(plot.Name .. "_F2_Vis")
	local f3Vis = plot:FindFirstChild("F3_Rebirth2_Visuals") or ServerStorage:FindFirstChild(plot.Name .. "_F3_Vis")

	if f2Vis then f2Vis.Name = plot.Name .. "_F2_Vis" end
	if f3Vis then f3Vis.Name = plot.Name .. "_F3_Vis" end

	local f2Plug = plot:FindFirstChild("F2_Locked_Plug")
	local f3Plug = plot:FindFirstChild("F3_Locked_Plug")
	if f2Plug then f2Plug.Parent = ServerStorage end
	if f3Plug then f3Plug.Parent = ServerStorage end

	if f2Vis then f2Vis.Parent = (rebirthLvl >= 10) and plot or ServerStorage end
	if f3Vis then f3Vis.Parent = (rebirthLvl >= 20) and plot or ServerStorage end

	local slotsDir = plot:FindFirstChild("Slots")
	if not slotsDir then return end

	local hiddenSlotsDir = ServerStorage:FindFirstChild("HiddenSlots_" .. plot.Name) 
	if not hiddenSlotsDir then
		hiddenSlotsDir = Instance.new("Folder")
		hiddenSlotsDir.Name = "HiddenSlots_" .. plot.Name
		hiddenSlotsDir.Parent = ServerStorage
	end

	local allSlots = {}
	for _, s in ipairs(slotsDir:GetChildren()) do table.insert(allSlots, s) end
	for _, s in ipairs(hiddenSlotsDir:GetChildren()) do table.insert(allSlots, s) end

	for _, slot in ipairs(allSlots) do
		local num = tonumber(string.match(slot.Name, "%d+"))
		if num then
			local isUnlocked = false
			if num <= 12 then isUnlocked = true
			elseif num > 12 and num <= 24 then isUnlocked = (rebirthLvl >= 10)
			elseif num > 24 then isUnlocked = (rebirthLvl >= 20)
			end

			if isUnlocked then
				slot.Parent = slotsDir
				local p = slot:FindFirstChildOfClass("ProximityPrompt")
				if p then p.Enabled = true end
			else
				slot.Parent = hiddenSlotsDir
				local p = slot:FindFirstChildOfClass("ProximityPrompt")
				if p then p.Enabled = false end
			end
		end
	end
end

function TycoonService:AttachBillboard(baddieGroup, targetData, tierCfg)
	local head = baddieGroup:FindFirstChild("Head", true) or baddieGroup.PrimaryPart
	if not head then return end

	if head:FindFirstChild("Stats") then head.Stats:Destroy() end

	local bCfg = GameConfig.GetBaddieData(targetData.Name)
	local baseIncome = bCfg and bCfg.Income or 10 -- FIX: Income, bukan BaseIncome
	local chanceNum = bCfg and bCfg.Chance or 1
	local chanceDisplay = "1 in " .. FormatNumber.Format(chanceNum)

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

function TycoonService:Init()
	for _, plot in ipairs(PlotsFolder:GetChildren()) do
		PlotOwners[plot] = nil
		self:SetupClaimPad(plot)
		self:SetupSlotPrompts(plot)
		self:SyncRebirthFloors(plot, 0) 
	end
end

function TycoonService:Start()
	Players.PlayerAdded:Connect(function(player)
		task.spawn(function() self:AssignAvailablePlot(player) end)
	end)
	Players.PlayerRemoving:Connect(function(player) self:ReleasePlot(player) end)

	task.spawn(function()
		while true do
			task.wait(1)
			for plot, owner in pairs(PlotOwners) do
				if owner and UnclaimedCash[owner] then
					local income, maxCapacity = self:CalculateTotalIncome(owner)

					UnclaimedCash[owner] += income
					if UnclaimedCash[owner] > maxCapacity then
						UnclaimedCash[owner] = maxCapacity
					end

					local core = plot:FindFirstChild("CoreMechanics")
					if core then
						local h = core:FindFirstChild("Hologram")
						if h and h:FindFirstChild("BillboardGui") then
							local txt = "Unclaimed:\n$" .. FormatNumber.Format(UnclaimedCash[owner])
							if UnclaimedCash[owner] >= maxCapacity then
								txt = txt .. "\n(MAX CAPACITY!)"
								h.BillboardGui.TextLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
							else
								h.BillboardGui.TextLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
							end
							h.BillboardGui.TextLabel.Text = txt
						end
					end
				end
			end
		end
	end)
end

function TycoonService:AssignAvailablePlot(player)
	local profile = DataService:WaitForProfile(player)
	if not profile then return end
	UpdateCashEvent:FireClient(player, profile.Data.Cash)

	for _, plot in ipairs(PlotsFolder:GetChildren()) do
		if PlotOwners[plot] == nil then
			PlotOwners[plot] = player
			UnclaimedCash[player] = 0
			
			local ownerVal = plot:FindFirstChild("Owner")
			if not ownerVal then
				ownerVal = Instance.new("StringValue")
				ownerVal.Name = "Owner"
				ownerVal.Parent = plot
			end
			ownerVal.Value = player.Name

			local core = plot:FindFirstChild("CoreMechanics")
			if core and core:FindFirstChild("Hologram") then
				core.Hologram.BillboardGui.Enabled = true
			end

			self:SyncRebirthFloors(plot, profile.Data.RebirthLevel)
			self:TeleportToPlot(player, plot)
			self:SyncSlots(player)
			return 
		end
	end
end

function TycoonService:TeleportToPlot(player, plot)
	local core = plot:FindFirstChild("CoreMechanics")
	local spawn = core and core:FindFirstChild("SpawnPoint")
	if not spawn then return end

	local function move(char)
		local root = char:WaitForChild("HumanoidRootPart")
		root.CFrame = spawn.CFrame + Vector3.new(0, 5, 0)
	end
	if player.Character then move(player.Character) end
	player.CharacterAdded:Connect(move)
end

function TycoonService:ReleasePlot(player)
	for plot, owner in pairs(PlotOwners) do
		if owner == player then
			PlotOwners[plot] = nil

			local ownerVal = plot:FindFirstChild("Owner")
			if ownerVal then
				ownerVal.Value = ""
			end
			UnclaimedCash[player] = nil

			local core = plot:FindFirstChild("CoreMechanics")
			if core and core:FindFirstChild("Hologram") then
				core.Hologram.BillboardGui.Enabled = false
				core.Hologram.BillboardGui.TextLabel.Text = "Unclaimed:\n$0"
			end

			self:SyncRebirthFloors(plot, 0)

			local pFolder = plot:FindFirstChild("Slots")
			if pFolder then
				for _, slot in ipairs(pFolder:GetChildren()) do
					for _, c in ipairs(slot:GetChildren()) do
						if c:IsA("Model") then c:Destroy() end
					end
					local p = slot:FindFirstChildOfClass("ProximityPrompt")
					local isPremium = slot:GetAttribute("Multiplier") and slot:GetAttribute("Multiplier") > 1
					if p then p.ActionText = isPremium and "PREMIUM (2X)" or "Equip Baddie" end
				end
			end
			break
		end
	end
end

function TycoonService:SetupClaimPad(plot)
	local core = plot:FindFirstChild("CoreMechanics")
	if not core then return end
	local pad = core:FindFirstChild("ClaimPad")
	if pad then
		local db = false
		pad.Touched:Connect(function(hit)
			local char = hit.Parent
			local p = Players:GetPlayerFromCharacter(char)
			if p and PlotOwners[plot] == p and not db then
				db = true
				self:ClaimCash(p)
				task.wait(0.5)
				db = false
			end
		end)
	end
end

function TycoonService:SetupSlotPrompts(plot)
	local pFolder = plot:FindFirstChild("Slots")
	if not pFolder then return end
	for _, slot in ipairs(pFolder:GetChildren()) do
		if slot:FindFirstChild("Stats") then slot.Stats:Destroy() end
		local prompt = slot:FindFirstChildOfClass("ProximityPrompt")
		if prompt then
			prompt.Triggered:Connect(function(player)
				if PlotOwners[plot] == player then
					self:HandleSlotInteraction(player, slot.Name)
				end
			end)
		end
	end
end

function TycoonService:HandleSlotInteraction(player, slotName)
	local profile = DataService:GetProfile(player)
	if not profile then return false end

	local currentEquipped = profile.Data.EquippedBaddies[slotName]

	if currentEquipped and currentEquipped ~= "" then

		profile.Data.EquippedBaddies[slotName] = ""

		if profile.Data.CombatHotbar then
			local addedToHotbar = false
			for i = 1, 8 do
				local key = "Slot" .. tostring(i)
				if profile.Data.CombatHotbar[key] == "" or profile.Data.CombatHotbar[key] == nil then
					profile.Data.CombatHotbar[key] = currentEquipped
					addedToHotbar = true
					break
				end
			end
		end

		self:SyncSlots(player)
		ForceClientRefresh:FireClient(player)
		return true
	else

		local char = player.Character
		if not char then return false end

		local heldBaddie = nil
		for _, tool in ipairs(char:GetChildren()) do
			if tool:IsA("Tool") and string.sub(tool.Name, 1, 5) == "Hold_" then
				heldBaddie = tool
				break
			end
		end

		if heldBaddie then
			local baddieId = string.sub(heldBaddie.Name, 6)

			for k, v in pairs(profile.Data.EquippedBaddies) do
				if v == baddieId then profile.Data.EquippedBaddies[k] = "" end
			end

			if profile.Data.CombatHotbar then
				for k, v in pairs(profile.Data.CombatHotbar) do
					if v == baddieId then profile.Data.CombatHotbar[k] = "" end
				end
			end

			profile.Data.EquippedBaddies[slotName] = baddieId
			heldBaddie:Destroy()
			self:SyncSlots(player)
			ForceClientRefresh:FireClient(player)
			return true
		end
	end
	return false
end

function TycoonService:SyncSlots(player)
	local plot = nil
	for p, owner in pairs(PlotOwners) do
		if owner == player then plot = p break end
	end
	if not plot then return end

	local profile = DataService:GetProfile(player)
	local pFolder = plot:FindFirstChild("Slots")
	if not pFolder or not profile then return end

	for _, slot in ipairs(pFolder:GetChildren()) do
		for _, c in ipairs(slot:GetChildren()) do
			if c:IsA("Model") then c:Destroy() end
		end

		local prompt = slot:FindFirstChildOfClass("ProximityPrompt")
		local bId = profile.Data.EquippedBaddies[slot.Name]
		local targetData = nil

		if bId and bId ~= "" then
			for _, b in ipairs(profile.Data.Baddies) do
				if b.Id == bId then targetData = b break end
			end
		end

		if targetData then
			local tCfg = GameConfig.Tiers[targetData.Rarity]
			if tCfg then
				local source = ReplicatedStorage.Baddies:FindFirstChild(tCfg.Folder)
				if source then
					local tool = source:FindFirstChild(targetData.Name)
					if tool and tool:IsA("Tool") then
						local baddieGroup = Instance.new("Model")
						baddieGroup.Name = "SlotBaddie"

						local mainRootPart = nil

						for _, child in ipairs(tool:GetChildren()) do
							if child:IsA("Model") and string.match(child.Name, "VisualModel") then
								local clone = child:Clone()
								clone.Parent = baddieGroup

								local rootPart = clone:FindFirstChild("HumanoidRootPart")
								if rootPart then
									if not mainRootPart then
										mainRootPart = rootPart
										baddieGroup.PrimaryPart = mainRootPart
									end
									rootPart.Anchored = true 
								end

								local hum = clone:FindFirstChildOfClass("Humanoid")
								if hum then
									hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
								end

								for _, desc in ipairs(clone:GetDescendants()) do
									if desc:IsA("BasePart") then
										desc.CanCollide = false
										desc.Massless = true
										if desc.Name ~= "HumanoidRootPart" then
											desc.Anchored = false
										end
									end

									if desc:IsA("WeldConstraint") then
										if desc.Part0 == nil or desc.Part1 == nil or not desc.Part1:IsDescendantOf(clone) then
											desc:Destroy()
										end
									end
								end
							end
						end

						if mainRootPart then
							baddieGroup.Parent = slot
							local yOffset = (slot.Size.Y / 2) + 3.2 
							baddieGroup:PivotTo(slot.CFrame * CFrame.new(0, yOffset, 0))
							self:AttachBillboard(baddieGroup, targetData, tCfg)
							if prompt then prompt.ActionText = "Take Baddie" end
						else
							baddieGroup:Destroy() 
						end
					end
				end
			end
		else
			local isPremium = slot:GetAttribute("Multiplier") and slot:GetAttribute("Multiplier") > 1
			if prompt then prompt.ActionText = isPremium and "PREMIUM (2X)" or "Equip Baddie" end
		end
	end
end

function TycoonService:CalculateTotalIncome(player)
	local profile = DataService:GetProfile(player)
	if not profile then return 10, 5000 end 

	local plot = nil
	for p, owner in pairs(PlotOwners) do
		if owner == player then plot = p break end
	end

	local totalIncome = 0
	local totalCapacity = 0

	-- 🔥 FIX Rebirth Logic (Mencegah pemanggilan tak perlu)
	local rLvl = profile.Data.RebirthLevel
	local rebirthMultiplier = 1.0
	if rLvl > 0 then
		local rebirthConfig = GameConfig.Rebirth[rLvl] or GameConfig.Rebirth[20]
		rebirthMultiplier = rebirthConfig.CoinMultiplier
	end

	-- 🔥 FIX Multiplier Logic (Langsung ditambah sesuai config 1.0 = +100%)
	local currentCoinLvl = profile.Data.Upgrades.CoinLevel or 0
	local upgradeCoinBonus = 1.0
	if currentCoinLvl > 0 and GameConfig.Upgrades.Coin.Tiers[currentCoinLvl] then
		upgradeCoinBonus = 1.0 + GameConfig.Upgrades.Coin.Tiers[currentCoinLvl].BonusPercent
	end

	local potionCoinBonus = 1.0
	if profile.Data.ActiveBuffs and os.time() < (profile.Data.ActiveBuffs.MoneyEndsAt or 0) then
		potionCoinBonus = profile.Data.ActiveBuffs.MoneyMultiplier or 1.0
	end

	local petCoinBonus = 1.0 

	local finalGlobalMultiplier = rebirthMultiplier * upgradeCoinBonus * potionCoinBonus * petCoinBonus

	for slotName, bId in pairs(profile.Data.EquippedBaddies) do
		if bId ~= "" then
			for _, bData in ipairs(profile.Data.Baddies) do
				if bData.Id == bId then
					local bCfg = GameConfig.GetBaddieData(bData.Name)
					if bCfg then 
						local income = bCfg.Income -- FIX: Income
						local capacity = bCfg.MaxStorage or (income * 100) -- FIX: Fallback karena MaxStorage di config baru dihilangkan
						local slotMulti = 1

						if plot and plot:FindFirstChild("Slots") then
							local slotPart = plot.Slots:FindFirstChild(slotName)
							if slotPart then
								slotMulti = slotPart:GetAttribute("Multiplier") or 1
							end
						end

						local baddieMultiplier = finalGlobalMultiplier * slotMulti
						totalIncome += (income * baddieMultiplier) 
						totalCapacity += (capacity * baddieMultiplier)
					end
					break
				end
			end
		end
	end

	if totalIncome == 0 then totalIncome = 10 end
	if totalCapacity == 0 then totalCapacity = 5000 end

	return totalIncome, totalCapacity
end

function TycoonService:ClaimCash(player)
	local profile = DataService:GetProfile(player)
	if profile and UnclaimedCash[player] and UnclaimedCash[player] > 0 then
		profile.Data.Cash += UnclaimedCash[player]
		UnclaimedCash[player] = 0
		UpdateCashEvent:FireClient(player, profile.Data.Cash)
	end
end

function TycoonService:GetPlayerPlot(player)
	for plot, owner in pairs(PlotOwners) do
		if owner == player then
			return plot
		end
	end
	return nil
end

return TycoonService