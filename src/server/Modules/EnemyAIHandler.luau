local EnemyAIHandler = {}

-- Base Aggro Weights by Archetype
local BaseAggro = {
	Tank = 300,
	DPS = 100,
	Control = 100,
	Controller = 100,
	Support = 50
}

function EnemyAIHandler.GetTarget(alivePlayers)
	if #alivePlayers == 0 then return nil end

	-- 1. TAUNT CHECK (Absolute Priority)
	local tauntedPlayers = {}
	for _, player in ipairs(alivePlayers) do
		for _, buff in ipairs(player.Buffs) do
			if buff.Type == "Taunt" then
				table.insert(tauntedPlayers, player)
				break
			end
		end
	end

	-- If anyone has Taunt, they are the ONLY valid targets.
	local poolToRoll = #tauntedPlayers > 0 and tauntedPlayers or alivePlayers

	-- 2. BUILD AGGRO WEIGHTS
	local totalAggro = 0
	local aggroMap = {}
	
	for _, player in ipairs(poolToRoll) do
		local aggroWeight = BaseAggro[player.Role] or 100

		-- Stealth Check (Overrides Base Aggro if no Taunt is active)
		-- If a player has Taunt, we ignore Stealth (Taunt forces them to be hit).
		if #tauntedPlayers == 0 then
			local hasStealth = false
			for _, buff in ipairs(player.Buffs) do
				if buff.Type == "Stealth" then
					hasStealth = true
					break
				end
			end
			
			if hasStealth then
				aggroWeight = 10
			end
		end

		totalAggro += aggroWeight
		table.insert(aggroMap, {Unit = player, Weight = aggroWeight})
	end

	-- 3. WEIGHTED RNG LOTTERY
	local roll = math.random(1, totalAggro)
	for _, data in ipairs(aggroMap) do
		roll -= data.Weight
		if roll <= 0 then
			return data.Unit
		end
	end

	-- Fallback
	return poolToRoll[1]
end

return EnemyAIHandler
