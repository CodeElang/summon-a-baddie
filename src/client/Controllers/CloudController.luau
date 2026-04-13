local CloudController = {}

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

-- ========================================================
-- CONSTANTS: MAP LOCATION & CLOUD SETTINGS
-- ========================================================
-- Set your specific game center point here!
local MAP_CENTER = Vector3.new(-2171.59, 1419.117, 369.21)

local CLOUD_COUNT = 40          
local CLOUD_SPEED = 6           
local MAP_BOUNDS = 2500         -- Larger bounds so they travel further
local FADE_ZONE = 400           -- Distance from the edge where clouds start fading

-- Altitude relative to your map's Y position
local CLOUD_ALTITUDE_MIN = MAP_CENTER.Y + 250
local CLOUD_ALTITUDE_MAX = MAP_CENTER.Y + 450

local CLOUD_COLOR = Color3.fromRGB(250, 250, 255)
local BASE_TRANSPARENCY = 0.2   -- Base transparency when fully visible

-- ========================================================
-- HELPER: RANDOMIZE CLOUD SIZE
-- ========================================================
local function GetRandomCloudSize()
	local scaleType = math.random(1, 100)
	local width, length, height

	if scaleType > 85 then 
		-- 15% chance for MASSIVE cloud banks (Dibuat lebih gepeng)
		width = math.random(300, 600)
		length = math.random(200, 500)
		height = math.random(10, 16) 
	elseif scaleType > 40 then 
		-- 45% chance for Medium clouds
		width = math.random(100, 250)
		length = math.random(100, 200)
		height = math.random(8, 12)
	else 
		-- 40% chance for Small broken clouds
		width = math.random(30, 80)
		length = math.random(30, 80)
		height = math.random(4, 8)
	end

	return Vector3.new(width, height, length)
end

function CloudController:Init()
	self.Clouds = {}

	self.CloudFolder = Instance.new("Folder")
	self.CloudFolder.Name = "LocalVoxelClouds"
	self.CloudFolder.Parent = Workspace

	for i = 1, CLOUD_COUNT do
		self:CreateCloud(true) -- Pass 'true' to randomize their starting Z position
	end
end

function CloudController:CreateCloud(isInitialSpawn)
	local cloud = Instance.new("Part")

	-- Gunakan fungsi helper untuk mendapatkan ukuran acak
	cloud.Size = GetRandomCloudSize()

	-- Set Spawn Position relative to MAP_CENTER
	local startX = MAP_CENTER.X + math.random(-MAP_BOUNDS/2, MAP_BOUNDS/2)
	local startY = math.random(CLOUD_ALTITUDE_MIN, CLOUD_ALTITUDE_MAX)

	local startZ
	if isInitialSpawn then
		-- Spread them out initially
		startZ = MAP_CENTER.Z + math.random(-MAP_BOUNDS/2, MAP_BOUNDS/2)
	else
		-- Spawn at the very back edge of the bounds
		startZ = MAP_CENTER.Z - (MAP_BOUNDS / 2)
	end

	cloud.Position = Vector3.new(startX, startY, startZ)

	-- Aesthetics & Optimization
	cloud.Color = CLOUD_COLOR
	cloud.Material = Enum.Material.Plastic
	cloud.MaterialVariant = "Studs"
	cloud.Transparency = BASE_TRANSPARENCY
	cloud.CastShadow = true
	cloud.Anchored = true
	cloud.CanCollide = false

	cloud.Parent = self.CloudFolder
	table.insert(self.Clouds, cloud)
end

function CloudController:Start()
	RunService.RenderStepped:Connect(function(deltaTime)
		local maxZ = MAP_CENTER.Z + (MAP_BOUNDS / 2)
		local minZ = MAP_CENTER.Z - (MAP_BOUNDS / 2)

		for _, cloud in ipairs(self.Clouds) do
			-- Move the cloud forward
			cloud.CFrame = cloud.CFrame * CFrame.new(0, 0, CLOUD_SPEED * deltaTime)

			-- ==========================================
			-- SMOOTH FADE IN / FADE OUT LOGIC
			-- ==========================================
			local distFromStart = cloud.Position.Z - minZ
			local distFromEnd = maxZ - cloud.Position.Z

			if distFromStart < FADE_ZONE then
				-- Fading IN (just spawned at the back)
				local fadeRatio = distFromStart / FADE_ZONE
				cloud.Transparency = 1 - ((1 - BASE_TRANSPARENCY) * fadeRatio)
			elseif distFromEnd < FADE_ZONE then
				-- Fading OUT (reaching the front edge)
				local fadeRatio = distFromEnd / FADE_ZONE
				cloud.Transparency = 1 - ((1 - BASE_TRANSPARENCY) * fadeRatio)
			else
				-- Fully visible in the middle of the map
				cloud.Transparency = BASE_TRANSPARENCY
			end

			-- Ensure transparency never goes below base
			if cloud.Transparency < BASE_TRANSPARENCY then
				cloud.Transparency = BASE_TRANSPARENCY
			end

			-- ==========================================
			-- LOOPING SYSTEM (IMPROVED)
			-- ==========================================
			-- Jika awan melewati batas ujung...
			if cloud.Position.Z > maxZ then
				-- 1. Acak ulang ukurannya agar awan yang muncul terasa baru!
				cloud.Size = GetRandomCloudSize()

				-- 2. Teleport kembali ke garis start
				local newX = MAP_CENTER.X + math.random(-MAP_BOUNDS/2, MAP_BOUNDS/2)
				local newY = math.random(CLOUD_ALTITUDE_MIN, CLOUD_ALTITUDE_MAX)
				cloud.CFrame = CFrame.new(newX, newY, minZ)
				cloud.Transparency = 1 -- Hide it completely before fading in
			end
		end
	end)
end

return CloudController