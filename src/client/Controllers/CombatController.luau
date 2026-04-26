local CombatController = {}

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Network = ReplicatedStorage.Network
local SkillData = require(ReplicatedStorage.Shared.Databases.SkillData)

local BattleStartEvent = Network:WaitForChild("BattleStart")
local ActionRequestEvent = Network:WaitForChild("ActionRequest")
local SubmitActionEvent = Network:WaitForChild("SubmitAction")
local TurnUpdateEvent = Network:WaitForChild("TurnUpdate")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

function CombatController:Init() end

function CombatController:Start()
	local MainUI = playerGui:WaitForChild("MainUI")
	local CombatHUD = MainUI:WaitForChild("CombatHUD")
	local TurnInd = MainUI:WaitForChild("TurnIndicator")
	local TurnOrderContainer = MainUI:WaitForChild("TurnOrderContainer")
	local TurnSlotTemplate = ReplicatedStorage:WaitForChild("Templates"):WaitForChild("TurnSlotTemplate")

	local BasicBtn = CombatHUD:WaitForChild("BasicBtn")
	local SkillBtn = CombatHUD:WaitForChild("SkillBtn")
	local UltBtn = CombatHUD:WaitForChild("UltBtn")
	local RunBtn = CombatHUD:WaitForChild("RunBtn")
	
	-- Setup dynamic SubMenu container if it doesn't exist
	local SkillSubMenu = CombatHUD:FindFirstChild("SkillSubMenu")
	if not SkillSubMenu then
		SkillSubMenu = Instance.new("Frame")
		SkillSubMenu.Name = "SkillSubMenu"
		SkillSubMenu.Size = UDim2.new(0, 250, 0, 0)
		SkillSubMenu.AutomaticSize = Enum.AutomaticSize.Y
		SkillSubMenu.AnchorPoint = Vector2.new(0.5, 1)
		SkillSubMenu.Position = UDim2.new(0.5, 0, 0.8, -50)
		SkillSubMenu.BackgroundTransparency = 1
		SkillSubMenu.Visible = false
		SkillSubMenu.Parent = CombatHUD
		
		local layout = Instance.new("UIListLayout", SkillSubMenu)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Padding = UDim.new(0, 10)
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	end
	
	-- Tooltip container
	local Tooltip = CombatHUD:FindFirstChild("Tooltip")
	if not Tooltip then
		Tooltip = Instance.new("Frame")
		Tooltip.Name = "Tooltip"
		Tooltip.Size = UDim2.new(0, 250, 0, 80)
		Tooltip.AnchorPoint = Vector2.new(0.5, 1)
		Tooltip.Position = UDim2.new(0.5, 0, 0.8, -150)
		Tooltip.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
		Tooltip.Visible = false
		Tooltip.Parent = CombatHUD
		
		local corner = Instance.new("UICorner", Tooltip)
		corner.CornerRadius = UDim.new(0, 8)
		
		local text = Instance.new("TextLabel", Tooltip)
		text.Name = "Desc"
		text.Size = UDim2.new(1, -10, 1, -10)
		text.Position = UDim2.new(0, 5, 0, 5)
		text.BackgroundTransparency = 1
		text.TextColor3 = Color3.new(1,1,1)
		text.TextWrapped = true
		text.TextScaled = true
		text.Font = Enum.Font.Gotham
	end
	local lastAnimTick = 0
	local currentBattleId = nil
	local currentTargetUid = nil
	local unitNames = {}
	local storedVisibleUIs = {}

	-- Targeting state
	local validTargetPool = {}
	local activeHighlights = {}
	local isInActionPhase = false
	local isAoEMode = false
	local cachedEnemies = {}
	local cachedAllies = {}
	local currentActiveUnit = nil

	-- BGM & Turn Indicator state
	local battleBGM = nil
	local activeIndicator = nil
	local indicatorConnection = nil
	local indicatorTemplate = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("TurnIndicator")

	-- Cinematic Camera Sway state
	local cameraSwayConnection = nil

	local function ToggleOtherUIs(isHidden)
		if isHidden then
			storedVisibleUIs = {}
			for _, child in ipairs(MainUI:GetChildren()) do
				if child:IsA("GuiObject") and child.Visible then
					if child.Name ~= "CombatHUD" and child.Name ~= "TurnIndicator" and child.Name ~= "TurnOrderContainer" then
						storedVisibleUIs[child.Name] = true
						child.Visible = false
					end
				end
			end
		else
			for name, _ in pairs(storedVisibleUIs) do
				local ui = MainUI:FindFirstChild(name)
				if ui then ui.Visible = true end
			end
			storedVisibleUIs = {}
		end
	end

	local indicatorAngle = 0
	local INDICATOR_ROTATION_SPEED = 0.012

	local function SetTurnIndicator(targetUid, isAlly)
		if not currentBattleId then return end
		local arena = workspace:FindFirstChild("Arena_" .. currentBattleId)
		if not arena then return end
		local model = arena:FindFirstChild(targetUid)
		if not model then return end

		-- Create indicator if it doesn't exist
		if not activeIndicator then
			activeIndicator = indicatorTemplate:Clone()
			activeIndicator.CanCollide = false
			activeIndicator.Anchored = true
			activeIndicator.Parent = arena
		end

		-- Set color based on faction
		if isAlly then
			activeIndicator.Color = Color3.fromRGB(0, 150, 255)
		else
			activeIndicator.Color = Color3.fromRGB(255, 50, 50)
		end

		-- Disconnect previous RenderStepped
		if indicatorConnection then
			indicatorConnection:Disconnect()
			indicatorConnection = nil
		end

		-- Attach to unit: ground-snapped flat spin
		local rootPart = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
		if rootPart then
			-- Compute ground position ONCE (units don't move in combat)
			local rayParams = RaycastParams.new()
			rayParams.FilterType = Enum.RaycastFilterType.Exclude
			rayParams.FilterDescendantsInstances = {model, arena}

			local currentPos = rootPart.Position
			local rayResult = workspace:Raycast(currentPos, Vector3.new(0, -1000, 0), rayParams)
			local groundY
			if rayResult and rayResult.Instance:IsA("BasePart") and rayResult.Instance.CanCollide then
				groundY = rayResult.Position.Y
			else
				groundY = currentPos.Y - 3
			end
			local fixedPos = Vector3.new(currentPos.X, groundY + (activeIndicator.Size.Y / 2), currentPos.Z)

			-- Only update rotation each frame (position is fixed)
			indicatorConnection = RunService.RenderStepped:Connect(function()
				if not activeIndicator or not rootPart or not rootPart.Parent then
					if indicatorConnection then indicatorConnection:Disconnect(); indicatorConnection = nil end
					return
				end

				indicatorAngle = indicatorAngle + INDICATOR_ROTATION_SPEED
				activeIndicator.CFrame = CFrame.new(fixedPos) * CFrame.Angles(0, indicatorAngle, 0)
			end)
		end
	end

	local function HideTurnIndicator()
		if indicatorConnection then
			indicatorConnection:Disconnect()
			indicatorConnection = nil
		end
		if activeIndicator then
			activeIndicator:Destroy()
			activeIndicator = nil
		end
	end

	local function IsEnemyUid(uid)
		return uid and string.find(uid, "Enemy") ~= nil
	end

	local function SetTargetHighlight(uid)
		for _, h in ipairs(activeHighlights) do h:Destroy() end
		activeHighlights = {}
		isAoEMode = false
		if not currentBattleId then return end
		local arena = workspace:FindFirstChild("Arena_" .. currentBattleId)
		if not arena then return end
		local model = arena:FindFirstChild(uid)
		if not model then return end

		local hl = Instance.new("Highlight")
		hl.Name = "TargetHighlight"
		if IsEnemyUid(uid) then
			hl.FillColor = Color3.fromRGB(255, 100, 120)
			hl.FillTransparency = 0.7
			hl.OutlineColor = Color3.fromRGB(255, 30, 30)
			hl.OutlineTransparency = 0
		else
			hl.FillColor = Color3.fromRGB(100, 180, 255)
			hl.FillTransparency = 0.7
			hl.OutlineColor = Color3.fromRGB(50, 200, 120)
			hl.OutlineTransparency = 0
		end
		hl.Parent = model
		table.insert(activeHighlights, hl)
		currentTargetUid = uid
	end

	local function SetAoEHighlight(pool)
		for _, h in ipairs(activeHighlights) do h:Destroy() end
		activeHighlights = {}
		isAoEMode = true
		if not currentBattleId then return end
		local arena = workspace:FindFirstChild("Arena_" .. currentBattleId)
		if not arena then return end

		for _, uid in ipairs(pool) do
			local model = arena:FindFirstChild(uid)
			if model then
				local hl = Instance.new("Highlight")
				hl.Name = "AoEHighlight"
				if IsEnemyUid(uid) then
					hl.FillColor = Color3.fromRGB(255, 80, 80)
					hl.FillTransparency = 0.5
					hl.OutlineColor = Color3.fromRGB(255, 50, 50)
					hl.OutlineTransparency = 0
				else
					hl.FillColor = Color3.fromRGB(80, 160, 255)
					hl.FillTransparency = 0.5
					hl.OutlineColor = Color3.fromRGB(40, 180, 100)
					hl.OutlineTransparency = 0
				end
				hl.Parent = model
				table.insert(activeHighlights, hl)
			end
		end
	end

	local function ClearTargetHighlight()
		for _, h in ipairs(activeHighlights) do h:Destroy() end
		activeHighlights = {}
		isInActionPhase = false
		isAoEMode = false
		validTargetPool = {}
	end

	local function BuildTargetPool(context)
		local pool = {}
		local src = context == "enemy" and cachedEnemies or cachedAllies
		for _, unit in ipairs(src) do
			if unit.HP > 0 then table.insert(pool, unit.Uid) end
		end
		local arena = workspace:FindFirstChild("Arena_" .. currentBattleId)
		if arena then
			table.sort(pool, function(a, b)
				local ma, mb = arena:FindFirstChild(a), arena:FindFirstChild(b)
				if ma and mb then
					local pa = ma.PrimaryPart or ma:FindFirstChildWhichIsA("BasePart")
					local pb = mb.PrimaryPart or mb:FindFirstChildWhichIsA("BasePart")
					if pa and pb then return pa.Position.X > pb.Position.X end
				end
				return false
			end)
		end
		validTargetPool = pool
		return pool
	end

	local function CycleTarget(direction)
		if #validTargetPool == 0 then return end
		local idx = 1
		for i, uid in ipairs(validTargetPool) do
			if uid == currentTargetUid then idx = i; break end
		end
		local newIdx = ((idx - 1 + direction) % #validTargetPool) + 1
		SetTargetHighlight(validTargetPool[newIdx])
	end

	local function GetTargetContext(skillId)
		if not skillId then return "enemy" end
		local info = SkillData.Dictionary[skillId]
		if not info then return "enemy" end
		local tt = info.TargetType
		if tt == "AllAllies" or tt == "Self" or tt == "LowestAlly" or tt == "AllAlliesExcludeSelf" or tt == "LowestSpeedAlly" then
			return "ally"
		end
		return "enemy"
	end

	local function GetSafeTargetUid(actionType)
		if not currentActiveUnit then return currentTargetUid end
		local skillId = "Basic_Attack"
		if actionType == "Skill" then skillId = currentActiveUnit.SkillId or "Basic_Attack"
		elseif actionType == "Ultimate" then skillId = currentActiveUnit.UltId or skillId end
		local info = SkillData.Dictionary[skillId]
		if info and (info.TargetType == "Self" or info.TargetType == "AllAllies" or info.TargetType == "AllEnemies" or info.TargetType == "AllAlliesExcludeSelf" or info.TargetType == "LowestAlly" or info.TargetType == "LowestSpeedAlly") then
			return currentActiveUnit.Uid
		end
		return currentTargetUid
	end

	local function SetupMiniViewport(vpFrame, uid)
		local arena = workspace:FindFirstChild("Arena_" .. currentBattleId)
		if not arena then return end
		local unitModel = arena:FindFirstChild(uid)
		if not unitModel then return end

		for _, child in ipairs(vpFrame:GetChildren()) do
			if child:IsA("WorldModel") then child:Destroy() end
		end

		local worldModel = Instance.new("WorldModel")
		worldModel.Parent = vpFrame

		local origArchivable = unitModel.Archivable
		unitModel.Archivable = true
		local clone = unitModel:Clone()
		unitModel.Archivable = origArchivable
		clone.Parent = worldModel

		for _, desc in ipairs(clone:GetDescendants()) do
			if desc:IsA("GuiObject") or desc:IsA("ScreenGui") or desc:IsA("BillboardGui")
				or desc:IsA("SurfaceGui") or desc:IsA("Highlight") or desc:IsA("ParticleEmitter")
				or desc:IsA("Trail") or desc:IsA("Beam") or desc:IsA("Script") or desc:IsA("LocalScript") then
				desc:Destroy()
			elseif desc:IsA("BasePart") and desc.Name ~= "HumanoidRootPart" then
				desc.Transparency = 0
			end
		end

		local refPart = clone:FindFirstChild("Head", true)
			or clone:FindFirstChild("HumanoidRootPart", true)
			or clone:FindFirstChildWhichIsA("BasePart", true)

		if refPart then
			clone.PrimaryPart = refPart
			clone:PivotTo(CFrame.new(0, 0, 0))

			local humanoid = clone:FindFirstChildWhichIsA("Humanoid", true)
			local idleAnim = clone:FindFirstChild("IdleAnim", true)

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

			local oldCam = vpFrame:FindFirstChildOfClass("Camera")
			if oldCam then oldCam:Destroy() end

			local cam = Instance.new("Camera")
			cam.FieldOfView = 40
			vpFrame.CurrentCamera = cam
			cam.Parent = vpFrame

			local _, size = clone:GetBoundingBox()
			local distance = math.max(4.5, size.Magnitude * 0.7)
			cam.CFrame = CFrame.lookAt(
				refPart.Position + (refPart.CFrame.LookVector * distance) + Vector3.new(0, -0.2, 0),
				refPart.Position
			)
		else
			clone:Destroy()
		end
	end

	local function RenderTurnQueue(queueData)
		for _, child in ipairs(TurnOrderContainer:GetChildren()) do
			if child:IsA("Frame") then child:Destroy() end
		end

		for i, data in ipairs(queueData) do
			local slot = TurnSlotTemplate:Clone()
			slot.LayoutOrder = i

			if data.IsPlayer then
				slot.TeamBorder.Color = Color3.fromRGB(85, 170, 255)
			else
				slot.TeamBorder.Color = Color3.fromRGB(255, 85, 85)
			end

			if slot:FindFirstChild("SpeedBadge") then
				slot.SpeedBadge.SpeedLabel.Text = tostring(math.floor(data.Speed or 0))
			end

			if i == 1 then
				slot.Size = UDim2.new(0, 52, 0, 52)
				slot.ActiveGlow.ImageTransparency = 0.3
				slot.TeamBorder.Thickness = 3
				slot.ZIndex = 10
				slot.ActiveGlow.ZIndex = 9
				slot.Viewport.ZIndex = 15
				if slot:FindFirstChild("SpeedBadge") then
					slot.SpeedBadge.ZIndex = 20
					slot.SpeedBadge.SpeedLabel.ZIndex = 21
				end
			else
				slot.Size = UDim2.new(0, 45, 0, 45)
				slot.ActiveGlow.ImageTransparency = 1
				slot.TeamBorder.Thickness = 2
				slot.ZIndex = 1
				slot.ActiveGlow.ZIndex = 0
				slot.Viewport.ZIndex = 5
				if slot:FindFirstChild("SpeedBadge") then
					slot.SpeedBadge.ZIndex = 10
					slot.SpeedBadge.SpeedLabel.ZIndex = 11
				end
			end

			SetupMiniViewport(slot.Viewport, data.Uid)

			slot.Position = UDim2.new(0, -20, 0, 0)
			slot.BackgroundTransparency = 1
			TweenService:Create(slot, TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
				Position = UDim2.new(0, 0, 0, 0),
				BackgroundTransparency = 0
			}):Play()

			slot.Parent = TurnOrderContainer
		end
	end

	local function UpdateHPBar(model, maxHp, currentHp, currentShield)
		local head = model:FindFirstChild("Head") or model.PrimaryPart
		if not head then return end
		local bb = head:FindFirstChild("HPBar")
		if not bb then return end

		currentShield = currentShield or 0
		currentHp = math.max(0, currentHp)

		local hpLbl = bb:FindFirstChild("HPLabel")
		if hpLbl then
			local hpText = tostring(math.floor(currentHp)) .. " / " .. tostring(maxHp)
			if currentShield > 0 then hpText = hpText .. "   🛡 " .. tostring(math.floor(currentShield)) end
			hpLbl.Text = hpText
		end

		local hpBg = bb:FindFirstChild("HPBarBG")
		if hpBg then
			local hpFill = hpBg:FindFirstChild("HPFill")
			local shieldFill = hpBg:FindFirstChild("ShieldFill")

			local hpPercent = math.clamp(currentHp / maxHp, 0, 1)
			local shieldPercent = math.clamp(currentShield / maxHp, 0, 1)

			local tInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

			if hpFill then
				TweenService:Create(hpFill, tInfo, {Size = UDim2.new(hpPercent, 0, 1, 0)}):Play()
			end

			if shieldFill then
				TweenService:Create(shieldFill, tInfo, {
					Size = UDim2.new(shieldPercent, 0, 1, 0),
					Position = UDim2.new(0, 0, 0, 0)
				}):Play()
			end
		end
	end

	local function CreateHPBar(model, unitName, maxHp, currentHp, currentShield)
		local head = model:FindFirstChild("Head") or model.PrimaryPart
		if not head then return end
		
		if head:FindFirstChild("HPBar") then 
			UpdateHPBar(model, maxHp, currentHp, currentShield)
			return 
		end

		currentShield = currentShield or 0
		currentHp = math.max(0, currentHp)

		local bb = Instance.new("BillboardGui", head)
		bb.Name = "HPBar"
		bb.Size = UDim2.new(5, 0, 2.2, 0)
		bb.StudsOffset = Vector3.new(0, 3.8, 0)
		bb.AlwaysOnTop = true

		local nameLbl = Instance.new("TextLabel", bb)
		nameLbl.Name = "NameLabel"
		nameLbl.Size = UDim2.new(1, 0, 0.28, 0)
		nameLbl.Position = UDim2.new(0, 0, 0, 0)
		nameLbl.BackgroundTransparency = 1
		nameLbl.Text = unitName
		nameLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
		nameLbl.Font = Enum.Font.GothamBlack
		nameLbl.TextScaled = true
		nameLbl.TextStrokeTransparency = 0.2

		local hpText = tostring(math.floor(currentHp)) .. " / " .. tostring(maxHp)
		if currentShield > 0 then hpText = hpText .. "   🛡 " .. tostring(math.floor(currentShield)) end

		local hpLbl = Instance.new("TextLabel", bb)
		hpLbl.Name = "HPLabel"
		hpLbl.Size = UDim2.new(1, 0, 0.22, 0)
		hpLbl.Position = UDim2.new(0, 0, 0.28, 0)
		hpLbl.BackgroundTransparency = 1
		hpLbl.Text = hpText
		hpLbl.TextColor3 = Color3.fromRGB(220, 220, 220)
		hpLbl.Font = Enum.Font.GothamMedium
		hpLbl.TextScaled = true
		hpLbl.TextStrokeTransparency = 0.2

		local hpBg = Instance.new("Frame", bb)
		hpBg.Name = "HPBarBG"
		hpBg.Size = UDim2.new(1, 0, 0.16, 0)
		hpBg.Position = UDim2.new(0, 0, 0.60, 0)
		hpBg.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
		hpBg.ClipsDescendants = true
		Instance.new("UICorner", hpBg).CornerRadius = UDim.new(1, 0)

		local hpPercent = math.clamp(currentHp / maxHp, 0, 1)
		local shieldPercent = math.clamp(currentShield / maxHp, 0, 1)

		local hpFill = Instance.new("Frame", hpBg)
		hpFill.Name = "HPFill"
		hpFill.Size = UDim2.new(hpPercent, 0, 1, 0)
		hpFill.BackgroundColor3 = Color3.fromRGB(200, 40, 40)
		hpFill.ZIndex = 1
		Instance.new("UICorner", hpFill).CornerRadius = UDim.new(1, 0)

		local shieldFill = Instance.new("Frame", hpBg)
		shieldFill.Name = "ShieldFill"
		shieldFill.Size = UDim2.new(shieldPercent, 0, 1, 0)
		shieldFill.Position = UDim2.new(0, 0, 0, 0)
		shieldFill.BackgroundColor3 = Color3.fromRGB(85, 170, 255)
		shieldFill.ZIndex = 2
		Instance.new("UICorner", shieldFill).CornerRadius = UDim.new(1, 0)
	end

	local function ShowDamagePopup(model, amount)
		local head = model:FindFirstChild("Head") or model.PrimaryPart
		if not head then return end

		local bb = Instance.new("BillboardGui", head)
		bb.Size = UDim2.new(3, 0, 1.5, 0)
		bb.StudsOffset = Vector3.new(math.random(-1, 1), 3.5, 0)
		bb.AlwaysOnTop = true

		local txt = Instance.new("TextLabel", bb)
		txt.Size = UDim2.new(1, 0, 1, 0)
		txt.BackgroundTransparency = 1
		txt.Font = Enum.Font.GothamBlack
		txt.TextScaled = true
		txt.TextStrokeTransparency = 0.2

		if type(amount) == "string" then
			txt.Text = amount
			txt.TextColor3 = Color3.fromRGB(255, 255, 100)
		elseif amount > 0 then
			txt.Text = "-" .. tostring(amount)
			txt.TextColor3 = Color3.fromRGB(255, 255, 255)
		elseif amount < 0 then
			txt.Text = "+" .. tostring(math.abs(amount))
			txt.TextColor3 = Color3.fromRGB(85, 255, 127)
		else
			txt.Text = "SHIELD"
			txt.TextColor3 = Color3.fromRGB(85, 170, 255)
		end

		local tInfo = TweenInfo.new(1, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out)
		local tween = TweenService:Create(bb, tInfo, {StudsOffset = bb.StudsOffset + Vector3.new(0, 3, 0)})
		local tweenTxt = TweenService:Create(txt, tInfo, {TextTransparency = 1, TextStrokeTransparency = 1})

		tween:Play()
		tweenTxt:Play()
		game.Debris:AddItem(bb, 1)
	end

	BattleStartEvent.OnClientEvent:Connect(function(data)
		if data.IsEnding then
			currentBattleId = nil
			CombatHUD.Visible = false
			TurnInd.Visible = false
			TurnOrderContainer.Visible = false
			unitNames = {}
			currentActiveUnit = nil
			cachedEnemies = {}
			cachedAllies = {}
			ClearTargetHighlight()
			HideTurnIndicator()
			ToggleOtherUIs(false)

			-- WAJIB: Disconnect camera sway sebelum kembalikan kamera
			if cameraSwayConnection then
				cameraSwayConnection:Disconnect()
				cameraSwayConnection = nil
			end

			workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
			workspace.CurrentCamera.FieldOfView = 70

			-- Fade out Battle BGM
			if battleBGM then
				local bgmRef = battleBGM
				TweenService:Create(bgmRef, TweenInfo.new(1.5, Enum.EasingStyle.Quad), {Volume = 0}):Play()
				task.delay(1.6, function()
					bgmRef:Stop()
					bgmRef:Destroy()
				end)
				battleBGM = nil
			end

			-- Resume Overworld BGM
			local mainBGM = SoundService:FindFirstChild("MainBGM")
			if mainBGM then
				mainBGM:Resume()
			end
			return
		end

		currentBattleId = data.Id
		ToggleOtherUIs(true)
		TurnInd.Visible = true
		TurnOrderContainer.Visible = true

		-- Pause Overworld BGM
		local mainBGM = SoundService:FindFirstChild("MainBGM")
		if mainBGM then
			mainBGM:Pause()
		end

		-- Start Battle BGM
		if battleBGM then battleBGM:Stop(); battleBGM:Destroy() end
		battleBGM = Instance.new("Sound")
		battleBGM.SoundId = "rbxassetid://94641654405082"
		battleBGM.Volume = 0.3
		battleBGM.Looped = true
		battleBGM.Parent = SoundService
		battleBGM:Play()

		local cam = workspace.CurrentCamera
		cam.CameraType = Enum.CameraType.Scriptable
		cam.FieldOfView = 60
		local playerCenter = data.PlayerCenter
		local enemyCenter = data.EnemyCenter

		-- Cinematic camera: dekat, sedikit tinggi, miring sedikit ke bawah
		local lookDir = (enemyCenter - playerCenter).Unit
		local baseCamPos = playerCenter - (lookDir * 10) + Vector3.new(0, 8, 0)
		local lookTarget = enemyCenter + Vector3.new(0, -5, 0)
		cam.CFrame = CFrame.lookAt(baseCamPos, lookTarget)

		-- Cinematic Sway: gentle breathing effect (left-right oscillation)
		if cameraSwayConnection then
			cameraSwayConnection:Disconnect()
			cameraSwayConnection = nil
		end
		local rightVector = cam.CFrame.RightVector
		cameraSwayConnection = RunService.RenderStepped:Connect(function()
			local swayOffset = rightVector * (math.sin(tick() * 0.4) * 2.5)
			cam.CFrame = CFrame.lookAt(baseCamPos + swayOffset, lookTarget)
		end)

		local arena = workspace:WaitForChild("Arena_" .. data.Id)
		for _, unit in ipairs(data.Units) do
			unitNames[unit.Uid] = unit.Name
			local model = arena:WaitForChild(unit.Uid, 5)
			if model then
				CreateHPBar(model, unit.Name, unit.MaxHP, unit.HP, unit.Shield)
			end
		end
	end)

	ActionRequestEvent.OnClientEvent:Connect(function(data)
		CombatHUD.Visible = true
		SkillSubMenu.Visible = false
		Tooltip.Visible = false

		-- Cache targeting data
		cachedEnemies = data.Enemies or {}
		cachedAllies = data.Allies or {}
		currentActiveUnit = data.ActiveUnit
		isInActionPhase = true

		-- Default: target enemies, highlight first
		BuildTargetPool("enemy")
		if #validTargetPool > 0 then
			SetTargetHighlight(validTargetPool[1])
		end

		local activeUnit = data.ActiveUnit
		local skillCDs = data.SkillCDs or {}

		if activeUnit.Tier == 1 then
			SkillBtn.Visible = false
			UltBtn.Visible = false
		else
			SkillBtn.Visible = true
			
			local currentSkillCD = skillCDs[activeUnit.SkillId] or 0
			if currentSkillCD > 0 then
				SkillBtn.Text = "CD: " .. tostring(currentSkillCD)
				SkillBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
				SkillBtn.Active = false
			else
				SkillBtn.Text = "SKILL"
				SkillBtn.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
				SkillBtn.Active = true
			end

			if activeUnit.Tier >= 5 then
				UltBtn.Visible = true
				UltBtn.Text = "ULTIMATE (" .. activeUnit.Energy .. "/3)"
				local isReady = activeUnit.Energy >= 3
				if isReady then
					UltBtn.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
					UltBtn.Active = true
				else
					UltBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
					UltBtn.Active = false
				end
			else
				UltBtn.Visible = false
			end
		end

		-- Populate SkillSubMenu dynamically
		for _, child in ipairs(SkillSubMenu:GetChildren()) do
			if child:IsA("TextButton") then child:Destroy() end
		end

		local function createSubMenuBtn(name, isReady, tooltipText, actionType)
			local btn = Instance.new("TextButton")
			btn.Name = name
			btn.Size = UDim2.new(1, 0, 0, 40)
			btn.Text = name
			btn.BackgroundColor3 = isReady and Color3.fromRGB(85, 170, 255) or Color3.fromRGB(40, 40, 40)
			btn.Font = Enum.Font.GothamBold
			btn.TextColor3 = Color3.new(1,1,1)
			btn.TextSize = 14
			
			local corner = Instance.new("UICorner", btn)
			corner.CornerRadius = UDim.new(0, 8)
			
			btn.Parent = SkillSubMenu
			
			btn.MouseEnter:Connect(function()
				Tooltip.Visible = true
				Tooltip.Desc.Text = tooltipText or "No description provided."
				-- Adjust tooltip position to be right above this button
				Tooltip.Position = UDim2.new(0.5, 0, 0.8, -50 - SkillSubMenu.AbsoluteSize.Y - 10)
			end)
			btn.MouseLeave:Connect(function()
				Tooltip.Visible = false
			end)
			
			if isReady then
				btn.MouseButton1Click:Connect(function()
					local safeTarget = GetSafeTargetUid(actionType)
					CombatHUD.Visible = false
					SkillSubMenu.Visible = false
					Tooltip.Visible = false
					ClearTargetHighlight()
					SubmitActionEvent:InvokeServer(currentBattleId, actionType, safeTarget)
				end)
			end
		end

		local skillInfo = SkillData.Dictionary[activeUnit.SkillId]
		if skillInfo then
			local cd = skillCDs[activeUnit.SkillId] or 0
			local isReady = cd == 0
			createSubMenuBtn("Skill: " .. skillInfo.Name .. (cd > 0 and " (CD:"..cd..")" or ""), isReady, skillInfo.Description, "Skill")
		end

		if activeUnit.Tier >= 5 then
			local ultInfo = SkillData.Dictionary[activeUnit.UltId]
			if ultInfo then
				local isReady = activeUnit.Energy >= 3
				createSubMenuBtn("Ultimate: " .. ultInfo.Name, isReady, ultInfo.Description, "Ultimate")
			end
		end
	end)

	BasicBtn.MouseButton1Click:Connect(function()
		if not currentTargetUid or not isInActionPhase then return end
		-- Reset to enemy pool for basic attack
		if not IsEnemyUid(currentTargetUid) then
			BuildTargetPool("enemy")
			if #validTargetPool > 0 then SetTargetHighlight(validTargetPool[1]) end
		end
		CombatHUD.Visible = false
		SkillSubMenu.Visible = false
		Tooltip.Visible = false
		ClearTargetHighlight()
		SubmitActionEvent:InvokeServer(currentBattleId, "Basic", currentTargetUid)
	end)

	SkillBtn.MouseButton1Click:Connect(function()
		if not currentTargetUid or not SkillBtn.Active or not isInActionPhase then return end
		SkillSubMenu.Visible = not SkillSubMenu.Visible
		-- Switch target context based on skill
		if SkillSubMenu.Visible and currentActiveUnit and currentActiveUnit.SkillId then
			local skillInfo = SkillData.Dictionary[currentActiveUnit.SkillId]
			local ctx = GetTargetContext(currentActiveUnit.SkillId)
			BuildTargetPool(ctx)
			-- Check if skill is AoE → multi-highlight
			if skillInfo and (skillInfo.TargetType == "AllEnemies" or skillInfo.TargetType == "AllAllies") then
				SetAoEHighlight(validTargetPool)
			elseif #validTargetPool > 0 and not table.find(validTargetPool, currentTargetUid) then
				SetTargetHighlight(validTargetPool[1])
			end
		else
			-- Submenu closed, reset to single-target enemy pool
			BuildTargetPool("enemy")
			if #validTargetPool > 0 then
				SetTargetHighlight(validTargetPool[1])
			end
		end
	end)

	UltBtn.MouseButton1Click:Connect(function()
		if not currentTargetUid or not UltBtn.Active or not isInActionPhase then return end
		-- Check if ult is AoE, apply multi-highlight before executing
		if currentActiveUnit and currentActiveUnit.UltId then
			local ultInfo = SkillData.Dictionary[currentActiveUnit.UltId]
			if ultInfo and (ultInfo.TargetType == "AllEnemies" or ultInfo.TargetType == "AllAllies") then
				local ctx = GetTargetContext(currentActiveUnit.UltId)
				BuildTargetPool(ctx)
				SetAoEHighlight(validTargetPool)
			end
		end
		local safeTarget = GetSafeTargetUid("Ultimate")
		CombatHUD.Visible = false
		SkillSubMenu.Visible = false
		Tooltip.Visible = false
		ClearTargetHighlight()
		SubmitActionEvent:InvokeServer(currentBattleId, "Ultimate", safeTarget)
	end)

	RunBtn.MouseButton1Click:Connect(function()
		CombatHUD.Visible = false
		SkillSubMenu.Visible = false
		Tooltip.Visible = false
		ClearTargetHighlight()
		SubmitActionEvent:InvokeServer(currentBattleId, "Flee")
	end)

	TurnUpdateEvent.OnClientEvent:Connect(function(action, param1, param2, displayValue, newHp, maxHp, shield, visualTag)
		if action == "UpdateTurnUI" then
			TurnInd.Text = string.upper(param1) .. "'S TURN"
			if param2 then
				RenderTurnQueue(param2)
				-- Set turn indicator on the active unit (first in queue)
				if param2[1] then
					SetTurnIndicator(param2[1].Uid, param2[1].IsPlayer == true)
				end
			end

		elseif action == "RefreshTurnQueue" then
			if param1 then RenderTurnQueue(param1) end

		elseif action == "UpdateHPBar" then
			local targetUid = param1
			local arena = workspace:FindFirstChild("Arena_" .. currentBattleId)
			if not arena then return end
			local tgtModel = arena:FindFirstChild(targetUid)
			if tgtModel then
				CreateHPBar(tgtModel, unitNames[targetUid] or "Unknown", maxHp, newHp, shield)
			end

		elseif action == "DeathVisual" then
			local deadUid = param1
			local arena = workspace:FindFirstChild("Arena_" .. currentBattleId)
			if arena then
				local model = arena:FindFirstChild(deadUid)
				if model then
					for _, part in ipairs(model:GetDescendants()) do
						if part:IsA("BasePart") then
							TweenService:Create(part, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Transparency = 1}):Play()
						end
					end
					game.Debris:AddItem(model, 0.7)
				end
			end

		elseif action == "AttackVisual" then
			local attackerUid = param1
			local targetUid = param2

			local arena = workspace:FindFirstChild("Arena_" .. currentBattleId)
			if not arena then return end

			local atkModel = arena:FindFirstChild(attackerUid)
			local tgtModel = arena:FindFirstChild(targetUid)
			if not atkModel or not tgtModel then return end

			local targetName = unitNames[targetUid] or "Unknown"

			if visualTag == "Anim_Melee_Hit" or visualTag == "Anim_Heavy_Smash" or visualTag == nil then
				if attackerUid ~= targetUid then
					-- =========================================================
					-- DYNAMIC DASH: 4-Phase Timing (Maju → Tunggu → Impact → Kembali)
					-- WAJIB: Anchor root part agar TweenService menang vs Humanoid physics
					-- =========================================================

					-- Resolve root parts (HumanoidRootPart > PrimaryPart fallback)
					local attackerRoot = atkModel:FindFirstChild("HumanoidRootPart") or atkModel.PrimaryPart
					local targetRoot = tgtModel:FindFirstChild("HumanoidRootPart") or tgtModel.PrimaryPart
					if not attackerRoot or not targetRoot then return end

					-- Simpan posisi awal
					local origCFrame = attackerRoot.CFrame

					-- Kalkulasi titik berhenti (4.5 studs di depan target)
					local attackDir  = (targetRoot.Position - attackerRoot.Position).Unit
					local dashPos    = targetRoot.Position - (attackDir * 5)
					local dashCFrame = CFrame.lookAt(dashPos, targetRoot.Position)

					-- WAJIB: Matikan gangguan fisika Humanoid
					attackerRoot.Anchored = true

					-- Sembunyikan Turn Indicator selama dash
					if activeIndicator then
						activeIndicator.Transparency = 1
					end

					-- TAHAP 1: MAJU — Dash elegan ke depan target (0.45s, Sine/Out = berbobot)
					local dashTween = TweenService:Create(
						attackerRoot,
						TweenInfo.new(0.45, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
						{CFrame = dashCFrame}
					)
					dashTween:Play()

					-- TAHAP 2: TUNGGU — Completed:Wait() menjamin tween selesai 100%
					dashTween.Completed:Wait()

					-- TAHAP 3: IMPACT — Play hit anim, damage popup, HP bar update
					local hum = atkModel:FindFirstChildOfClass("Humanoid")
					if hum then
						local hitAnim = atkModel:FindFirstChild("AttackAnim", true)
							or (ReplicatedStorage:FindFirstChild("Assets")
								and ReplicatedStorage.Assets:FindFirstChild("Animations")
								and ReplicatedStorage.Assets.Animations:FindFirstChild("MeleeHit"))
						if hitAnim then
							local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
							local track = animator:LoadAnimation(hitAnim)
							track.Looped = false
							track:Play()
						end
					end

					ShowDamagePopup(tgtModel, displayValue)
					CreateHPBar(tgtModel, targetName, maxHp, newHp, shield)

					-- Impact frame: tahan posisi agar pukulan terasa berat
					task.wait(0.5)

					-- TAHAP 4: KEMBALI — Return ke posisi formasi awal (0.35s, Quad smooth)
					local backTween = TweenService:Create(
						attackerRoot,
						TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
						{CFrame = origCFrame}
					)
					backTween:Play()
					backTween.Completed:Wait()

					-- Munculkan kembali Turn Indicator setelah kembali ke formasi
					if activeIndicator then
						activeIndicator.Transparency = 0
					end
				else
					-- Self-target (DoT tick, self-buff): no dash, just show effect
					ShowDamagePopup(tgtModel, displayValue)
					CreateHPBar(tgtModel, targetName, maxHp, newHp, shield)
					task.wait(0.5)
				end

			elseif visualTag == "VFX_Heal_Aura" or visualTag == "VFX_Shield_Up" or visualTag == "VFX_Speed_Buff" then
				ShowDamagePopup(tgtModel, displayValue)
				CreateHPBar(tgtModel, targetName, maxHp, newHp, shield)
				task.wait(0.5)

			elseif visualTag == "Cinematic_Meteor_Drop" then
				ShowDamagePopup(tgtModel, displayValue)
				CreateHPBar(tgtModel, targetName, maxHp, newHp, shield)
				task.wait(0.5)
			
			elseif visualTag == "VFX_Party_Heal" then
				local currentTick = tick()

				if currentTick - lastAnimTick > 1 then
					lastAnimTick = currentTick

					local hum = atkModel:FindFirstChildOfClass("Humanoid")
					local animObj = ReplicatedStorage.Assets.Animations:FindFirstChild("CastHeal")
					if hum and animObj then
						local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
						local track = animator:LoadAnimation(animObj)

						track.Looped = false 
						track:Play()
					end

					local sfx = ReplicatedStorage.Assets.Sounds:FindFirstChild("HealSFX")
					if sfx then
						local sfxClone = sfx:Clone()
						sfxClone.Parent = atkModel.PrimaryPart
						sfxClone:Play()
						game.Debris:AddItem(sfxClone, 3)
					end
				end

				local vfx = ReplicatedStorage.Assets.VFX:FindFirstChild("HealAura")
				if vfx then
					local vfxClone = vfx:Clone()
					vfxClone.Parent = tgtModel.PrimaryPart

					for _, emitter in ipairs(vfxClone:GetChildren()) do
						if emitter:IsA("ParticleEmitter") then
							emitter:Emit(20)
						end
					end

					game.Debris:AddItem(vfxClone, 2)
				end

				ShowDamagePopup(tgtModel, displayValue)
				CreateHPBar(tgtModel, targetName, maxHp, newHp, shield)
				task.wait(0.2)
			else
				ShowDamagePopup(tgtModel, displayValue)
				CreateHPBar(tgtModel, targetName, maxHp, newHp, shield)
				task.wait(0.5)
			end
			
		end
		
	end)

	-- ========================================
	-- INPUT HANDLERS: Keyboard & Mouse Targeting
	-- ========================================

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed or not isInActionPhase or isAoEMode then return end
		if input.KeyCode == Enum.KeyCode.A or input.KeyCode == Enum.KeyCode.Left then
			CycleTarget(-1)
		elseif input.KeyCode == Enum.KeyCode.D or input.KeyCode == Enum.KeyCode.Right then
			CycleTarget(1)
		end
	end)

	local mouse = player:GetMouse()
	mouse.Button1Down:Connect(function()
		if not isInActionPhase or not currentBattleId or isAoEMode then return end
		local hit = mouse.Target
		if not hit then return end

		-- Walk up parent tree to find arena model
		local arenaName = "Arena_" .. currentBattleId
		local model = hit.Parent
		while model and model ~= workspace do
			if model.Parent and model.Parent.Name == arenaName then
				local uid = model.Name
				if table.find(validTargetPool, uid) then
					SetTargetHighlight(uid)
				end
				break
			end
			model = model.Parent
		end
	end)
end

return CombatController