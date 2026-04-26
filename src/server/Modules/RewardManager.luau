local RewardManager = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

-- Mock Books Data if it doesn't exist in GameConfig yet
local FallbackBooks = {
	Common = { "Novice XP Book", "Basic Grimoire" },
	Rare = { "Adept XP Book", "Rare Grimoire" },
	Superior = { "Expert XP Book", "Superior Grimoire" },
	Epic = { "Master XP Book", "Epic Grimoire" },
	Legendary = { "Grandmaster XP Book", "Legendary Grimoire" },
	Mythic = { "Mythical Tome", "Forbidden Grimoire" }
}

-- Utility function to map a numeric Tier to a Rarity string
local function GetRarityFromTier(tier)
	if tier <= 1 then return "Common"
	elseif tier <= 2 then return "Rare"
	elseif tier <= 3 then return "Superior"
	elseif tier <= 4 then return "Epic"
	elseif tier <= 5 then return "Legendary"
	else return "Mythic" end
end

-- Core Function: Called by CombatService:EndBattle() on Victory
function RewardManager:DistributeVictoryRewards(player, defeatedEnemies)
	if not player or not defeatedEnemies or #defeatedEnemies == 0 then return end

	local totalCoins = 0
	local highestTier = 1

	-- Mocked Multipliers (To be replaced with actual Player Save Data fetching later)
	local playerRebirthMultiplier = 1.0
	local playerUpgradeMultiplier = 0.0
	local totalMultiplier = (playerRebirthMultiplier + playerUpgradeMultiplier)

	-- Base value per enemy
	local baseCoinValue = 50 

	-- 1. SCALABLE COIN CALCULATION
	for _, enemy in ipairs(defeatedEnemies) do
		local enemyTier = enemy.Tier or 1
		
		-- Track highest tier for Loot Drops
		if enemyTier > highestTier then
			highestTier = enemyTier
		end

		local tierScale = GameConfig.CombatSettings and GameConfig.CombatSettings.TierScale[enemyTier] or 1
		local enemyCoins = baseCoinValue * tierScale * totalMultiplier
		
		totalCoins += enemyCoins
	end

	totalCoins = math.floor(totalCoins)

	-- 2. TIER-BASED LOOT TABLE (Books)
	local bookDropped = nil
	local dropChance = 0.60 -- 60% chance to drop a book

	if math.random() <= dropChance then
		local targetRarity = GetRarityFromTier(highestTier)
		local possibleBooks = GameConfig.Books and GameConfig.Books[targetRarity] or FallbackBooks[targetRarity]
		
		if possibleBooks and #possibleBooks > 0 then
			bookDropped = possibleBooks[math.random(1, #possibleBooks)]
		end
	end

	-- 3. LOGGING / PROOF OF CONCEPT
	print("\n========================================")
	print("🏆 BATTLE VICTORY REWARDS FOR: " .. player.Name)
	print("💰 Coins Earned: " .. totalCoins .. " (Max Tier Scaled: " .. highestTier .. ")")
	if bookDropped then
		print("📖 Loot Drop: [" .. bookDropped .. "]")
	else
		print("📖 Loot Drop: None (Unlucky RNG!)")
	end
	print("========================================\n")

	-- TODO: Wire up to InventoryService / LeaderstatsService
end

return RewardManager
