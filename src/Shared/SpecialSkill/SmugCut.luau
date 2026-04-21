local SpecialSkill = {}

function SpecialSkill.Execute(CombatService, battleId, attacker, actualTargets, skillInfo)
	
	local target = actualTargets[1]
	if not target then return end

	-- Custom Damage: Basic ATK + 5% of Target's Max HP
	local maxHpBonus = math.floor(target.MaxHP * 0.05)
	local finalMultiplier = 1.0 + (maxHpBonus / math.max(1, attacker.ATK)) -- Dynamically inject the extra damage into the multiplier

	local effects = {
		{ Type = "Damage", Multiplier = finalMultiplier }
	}

	CombatService:ProcessEffects(battleId, attacker, target, effects, "Anim_Melee_Hit")
end

return SpecialSkill
