-- BattleLogger.lua
-- Letakkan di: ServerScriptService/Modules/BattleLogger
-- Cara pakai di CombatService:
--   local BattleLogger = require(script.Parent.BattleLogger)
--   Panggil fungsi logger di titik-titik yang relevan (lihat komentar di bawah)

local BattleLogger = {}

local logs = {} -- [battleId] = { lines = {}, turnCount = 0 }

local DIVIDER      = string.rep("=", 60)
local DIVIDER_THIN = string.rep("-", 60)

-- ============================================================
-- INTERNAL HELPERS
-- ============================================================

local function pad(str, width)
	str = tostring(str)
	return str .. string.rep(" ", math.max(0, width - #str))
end

local function log(battleId, line)
	if not logs[battleId] then return end
	table.insert(logs[battleId].lines, line)
end

local function formatStat(label, value)
	return string.format("  %-16s: %s", label, tostring(value))
end

local function formatHP(hp, maxHp, shield)
	local bar = ""
	local pct = math.clamp(hp / math.max(1, maxHp), 0, 1)
	local filled = math.floor(pct * 20)
	bar = "[" .. string.rep("|", filled) .. string.rep(".", 20 - filled) .. "]"

	local shieldStr = shield and shield > 0 and ("  🛡 " .. tostring(shield)) or ""
	return string.format("%s %d/%d%s", bar, math.floor(hp), maxHp, shieldStr)
end

-- ============================================================
-- PUBLIC API
-- ============================================================

-- Panggil di: CombatService:InitiateBattle() setelah battleInst dibuat
function BattleLogger.StartBattle(battleId, units)
	logs[battleId] = { lines = {}, turnCount = 0 }

	log(battleId, DIVIDER)
	log(battleId, string.format("  BATTLE START  |  ID: %s", string.sub(battleId, 1, 8) .. "..."))
	log(battleId, DIVIDER)

	log(battleId, "\n📋 UNIT ROSTER")
	log(battleId, DIVIDER_THIN)

	for _, u in ipairs(units) do
		local side = u.IsPlayer and "[ ALLY ]" or "[ ENEMY ]"
		log(battleId, string.format("\n%s  %s  (Uid: %s)", side, u.Name, u.Uid))
		log(battleId, formatStat("HP",      string.format("%d  (MaxHP: %d)", u.HP, u.MaxHP)))
		log(battleId, formatStat("ATK",     u.ATK))
		log(battleId, formatStat("DEF",     u.DEF))
		log(battleId, formatStat("SPD",     u.SPD))
		log(battleId, formatStat("AV Init", string.format("%.2f  (10000 / %d)", 10000 / math.max(1, u.SPD), u.SPD)))
		if u.IsPlayer then
			log(battleId, formatStat("Tier",    u.Tier or "?"))
			log(battleId, formatStat("Role",    u.Role or "?"))
			log(battleId, formatStat("Energy",  string.format("%d / %d", u.Energy or 0, u.MaxEnergy or 3)))
			log(battleId, formatStat("Skill",   u.SkillId or "none"))
			log(battleId, formatStat("Ultimate",u.UltId or "none"))
		end
		if u.AI then
			log(battleId, formatStat("AI Type", u.AI))
		end
	end

	log(battleId, "\n" .. DIVIDER_THIN)
	log(battleId, string.format("  Total units: %d", #units))
	log(battleId, DIVIDER)
end

-- Panggil di: CombatService:ProcessNextTurn() setelah currentUnit ditentukan
function BattleLogger.LogTurnStart(battleId, currentUnit, displayQueue)
	if not logs[battleId] then return end
	logs[battleId].turnCount += 1
	local turn = logs[battleId].turnCount

	log(battleId, string.format("\n\n⚡ TURN %d  |  %s (%s)",
		turn,
		currentUnit.Name,
		currentUnit.IsPlayer and "ALLY" or "ENEMY"
		))
	log(battleId, DIVIDER_THIN)
	log(battleId, formatStat("SPD",    currentUnit.SPD))
	log(battleId, formatStat("HP",     formatHP(currentUnit.HP, currentUnit.MaxHP, currentUnit.Shield)))
	if currentUnit.IsPlayer then
		log(battleId, formatStat("Energy", string.format("%d / %d", currentUnit.Energy or 0, currentUnit.MaxEnergy or 3)))
	end

	-- Cetak prediksi urutan turn
	if displayQueue and #displayQueue > 0 then
		log(battleId, "\n  📊 Turn Order Preview:")
		for i, entry in ipairs(displayQueue) do
			local marker = i == 1 and " ◀ NOW" or ""
			local side = entry.IsPlayer and "ally" or "enemy"
			log(battleId, string.format("    [%d] %-28s (spd: %d) %s",
				i, entry.Name .. " [" .. side .. "]", entry.Speed or 0, marker
				))
		end
	end
end

-- Panggil di: CombatService:ExecuteAction() setelah skillInfo didapat
function BattleLogger.LogActionDecision(battleId, attacker, actionType, skillId, skillInfo)
	if not logs[battleId] then return end

	log(battleId, string.format("\n  🎯 ACTION: %s", string.upper(actionType)))
	log(battleId, formatStat("Skill ID",   skillId or "none"))
	log(battleId, formatStat("Skill Type", skillInfo and skillInfo.Type or "?"))
	if skillInfo then
		if skillInfo.Multiplier then
			log(battleId, formatStat("Multiplier", skillInfo.Multiplier))
		end
		if skillInfo.EnergyGain then
			log(battleId, formatStat("Energy Gain", skillInfo.EnergyGain))
		end
		if skillInfo.Target then
			log(battleId, formatStat("Target Rule", skillInfo.Target))
		end
		if skillInfo.BuffType then
			log(battleId, formatStat("Buff Type",   skillInfo.BuffType))
			log(battleId, formatStat("Buff Amount", skillInfo.Amount or "?"))
		end
	end
end

-- Panggil di: CombatService:ExecuteAction() setelah actualTarget ditentukan dan aksi dieksekusi
-- damageOrHeal: angka positif = damage, negatif = heal, 0 = shield/buff
-- extraInfo: string tambahan opsional
function BattleLogger.LogActionResult(battleId, attacker, target, actionType, damageOrHeal, extraInfo)
	if not logs[battleId] then return end

	local resultLine = ""

	if actionType == "Damage" then
		local shieldAbsorbed = 0
		-- extraInfo bisa diisi shield yang diserap jika ada
		resultLine = string.format("  💥 %s → %s | Damage: %d",
			attacker.Name, target.Name, damageOrHeal
		)
		if extraInfo then resultLine = resultLine .. "  (" .. extraInfo .. ")" end

	elseif actionType == "Heal" then
		resultLine = string.format("  💚 %s → %s | Heal: +%d",
			attacker.Name, target.Name, math.abs(damageOrHeal)
		)

	elseif actionType == "Shield" then
		resultLine = string.format("  🛡  %s → %s | Shield Added: +%d",
			attacker.Name, target.Name, damageOrHeal
		)

	elseif actionType == "Buff" then
		resultLine = string.format("  ⬆  %s → %s | Buff Applied: %s",
			attacker.Name, target.Name, extraInfo or "?"
		)
	else
		resultLine = string.format("  ❓ %s → %s | %s",
			attacker.Name, target.Name, extraInfo or actionType
		)
	end

	log(battleId, resultLine)

	-- State target setelah aksi
	log(battleId, string.format("  └─ %s after: %s",
		target.Name,
		formatHP(target.HP, target.MaxHP, target.Shield)
		))
end

-- Panggil di: CombatService:ExecuteAction() setelah energy diupdate
function BattleLogger.LogEnergyChange(battleId, unit, oldEnergy, newEnergy)
	if not logs[battleId] then return end
	if oldEnergy == newEnergy then return end

	log(battleId, string.format("  ⚡ Energy: %s  %d → %d / %d",
		unit.Name, oldEnergy, newEnergy, unit.MaxEnergy or 3
		))
end

-- Panggil di: CombatService setelah speed buff diterapkan
function BattleLogger.LogSpeedBuff(battleId, target, oldSpd, newSpd, oldAV, newAV)
	if not logs[battleId] then return end

	log(battleId, string.format("  🏃 Speed Buff on %s:", target.Name))
	log(battleId, string.format("     SPD: %d → %d", oldSpd, newSpd))
	log(battleId, string.format("     AV:  %.3f → %.3f  (lower = acts sooner)", oldAV, newAV))
end

-- Panggil di: CombatService:ApplyDamage() (opsional, untuk detail shield absorption)
function BattleLogger.LogShieldAbsorb(battleId, targetName, shieldBefore, absorbed, shieldAfter)
	if not logs[battleId] then return end
	if absorbed <= 0 then return end

	log(battleId, string.format("  🛡  Shield absorbed %d damage on %s  (shield: %d → %d)",
		absorbed, targetName, shieldBefore, shieldAfter
		))
end

-- Panggil di: CombatService:EndBattle()
function BattleLogger.EndBattle(battleId, result, units)
	if not logs[battleId] then return end

	log(battleId, "\n\n" .. DIVIDER)
	log(battleId, string.format("  BATTLE END  |  Result: %s  |  Total Turns: %d",
		string.upper(result),
		logs[battleId].turnCount
		))
	log(battleId, DIVIDER)

	if units then
		log(battleId, "\n📋 FINAL UNIT STATES")
		log(battleId, DIVIDER_THIN)
		for _, u in ipairs(units) do
			local status = u.HP > 0 and "ALIVE" or "DEFEATED"
			log(battleId, string.format("\n  %s  [%s]", u.Name, status))
			log(battleId, string.format("  └─ %s", formatHP(u.HP, u.MaxHP, u.Shield)))
			if u.IsPlayer then
				log(battleId, formatStat("Final Energy", string.format("%d / %d", u.Energy or 0, u.MaxEnergy or 3)))
				log(battleId, formatStat("Final SPD",    u.SPD))
			end
		end
	end

	log(battleId, "\n" .. DIVIDER)

	-- Print semua log sekaligus ke Output Roblox
	BattleLogger.PrintBattleLog(battleId)

	-- Cleanup memori
	logs[battleId] = nil
end

-- Print manual (jika ingin print di tengah battle untuk debug)
function BattleLogger.PrintBattleLog(battleId)
	if not logs[battleId] then
		print("[BattleLogger] No log found for battleId: " .. tostring(battleId))
		return
	end

	print("\n" .. table.concat(logs[battleId].lines, "\n"))
end

-- Cek apakah logger aktif untuk battle ini
function BattleLogger.IsActive(battleId)
	return logs[battleId] ~= nil
end

return BattleLogger