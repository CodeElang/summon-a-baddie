local PartyController = {}
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

local Network = ReplicatedStorage.Network
local GetInvEvent = Network:WaitForChild("GetInventory")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

function PartyController:Init() end

function PartyController:Start()
	playerGui:SetAttribute("SelectedPartySlot", 0)

	local mainUI = playerGui:WaitForChild("MainUI")
	-- UBAH BLOK INI:
	local hotbarContainer = mainUI:WaitForChild("HotbarContainer")
	local partyHotbar = hotbarContainer:WaitForChild("PartyHotbar")
	local bottomHotbar = hotbarContainer:WaitForChild("BottomHotbar")
	local toggleBtn = bottomHotbar:WaitForChild("PartyToggleBtn")
	local template = ReplicatedStorage:WaitForChild("Templates"):WaitForChild("CompactBaddieCard")

	local layout = partyHotbar:FindFirstChildOfClass("UIListLayout")
	if layout then
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		-- KITA UBAH KE CENTER AGAR RAPI SEJAJAR DENGAN BOTTOM HOTBAR
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Center 
	end

	local cachedInventory = {}
	local cachedParty = {}

	local function UpdateHighlight()
		local selectedSlot = playerGui:GetAttribute("SelectedPartySlot") or 0
		for _, card in ipairs(partyHotbar:GetChildren()) do
			if card:IsA("Frame") and card:FindFirstChild("CardBox") then
				if selectedSlot > 0 and card.LayoutOrder == selectedSlot then
					card.CardBox.ColorBorder.BackgroundColor3 = Color3.fromRGB(255, 255, 100) -- Kuning saat dipilih
				else
					local origColor = card:GetAttribute("TierColor") or Color3.fromRGB(30, 30, 35)
					card.CardBox.ColorBorder.BackgroundColor3 = origColor
				end
			end
		end
	end

	-- DI-UPDATE AGAR ANIMASI IDLE TER-RENDER SEPERTI DI INVENTORY HOTBAR
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
					clonedModel:PivotTo(CFrame.new(0,0,0))
					local cam = Instance.new("Camera")
					cam.FieldOfView = 40
					vpFrame.CurrentCamera = cam
					cam.Parent = vpFrame
					local _, size = clonedModel:GetBoundingBox()
					local dist = math.max(6.5, size.Magnitude * 0.7)
					cam.CFrame = CFrame.lookAt(refPart.Position + (refPart.CFrame.LookVector * dist) + Vector3.new(0,-0.5,0), refPart.Position)
				else 
					clonedModel:Destroy() 
				end
				break
			end
		end
	end

	local function RefreshPartyUI()
		local baddies, _, _, partyData = GetInvEvent:InvokeServer()
		if not baddies then return end
		cachedInventory = {}
		for _, b in ipairs(baddies) do cachedInventory[b.Id] = b end
		cachedParty = partyData or {Slot1="", Slot2="", Slot3="", Slot4=""}

		for _, child in ipairs(partyHotbar:GetChildren()) do
			if child:IsA("Frame") then child:Destroy() end
		end

		for i = 1, 4 do
			local bId = cachedParty["Slot"..i]
			local baddie = cachedInventory[bId]
			local card = template:Clone()
			card.Visible = true
			card.LayoutOrder = i

			local numLbl = Instance.new("TextLabel", card)
			numLbl.Size = UDim2.new(0, 20, 0, 20)
			numLbl.Position = UDim2.new(0, -5, 0, -5)
			-- WARNA DISAMAKAN DENGAN HOTBAR (Jika mau tetap merah, ubah kembali ke 150, 40, 40)
			numLbl.BackgroundColor3 = Color3.fromRGB(40, 40, 45) 
			numLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
			numLbl.Text = tostring(i)
			numLbl.Font = Enum.Font.GothamBold
			numLbl.ZIndex = 55
			Instance.new("UICorner", numLbl).CornerRadius = UDim.new(1, 0)

			if baddie then
				local bCfg = GameConfig.GetBaddieData(baddie.Name)
				local tCfg = GameConfig.Tiers[baddie.Rarity]
				card.Name = baddie.Id
				card:SetAttribute("TierColor", tCfg.Color)
				card.CardBox.ColorBorder.BackgroundColor3 = tCfg.Color
				local bg = card.CardBox.ColorBorder.InnerBlack.Background
				bg.TextOverlay.RarityLabel.Text = string.upper(baddie.Rarity)
				bg.TextOverlay.RarityLabel.TextColor3 = tCfg.Color
				bg.TextOverlay.NameLabel.Text = baddie.Name
				card.ChanceLabel.Visible = false
				if baddie.IsFavorite and card:FindFirstChild("FavIcon") then card.FavIcon.Visible = true else card.FavIcon.Visible = false end
				SetupViewport(bg.ViewportFrame, baddie.Name, baddie.Rarity)
			else
				card.Name = "EmptySlot"
				card:SetAttribute("TierColor", Color3.fromRGB(30, 30, 35))
				card.CardBox.ColorBorder.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
				local bg = card.CardBox.ColorBorder.InnerBlack.Background
				bg.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
				bg.TextOverlay.Visible = false
				card.ChanceLabel.Visible = false
				if card:FindFirstChild("FavIcon") then card.FavIcon.Visible = false end
			end

			local btn = Instance.new("TextButton", card)
			btn.Size = UDim2.new(1, 0, 1, 0)
			btn.BackgroundTransparency = 1
			btn.Text = ""
			btn.ZIndex = 50

			btn.MouseButton1Click:Connect(function()
				local currentSelected = playerGui:GetAttribute("SelectedPartySlot")
				if currentSelected == i then
					playerGui:SetAttribute("SelectedPartySlot", 0)
				else
					playerGui:SetAttribute("SelectedPartySlot", i)
					playerGui:SetAttribute("SelectedHotbarSlot", 0) 
				end
				UpdateHighlight()
			end)
			card.Parent = partyHotbar
		end
		UpdateHighlight()
	end

	toggleBtn.MouseButton1Click:Connect(function()
		partyHotbar.Visible = not partyHotbar.Visible
		if partyHotbar.Visible then
			RefreshPartyUI()
		else
			playerGui:SetAttribute("SelectedPartySlot", 0)
			UpdateHighlight()
		end
	end)

	playerGui:GetAttributeChangedSignal("ForcePartyRefresh"):Connect(function()
		if partyHotbar.Visible then RefreshPartyUI() end
	end)
end

return PartyController