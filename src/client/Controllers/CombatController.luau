local CombatController = {}

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Network = ReplicatedStorage.Network

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
	local lastAnimTick = 0
	local currentBattleId = nil
	local currentTargetUid = nil
	local unitNames = {}
	local storedVisibleUIs = {}

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

	local function CreateHPBar(model, unitName, maxHp, currentHp, currentShield)
		currentShield = currentShield or 0
		currentHp = math.max(0, currentHp)
		local head = model:FindFirstChild("Head") or model.PrimaryPart
		if not head then return end
		if head:FindFirstChild("HPBar") then head.HPBar:Destroy() end

		local bb = Instance.new("BillboardGui", head)
		bb.Name = "HPBar"
		bb.Size = UDim2.new(5, 0, 2.2, 0)
		bb.StudsOffset = Vector3.new(0, 3.8, 0)
		bb.AlwaysOnTop = true

		local nameLbl = Instance.new("TextLabel", bb)
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
		hpLbl.Size = UDim2.new(1, 0, 0.22, 0)
		hpLbl.Position = UDim2.new(0, 0, 0.28, 0)
		hpLbl.BackgroundTransparency = 1
		hpLbl.Text = hpText
		hpLbl.TextColor3 = Color3.fromRGB(220, 220, 220)
		hpLbl.Font = Enum.Font.GothamMedium
		hpLbl.TextScaled = true
		hpLbl.TextStrokeTransparency = 0.2

		local shieldBg = Instance.new("Frame", bb)
		shieldBg.Name = "ShieldBarBG"
		shieldBg.Size = UDim2.new(1, 0, 0.16, 0)
		shieldBg.Position = UDim2.new(0, 0, 0.52, 0)
		shieldBg.BackgroundColor3 = Color3.fromRGB(20, 20, 50)
		shieldBg.ClipsDescendants = true
		shieldBg.Visible = currentShield > 0
		Instance.new("UICorner", shieldBg).CornerRadius = UDim.new(1, 0)

		if currentShield > 0 then
			local shieldPercent = math.clamp(currentShield / maxHp, 0, 1)
			local shieldFill = Instance.new("Frame", shieldBg)
			shieldFill.Size = UDim2.new(shieldPercent, 0, 1, 0)
			shieldFill.BackgroundColor3 = Color3.fromRGB(85, 170, 255)
			Instance.new("UICorner", shieldFill).CornerRadius = UDim.new(1, 0)
		end

		local hpBg = Instance.new("Frame", bb)
		hpBg.Name = "HPBarBG"
		hpBg.Size = UDim2.new(1, 0, 0.16, 0)
		hpBg.Position = UDim2.new(0, 0, 0.72, 0)
		hpBg.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
		hpBg.ClipsDescendants = true
		Instance.new("UICorner", hpBg).CornerRadius = UDim.new(1, 0)

		local hpPercent = math.clamp(currentHp / maxHp, 0, 1)
		local fill = Instance.new("Frame", hpBg)
		fill.Size = UDim2.new(hpPercent, 0, 1, 0)
		fill.BackgroundColor3 = Color3.fromRGB(200, 40, 40)
		Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)
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
			ToggleOtherUIs(false)
			workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
			return
		end

		currentBattleId = data.Id
		ToggleOtherUIs(true)
		TurnInd.Visible = true
		TurnOrderContainer.Visible = true

		local cam = workspace.CurrentCamera
		cam.CameraType = Enum.CameraType.Scriptable
		cam.CFrame = CFrame.lookAt(data.CenterPosition + data.CameraOffset, data.CenterPosition)

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
		currentTargetUid = data.Enemies[1].Uid

		local activeUnit = data.ActiveUnit

		if activeUnit.Tier == 1 then
			SkillBtn.Visible = false
			UltBtn.Visible = false
		else
			SkillBtn.Visible = true
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
	end)

	BasicBtn.MouseButton1Click:Connect(function()
		if not currentTargetUid then return end
		CombatHUD.Visible = false
		SubmitActionEvent:InvokeServer(currentBattleId, "Basic", currentTargetUid)
	end)

	SkillBtn.MouseButton1Click:Connect(function()
		if not currentTargetUid then return end
		CombatHUD.Visible = false
		SubmitActionEvent:InvokeServer(currentBattleId, "Skill", currentTargetUid)
	end)

	UltBtn.MouseButton1Click:Connect(function()
		if not currentTargetUid or not UltBtn.Active then return end
		CombatHUD.Visible = false
		SubmitActionEvent:InvokeServer(currentBattleId, "Ultimate", currentTargetUid)
	end)

	RunBtn.MouseButton1Click:Connect(function()
		CombatHUD.Visible = false
		SubmitActionEvent:InvokeServer(currentBattleId, "Flee")
	end)

	TurnUpdateEvent.OnClientEvent:Connect(function(action, param1, param2, displayValue, newHp, maxHp, shield, visualTag)
		if action == "UpdateTurnUI" then
			TurnInd.Text = string.upper(param1) .. "'S TURN"
			if param2 then RenderTurnQueue(param2) end

		elseif action == "RefreshTurnQueue" then
			if param1 then RenderTurnQueue(param1) end

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
					local origCFrame = atkModel.PrimaryPart.CFrame
					local targetPos = tgtModel.PrimaryPart.Position
					local dashPos = origCFrame.Position:Lerp(targetPos, 0.6)

					local tInfo = TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
					local dashTween = TweenService:Create(atkModel.PrimaryPart, tInfo, {CFrame = CFrame.lookAt(dashPos, targetPos)})
					local backTween = TweenService:Create(atkModel.PrimaryPart, tInfo, {CFrame = origCFrame})

					dashTween:Play()
					dashTween.Completed:Wait()

					ShowDamagePopup(tgtModel, displayValue)
					CreateHPBar(tgtModel, targetName, maxHp, newHp, shield)

					backTween:Play()
				else
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
					local animObj = ReplicatedStorage.Shared.Assets.Animations:FindFirstChild("CastHeal")
					if hum and animObj then
						local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
						local track = animator:LoadAnimation(animObj)

						track.Looped = false 
						track:Play()
					end

					local sfx = ReplicatedStorage.Shared.Assets.Sounds:FindFirstChild("HealSFX")
					if sfx then
						local sfxClone = sfx:Clone()
						sfxClone.Parent = atkModel.PrimaryPart
						sfxClone:Play()
						game.Debris:AddItem(sfxClone, 3)
					end
				end

				local vfx = ReplicatedStorage.Shared.Assets.VFX:FindFirstChild("HealAura")
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
end

return CombatController