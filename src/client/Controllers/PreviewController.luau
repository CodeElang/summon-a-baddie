local PreviewController = {}
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")

local camera = Workspace.CurrentCamera
local currentModel = nil
local renderConnection = nil
local localScene = nil

local orbitAngleX = 0
local orbitAngleY = 0
local orbitDistance = 10

local targetAngleX = 0
local targetAngleY = 0
local targetDistance = 10

local savedAtmosphere = nil
local originalFogEnd = 2500

local mouse = Players.LocalPlayer:GetMouse()

function PreviewController:Init() end

function PreviewController:Start() end

local function GetOrMakeLocalScene()
	if localScene then return localScene end

	localScene = Instance.new("Model")
	localScene.Name = "LocalRPGScene"

	local waterFloor = Instance.new("Part", localScene)
	waterFloor.Name = "WaterFloor"
	waterFloor.Size = Vector3.new(300, 1, 300)
	waterFloor.Position = Vector3.new(0, 10000, 0)
	waterFloor.Anchored = true
	waterFloor.Color = Color3.fromRGB(15, 10, 20)
	waterFloor.Material = Enum.Material.Glass
	waterFloor.Reflectance = 0.3

	local spawnPt = Instance.new("Part", localScene)
	spawnPt.Name = "SpawnPoint"
	spawnPt.Size = Vector3.new(1, 1, 1)
	spawnPt.Position = Vector3.new(0, 10001, 0)
	spawnPt.Anchored = true
	spawnPt.Transparency = 1

	local camPt = Instance.new("Part", localScene)
	camPt.Name = "DefaultCamera"
	camPt.Size = Vector3.new(1, 1, 1)
	camPt.Position = Vector3.new(0, 10005, 12)
	camPt.Anchored = true
	camPt.Transparency = 1

	local light = Instance.new("PointLight", spawnPt)
	light.Range = 30
	light.Brightness = 1.2 
	light.Color = Color3.fromRGB(240, 230, 255)

	localScene.Parent = Workspace
	return localScene
end

-- Fungsi khusus untuk menghancurkan ilusi kabut
local function ClearFog()
	if not savedAtmosphere then
		savedAtmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
		if savedAtmosphere then
			savedAtmosphere.Parent = nil -- Cabut paksa dari Lighting
		end
		originalFogEnd = Lighting.FogEnd
		Lighting.FogEnd = 100000 -- Pandangan jarak jauh 100% bersih
	end
end

-- Fungsi untuk mengembalikan kabut seperti semula
local function RestoreFog()
	if savedAtmosphere then
		savedAtmosphere.Parent = Lighting
		savedAtmosphere = nil
	end
	Lighting.FogEnd = originalFogEnd
end

function PreviewController:FocusEmptyScene()
	self:ClearPreview()
	ClearFog() -- Bersihkan kabut

	local scene = GetOrMakeLocalScene()
	local camPt = scene:FindFirstChild("DefaultCamera")
	local spawnPt = scene:FindFirstChild("SpawnPoint")

	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = 40

	camera.CFrame = CFrame.lookAt(camPt.Position, spawnPt.Position + Vector3.new(0, 3, 0))

	renderConnection = RunService.RenderStepped:Connect(function(dt)
		local screenSize = camera.ViewportSize
		local mouseX = (mouse.X - (screenSize.X / 2)) / screenSize.X
		local mouseY = (mouse.Y - (screenSize.Y / 2)) / screenSize.Y

		local offset = CFrame.new(mouseX * 1.5, -mouseY * 1.5, 0)
		local goalCFrame = CFrame.lookAt(camPt.Position, spawnPt.Position + Vector3.new(0, 3, 0)) * offset

		camera.CFrame = camera.CFrame:Lerp(goalCFrame, dt * 5)
	end)
end

function PreviewController:ShowBaddie(baddieTool)
	self:ClearPreview()
	ClearFog() -- Bersihkan kabut

	local scene = GetOrMakeLocalScene()
	local spawnPt = scene:FindFirstChild("SpawnPoint")

	local visualModel = baddieTool:FindFirstChild("VisualModel")
	if not visualModel then return end

	currentModel = visualModel:Clone()
	local rootPart = currentModel:FindFirstChild("HumanoidRootPart") or currentModel.PrimaryPart

	if rootPart then
		currentModel.PrimaryPart = rootPart
		currentModel:PivotTo(spawnPt.CFrame * CFrame.new(0, 2.5, 0))
		currentModel.Parent = scene

		local hum = currentModel:FindFirstChildOfClass("Humanoid")
		local idleAnim = currentModel:FindFirstChild("IdleAnim")
		if hum and idleAnim then
			local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
			local track = animator:LoadAnimation(idleAnim)
			track.Looped = true
			track:Play()
		end

		camera.CameraType = Enum.CameraType.Scriptable
		camera.FieldOfView = 40 

		targetAngleX = 0
		targetAngleY = math.rad(10)
		targetDistance = 9
		orbitAngleX = targetAngleX
		orbitAngleY = targetAngleY
		orbitDistance = targetDistance

		renderConnection = RunService.RenderStepped:Connect(function(dt)
			if currentModel and rootPart then
				orbitAngleX = orbitAngleX + (targetAngleX - orbitAngleX) * (dt * 12)
				orbitAngleY = orbitAngleY + (targetAngleY - orbitAngleY) * (dt * 12)
				orbitDistance = orbitDistance + (targetDistance - orbitDistance) * (dt * 10)

				local lookAtPos = rootPart.Position + Vector3.new(0, 1.5, 0)
				local rotationCFrame = CFrame.Angles(0, orbitAngleX, 0) * CFrame.Angles(orbitAngleY, 0, 0)
				local cameraPos = lookAtPos + (rotationCFrame.LookVector * orbitDistance)

				camera.CFrame = CFrame.lookAt(cameraPos, lookAtPos)
			end
		end)
	end
end

function PreviewController:ClearPreview()
	if currentModel then
		currentModel:Destroy()
		currentModel = nil
	end
	if renderConnection then
		renderConnection:Disconnect()
		renderConnection = nil
	end
end

function PreviewController:DragRotate(deltaX, deltaY)
	if currentModel then
		targetAngleX = targetAngleX - math.rad(deltaX * 0.4)
		targetAngleY = targetAngleY - math.rad(deltaY * 0.4)
		targetAngleY = math.clamp(targetAngleY, math.rad(-5), math.rad(60))
	end
end

function PreviewController:Zoom(zoomDelta)
	if currentModel then
		targetDistance = targetDistance + zoomDelta
		targetDistance = math.clamp(targetDistance, 4, 18)
	end
end

function PreviewController:ClosePreview()
	self:ClearPreview()
	RestoreFog() -- Kembalikan efek kabut Tycoon
	camera.CameraType = Enum.CameraType.Custom
	camera.FieldOfView = 70
end

return PreviewController