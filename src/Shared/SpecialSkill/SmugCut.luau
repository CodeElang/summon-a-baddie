local SpecialSkill = {}

function SpecialSkill.Execute(CombatService, battleId, attacker, actualTargets, skillInfo)
	
	local target = actualTargets[1]
	if not target then return end

	-- Custom Damage: Basic ATK + 5% of Target's Max HP
	local maxHpBonus = math.floor(target.MaxHP * 0.05)

	local effects = {
		{ Type = "Damage", Multiplier = 1.0, FlatBonus = maxHpBonus }
	}

	CombatService:ProcessEffects(battleId, attacker, target, effects, "Anim_Melee_Hit")
end

return SpecialSkill
