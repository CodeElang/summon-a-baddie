local SpecialSkill = {}

function SpecialSkill.Execute(CombatService, battleId, attacker, actualTargets, skillInfo)
	local battleInst = CombatService.ActiveBattles and CombatService.ActiveBattles[battleId] -- Need a way to get battleInst or player
	-- Wait, ActiveBattles is local to CombatService. 
	-- So we should use ProcessEffects instead!

	local shieldAmount = math.floor(attacker.MaxHP * 0.10)

	for _, target in ipairs(actualTargets) do
		local speedBuff = math.floor(target.SPD * 0.10)

		-- We pass the manual shield as an effect, we just trick the multiplier
		-- Since CombatService uses attacker.DEF * Multiplier, we can reverse math!
		-- Multiplier = shieldAmount / attacker.DEF
		local revMult = 0
		if attacker.DEF > 0 then
			revMult = shieldAmount / attacker.DEF
		else
			-- If DEF is 0, we can't use ProcessEffects for shield. We'll buff speed through it.
		end

		local effects = {
			{ Type = "Shield", Multiplier = revMult, Duration = 2, MaxStacks = 2 },
			{ Type = "Buff", BuffType = "Speed", Amount = speedBuff, Duration = 2, MaxStacks = 2 }
		}

		CombatService:ProcessEffects(battleId, attacker, target, effects, "VFX_Shield_Up")
	end
end

return SpecialSkill
