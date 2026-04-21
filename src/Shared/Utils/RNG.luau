local RNG = {}
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Randomizer = Random.new()


function RNG.RollBaddie(luckMultiplier, tierBoosts)
	luckMultiplier = luckMultiplier or 1
	tierBoosts = tierBoosts or {}


	-- Default fallback jika sangat sial
	local wonBaddieName = "Goblin Baddie"
	local wonRarity = "Common"


	-- Iterasi HARUS MUNDUR (dari Rarity tertinggi ke terendah) 
	-- agar item Common yang punya Chance kecil tidak selalu terpilih saat Luck tinggi.
	for i = #GameConfig.BaddiesData, 1, -1 do
		local baddie = GameConfig.BaddiesData[i]
		-- Menggunakan presisi floating point (NextNumber) agar bisa memproses
		-- Chance raksasa (Triliunan) dari GameConfig auto-calculator kita dengan akurat.
		local roll = Randomizer:NextNumber(0, baddie.Chance)


		local specificRarityBoost = tierBoosts[baddie.Rarity] or 1
		local finalCalculatedLuck = luckMultiplier * specificRarityBoost


		-- Jika beruntung masuk ke dalam zona Luck
		if roll <= finalCalculatedLuck then
			wonBaddieName = baddie.Name
			wonRarity = baddie.Rarity
			break 
		end
	end

	return wonBaddieName, wonRarity

end

return RNG