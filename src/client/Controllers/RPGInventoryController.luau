local RPGInventoryController = {}
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local PreviewController = require(script.Parent:WaitForChild("PreviewController"))
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local FormatNumber = require(ReplicatedStorage.Shared.Utils.FormatNumber)

local Network = ReplicatedStorage.Network
local GetInvEvent = Network:WaitForChild("GetInventory")
local SwapEvent = Network:WaitForChild("SwapHotbar")
local SwapPartyEvent = Network:WaitForChild("SwapPartySlot")
local AutoBestEvent = Network:WaitForChild("AutoEquipBest")
local ToggleFavEvent = Network:WaitForChild("ToggleFavorite")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local isDragging = false
local lastMousePos = Vector2.new()

local cachedInventory = {}
local cachedCombatHotbar = {}
local cachedEquippedBaddies = {}
local cachedParty = {}

local currentlySelectedCardId = nil 
local currentRenderId = 0 

function RPGInventoryController:Init() end

function RPGInventoryController:Start()
	playerGui:SetAttribute("SelectedHotbarSlot", 0)
	playerGui:SetAttribute("SelectedPartySlot", 0)

	local mainUI = playerGui:WaitForChild("MainUI")
	local summonHUD = mainUI:FindFirstChild("SummonHUD") or mainUI:WaitForChild("SummonHUD")
	local openBtn = summonHUD:WaitForChild("LeftBar"):WaitForChild("BagBtn")

	local inventoryUI = mainUI:WaitForChild("RPGInventoryContainer")
	local dragArea = inventoryUI:WaitForChild("DragArea")
	local closeBtn = inventoryUI:WaitForChild("CloseButton")
	local statsPanel = inventoryUI:WaitForChild("StatsPanel")
	local baddieList = inventoryUI:WaitForChild("BaddieList")
	local searchFilter = inventoryUI:WaitForChild("SearchFilter")
	local placeBestBtn = inventoryUI:WaitForChild("PlaceBestBtn")

	local template = ReplicatedStorage:WaitForChild("Templates"):WaitForChild("CompactBaddieCard")

	baddieList.CanvasSize = UDim2.new(0, 0, 0, 0)
	local listGrid = baddieList:FindFirstChildOfClass("UIGridLayout")
	if listGrid then
		listGrid:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
			baddieList.CanvasSize = UDim2.new(0, 0, 0, listGrid.AbsoluteContentSize.Y + 20)
		end)
	end

	local function ToggleExtraUI(isVisible)
		if summonHUD then summonHUD.Visible = isVisible end
		local cashHUD = playerGui:FindFirstChild("CashHUD", true)
		if cashHUD then cashHUD.Visible = isVisible end
		if mainUI then
			for _, child in ipairs(mainUI:GetChildren()) do
				local n = string.lower(child.Name)
				if (string.find(n, "cash") or string.find(n, "money") or string.find(n, "statsbtn")) and child.Name ~= "RPGInventoryContainer" then
					child.Visible = isVisible
				end
			end
		end
	end

	local function SetupViewport(vpFrame, baddieName, rarity)
		local tierData = GameConfig.Tiers[rarity]
		if not tierData then return end
		local folder = ReplicatedStorage.Baddies:FindFirstChild(tierData.Folder)
		local tool = folder and folder:FindFirstChild(baddieName)
		if not tool then return end

		local worldModel = vpFrame:FindFirstChild("WorldModel")
		for _, child in ipairs(worldModel:GetChildren()) do child:Destroy() end

		local clonedModel = nil
		for _, child in ipairs(tool:GetChildren()) do
			if child.Name == "VisualModel" and child:IsA("Model") then
				clonedModel = child:Clone()
				clonedModel.Parent = worldModel
				local refPart = clonedModel:FindFirstChild("Head", true) or clonedModel:FindFirstChild("HumanoidRootPart", true) or clonedModel:FindFirstChildWhichIsA("BasePart", true)

				if refPart then
					local humanoid = clonedModel:FindFirstChildWhichIsA("Humanoid", true)
					local idleAnim = clonedModel:FindFirstChild("IdleAnim", true)
					if humanoid and idleAnim then
						local oldAnimator = humanoid:FindFirstChildOfClass("Animator")
						if oldAnimator then oldAnimator:Destroy() end
						local newAnimator = Instance.new("Animator", humanoid)
						task.spawn(function()
							task.wait(0.05)
							pcall(function()
								local animTrack = newAnimator:LoadAnimation(idleAnim)
								animTrack.Looped = true
								animTrack:Play()
							end)
						end)
					end
					clonedModel.PrimaryPart = refPart
					clonedModel:PivotTo(CFrame.new(0, 0, 0))
					local cam = Instance.new("Camera")
					cam.FieldOfView = 40 
					vpFrame.CurrentCamera = cam
					cam.Parent = vpFrame
					local _, size = clonedModel:GetBoundingBox()
					local distance = math.max(6.5, size.Magnitude * 0.7)
					cam.CFrame = CFrame.lookAt(refPart.Position + (refPart.CFrame.LookVector * distance) + Vector3.new(0, -0.5, 0), refPart.Position)
				else
					clonedModel:Destroy()
				end
				break
			end
		end
	end

	local function UpdateStatsPanel(baddieData)
		if not baddieData then 
			statsPanel.Visible = false
			return 
		end
		statsPanel.Visible = true
		local bCfg = GameConfig.GetBaddieData(baddieData.Name)
		if not bCfg then return end

		local header = statsPanel:FindFirstChild("Header")
		if header then
			if header:FindFirstChild("BaddieName") then header.BaddieName.Text = string.upper(baddieData.Name) end
			local favBtn = header:FindFirstChild("FavBtn")
			if favBtn and favBtn:FindFirstChild("Icon") then
				favBtn.Icon.ImageColor3 = (baddieData.IsFavorite or false) and Color3.fromRGB(255, 200, 50) or Color3.fromRGB(100, 100, 100)
			end
			local starCount = baddieData.Stars or 0
			if header:FindFirstChild("StarsContainer") then
				for i = 1, 5 do
					local starImg = header.StarsContainer:FindFirstChild("Star"..i)
					if starImg then starImg.Image = (i <= starCount) and "rbxassetid://77071225732995" or "rbxassetid://93073028679545" end
				end
			end
		end

		local sCont = statsPanel:FindFirstChild("StatsContainer")
		if sCont then
			if sCont:FindFirstChild("RoleRow") then sCont.RoleRow.Value.Text = bCfg.Role or "Unknown" end
			if sCont:FindFirstChild("HPRow") then sCont.HPRow.Value.Text = tostring(bCfg.BaseHP or 0) end
			if sCont:FindFirstChild("ATKRow") then sCont.ATKRow.Value.Text = tostring(bCfg.BaseATK or 0) end
			if sCont:FindFirstChild("DEFRow") then sCont.DEFRow.Value.Text = tostring(bCfg.BaseDEF or 0) end
			if sCont:FindFirstChild("SPDRow") then sCont.SPDRow.Value.Text = tostring(bCfg.BaseSPD or 0) end
		end

		local mCont = statsPanel:FindFirstChild("MutationsContainer")
		if mCont and mCont:FindFirstChild("Value") then
			mCont.Value.Text = (baddieData.Mutations and #baddieData.Mutations > 0) and table.concat(baddieData.Mutations, " | ") or "None"
		end

		local rCont = statsPanel:FindFirstChild("RelicsContainer")
		if rCont then
			local r1 = baddieData.Relics and baddieData.Relics.Slot1
			local r2 = baddieData.Relics and baddieData.Relics.Slot2
			if rCont:FindFirstChild("Relic1") then rCont.Relic1.Text = "Slot 1: " .. (r1 and r1.Name or "Empty") end
			if rCont:FindFirstChild("Relic2") then rCont.Relic2.Text = "Slot 2: " .. (r2 and r2.Name or "Empty") end
		end
	end

	local function HighlightSelectedCard()
		for _, card in ipairs(baddieList:GetChildren()) do
			if card:IsA("Frame") and card:FindFirstChild("CardBox") then
				if card.Name == currentlySelectedCardId then
					card.CardBox.ColorBorder.BackgroundColor3 = Color3.fromRGB(255, 255, 100)
				else
					card.CardBox.ColorBorder.BackgroundColor3 = card:GetAttribute("TierColor") or Color3.fromRGB(30, 30, 35)
				end
			end
		end
	end

	local function CreateCardLogic(cardData)
		local card = template:Clone()

		if cardData then
			local bCfg = GameConfig.GetBaddieData(cardData.Name)
			local tCfg = GameConfig.Tiers[cardData.Rarity]

			if bCfg and tCfg then
				card.Name = cardData.Id
				card:SetAttribute("TierColor", tCfg.Color) 
				local bg = card.CardBox.ColorBorder.InnerBlack.Background
				card.CardBox.ColorBorder.BackgroundColor3 = tCfg.Color
				bg.TextOverlay.RarityLabel.Text = string.upper(cardData.Rarity)
				bg.TextOverlay.RarityLabel.TextColor3 = tCfg.Color
				bg.TextOverlay.NameLabel.Text = cardData.Name
				card.ChanceLabel.Text = "1 in " .. FormatNumber.Format(bCfg.Chance)
				if cardData.IsFavorite and card:FindFirstChild("FavIcon") then card.FavIcon.Visible = true end
				SetupViewport(bg.ViewportFrame, cardData.Name, cardData.Rarity)
			end
		else
			card.Name = "EMPTY"
			card:SetAttribute("TierColor", Color3.fromRGB(30, 30, 35)) 
			card.CardBox.ColorBorder.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
			local bg = card.CardBox.ColorBorder.InnerBlack.Background
			bg.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
			bg.TextOverlay.Visible = false
			card.ChanceLabel.Visible = false

			local centerText = Instance.new("TextLabel", bg)
			centerText.Size = UDim2.new(1,0,1,0)
			centerText.BackgroundTransparency = 1
			centerText.Text = "UNEQUIP"
			centerText.TextColor3 = Color3.fromRGB(100,100,100)
			centerText.Font = Enum.Font.GothamBold
			centerText.TextSize = 14
		end

		if card.Name == currentlySelectedCardId then card.CardBox.ColorBorder.BackgroundColor3 = Color3.fromRGB(255, 255, 100) end

		local btn = Instance.new("TextButton", card)
		btn.Size = UDim2.new(1, 0, 1, 0)
		btn.BackgroundTransparency = 1
		btn.Text = ""
		btn.ZIndex = 50

		btn.MouseButton1Click:Connect(function()
			local selectedHotbarSlot = playerGui:GetAttribute("SelectedHotbarSlot") or 0
			local selectedPartySlot = playerGui:GetAttribute("SelectedPartySlot") or 0
			local targetId = (card.Name == "EMPTY") and "" or card.Name

			if selectedPartySlot > 0 then
				local success = SwapPartyEvent:InvokeServer(selectedPartySlot, targetId)
				if success then
					currentlySelectedCardId = nil
					playerGui:SetAttribute("SelectedPartySlot", 0)
					playerGui:SetAttribute("ForceHotbarRefresh", not playerGui:GetAttribute("ForceHotbarRefresh"))
					playerGui:SetAttribute("ForcePartyRefresh", not playerGui:GetAttribute("ForcePartyRefresh"))
					PreviewController:FocusEmptyScene() 
					UpdateStatsPanel(nil)
					self:RefreshInventory()
				end
			elseif selectedHotbarSlot > 0 then
				local success = SwapEvent:InvokeServer(selectedHotbarSlot, targetId)
				if success then
					currentlySelectedCardId = nil
					playerGui:SetAttribute("SelectedHotbarSlot", 0)
					playerGui:SetAttribute("ForceHotbarRefresh", not playerGui:GetAttribute("ForceHotbarRefresh"))
					PreviewController:FocusEmptyScene() 
					UpdateStatsPanel(nil)
					self:RefreshInventory()
				end
			else
				currentlySelectedCardId = card.Name
				HighlightSelectedCard()

				if cardData then
					UpdateStatsPanel(cardData)
					local tCfg = GameConfig.Tiers[cardData.Rarity]
					if tCfg then
						local folder = ReplicatedStorage.Baddies:FindFirstChild(tCfg.Folder)
						local tool = folder and folder:FindFirstChild(cardData.Name)
						if tool then PreviewController:ShowBaddie(tool) end
					end
				else
					UpdateStatsPanel(nil)
					PreviewController:FocusEmptyScene()
				end
			end
		end)

		card.Visible = true
		return card
	end

	local function PopulateUI(filterText)
		currentRenderId += 1
		local thisRenderId = currentRenderId

		for _, child in ipairs(baddieList:GetChildren()) do
			if child:IsA("Frame") or child:IsA("TextButton") then child:Destroy() end
		end

		local toRender = {}
		for _, baddieData in ipairs(cachedInventory) do
			local inHotbar, isEquippedInBase, inParty = false, false, false

			for i = 1, 8 do if cachedCombatHotbar["Slot"..i] == baddieData.Id then inHotbar = true break end end
			for i = 1, 4 do if cachedParty["Slot"..i] == baddieData.Id then inParty = true break end end
			for _, equippedId in pairs(cachedEquippedBaddies) do if equippedId == baddieData.Id then isEquippedInBase = true break end end

			if not inHotbar and not isEquippedInBase and not inParty then
				if filterText == "" or string.find(string.lower(baddieData.Name), string.lower(filterText)) then
					table.insert(toRender, baddieData)
				end
			end
		end

		local count = 0
		for _, baddieData in ipairs(toRender) do
			if currentRenderId ~= thisRenderId then return end 
			local card = CreateCardLogic(baddieData)
			card.Parent = baddieList
			count += 1
			if count % 20 == 0 then task.wait() end 
		end

		if currentRenderId ~= thisRenderId then return end
		local emptyCard = CreateCardLogic(nil)
		emptyCard.LayoutOrder = 9999
		emptyCard.Parent = baddieList
	end

	function self:RefreshInventory()
		local baddies, equipped, hotbar, partyData = GetInvEvent:InvokeServer()
		if baddies then
			cachedInventory = {}
			for _, b in ipairs(baddies) do table.insert(cachedInventory, b) end
			table.sort(cachedInventory, function(a, b)
				local favA = a.IsFavorite and 1 or 0
				local favB = b.IsFavorite and 1 or 0
				if favA ~= favB then return favA > favB end
				local cfgA = GameConfig.GetBaddieData(a.Name)
				local cfgB = GameConfig.GetBaddieData(b.Name)
				local tierA = cfgA and cfgA.Tier or 0
				local tierB = cfgB and cfgB.Tier or 0
				if tierA ~= tierB then return tierA > tierB end
				return a.Id > b.Id
			end)
			cachedCombatHotbar = hotbar or {}
			cachedEquippedBaddies = equipped or {}
			cachedParty = partyData or {}
			PopulateUI(searchFilter.Text)
		end
	end

	local favBtn = statsPanel:FindFirstChild("Header") and statsPanel.Header:FindFirstChild("FavBtn")
	if favBtn then
		favBtn.MouseButton1Click:Connect(function()
			if currentlySelectedCardId and currentlySelectedCardId ~= "EMPTY" then
				local success, newFavState = ToggleFavEvent:InvokeServer(currentlySelectedCardId)
				if success then
					favBtn.Icon.ImageColor3 = newFavState and Color3.fromRGB(255, 200, 50) or Color3.fromRGB(100, 100, 100)
					self:RefreshInventory() 
				end
			end
		end)
	end

	placeBestBtn.MouseButton1Click:Connect(function()
		local success = AutoBestEvent:InvokeServer()
		if success then
			placeBestBtn.Text = "EQUIPPED"
			placeBestBtn.BackgroundColor3 = Color3.fromRGB(30, 100, 40)
			task.delay(1.5, function()
				if placeBestBtn then
					placeBestBtn.Text = "EQUIP BEST"
					placeBestBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
				end
			end)
		end
	end)

	playerGui:GetAttributeChangedSignal("SelectedHotbarSlot"):Connect(function()
		local slot = playerGui:GetAttribute("SelectedHotbarSlot")
		if slot and slot > 0 then
			if inventoryUI.Visible then
				PreviewController:FocusEmptyScene()
				UpdateStatsPanel(nil)
				currentlySelectedCardId = nil
				HighlightSelectedCard()
			end
		end
	end)

	playerGui:GetAttributeChangedSignal("SelectedPartySlot"):Connect(function()
		local slot = playerGui:GetAttribute("SelectedPartySlot")
		if slot and slot > 0 then
			if inventoryUI.Visible then
				PreviewController:FocusEmptyScene()
				UpdateStatsPanel(nil)
				currentlySelectedCardId = nil
				HighlightSelectedCard()
			end
		end
	end)

	openBtn.MouseButton1Click:Connect(function()
		inventoryUI.Visible = true
		currentlySelectedCardId = nil
		playerGui:SetAttribute("SelectedHotbarSlot", 0)
		UpdateStatsPanel(nil)
		ToggleExtraUI(false)
		PreviewController:FocusEmptyScene() 
		self:RefreshInventory()
	end)

	closeBtn.MouseButton1Click:Connect(function()
		inventoryUI.Visible = false
		currentlySelectedCardId = nil
		playerGui:SetAttribute("SelectedHotbarSlot", 0)
		playerGui:SetAttribute("ForceHotbarRefresh", not playerGui:GetAttribute("ForceHotbarRefresh"))
		ToggleExtraUI(true)
		PreviewController:ClosePreview()
	end)

	searchFilter.Changed:Connect(function(prop)
		if prop == "Text" then PopulateUI(searchFilter.Text) end
	end)

	dragArea.InputBegan:Connect(function(input)
		if inventoryUI.Visible and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
			isDragging = true
			lastMousePos = Vector2.new(input.Position.X, input.Position.Y)
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then isDragging = false end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if inventoryUI.Visible then
			if isDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
				local currentPos = Vector2.new(input.Position.X, input.Position.Y)
				local delta = currentPos - lastMousePos
				PreviewController:DragRotate(delta.X, delta.Y)
				lastMousePos = currentPos
			end
			if input.UserInputType == Enum.UserInputType.MouseWheel then PreviewController:Zoom(-input.Position.Z * 1.5) end
		end
	end)
end

return RPGInventoryController