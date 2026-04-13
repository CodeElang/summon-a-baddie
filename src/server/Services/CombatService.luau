local CombatService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local DataService = require(script.Parent.DataService)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local SkillData = require(ReplicatedStorage.Shared.Databases.SkillData)
local Network = ReplicatedStorage.Network
local BattleLogger = require(script.Parent.BattleLogger)

local BattleStartEvent = Network:FindFirstChild("BattleStart") or Instance.new("RemoteEvent")
BattleStartEvent.Name = "BattleStart"
BattleStartEvent.Parent = Network

local TurnUpdateEvent = Network:FindFirstChild("TurnUpdate") or Instance.new("RemoteEvent")
TurnUpdateEvent.Name = "TurnUpdate"
TurnUpdateEvent.Parent = Network

local ActionRequestEvent = Network:FindFirstChild("ActionRequest") or Instance.new("RemoteEvent")
ActionRequestEvent.Name = "ActionRequest"
ActionRequestEvent.Parent = Network

local SubmitActionEvent = Network:FindFirstChild("SubmitAction") or Instance.new("RemoteFunction")
SubmitActionEvent.Name = "SubmitAction"
SubmitActionEvent.Parent = Network

local ActiveBattles = {}
local VALID_ACTION_TYPES = { Basic = true, Skill = true, Ultimate = true, Flee = true }

function CombatService:Init() end
function CombatService:Start() end

function CombatService:InitiateBattle(player, npcId, npcModel)
	local profile = DataService:GetProfile(player)
	if not profile then return false end

	local npcData = GameConfig.GetNPCData(npcId)
	if not npcData then return false end

	local playerUnits = self:AssemblePlayerParty(profile)
	if #playerUnits == 0 then return false end

	local battleId = HttpService:GenerateGUID(false)
	local battleInst = {
		Id = battleId,
		State = "InProgress",
		Player = player,
		Units = {},
		CurrentActorUid = nil
	}

	for _, unit in ipairs(playerUnits) do
		table.insert(battleInst.Units, unit)
	end

	local zoneData = GameConfig.Zones[npcData.Zone]
	local zoneMult = zoneData and zoneData.DifficultyMult or 1.0

	table.insert(battleInst.Units, {
		Uid = "Enemy_1",
		IsPlayer = false,
		Name = npcData.Name,
		HP = math.floor(npcData.HP * zoneMult),
		MaxHP = math.floor(npcData.HP * zoneMult),
		ATK = math.floor(npcData.ATK * zoneMult),
		DEF = math.floor(npcData.DEF * zoneMult),
		SPD = npcData.SPD,
		Energy = 0,
		Shield = 0,
		Buffs = {},
		AI = npcData.AI
	})

	for _, unit in ipairs(battleInst.Units) do
		unit.AV = 10000 / math.max(1, unit.SPD)
	end

	ActiveBattles[battleId] = battleInst
	BattleLogger.StartBattle(battleId, battleInst.Units)
	self:SetupBattleArena(battleId, npcModel)

	task.delay(1, function()
		if ActiveBattles[battleId] then
			self:ProcessNextTurn(battleId)
		end
	end)
	return true
end

function CombatService:AssemblePlayerParty(profile)
	local units = {}
	local party = profile.Data.Party

	for i = 1, 4 do
		local baddieId = party["Slot" .. i]
		if baddieId and baddieId ~= "" then
			for _, baddieData in ipairs(profile.Data.Baddies) do
				if baddieData.Id == baddieId then
					local bCfg = GameConfig.GetBaddieData(baddieData.Name)
					if bCfg then
						local starMult = GameConfig.StarMultipliers[baddieData.Stars or 0] or 1.0
						local finalHP  = math.floor(bCfg.BaseHP  * starMult)
						local finalATK = math.floor(bCfg.BaseATK * starMult)
						local finalDEF = math.floor(bCfg.BaseDEF * starMult)
						local finalSPD = bCfg.BaseSPD
						local startEnergy = 0

						if baddieData.Relics then
							for _, relicName in pairs(baddieData.Relics) do
								if relicName == "SpeedBoots" then finalSPD += 5
								elseif relicName == "AtkRing"  then finalATK += math.floor(finalATK * 0.05)
								elseif relicName == "DefPlate" then finalDEF += math.floor(finalDEF * 0.05)
								end
							end
						end

						if baddieData.Mutations then
							for _, mutation in ipairs(baddieData.Mutations) do
								if mutation == "Speedy"    then finalSPD += 5
								elseif mutation == "Energetic" then startEnergy = 1 end
							end
						end

						table.insert(units, {
							Uid      = "PUnit_" .. i,
							IsPlayer = true,
							BaddieId = baddieData.Id,
							Name     = baddieData.Name,
							Tier     = bCfg.Tier,
							HP = finalHP, MaxHP = finalHP,
							ATK = finalATK, DEF = finalDEF, SPD = finalSPD,
							Role      = bCfg.Role,
							Energy    = startEnergy, MaxEnergy = 3,
							Shield    = 0,
							Buffs     = {},
							SkillId   = bCfg.SkillId,
							UltId     = bCfg.UltId
						})
					end
					break
				end
			end
		end
	end
	return units
end

function CombatService:CalculateDamage(attacker, defender, skillMultiplier)
	local rawDamage     = attacker.ATK * skillMultiplier
	local damageReduction = defender.DEF / (defender.DEF + 120)
	local finalDamage   = math.floor(rawDamage * (1 - damageReduction))
	return math.max(1, finalDamage)
end

function CombatService:ApplyDamage(battleId, targetUid, damageAmount)
	local battleInst = ActiveBattles[battleId]
	if not battleInst then return false end

	local targetUnit = self:GetUnitByUid(battleInst, targetUid)
	if not targetUnit then return false end

	local shieldBefore = targetUnit.Shield
	local absorbed     = 0

	if targetUnit.Shield > 0 then
		if damageAmount <= targetUnit.Shield then
			absorbed          = damageAmount
			targetUnit.Shield -= damageAmount
			damageAmount      = 0
		else
			absorbed          = targetUnit.Shield
			damageAmount      -= targetUnit.Shield
			targetUnit.Shield = 0
		end
	end

	if damageAmount > 0 then
		targetUnit.HP = math.max(0, targetUnit.HP - damageAmount)
	end
	return true
end

function CombatService:ApplyShield(battleId, targetUid, shieldAmount)
	local battleInst = ActiveBattles[battleId]
	if not battleInst then return end
	local u = self:GetUnitByUid(battleInst, targetUid)
	if u then u.Shield += shieldAmount end
end

function CombatService:GenerateTurnQueue(battleInst, count)
	local queue = {}

	local simUnits = {}
	for _, u in ipairs(battleInst.Units) do
		if u.HP > 0 then
			table.insert(simUnits, {
				Uid      = u.Uid,
				Name     = u.Name,
				IsPlayer = u.IsPlayer,
				Speed    = u.SPD,
				AV       = u.AV
			})
		end
	end

	for _ = 1, count do
		local minAV   = math.huge
		local actUnit = nil
		for _, u in ipairs(simUnits) do
			if u.AV < minAV then minAV = u.AV; actUnit = u end
		end
		if not actUnit then break end

		table.insert(queue, {
			Uid      = actUnit.Uid,
			Name     = actUnit.Name,
			IsPlayer = actUnit.IsPlayer,
			Speed    = actUnit.Speed
		})

		for _, u in ipairs(simUnits) do u.AV = u.AV - minAV end
		actUnit.AV = 10000 / math.max(1, actUnit.Speed)
	end

	return queue
end

function CombatService:BuildDisplayQueue(battleInst, currentUnit, previewCount)
	local upcomingQueue = self:GenerateTurnQueue(battleInst, previewCount)

	local displayQueue = {
		{
			Uid      = currentUnit.Uid,
			Name     = currentUnit.Name,
			IsPlayer = currentUnit.IsPlayer,
			Speed    = currentUnit.SPD
		}
	}

	for _, entry in ipairs(upcomingQueue) do
		table.insert(displayQueue, entry)
	end

	return displayQueue
end

function CombatService:ProcessTurnStartHooks(battleId, unit)
	local battleInst = ActiveBattles[battleId]
	if not battleInst or unit.HP <= 0 then return end

	local speedChanged = false

	for i = #unit.Buffs, 1, -1 do
		local buff = unit.Buffs[i]

		if buff.Type == "Burn" then
			local dmg = math.floor(unit.MaxHP * (buff.Value or 0.05))
			self:ApplyDamage(battleId, unit.Uid, dmg)
			TurnUpdateEvent:FireClient(battleInst.Player, "AttackVisual", unit.Uid, unit.Uid, dmg, unit.HP, unit.MaxHP, unit.Shield, "VFX_Burn_Tick")
			task.wait(0.5)
		end

		buff.Duration -= 1

		if buff.Duration <= 0 then
			if buff.Type == "Speed" then
				unit.SPD -= buff.Amount
				unit.AV = unit.AV * ((unit.SPD + buff.Amount) / math.max(1, unit.SPD))
				speedChanged = true
			end
			table.remove(unit.Buffs, i)
		end
	end

	if speedChanged then
		local refreshedQueue = self:BuildDisplayQueue(battleInst, unit, 5)
		TurnUpdateEvent:FireClient(battleInst.Player, "RefreshTurnQueue", refreshedQueue)
	end
end

function CombatService:ProcessNextTurn(battleId)
	local battleInst = ActiveBattles[battleId]
	if not battleInst or battleInst.State ~= "InProgress" then return end

	local alivePlayers = self:GetAlivePlayers(battleInst)
	local aliveEnemies = self:GetAliveEnemies(battleInst)
	if #alivePlayers == 0 then self:EndBattle(battleId, "Defeat")  return end
	if #aliveEnemies == 0 then self:EndBattle(battleId, "Victory") return end

	local minAV      = math.huge
	local currentUnit = nil
	for _, u in ipairs(battleInst.Units) do
		if u.HP > 0 and u.AV < minAV then
			minAV = u.AV
			currentUnit = u
		end
	end
	if not currentUnit then return end

	for _, u in ipairs(battleInst.Units) do
		if u.HP > 0 then u.AV = u.AV - minAV end
	end

	currentUnit.AV           = 10000 / math.max(1, currentUnit.SPD)
	battleInst.CurrentActorUid = currentUnit.Uid

	self:ProcessTurnStartHooks(battleId, currentUnit)

	if currentUnit.HP <= 0 then
		task.delay(1.5, function()
			if not ActiveBattles[battleId] or ActiveBattles[battleId].State ~= "InProgress" then return end
			self:NextTurn(battleId)
		end)
		return
	end

	local displayQueue = self:BuildDisplayQueue(battleInst, currentUnit, 5)
	TurnUpdateEvent:FireClient(battleInst.Player, "UpdateTurnUI", currentUnit.Name, displayQueue)

	if currentUnit.IsPlayer then
		ActionRequestEvent:FireClient(battleInst.Player, {
			BattleId   = battleId,
			ActiveUnit = currentUnit,
			Enemies    = aliveEnemies
		})
	else
		task.delay(1.5, function()
			if not ActiveBattles[battleId] or ActiveBattles[battleId].State ~= "InProgress" then return end
			self:ExecuteNPCAction(battleId, currentUnit)
		end)
	end
end

SubmitActionEvent.OnServerInvoke = function(player, battleId, actionType, targetUid)
	if type(battleId) ~= "string" or not VALID_ACTION_TYPES[actionType] then return false end

	local battleInst = ActiveBattles[battleId]
	if not battleInst or battleInst.Player ~= player or battleInst.State ~= "InProgress" then return false end

	if actionType == "Flee" then
		CombatService:EndBattle(battleId, "Fled")
		return true
	end

	local currentUnit = CombatService:GetUnitByUid(battleInst, battleInst.CurrentActorUid)
	if not currentUnit or not currentUnit.IsPlayer then return false end

	if actionType == "Skill"   and (not currentUnit.SkillId or currentUnit.Tier == 1)       then return false end
	if actionType == "Ultimate" and (currentUnit.Tier < 5 or currentUnit.Energy < 3)         then return false end
	if type(targetUid) ~= "string"                                                           then return false end

	local targetUnit = CombatService:GetUnitByUid(battleInst, targetUid)
	if not targetUnit or targetUnit.HP <= 0 then return false end

	CombatService:ExecuteAction(battleId, currentUnit, actionType, targetUid)
	return true
end

function CombatService:ProcessEffects(battleId, attacker, target, effectsArray, visualTag)
	local battleInst = ActiveBattles[battleId]
	local totalDamage = 0
	local totalHeal = 0
	local totalShield = 0
	local appliedTags = {}

	for _, effect in ipairs(effectsArray) do
		if effect.Type == "Damage" then
			local dmg = self:CalculateDamage(attacker, target, effect.Multiplier)
			self:ApplyDamage(battleId, target.Uid, dmg)
			totalDamage += dmg
		elseif effect.Type == "Heal" then
			local heal = math.floor(attacker.ATK * effect.Multiplier)
			target.HP = math.min(target.MaxHP, target.HP + heal)
			totalHeal += heal
		elseif effect.Type == "Shield" then
			local shield = math.floor(attacker.DEF * effect.Multiplier)
			self:ApplyShield(battleId, target.Uid, shield)
			totalShield += shield
		elseif effect.Type == "Buff" and effect.BuffType == "Speed" then
			target.SPD += effect.Amount
			target.AV = target.AV * ((target.SPD - effect.Amount) / target.SPD)
			table.insert(target.Buffs, {Type = "Speed", Amount = effect.Amount, Duration = effect.Duration or 2})
			table.insert(appliedTags, "+SPEED")
		elseif effect.Type == "ApplyStatus" then
			table.insert(target.Buffs, {Type = effect.Status, Duration = effect.Duration, Value = effect.Value})
			table.insert(appliedTags, string.upper(effect.Status))
		end
	end

	local displayValue = 0
	if totalDamage > 0 then displayValue = totalDamage 
	elseif totalHeal > 0 then displayValue = -totalHeal
	elseif totalShield > 0 then displayValue = "SHIELD"
	elseif #appliedTags > 0 then displayValue = table.concat(appliedTags, ", ") end

	TurnUpdateEvent:FireClient(battleInst.Player, "AttackVisual", attacker.Uid, target.Uid, displayValue, target.HP, target.MaxHP, target.Shield, visualTag)

	if #appliedTags > 0 then
		local currentActor = self:GetUnitByUid(battleInst, battleInst.CurrentActorUid)
		if currentActor then
			local refreshedQueue = self:BuildDisplayQueue(battleInst, currentActor, 5)
			TurnUpdateEvent:FireClient(battleInst.Player, "RefreshTurnQueue", refreshedQueue)
		end
	end
end

function CombatService:ExecuteAction(battleId, attacker, actionType, targetUid)
	local battleInst = ActiveBattles[battleId]
	if not battleInst then return end

	local usedSkillId = "Basic_Attack"
	if actionType == "Skill"    then usedSkillId = attacker.SkillId or "Heavy_Strike"
	elseif actionType == "Ultimate" then usedSkillId = attacker.UltId  or "Ult_Meteor" end

	local skillInfo = SkillData.Dictionary[usedSkillId] or SkillData.Dictionary["Basic_Attack"]

	if actionType == "Ultimate" then
		attacker.Energy = 0
	elseif attacker.Tier and attacker.Tier >= 5 and attacker.Energy < attacker.MaxEnergy then
		attacker.Energy = math.min(attacker.MaxEnergy, attacker.Energy + (skillInfo.EnergyGain or 1))
	end

	local actualTargets = {}

	if skillInfo.TargetRule == "All_Allies" and attacker.IsPlayer then
		actualTargets = self:GetAlivePlayers(battleInst)
	elseif skillInfo.TargetRule == "All_Allies_Exclude_Self" and attacker.IsPlayer then
		local allies = self:GetAlivePlayers(battleInst)
		for _, ally in ipairs(allies) do
			if ally.Uid ~= attacker.Uid then
				table.insert(actualTargets, ally)
			end
		end
	elseif skillInfo.TargetRule == "Lowest_Ally" and attacker.IsPlayer then
		table.insert(actualTargets, self:GetLowestHPAlly(battleInst))
	elseif skillInfo.TargetRule == "Lowest_Speed_Ally" and attacker.IsPlayer then
		table.insert(actualTargets, self:GetLowestSpeedAlly(battleInst))
	elseif skillInfo.TargetRule == "Self" then
		table.insert(actualTargets, attacker)
	else
		local singleTarget = self:GetUnitByUid(battleInst, targetUid)
		if singleTarget then table.insert(actualTargets, singleTarget) end
	end

	if #actualTargets == 0 then
		self:NextTurn(battleId)
		return
	end

	local specialModule = ReplicatedStorage.Shared:FindFirstChild("SpecialSkills")
	if specialModule then
		local skillScript = specialModule:FindFirstChild(usedSkillId)
		if skillScript then
			local executor = require(skillScript)
			executor.Execute(self, battleId, attacker, actualTargets, skillInfo)
			return
		end
	end

	for _, target in ipairs(actualTargets) do
		self:ProcessEffects(battleId, attacker, target, skillInfo.Effects, skillInfo.VisualTag)
	end

	task.delay(2.5, function()
		if not ActiveBattles[battleId] or ActiveBattles[battleId].State ~= "InProgress" then return end
		self:NextTurn(battleId)
	end)
end

function CombatService:ExecuteNPCAction(battleId, npcUnit)
	local battleInst = ActiveBattles[battleId]
	if not battleInst then return end

	local alivePlayers = self:GetAlivePlayers(battleInst)
	if #alivePlayers > 0 then
		local target = alivePlayers[math.random(1, #alivePlayers)]
		local skillInfo = SkillData.Dictionary["Basic_Attack"]
		if npcUnit.SkillId and SkillData.Dictionary[npcUnit.SkillId] then
			skillInfo = SkillData.Dictionary[npcUnit.SkillId]
		end

		self:ProcessEffects(battleId, npcUnit, target, skillInfo.Effects, skillInfo.VisualTag)
	end

	task.delay(2.5, function()
		if not ActiveBattles[battleId] or ActiveBattles[battleId].State ~= "InProgress" then return end
		self:NextTurn(battleId)
	end)
end

function CombatService:NextTurn(battleId)
	local battleInst = ActiveBattles[battleId]
	if not battleInst then return end
	battleInst.CurrentActorUid = nil
	self:ProcessNextTurn(battleId)
end

function CombatService:EndBattle(battleId, result)
	local battleInst = ActiveBattles[battleId]
	if not battleInst then return end

	battleInst.State = result

	BattleLogger.EndBattle(battleId, result, battleInst.Units)

	if battleInst.ArenaFolder then battleInst.ArenaFolder:Destroy() end

	local char = battleInst.Player.Character
	if char and char:FindFirstChild("Humanoid") then
		char.Humanoid.WalkSpeed = 16
		char.Humanoid.JumpPower = 50
	end

	BattleStartEvent:FireClient(battleInst.Player, {IsEnding = true, Result = result})
	ActiveBattles[battleId] = nil
end

function CombatService:GetUnitByUid(battleInst, uid)
	for _, u in ipairs(battleInst.Units) do
		if u.Uid == uid then return u end
	end
	return nil
end

function CombatService:GetAliveEnemies(battleInst)
	local e = {}
	for _, u in ipairs(battleInst.Units) do
		if not u.IsPlayer and u.HP > 0 then table.insert(e, u) end
	end
	return e
end

function CombatService:GetAlivePlayers(battleInst)
	local p = {}
	for _, u in ipairs(battleInst.Units) do
		if u.IsPlayer and u.HP > 0 then table.insert(p, u) end
	end
	return p
end

function CombatService:GetLowestHPAlly(battleInst)
	local players = self:GetAlivePlayers(battleInst)
	if #players == 0 then return nil end
	local lowest = players[1]
	for _, p in ipairs(players) do
		if (p.HP / p.MaxHP) < (lowest.HP / lowest.MaxHP) then lowest = p end
	end
	return lowest
end

function CombatService:GetLowestSpeedAlly(battleInst)
	local players = self:GetAlivePlayers(battleInst)
	if #players == 0 then return nil end
	local lowest = players[1]
	for _, p in ipairs(players) do
		if p.SPD < lowest.SPD then lowest = p end
	end
	return lowest
end

function CombatService:SetupBattleArena(battleId, npcModel)
	local battleInst = ActiveBattles[battleId]
	if not battleInst then return end

	local playerChar = battleInst.Player.Character
	if not playerChar or not playerChar:FindFirstChild("HumanoidRootPart") then return end

	local rootPart = playerChar.HumanoidRootPart
	playerChar.Humanoid.WalkSpeed = 0
	playerChar.Humanoid.JumpPower = 0

	local arenaFolder = Instance.new("Folder")
	arenaFolder.Name  = "Arena_" .. battleId
	arenaFolder.Parent = workspace
	battleInst.ArenaFolder = arenaFolder

	local enemySpawnPos = rootPart.CFrame * CFrame.new(0, 0, -15)

	if npcModel and npcModel.PrimaryPart then
		local npcHum = npcModel:FindFirstChildOfClass("Humanoid")
		if npcHum then npcHum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None end
		npcModel:PivotTo(CFrame.lookAt(enemySpawnPos.Position, rootPart.Position))
		npcModel.Parent = arenaFolder
		for _, u in ipairs(battleInst.Units) do
			if not u.IsPlayer then
				npcModel.Name = u.Uid
				u.Model3D     = npcModel
				break
			end
		end
	end

	local playerUnits = self:GetAlivePlayers(battleInst)
	local formationOffsets = {
		Vector3.new(-4, 0, -5),
		Vector3.new(4,  0, -5),
		Vector3.new(-8, 0, -3),
		Vector3.new(8,  0, -3)
	}

	for i, pUnit in ipairs(playerUnits) do
		local baddieCfg = GameConfig.GetBaddieData(pUnit.Name)
		local tierData  = GameConfig.Tiers[baddieCfg and baddieCfg.Rarity]
		if not tierData then continue end

		local sourceFolder = ReplicatedStorage.Baddies:FindFirstChild(tierData.Folder)
		local sourceTool   = sourceFolder and sourceFolder:FindFirstChild(pUnit.Name)

		if sourceTool and sourceTool:FindFirstChild("VisualModel") then
			local clone3D = sourceTool.VisualModel:Clone()
			clone3D.Name  = pUnit.Uid

			local hum = clone3D:FindFirstChildOfClass("Humanoid")
			if hum then hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None end

			local spawnPos = rootPart.CFrame * CFrame.new(formationOffsets[i] or Vector3.new(0, 0, -5))
			clone3D:PivotTo(CFrame.lookAt(spawnPos.Position, enemySpawnPos.Position))
			clone3D.Parent = arenaFolder
			pUnit.Model3D  = clone3D

			local idleAnim = clone3D:FindFirstChild("IdleAnim", true)
			if hum and idleAnim then
				local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
				local track    = animator:LoadAnimation(idleAnim)
				track.Looped   = true
				track:Play()
			end
		end
	end

	BattleStartEvent:FireClient(battleInst.Player, {
		Id             = battleId,
		Units          = battleInst.Units,
		CenterPosition = rootPart.Position:Lerp(enemySpawnPos.Position, 0.5),
		CameraOffset   = Vector3.new(15, 10, 0)
	})
end

return CombatService