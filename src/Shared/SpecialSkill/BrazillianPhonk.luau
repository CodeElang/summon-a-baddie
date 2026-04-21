local SpecialSkill = {}

function SpecialSkill.Execute(CombatService, battleId, attacker, actualTargets, skillInfo)

	for _, target in ipairs(actualTargets) do
		local speedBuff = math.floor(target.SPD * 0.20)

		local effects = {
			{ Type = "Buff", BuffType = "Speed", Amount = speedBuff, Duration = 3, MaxStacks = 2 }
		}
		
		CombatService:ProcessEffects(battleId, attacker, target, effects, "VFX_Speed_Buff")
	end
end

return SpecialSkill
