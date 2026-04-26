local EncounterService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CombatService = require(script.Parent.CombatService)

local Debounces = {}

function EncounterService:Init()
	-- Wait for workspace to load completely if needed
	local enemiesFolder = workspace:FindFirstChild("OverworldEnemies") or workspace:FindFirstChild("Enemies")
	if not enemiesFolder then
		warn("[EncounterService] 'Enemies' folder not found in workspace!")
		return
	end

	-- Future-Proofing: Currently using .Touched (Body collision). 
	-- To change to HSR-style weapon hitbox triggers, we would replace this loop to listen 
	-- to player weapon casts (Raycasts/Region3) hitting these models instead.
	for _, model in ipairs(enemiesFolder:GetChildren()) do
		if model:IsA("Model") then
			self:HookEncounter(model)
		end
	end
end

function EncounterService:HookEncounter(npcModel)
	local hitbox = npcModel:FindFirstChild("HumanoidRootPart") or npcModel.PrimaryPart or npcModel:FindFirstChildWhichIsA("BasePart")
	if not hitbox then 
		warn("[EncounterService] No hitbox found for " .. npcModel.Name)
		return 
	end

	print("[EncounterService] Hooked Overworld NPC: " .. npcModel.Name)

	hitbox.Touched:Connect(function(hit)
		-- 1. Check if it's already locked in combat
		if npcModel:GetAttribute("InCombat") then return end

		-- 2. Verify it's a Player
		local character = hit.Parent
		if not character then return end
		local player = game.Players:GetPlayerFromCharacter(character)
		if not player then return end

		-- 3. Debounce (Prevent 50 triggers in a single frame)
		if Debounces[player.UserId] then return end
		Debounces[player.UserId] = true
		task.delay(2, function() Debounces[player.UserId] = nil end)

		-- 4. Combat Lock (Prevent other players from joining/touching)
		npcModel:SetAttribute("InCombat", true)

		local npcId = npcModel:GetAttribute("NPCId") or npcModel.Name

		-- 5. Initiate Battle (Classic)
		local success = CombatService:InitiateBattle(player, npcId, npcModel)
		
		if success then
			print("[EncounterService] Battle Initiated successfully!")
		else
			warn("[EncounterService] CombatService:InitiateBattle returned false.")
			-- Unlock if it failed
			npcModel:SetAttribute("InCombat", false)
		end
	end)
end

function EncounterService:Start()
	self:Init()
end

return EncounterService
