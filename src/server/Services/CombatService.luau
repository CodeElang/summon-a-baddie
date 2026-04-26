local CombatService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local DataService = require(script.Parent.DataService)
local EnemyAIHandler = require(script.Parent.Parent.Modules.EnemyAIHandler)
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

	-- Spawn primary enemy
	table.insert(battleInst.Units, {
		Uid = "Enemy_1",
		IsPlayer = false,
		Name = npcData.Name,
		HP = math.floor(npcData.HP * zoneMult),
		MaxHP = math.floor(npcData.HP * zoneMult),
		ATK = math.floor(npcData.ATK * zoneMult),
		DEF = math.floor(npcData.DEF * zoneMult),
		SPD = npcData.SPD,
		BaseSPD = npcData.SPD,
		Energy = 0,
		Shield = 0,
		ShieldStack = {},
		Buffs = {},
		CDs = {},
		AI = npcData.AI
	})

	-- Spawn companion enemies from PartyComp
	if npcData.PartyComp then
		for i, compId in ipairs(npcData.PartyComp) do
			local compData = GameConfig.GetNPCData(compId)
			if compData then
				local compZone = GameConfig.Zones[compData.Zone]
				local compMult = compZone and compZone.DifficultyMult or zoneMult
				table.insert(battleInst.Units, {
					Uid = "Enemy_" .. (i + 1),
					IsPlayer = false,
					Name = compData.Name,
					HP = math.floor(compData.HP * compMult),
					MaxHP = math.floor(compData.HP * compMult),
					ATK = math.floor(compData.ATK * compMult),
					DEF = math.floor(compData.DEF * compMult),
					SPD = compData.SPD,
					BaseSPD = compData.SPD,
					Energy = 0,
					Shield = 0,
					ShieldStack = {},
					Buffs = {},
					CDs = {},
					AI = compData.AI
				})
			end
		end
	end

	for _, unit in ipairs(battleInst.Units) do
		unit.AV = 10000 / math.max(1, unit.SPD)
	end

	ActiveBattles[battleId] = battleInst
	BattleLogger.StartBattle(battleId, battleInst.Units)
	self:SetupBattleArena(battleId, npcModel)
	
	player:SetAttribute("InCombat", true)

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
							BaseSPD   = bCfg.BaseSPD,
							Role      = bCfg.Role,
							Energy    = startEnergy, MaxEnergy = 3,
							Shield    = 0,
							ShieldStack = {},
							Buffs     = {},
							CDs       = {},
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

function CombatService:CalculateDamage(attacker, defender, skillMultiplier, flatBonus)
	local atkMult = 1.0
	local defMult = 1.0

	for _, buff in ipairs(attacker.Buffs) do
		if buff.Type == "ATK_Up" then atkMult += buff.Value
		elseif buff.Type == "ATK_Down" then atkMult -= buff.Value end
	end
	
	for _, buff in ipairs(defender.Buffs) do
		if buff.Type == "DEF_Up" then defMult += buff.Value
		elseif buff.Type == "DEF_Down" then defMult -= buff.Value end
	end

	atkMult = math.max(0.1, atkMult)
	defMult = math.max(0.1, defMult)

	local rawDamage     = ((attacker.ATK * atkMult) * skillMultiplier) + (flatBonus or 0)
	local finalDef      = math.max(0, defender.DEF * defMult)
	local damageReduction = finalDef / (finalDef + 120)
	local finalDamage   = math.floor(rawDamage * (1 - damageReduction))
	
	return math.max(1, finalDamage)
end

function CombatService:ApplyDamage(battleId, targetUid, damageAmount)
	local battleInst = ActiveBattles[battleId]
	if not battleInst then return false end

	local targetUnit = self:GetUnitByUid(battleInst, targetUid)
	if not targetUnit then return false end

	local absorbed = 0

	if targetUnit.Shield > 0 then
		for i = 1, #targetUnit.ShieldStack do
			local st = targetUnit.ShieldStack[i]
			if st and st.Amount > 0 and damageAmount > 0 then
				if damageAmount <= st.Amount then
					absorbed += damageAmount
					st.Amount -= damageAmount
					damageAmount = 0
				else
					absorbed += st.Amount
					damageAmount -= st.Amount
					st.Amount = 0
				end
			end
		end

		for i = #targetUnit.ShieldStack, 1, -1 do
			if targetUnit.ShieldStack[i].Amount <= 0 then
				table.remove(targetUnit.ShieldStack, i)
			end
		end

		local totalShield = 0
		for _, st in ipairs(targetUnit.ShieldStack) do
			totalShield += st.Amount
		end
		targetUnit.Shield = totalShield
	end

	if damageAmount > 0 then
		targetUnit.HP = math.max(0, targetUnit.HP - damageAmount)
	end
	return true
end

function CombatService:ApplyStackableShield(battleId, targetUid, amount, duration, maxStacks)
	local battleInst = ActiveBattles[battleId]
	if not battleInst then return end
	local target = self:GetUnitByUid(battleInst, targetUid)
	if not target then return end

	maxStacks = maxStacks or 2
	duration = duration or 2

	if #target.ShieldStack >= maxStacks then
		local lowestAmtIdx = 1
		local lowestAmt = math.huge
		for i, st in ipairs(target.ShieldStack) do
			if st.Amount < lowestAmt then
				lowestAmt = st.Amount
				lowestAmtIdx = i
			end
		end
		target.ShieldStack[lowestAmtIdx] = {Amount = amount, Duration = duration}
	else
		table.insert(target.ShieldStack, {Amount = amount, Duration = duration})
	end

	local totalShield = 0
	for _, st in ipairs(target.ShieldStack) do
		totalShield += st.Amount
	end
	target.Shield = totalShield
end

function CombatService:ApplyStackableBuff(battleId, targetUid, buffType, amount, duration, maxStacks)
	local battleInst = ActiveBattles[battleId]
	if not battleInst then return end
	local target = self:GetUnitByUid(battleInst, targetUid)
	if not target then return end

	maxStacks = maxStacks or 2
	duration = duration or 2

	local sameTypeBuffs = {}
	for i, buff in ipairs(target.Buffs) do
		if buff.Type == buffType then
			table.insert(sameTypeBuffs, {index = i, buff = buff})
		end
	end

	if #sameTypeBuffs >= maxStacks then
		local lowestDurIdx = sameTypeBuffs[1].index
		local lowestDur = sameTypeBuffs[1].buff.Duration
		for _, v in ipairs(sameTypeBuffs) do
			if v.buff.Duration < lowestDur then
				lowestDur = v.buff.Duration
				lowestDurIdx = v.index
			end
		end
		
		local oldBuff = target.Buffs[lowestDurIdx]
		if oldBuff.Type == "Speed" then
			local preSpd = target.SPD
			local preAV = target.AV
			target.SPD = math.max(1, target.SPD - oldBuff.Amount)
			target.AV = target.AV * (preSpd / math.max(1, target.SPD))
			BattleLogger.LogSpeedBuff(battleId, target, preSpd, target.SPD, preAV, target.AV)
		end

		target.Buffs[lowestDurIdx] = {Type = buffType, Amount = amount, Duration = duration}
		if buffType == "Speed" then
			local preSpd = target.SPD
			local preAV = target.AV
			target.SPD += amount
			target.AV = target.AV * (preSpd / math.max(1, target.SPD))
			BattleLogger.LogSpeedBuff(battleId, target, preSpd, target.SPD, preAV, target.AV)
		end
	else
		table.insert(target.Buffs, {Type = buffType, Amount = amount, Duration = duration})
		if buffType == "Speed" then
			local preSpd = target.SPD
			local preAV = target.AV
			target.SPD += amount
			target.AV = target.AV * (preSpd / math.max(1, target.SPD))
			BattleLogger.LogSpeedBuff(battleId, target, preSpd, target.SPD, preAV, target.AV)
		end
	end
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
	if not battleInst or unit.HP <= 0 then return false end

	-- Decrement CDs
	if unit.CDs then
		for skillId, cd in pairs(unit.CDs) do
			if cd - 1 <= 0 then
				unit.CDs[skillId] = nil
			else
				unit.CDs[skillId] = cd - 1
			end
		end
	end

	local speedChanged = false
	local isStunned = false

	for i = #unit.Buffs, 1, -1 do
		local buff = unit.Buffs[i]

		if buff.Type == "Burn" then
			-- Burn: Damage based on attacker's ATK snapshot * buff.Value
			local dmg = math.floor((buff.SourceATK or 0) * (buff.Value or 0.50))
			dmg = math.max(1, dmg)
			self:ApplyDamage(battleId, unit.Uid, dmg)
			BattleLogger.LogActionResult(battleId, unit, unit, "Damage", dmg, "Burn Tick")
			TurnUpdateEvent:FireClient(battleInst.Player, "AttackVisual", unit.Uid, unit.Uid, dmg, unit.HP, unit.MaxHP, unit.Shield, "VFX_Burn_Tick")
			task.wait(0.5)
		elseif buff.Type == "Poison" then
			-- Poison: Damage based on target's current HP * buff.Value
			local dmg = math.floor(unit.HP * (buff.Value or 0.05))
			dmg = math.max(1, dmg)
			self:ApplyDamage(battleId, unit.Uid, dmg)
			BattleLogger.LogActionResult(battleId, unit, unit, "Damage", dmg, "Poison Tick")
			TurnUpdateEvent:FireClient(battleInst.Player, "AttackVisual", unit.Uid, unit.Uid, dmg, unit.HP, unit.MaxHP, unit.Shield, "VFX_Poison_Tick")
			task.wait(0.5)
		elseif buff.Type == "Stun" then
			isStunned = true
		end

		buff.Duration -= 1

		if buff.Duration <= 0 then
			if buff.Type == "Speed" then
				local preSpd = unit.SPD
				local preAV = unit.AV
				unit.SPD = math.max(1, unit.SPD - buff.Amount)
				unit.AV = unit.AV * (preSpd / math.max(1, unit.SPD))
				BattleLogger.LogSpeedBuff(battleId, unit, preSpd, unit.SPD, preAV, unit.AV)
				speedChanged = true
			end
			table.remove(unit.Buffs, i)
		end
	end

	for i = #unit.ShieldStack, 1, -1 do
		unit.ShieldStack[i].Duration -= 1
		if unit.ShieldStack[i].Duration <= 0 then
			table.remove(unit.ShieldStack, i)
		end
	end

	local totalShield = 0
	for _, st in ipairs(unit.ShieldStack) do
		totalShield += st.Amount
	end
	if unit.Shield ~= totalShield then
		unit.Shield = totalShield
		TurnUpdateEvent:FireClient(battleInst.Player, "UpdateHPBar", unit.Uid, nil, nil, unit.HP, unit.MaxHP, unit.Shield)
	end

	if speedChanged then
		local refreshedQueue = self:BuildDisplayQueue(battleInst, unit, 5)
		TurnUpdateEvent:FireClient(battleInst.Player, "RefreshTurnQueue", refreshedQueue)
	end
	
	return isStunned
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

	local isStunned = self:ProcessTurnStartHooks(battleId, currentUnit)

	if currentUnit.HP <= 0 then
		task.delay(1.5, function()
			if not ActiveBattles[battleId] or ActiveBattles[battleId].State ~= "InProgress" then return end
			self:NextTurn(battleId)
		end)
		return
	end

	if isStunned then
		TurnUpdateEvent:FireClient(battleInst.Player, "AttackVisual", currentUnit.Uid, currentUnit.Uid, "STUNNED!", currentUnit.HP, currentUnit.MaxHP, currentUnit.Shield, nil)
		task.delay(1.5, function()
			self:NextTurn(battleId)
		end)
		return
	end

	local displayQueue = self:BuildDisplayQueue(battleInst, currentUnit, 5)
	BattleLogger.LogTurnStart(battleId, currentUnit, displayQueue)
	TurnUpdateEvent:FireClient(battleInst.Player, "UpdateTurnUI", currentUnit.Name, displayQueue)

	if currentUnit.IsPlayer then
		ActionRequestEvent:FireClient(battleInst.Player, {
			BattleId   = battleId,
			ActiveUnit = currentUnit,
			Enemies    = aliveEnemies,
			Allies     = alivePlayers,
			SkillCDs   = currentUnit.CDs
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

	-- STRICT COOLDOWN BLOCKER
	if actionType == "Skill" then
		local usedSkillId = currentUnit.SkillId or "Basic_Attack"
		if currentUnit.CDs[usedSkillId] and currentUnit.CDs[usedSkillId] > 0 then
			warn("[CombatService] Blocked CD spam: " .. player.Name .. " tried " .. usedSkillId .. " (CD: " .. tostring(currentUnit.CDs[usedSkillId]) .. ")")
			return false
		end
	end

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
		-- Chance calculation for effect
		local applies = true
		if effect.Chance then
			applies = (math.random(1, 100) <= effect.Chance)
		end

		if applies then
			if effect.Type == "Damage" then
				local dmg = self:CalculateDamage(attacker, target, effect.Multiplier or 1.0, effect.FlatBonus)
				self:ApplyDamage(battleId, target.Uid, dmg)
				totalDamage += dmg
				BattleLogger.LogActionResult(battleId, attacker, target, "Damage", dmg)

			elseif effect.Type == "Heal" then
				local heal = effect.FlatValue or 0
				if effect.MaxHPPct then
					heal += math.floor(attacker.MaxHP * effect.MaxHPPct)
				elseif effect.MissingHPPct then
					heal += math.floor((target.MaxHP - target.HP) * effect.MissingHPPct)
				end
				if heal == 0 and effect.Multiplier then
					heal = math.floor(attacker.MaxHP * effect.Multiplier)
				end
				target.HP = math.min(target.MaxHP, target.HP + heal)
				totalHeal += heal
				BattleLogger.LogActionResult(battleId, attacker, target, "Heal", heal)

			elseif effect.Type == "Shield" then
				local shield = effect.FlatValue or 0
				if effect.MaxHPPct then
					shield += math.floor(attacker.MaxHP * effect.MaxHPPct)
				elseif effect.ShieldPct then
					shield += math.floor(target.MaxHP * effect.ShieldPct)
				end
				if shield == 0 and effect.Multiplier then
					shield = math.floor(attacker.DEF * effect.Multiplier)
				end
				self:ApplyStackableShield(battleId, target.Uid, shield, effect.Duration, effect.MaxStacks)
				totalShield += shield
				BattleLogger.LogActionResult(battleId, attacker, target, "Shield", shield)

			elseif effect.Type == "Buff" then
				local buffAmt = effect.Amount
				-- Support SPDPct: dynamically compute buff amount from target's current SPD
				if effect.SPDPct and not buffAmt then
					buffAmt = math.floor((target.BaseSPD or target.SPD) * effect.SPDPct)
				end
				self:ApplyStackableBuff(battleId, target.Uid, effect.BuffType, buffAmt, effect.Duration, effect.MaxStacks)
				table.insert(appliedTags, "+" .. tostring(buffAmt) .. " " .. effect.BuffType)
				BattleLogger.LogActionResult(battleId, attacker, target, "Buff", 0, "+" .. tostring(buffAmt) .. " " .. effect.BuffType)

			elseif effect.Type == "Delay" then
				-- Delay: Push target further back in the AV queue by a percentage of their base AV
				local delayAmount = (10000 / math.max(1, target.SPD)) * (effect.Amount or 0)
				target.AV = target.AV + delayAmount
				table.insert(appliedTags, "DELAYED")
				BattleLogger.LogActionResult(battleId, attacker, target, "Buff", 0, "Delayed AV +" .. string.format("%.0f", delayAmount))
				-- Refresh turn queue visually since AV changed
				local currentActor = self:GetUnitByUid(battleInst, battleInst.CurrentActorUid)
				if currentActor then
					local refreshedQueue = self:BuildDisplayQueue(battleInst, currentActor, 5)
					TurnUpdateEvent:FireClient(battleInst.Player, "RefreshTurnQueue", refreshedQueue)
				end

			elseif effect.Type == "HPCost" then
				-- HPCost: Subtract HP from the ATTACKER (self-damage)
				local cost = effect.FlatValue or 0
				if effect.MaxHPPct then
					cost += math.floor(attacker.MaxHP * effect.MaxHPPct)
				end
				attacker.HP = math.max(1, attacker.HP - cost)
				BattleLogger.LogActionResult(battleId, attacker, attacker, "Damage", cost, "HP Cost")
				-- Immediately update attacker's HP bar on the client
				TurnUpdateEvent:FireClient(battleInst.Player, "AttackVisual", attacker.Uid, attacker.Uid, cost, attacker.HP, attacker.MaxHP, attacker.Shield, "VFX_HPCost")
				task.wait(0.5)

			elseif effect.Type == "ApplyStatus" then
				local statusType = effect.Status
				local isHardCC = (statusType == "Stun" or statusType == "Freeze")

				-- Boss Immunity: Hard CC cannot be applied to bosses
				if isHardCC and target.IsBoss then
					table.insert(appliedTags, statusType .. " RESISTED")
					BattleLogger.LogActionResult(battleId, attacker, target, "Buff", 0, statusType .. " RESISTED (Boss)")
				else
					-- For Burn, inject SourceATK so DoT ticks scale off the attacker
					local buffEntry = {
						Type = statusType,
						Value = effect.Value or 0,
						Duration = effect.Duration,
					}
					if statusType == "Burn" then
						buffEntry.SourceATK = attacker.ATK
					end

					-- Stack management
					local maxStacks = effect.MaxStacks or 1
					local sameTypeCount = 0
					for _, b in ipairs(target.Buffs) do
						if b.Type == statusType then sameTypeCount += 1 end
					end

					if sameTypeCount < maxStacks then
						table.insert(target.Buffs, buffEntry)
					end

					table.insert(appliedTags, "+" .. string.upper(statusType))
					BattleLogger.LogActionResult(battleId, attacker, target, "Buff", 0, statusType .. " Applied")
				end
			end
		else
			-- Effect missed due to Chance roll
			if effect.Type == "ApplyStatus" then
				BattleLogger.LogActionResult(battleId, attacker, target, "Buff", 0, (effect.Status or "Status") .. " MISSED")
			end
		end
	end

	local displayValue = 0
	if totalDamage > 0 then displayValue = totalDamage 
	elseif totalHeal > 0 then displayValue = -totalHeal
	else
		local customTexts = {}
		if totalShield > 0 then table.insert(customTexts, "+" .. totalShield .. " Shield") end
		if #appliedTags > 0 then table.insert(customTexts, table.concat(appliedTags, "\n")) end
		if #customTexts > 0 then displayValue = table.concat(customTexts, "\n") end
	end

	TurnUpdateEvent:FireClient(battleInst.Player, "AttackVisual", attacker.Uid, target.Uid, displayValue, target.HP, target.MaxHP, target.Shield, visualTag)

	-- Death visual: notify client to remove corpse
	if target.HP <= 0 then
		task.delay(0.5, function()
			if battleInst and battleInst.Player then
				TurnUpdateEvent:FireClient(battleInst.Player, "DeathVisual", target.Uid)
			end
		end)
	end

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

	BattleLogger.LogActionDecision(battleId, attacker, actionType, usedSkillId, skillInfo)

	local oldEnergy = attacker.Energy or 0
	if actionType == "Ultimate" then
		attacker.Energy = 0
	elseif attacker.Tier and attacker.Tier >= 5 and attacker.Energy < attacker.MaxEnergy then
		attacker.Energy = math.min(attacker.MaxEnergy, attacker.Energy + (skillInfo.EnergyGain or 1))
	end
	BattleLogger.LogEnergyChange(battleId, attacker, oldEnergy, attacker.Energy or 0)

	-- Apply Cooldown internally if any
	if skillInfo.BaseCooldown and actionType == "Skill" then
		attacker.CDs[usedSkillId] = skillInfo.BaseCooldown
	end

	local actualTargets = {}

	if skillInfo.TargetType == "AllEnemies" then
		actualTargets = attacker.IsPlayer and self:GetAliveEnemies(battleInst) or self:GetAlivePlayers(battleInst)
	elseif skillInfo.TargetType == "AllAllies" then
		actualTargets = attacker.IsPlayer and self:GetAlivePlayers(battleInst) or self:GetAliveEnemies(battleInst)
	elseif skillInfo.TargetType == "AllAlliesExcludeSelf" then
		local allies = attacker.IsPlayer and self:GetAlivePlayers(battleInst) or self:GetAliveEnemies(battleInst)
		for _, ally in ipairs(allies) do
			if ally.Uid ~= attacker.Uid then
				table.insert(actualTargets, ally)
			end
		end
	elseif skillInfo.TargetType == "LowestAlly" then
		local target = attacker.IsPlayer and self:GetLowestHPAlly(battleInst) or nil
		if target then table.insert(actualTargets, target) end
	elseif skillInfo.TargetType == "LowestSpeedAlly" then
		local target = attacker.IsPlayer and self:GetLowestSpeedAlly(battleInst) or nil
		if target then table.insert(actualTargets, target) end
	elseif skillInfo.TargetType == "Self" then
		table.insert(actualTargets, attacker)
	else
		local singleTarget = self:GetUnitByUid(battleInst, targetUid)
		if singleTarget then table.insert(actualTargets, singleTarget) end
	end

	if #actualTargets == 0 then
		self:NextTurn(battleId)
		return
	end

	local specialModule = ReplicatedStorage.Shared:FindFirstChild("SpecialSkill")
	if specialModule then
		local skillScript = specialModule:FindFirstChild(usedSkillId)
		if skillScript then
			local executor = require(skillScript)
			
			local success, err = pcall(function()
				executor.Execute(self, battleId, attacker, actualTargets, skillInfo)
			end)
			
			if not success then
				warn("⚠️ [CombatService] Error executing SpecialSkill '" .. usedSkillId .. "':\n" .. tostring(err))
			end
			
			task.delay(2.5, function()
				if not ActiveBattles[battleId] or ActiveBattles[battleId].State ~= "InProgress" then return end
				self:NextTurn(battleId)
			end)
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
		local target = EnemyAIHandler.GetTarget(alivePlayers)
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

	battleInst.Player:SetAttribute("InCombat", false)
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

	-- =============================================
	-- ARENA SPACING: 18 studs Z gap between teams
	-- =============================================

	-- Enemy formation: center at Z=-18, flanks at Z=-20, X spread 7 studs
	local enemyFormation = {
		CFrame.new(0,  0, -18),
		CFrame.new(-7, 0, -20),
		CFrame.new(7,  0, -20),
	}

	local enemyUnits = self:GetAliveEnemies(battleInst)
	local enemyPositions = {}

	for i, eUnit in ipairs(enemyUnits) do
		local offset = enemyFormation[i] or CFrame.new((i - 2) * 7, 0, -18)
		local spawnCFrame = rootPart.CFrame * offset
		local model

		if i == 1 and npcModel and npcModel.PrimaryPart then
			model = npcModel
		elseif npcModel then
			local origArch = npcModel.Archivable
			npcModel.Archivable = true
			model = npcModel:Clone()
			npcModel.Archivable = origArch
		end

		if model then
			local npcHum = model:FindFirstChildOfClass("Humanoid")
			if npcHum then npcHum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None end
			model.Name = eUnit.Uid
			model:PivotTo(CFrame.lookAt(spawnCFrame.Position, rootPart.Position))
			model.Parent = arenaFolder
			eUnit.Model3D = model
			table.insert(enemyPositions, spawnCFrame.Position)

			local hum = model:FindFirstChildOfClass("Humanoid")
			local idleAnim = model:FindFirstChild("IdleAnim", true)
			if hum and idleAnim then
				local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
				local track = animator:LoadAnimation(idleAnim)
				track.Looped = true
				track:Play()
			end
		end
	end

	-- Compute actual enemy centroid
	local enemyCenterPos = Vector3.new(0, 0, 0)
	for _, pos in ipairs(enemyPositions) do
		enemyCenterPos = enemyCenterPos + pos
	end
	enemyCenterPos = enemyCenterPos / math.max(1, #enemyPositions)

	-- Player formation: behind the player root, 8 studs X spread
	local playerUnits = self:GetAlivePlayers(battleInst)
	local formationOffsets = {
		Vector3.new(-4, 0, 3),
		Vector3.new(4,  0, 3),
		Vector3.new(-8, 0, 5),
		Vector3.new(8,  0, 5)
	}
	local playerPositions = {}

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

			local spawnPos = rootPart.CFrame * CFrame.new(formationOffsets[i] or Vector3.new(0, 0, 3))
			clone3D:PivotTo(CFrame.lookAt(spawnPos.Position, enemyCenterPos))
			clone3D.Parent = arenaFolder
			pUnit.Model3D  = clone3D
			table.insert(playerPositions, spawnPos.Position)

			local idleAnim = clone3D:FindFirstChild("IdleAnim", true)
			if hum and idleAnim then
				local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
				local track    = animator:LoadAnimation(idleAnim)
				track.Looped   = true
				track:Play()
			end
		end
	end

	-- Compute actual player centroid
	local playerCenterPos = Vector3.new(0, 0, 0)
	for _, pos in ipairs(playerPositions) do
		playerCenterPos = playerCenterPos + pos
	end
	playerCenterPos = playerCenterPos / math.max(1, #playerPositions)

	BattleStartEvent:FireClient(battleInst.Player, {
		Id             = battleId,
		Units          = battleInst.Units,
		PlayerCenter   = playerCenterPos,
		EnemyCenter    = enemyCenterPos
	})
end

return CombatService