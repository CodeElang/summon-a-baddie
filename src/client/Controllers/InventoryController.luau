local InventoryController = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local FormatNumber = require(ReplicatedStorage.Shared.Utils.FormatNumber)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

local Network = ReplicatedStorage.Network
local GetInvEvent = Network:WaitForChild("GetInventory")
local HoldEvent = Network:WaitForChild("HoldBaddie")
local SwapEvent = Network:WaitForChild("SwapHotbar")
local SwapPartyEvent = Network:WaitForChild("SwapPartySlot") 

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

function InventoryController:Init() end

function InventoryController:Start()
	local MainUI = playerGui:WaitForChild("MainUI")
	local BottomHotbar = MainUI:WaitForChild("HotbarContainer"):WaitForChild("BottomHotbar")
	local CardTemplate = ReplicatedStorage:WaitForChild("Templates"):WaitForChild("CompactBaddieCard")

	BottomHotbar.Visible = true

	local currentlyHeldId = ""
	local currentDisplayedIds = {}
	local cachedParty = {}

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

					local oldCam = vpFrame:FindFirstChildOfClass("Camera")
					if oldCam then oldCam:Destroy() end

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

	local function UpdateHighlight()
		local swapSlot = playerGui:GetAttribute("SelectedHotbarSlot") or 0
		for _, card in ipairs(BottomHotbar:GetChildren()) do
			if card:IsA("Frame") and card:FindFirstChild("CardBox") then
				if swapSlot > 0 and card.LayoutOrder == swapSlot then
					card.CardBox.ColorBorder.BackgroundColor3 = Color3.fromRGB(255, 255, 100)
				elseif card.Name == currentlyHeldId and card.Name ~= "EmptySlot" then
					card.CardBox.ColorBorder.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
				else
					local origColor = card:GetAttribute("TierColor")
					if origColor then
						card.CardBox.ColorBorder.BackgroundColor3 = origColor
					else
						card.CardBox.ColorBorder.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
					end
				end
			end
		end
	end

	local function RefreshInventory()
		local baddies, _, hotbarData, partyData = GetInvEvent:InvokeServer()

		-- [PERBAIKAN] Jika ProfileService belum siap, kembalikan false agar sistem tahu untuk mencoba lagi
		if not baddies then return false end 

		hotbarData = hotbarData or {}
		cachedParty = partyData or {Slot1="", Slot2="", Slot3="", Slot4=""}

		local baddieDict = {}
		for _, b in ipairs(baddies) do baddieDict[b.Id] = b end

		local newTopIds = {}
		for i = 1, 8 do
			local bId = hotbarData["Slot"..i]
			if bId and bId ~= "" and baddieDict[bId] then
				table.insert(newTopIds, bId)
			else
				table.insert(newTopIds, "EmptySlot")
			end
		end

		currentDisplayedIds = newTopIds

		for _, child in ipairs(BottomHotbar:GetChildren()) do
			if child:IsA("Frame") and child.Name ~= "PartyToggleBtn" then 
				child:Destroy() 
			end
		end

		for i = 1, 8 do
			local bId = newTopIds[i]
			local baddie = baddieDict[bId]
			local card = CardTemplate:Clone()
			card.Visible = true
			card.LayoutOrder = i

			local numLbl = Instance.new("TextLabel", card)
			numLbl.Size = UDim2.new(0, 20, 0, 20)
			numLbl.Position = UDim2.new(0, -5, 0, -5)
			numLbl.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
			numLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
			numLbl.Text = tostring(i)
			numLbl.Font = Enum.Font.GothamBold
			numLbl.ZIndex = 55
			Instance.new("UICorner", numLbl).CornerRadius = UDim.new(1, 0)

			if baddie then
				local baddieCfg = GameConfig.GetBaddieData(baddie.Name)
				local tierData = GameConfig.Tiers[baddie.Rarity]

				if baddieCfg and tierData then
					card.Name = baddie.Id
					card:SetAttribute("TierColor", tierData.Color)

					local bg = card.CardBox.ColorBorder.InnerBlack.Background
					local overlay = bg.TextOverlay

					card.CardBox.ColorBorder.BackgroundColor3 = tierData.Color
					overlay.RarityLabel.Text = string.upper(baddie.Rarity)
					overlay.RarityLabel.TextColor3 = tierData.Color
					overlay.NameLabel.Text = baddie.Name
					card.ChanceLabel.Text = "1 in " .. FormatNumber.Format(baddieCfg.Chance)

					if baddie.IsFavorite and card:FindFirstChild("FavIcon") then card.FavIcon.Visible = true else card.FavIcon.Visible = false end

					SetupViewport(bg.ViewportFrame, baddie.Name, baddie.Rarity)

					local btn = Instance.new("TextButton", card)
					btn.Size = UDim2.new(1, 0, 1, 0)
					btn.BackgroundTransparency = 1
					btn.Text = ""
					btn.ZIndex = 50

					btn.MouseButton1Click:Connect(function()
						local rpgUI = MainUI:FindFirstChild("RPGInventoryContainer")
						local selectedPartySlot = playerGui:GetAttribute("SelectedPartySlot") or 0

						if selectedPartySlot > 0 then
							local success = SwapPartyEvent:InvokeServer(selectedPartySlot, baddie.Id)
							if success then
								-- [PERBAIKAN BUG] Lepaskan Baddie secara paksa jika sedang dipegang!
								if currentlyHeldId == baddie.Id then
									HoldEvent:InvokeServer(baddie.Id) -- Hancurkan tool di tangan (Server)
									currentlyHeldId = "" -- Bersihkan memori pegangan di UI (Client)
								end

								playerGui:SetAttribute("SelectedPartySlot", 0)
								playerGui:SetAttribute("ForceHotbarRefresh", not playerGui:GetAttribute("ForceHotbarRefresh"))
								playerGui:SetAttribute("ForcePartyRefresh", not playerGui:GetAttribute("ForcePartyRefresh"))
							end
						elseif rpgUI and rpgUI.Visible then
							local currentSelected = playerGui:GetAttribute("SelectedHotbarSlot")
							if currentSelected == i then playerGui:SetAttribute("SelectedHotbarSlot", 0) else playerGui:SetAttribute("SelectedHotbarSlot", i) end
							UpdateHighlight()
						else
							local success, status = HoldEvent:InvokeServer(baddie.Id)
							if success then
								if status == "Equipped" then currentlyHeldId = baddie.Id
								elseif status == "Unequipped" then currentlyHeldId = "" end
								UpdateHighlight()
							end
						end
					end)
				end
			else
				card.Name = "EmptySlot"
				card:SetAttribute("TierColor", Color3.fromRGB(30, 30, 35))
				card.CardBox.ColorBorder.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
				card.CardBox.ColorBorder.InnerBlack.Background.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
				card.CardBox.ColorBorder.InnerBlack.Background.TextOverlay.Visible = false
				card.ChanceLabel.Visible = false
				if card:FindFirstChild("FavIcon") then card.FavIcon.Visible = false end

				local btn = Instance.new("TextButton", card)
				btn.Size = UDim2.new(1, 0, 1, 0)
				btn.BackgroundTransparency = 1
				btn.Text = ""
				btn.ZIndex = 50

				btn.MouseButton1Click:Connect(function()
					local rpgUI = MainUI:FindFirstChild("RPGInventoryContainer")
					local selectedPartySlot = playerGui:GetAttribute("SelectedPartySlot") or 0

					if selectedPartySlot > 0 then
						local partyId = cachedParty["Slot" .. selectedPartySlot] or ""
						if partyId ~= "" then
							local success = SwapEvent:InvokeServer(i, partyId)
							if success then
								playerGui:SetAttribute("SelectedPartySlot", 0)
								playerGui:SetAttribute("ForceHotbarRefresh", not playerGui:GetAttribute("ForceHotbarRefresh"))
								playerGui:SetAttribute("ForcePartyRefresh", not playerGui:GetAttribute("ForcePartyRefresh"))
							end
						else
							playerGui:SetAttribute("SelectedPartySlot", 0)
							UpdateHighlight()
						end
					elseif rpgUI and rpgUI.Visible then
						local currentSelected = playerGui:GetAttribute("SelectedHotbarSlot")
						if currentSelected == i then playerGui:SetAttribute("SelectedHotbarSlot", 0) else playerGui:SetAttribute("SelectedHotbarSlot", i) end
						UpdateHighlight()
					end
				end)
			end
			card.Parent = BottomHotbar
		end
		UpdateHighlight()

		-- [PERBAIKAN] Kembalikan true menandakan data sudah berhasil dirender
		return true 
	end

	player.CharacterAdded:Connect(function()
		currentlyHeldId = ""
		currentDisplayedIds = {}
		RefreshInventory()
	end)

	playerGui:GetAttributeChangedSignal("ForceHotbarRefresh"):Connect(function()
		currentDisplayedIds = {} 
		RefreshInventory()
	end)

	local ForceRefreshEvent = Network:FindFirstChild("ForceClientRefresh")
	if ForceRefreshEvent then
		ForceRefreshEvent.OnClientEvent:Connect(function()
			currentDisplayedIds = {} 
			RefreshInventory()
		end)
	end

	-- [PERBAIKAN] Smart Initializer: Menunggu ProfileService tanpa bikin nge-glitch!
	task.spawn(function()
		while true do
			local isDataReady = RefreshInventory()
			if isDataReady then
				break -- Hentikan loop selamanya setelah berhasil mendapat data pertama kali!
			end
			task.wait(1) -- Tunggu 1 detik jika ProfileService server masih memuat data
		end
	end)

end

return InventoryController