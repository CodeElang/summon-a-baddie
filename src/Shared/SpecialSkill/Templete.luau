local SpecialSkill = {}

function SpecialSkill.Execute(CombatService, battleId, attacker, target, skillInfo)
	attacker.AV = 0

	if not skillInfo.Effects then
		skillInfo.Effects = {}
	end

	CombatService:ProcessEffects(battleId, attacker, target, skillInfo.Effects, skillInfo.VisualTag)
end

return SpecialSkill