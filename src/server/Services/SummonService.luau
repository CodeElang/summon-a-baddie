local SummonService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataService = require(script.Parent.DataService)
local RNG = require(ReplicatedStorage.Shared.Utils.RNG)
local BaddieClass = require(ReplicatedStorage.Shared.Classes.Baddie)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

local NetworkFolder = ReplicatedStorage.Network
local SummonEvent = NetworkFolder:WaitForChild("RequestSummon")
local GetOwnedBooksEvent = NetworkFolder:WaitForChild("GetOwnedBooks")

function SummonService:Init() end

function SummonService:Start()
	GetOwnedBooksEvent.OnServerInvoke = function(player)
		local profile = DataService:GetProfile(player)
		if not profile then return {} end
		return profile.Data.Books
	end

	SummonEvent.OnServerInvoke = function(player, selectedBookName)
		local profile = DataService:GetProfile(player)
		if not profile then return false, "Data error!" end
		if not selectedBookName or selectedBookName == "" then return false, "Pilih buku dulu!" end

		-- Validasi Buku
		local bookConfig = nil
		for _, b in ipairs(GameConfig.Books) do
			if b.Name == selectedBookName then bookConfig = b break end
		end

		if not bookConfig then return false, "Buku Invalid" end
		if (profile.Data.Books[selectedBookName] or 0) <= 0 then return false, "NO BOOK" end

		profile.Data.Books[selectedBookName] -= 1

		-- ==============================================
		-- 🧮 KALKULASI LUCK (MULTIPLICATIVE STACKING)
		-- ==============================================
		local adminLuck = profile.Data.LuckBoost or 1
		local currentLuckLvl = profile.Data.Upgrades.LuckLevel or 0

		-- 1. Upgrade Shop Luck (Dihitung dari persentase GameConfig)
		local upgradeLuckBonus = 1.0
		if currentLuckLvl > 0 and GameConfig.Upgrades.Luck.Tiers[currentLuckLvl] then
			upgradeLuckBonus = 1.0 + (GameConfig.Upgrades.Luck.Tiers[currentLuckLvl].BonusPercent / 100)
		end

		-- 2. Potion Luck (Validasi waktu aktif)
		local potionLuckBonus = 1.0
		if profile.Data.ActiveBuffs and os.time() < (profile.Data.ActiveBuffs.LuckEndsAt or 0) then
			potionLuckBonus = profile.Data.ActiveBuffs.LuckMultiplier or 1.0
		end

		-- 3. Pet Luck (Sistem Tambah-Tambahan antar Pet)
		local petLuckSum = 0
		if profile.Data.EquippedPets then
			for _, petId in ipairs(profile.Data.EquippedPets) do
				-- TODO: Sambungkan ke module Pet System kamu nanti
				-- local petData = GetPetData(petId)
				-- if petData then petLuckSum += petData.LuckBoost end
			end
		end

		local totalPetLuckBonus = 1.0 + petLuckSum

		-- 🚀 RUMUS FINAL LUCK (Perkalian Total)
		local externalLuckMultiplier = adminLuck * upgradeLuckBonus * potionLuckBonus * totalPetLuckBonus
		local finalLuckToRoll = bookConfig.LuckBuff * externalLuckMultiplier
		-- ==============================================

		-- Eksekusi Roll Baddie (tanpa tierBoost karena sudah dihapus dari config)
		local rolledBaddieName, rolledRarity = RNG.RollBaddie(finalLuckToRoll, {})

		local baddieConfigData = GameConfig.GetBaddieData(rolledBaddieName)
		local rolledChance = baddieConfigData and baddieConfigData.Chance or 1

		local uniqueId = "Baddie_" .. os.time() .. "_" .. math.random(1000, 9999)
		local newBaddie = BaddieClass.new(uniqueId, rolledBaddieName, rolledRarity)

		table.insert(profile.Data.Baddies, newBaddie)

		if not profile.Data.CombatHotbar then
			profile.Data.CombatHotbar = {Slot1="", Slot2="", Slot3="", Slot4="", Slot5="", Slot6="", Slot7="", Slot8=""}
		end

		-- 🔥 Auto-Equip ke Hotbar jika ada slot kosong
		local validBaddies = {}
		for _, b in ipairs(profile.Data.Baddies) do validBaddies[b.Id] = true end

		for i = 1, 8 do
			local slotKey = "Slot" .. tostring(i)
			local currentId = profile.Data.CombatHotbar[slotKey]

			if currentId == "" or currentId == nil or not validBaddies[currentId] then
				profile.Data.CombatHotbar[slotKey] = uniqueId
				break 
			end
		end

		return true, {Name = rolledBaddieName, Rarity = rolledRarity, Chance = rolledChance}, profile.Data.Books[selectedBookName]
	end
end

return SummonService