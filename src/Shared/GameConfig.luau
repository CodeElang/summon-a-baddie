local GameConfig = {}


-- ==========================================
-- 🔄 1. REBIRTH SYSTEM (HARDCODED V1.0 TO V2.0 PREP)
-- ==========================================

GameConfig.Rebirth = {
	[1]  = { Cost = 1_000_000,                CoinMultiplier = 1.5 },
	[2]  = { Cost = 4_500_000,                CoinMultiplier = 2.1 },
	[3]  = { Cost = 20_000_000,               CoinMultiplier = 3.0 },
	[4]  = { Cost = 90_000_000,               CoinMultiplier = 4.4 },
	[5]  = { Cost = 400_000_000,              CoinMultiplier = 6.4 },
	[6]  = { Cost = 1_800_000_000,            CoinMultiplier = 9.3 },
	[7]  = { Cost = 8_000_000_000,            CoinMultiplier = 13.5 },
	[8]  = { Cost = 37_000_000_000,           CoinMultiplier = 19.5 },
	[9]  = { Cost = 165_000_000_000,          CoinMultiplier = 28.3 },
	[10] = { Cost = 750_000_000_000,          CoinMultiplier = 41.0 },  -- END V1.0
	[11] = { Cost = 3_400_000_000_000,        CoinMultiplier = 59.5 },
	[12] = { Cost = 15_000_000_000_000,       CoinMultiplier = 86.2 },
	[13] = { Cost = 68_000_000_000_000,       CoinMultiplier = 125.0 },
	[14] = { Cost = 310_000_000_000_000,      CoinMultiplier = 181.0 },
	[15] = { Cost = 1_400_000_000_000_000,    CoinMultiplier = 262.0 },
	[16] = { Cost = 6_200_000_000_000_000,    CoinMultiplier = 380.0 },
	[17] = { Cost = 28_000_000_000_000_000,   CoinMultiplier = 551.0 },
	[18] = { Cost = 125_000_000_000_000_000,  CoinMultiplier = 800.0 },
	[19] = { Cost = 570_000_000_000_000_000,  CoinMultiplier = 1160.0 },
	[20] = { Cost = 2_500_000_000_000_000_000,CoinMultiplier = 1700.0 }
}

-- ==========================================
--  2. BOOKS DATA 
-- ==========================================

GameConfig.Books = {
	{ Name = "Basic",       Rarity = "Common",       LuckBuff = 1.0,       Price = 300,                     RebirthReq = 0 },
	{ Name = "Worn",        Rarity = "Common",       LuckBuff = 1.5,       Price = 1_000,                   RebirthReq = 0 },
	{ Name = "Sturdy",      Rarity = "Common",       LuckBuff = 2.5,       Price = 3_500,                   RebirthReq = 0 },
	{ Name = "Silver",      Rarity = "Common",       LuckBuff = 4.0,       Price = 10_000,                  RebirthReq = 0 },
	{ Name = "Golden",      Rarity = "Common",       LuckBuff = 6.0,       Price = 35_000,                  RebirthReq = 0 },
	{ Name = "Azure",       Rarity = "Rare",         LuckBuff = 9.0,       Price = 120_000,                 RebirthReq = 1 },
	{ Name = "Crystal",     Rarity = "Superior",     LuckBuff = 13.0,      Price = 400_000,                 RebirthReq = 2 },
	{ Name = "Sapphire",    Rarity = "Epic",         LuckBuff = 19.0,      Price = 1_500_000,               RebirthReq = 3 },
	{ Name = "Emerald",     Rarity = "Legendary",    LuckBuff = 28.0,      Price = 5_000_000,               RebirthReq = 4 },
	{ Name = "Obsidian",    Rarity = "Mythical",     LuckBuff = 40.0,      Price = 15_000_000,              RebirthReq = 5 },
	{ Name = "Amethyst",    Rarity = "Ascendant",    LuckBuff = 60.0,      Price = 50_000_000,              RebirthReq = 6 },
	{ Name = "Nebulite",    Rarity = "Sovereign",    LuckBuff = 90.0,      Price = 150_000_000,             RebirthReq = 7 },
	{ Name = "Radiant",     Rarity = "Sovereign",    LuckBuff = 135.0,     Price = 500_000_000,             RebirthReq = 7 },
	{ Name = "Quantum",     Rarity = "Transcendant", LuckBuff = 200.0,     Price = 1_500_000_000,           RebirthReq = 8 },
	{ Name = "Luminous",    Rarity = "Transcendant", LuckBuff = 300.0,     Price = 5_000_000_000,           RebirthReq = 9 },
	{ Name = "Devil",       Rarity = "Secret",       LuckBuff = 450.0,     Price = 18_000_000_000,          RebirthReq = 10 },
	{ Name = "Angelic",     Rarity = "Secret",       LuckBuff = 675.0,     Price = 60_000_000_000,          RebirthReq = 10 },
	{ Name = "Ethereal",    Rarity = "Divine",       LuckBuff = 1000.0,    Price = 200_000_000_000,         RebirthReq = 11 },
	{ Name = "Astral",      Rarity = "Divine",       LuckBuff = 1500.0,    Price = 650_000_000_000,         RebirthReq = 12 },
	{ Name = "Singularity", Rarity = "Cosmic",       LuckBuff = 2250.0,    Price = 2_000_000_000_000,       RebirthReq = 13 },
	{ Name = "Celestial",   Rarity = "Cosmic",       LuckBuff = 3500.0,    Price = 7_000_000_000_000,       RebirthReq = 14 },
	{ Name = "Galactic",    Rarity = "Universal",    LuckBuff = 5000.0,    Price = 25_000_000_000_000,      RebirthReq = 15 },
	{ Name = "Sovereign",   Rarity = "Universal",    LuckBuff = 7500.0,    Price = 80_000_000_000_000,      RebirthReq = 16 },
	{ Name = "Emperor",     Rarity = "Universal",    LuckBuff = 11000.0,   Price = 250_000_000_000_000,     RebirthReq = 16 },
	{ Name = "Void",        Rarity = "Abyssal",      LuckBuff = 16000.0,   Price = 800_000_000_000_000,     RebirthReq = 17 },
	{ Name = "Abyssal",     Rarity = "Abyssal",      LuckBuff = 24000.0,   Price = 2_500_000_000_000_000,   RebirthReq = 18 },
	{ Name = "Paradox",     Rarity = "Abyssal",      LuckBuff = 36000.0,   Price = 8_000_000_000_000_000,   RebirthReq = 18 },
	{ Name = "Infinity",    Rarity = "Omni",         LuckBuff = 50000.0,   Price = 25_000_000_000_000_000,  RebirthReq = 19 },
	{ Name = "Omniscient",  Rarity = "Omni",         LuckBuff = 75000.0,   Price = 80_000_000_000_000_000,  RebirthReq = 19 },
	{ Name = "Genesis",     Rarity = "Origin",       LuckBuff = 100000.0,  Price = 300_000_000_000_000_000, RebirthReq = 20 }

}


-- ==========================================
-- 🎨 3. TIERS
-- ==========================================

GameConfig.Tiers = {
	["Common"]       = { Folder = "1Common",       Color = Color3.fromRGB(180, 180, 180) },
	["Rare"]         = { Folder = "2Rare",         Color = Color3.fromRGB(85, 170, 255) },
	["Superior"]     = { Folder = "3Superior",     Color = Color3.fromRGB(85, 255, 127) },
	["Epic"]         = { Folder = "4Epic",         Color = Color3.fromRGB(186, 67, 255) },
	["Legendary"]    = { Folder = "5Legendary",    Color = Color3.fromRGB(255, 170, 0) },
	["Mythical"]     = { Folder = "6Mythical",     Color = Color3.fromRGB(186, 18, 164) },
	["Ascendant"]    = { Folder = "7Ascendant",    Color = Color3.fromRGB(238, 227, 69) },
	["Sovereign"]    = { Folder = "8Sovereign",    Color = Color3.fromRGB(249, 91, 0) },
	["Transcendant"] = { Folder = "9Transcendant", Color = Color3.fromRGB(24, 151, 186) },
	["Secret"]       = { Folder = "10Secret",      Color = Color3.fromRGB(99, 1, 1) }
}


-- ==========================================
-- 👾 4. BADDIE DATA (STATIC CHANCE, INCOME, & SELL PRICE)
-- =========================================

GameConfig.BaddiesData = {
	-- TIER 1: COMMON (Sell Mult: 660)
	{ Name="Goblin Baddie",  Rarity="Common", Tier=1, Role="DPS",     BaseHP=320, BaseATK=65, BaseDEF=25, BaseSPD=95, SkillId="Basic_Attack", Chance=2,  Income=15, SellPrice=9_900 },
	{ Name="Worker Baddie",  Rarity="Common", Tier=1, Role="Tank",    BaseHP=420, BaseATK=40, BaseDEF=45, BaseSPD=80, SkillId="Heavy_Strike", Chance=5,  Income=19, SellPrice=12_540 },
	{ Name="Wakuri Baddie",  Rarity="Common", Tier=1, Role="Support", BaseHP=300, BaseATK=45, BaseDEF=30, BaseSPD=105,                        Chance=10, Income=24, SellPrice=15_840 },
	{ Name="Cute Baddie",    Rarity="Common", Tier=1, Role="DPS",     BaseHP=290, BaseATK=75, BaseDEF=20, BaseSPD=110,                        Chance=16, Income=30, SellPrice=19_800 },
	{ Name="School Baddie",  Rarity="Common", Tier=1, Role="Support", BaseHP=350, BaseATK=50, BaseDEF=35, BaseSPD=100, SkillId="FollowMyLead", Chance=22, Income=38, SellPrice=25_080 },


	-- TIER 2: RARE (Sell Mult: 720)
	{ Name="Office Baddie",  Rarity="Rare", Tier=2, Role="Support", BaseHP=520, BaseATK=90,  BaseDEF=55, BaseSPD=110, Chance=24,  Income=52,  SellPrice=37_440 },
	{ Name="Playful Baddie", Rarity="Rare", Tier=2, Role="DPS",     BaseHP=480, BaseATK=130, BaseDEF=45, BaseSPD=115, Chance=60,  Income=65,  SellPrice=46_800 },
	{ Name="Evil Baddie",    Rarity="Rare", Tier=2, Role="DPS",     BaseHP=500, BaseATK=140, BaseDEF=50, BaseSPD=105, Chance=120, Income=83,  SellPrice=59_760 },
	{ Name="Bamboo Baddie",  Rarity="Rare", Tier=2, Role="Tank",    BaseHP=700, BaseATK=85,  BaseDEF=90, BaseSPD=85,  Chance=192, Income=104, SellPrice=74_880 },
	{ Name="Raphie Baddie",  Rarity="Rare", Tier=2, Role="Support", BaseHP=550, BaseATK=95,  BaseDEF=60, BaseSPD=120, Chance=264, Income=130, SellPrice=93_600 },


	-- TIER 3: SUPERIOR (Sell Mult: 780)
	{ Name="Mirei Baddie",     Rarity="Superior", Tier=3, Role="DPS",     BaseHP=900,  BaseATK=240, BaseDEF=80,  BaseSPD=115, SkillId="Hemokinesis", Chance=288,   Income=183, SellPrice=142_740 },
	{ Name="Butterfly Baddie", Rarity="Superior", Tier=3, Role="DPS",     BaseHP=850,  BaseATK=260, BaseDEF=70,  BaseSPD=120, SkillId="Wisteria_Poison", Chance=720,   Income=228, SellPrice=177_840 },
	{ Name="Brazilian Baddie", Rarity="Superior", Tier=3, Role="Tank",    BaseHP=1200, BaseATK=180, BaseDEF=150, BaseSPD=85,  SkillId="BrazillianPhonk", Chance=1_440, Income=292, SellPrice=227_760 },
	{ Name="Student President Baddie",  Rarity="Superior", Tier=3, Role="Support", BaseHP=950,  BaseATK=220, BaseDEF=95,  BaseSPD=105, SkillId="FollowMyLead", Chance=2_304, Income=366, SellPrice=285_480 },
	{ Name="Smug Baddie",      Rarity="Superior", Tier=3, Role="DPS",     BaseHP=880,  BaseATK=275, BaseDEF=75,  BaseSPD=115, SkillId="SmugCut", Chance=3_168, Income=457, SellPrice=356_460 },


	-- TIER 4: EPIC (Sell Mult: 840)
	{ Name="Cat Ear Baddie",  Rarity="Epic", Tier=4, Role="DPS",     BaseHP=1600, BaseATK=450, BaseDEF=130, BaseSPD=125, SkillId="Cat_Noises", Chance=3_456,  Income=643,   SellPrice=540_120 },
	{ Name="Emo Baddie",      Rarity="Epic", Tier=4, Role="DPS",     BaseHP=1550, BaseATK=480, BaseDEF=120, BaseSPD=120, SkillId="Depression", Chance=8_640,  Income=803,   SellPrice=674_520 },
	{ Name="Blood Devil",     Rarity="Epic", Tier=4, Role="DPS",     BaseHP=1700, BaseATK=520, BaseDEF=140, BaseSPD=115, SkillId="Powa_Hamma", Chance=17_280, Income=1_028, SellPrice=863_520 },
	{ Name="Obsessed Baddie", Rarity="Epic", Tier=4, Role="Control", BaseHP=1650, BaseATK=400, BaseDEF=150, BaseSPD=130, Chance=27_648, Income=1_286, SellPrice=1_080_240 },
	{ Name="Clumsy Baddie",   Rarity="Epic", Tier=4, Role="Support", BaseHP=1800, BaseATK=350, BaseDEF=180, BaseSPD=120, SkillId="Trip", Chance=38_000, Income=1_607, SellPrice=1_349_880 },


	-- TIER 5: LEGENDARY (Sell Mult: 900)
	{ Name="Maid Baddie",   Rarity="Legendary", Tier=5, Role="Support", BaseHP=3200, BaseATK=650,  BaseDEF=350, BaseSPD=135, Chance=41_500,  Income=2_250, SellPrice=2_025_000 },
	{ Name="Genius Baddie", Rarity="Legendary", Tier=5, Role="Control", BaseHP=3000, BaseATK=720,  BaseDEF=300, BaseSPD=130, Chance=100_000, Income=2_812, SellPrice=2_530_800 },
	{ Name="Elf Baddie",    Rarity="Legendary", Tier=5, Role="DPS",     BaseHP=2800, BaseATK=850,  BaseDEF=250, BaseSPD=140, Chance=200_000, Income=3_600, SellPrice=3_240_000 },
	{ Name="Pirate Baddie", Rarity="Legendary", Tier=5, Role="DPS",     BaseHP=3000, BaseATK=900,  BaseDEF=280, BaseSPD=125, Chance=330_000, Income=4_500, SellPrice=4_050_000 },
	{ Name="Gamble Baddie", Rarity="Legendary", Tier=5, Role="DPS",     BaseHP=2900, BaseATK=1000, BaseDEF=220, BaseSPD=150, Chance=450_000, Income=5_625, SellPrice=5_062_500 },


	-- TIER 6: MYTHICAL (Sell Mult: 960)
	{ Name="Sniper Baddie", Rarity="Mythical", Tier=6, Role="DPS",     BaseHP=4500, BaseATK=1500, BaseDEF=400, BaseSPD=160, Chance=500_000,  Income=7_875,  SellPrice=7_560_000 },
	{ Name="Demon Baddie",  Rarity="Mythical", Tier=6, Role="DPS",     BaseHP=5000, BaseATK=1650, BaseDEF=450, BaseSPD=150, Chance=1_250_000,Income=9_843,  SellPrice=9_449_280 },
	{ Name="Rezu Baddie",   Rarity="Mythical", Tier=6, Role="DPS",     BaseHP=4800, BaseATK=1750, BaseDEF=420, BaseSPD=170, Chance=2_500_000,Income=12_600, SellPrice=12_096_000 },
	{ Name="Exile Baddie",  Rarity="Mythical", Tier=6, Role="Control", BaseHP=5200, BaseATK=1400, BaseDEF=600, BaseSPD=145, Chance=4_000_000,Income=15_750, SellPrice=15_120_000 },
	{ Name="Silver Fox",    Rarity="Mythical", Tier=6, Role="Support", BaseHP=5500, BaseATK=1300, BaseDEF=650, BaseSPD=155, Chance=5_500_000,Income=19_687, SellPrice=18_899_520 },


	-- TIER 7: ASCENDANT (Sell Mult: 1020)
	{ Name="Snake Princess",Rarity="Ascendant", Tier=7, Role="Control", BaseHP=7000, BaseATK=2100, BaseDEF=800, BaseSPD=165, Chance=6_000_000, Income=27_562, SellPrice=28_113_240 },
	{ Name="Love Sword",    Rarity="Ascendant", Tier=7, Role="DPS",     BaseHP=7500, BaseATK=2400, BaseDEF=750, BaseSPD=170, Chance=15_000_000,Income=34_452, SellPrice=35_141_040 },
	{ Name="Apothecary",    Rarity="Ascendant", Tier=7, Role="Support", BaseHP=8200, BaseATK=1900, BaseDEF=950, BaseSPD=150, SkillId="Wisteria_Poison", Chance=30_000_000,Income=44_099, SellPrice=44_980_980 },
	{ Name="Zenin Baddie",  Rarity="Ascendant", Tier=7, Role="DPS",     BaseHP=7800, BaseATK=2600, BaseDEF=700, BaseSPD=180, Chance=48_000_000,Income=55_124, SellPrice=56_226_480 },
	{ Name="Railgun Baddie",Rarity="Ascendant", Tier=7, Role="DPS",     BaseHP=7600, BaseATK=2800, BaseDEF=650, BaseSPD=175, Chance=65_000_000,Income=68_905, SellPrice=70_283_100 },


	-- TIER 8: SOVEREIGN (Sell Mult: 1080)
	{ Name="Electro Kitsune",Rarity="Sovereign", Tier=8, Role="DPS",     BaseHP=11000, BaseATK=3800, BaseDEF=1200, BaseSPD=185, Chance=70_000_000, Income=96_468,  SellPrice=104_185_440 },
	{ Name="Vanguard Baddie",Rarity="Sovereign", Tier=8, Role="Tank",    BaseHP=15000, BaseATK=3000, BaseDEF=2000, BaseSPD=130, Chance=180_000_000,Income=120_585, SellPrice=130_231_800 },
	{ Name="Hacker Baddie",  Rarity="Sovereign", Tier=8, Role="Control", BaseHP=12000, BaseATK=3400, BaseDEF=1400, BaseSPD=190, Chance=350_000_000,Income=154_348, SellPrice=166_695_840 },
	{ Name="Explosion Mage", Rarity="Sovereign", Tier=8, Role="DPS",     BaseHP=11500, BaseATK=4200, BaseDEF=1100, BaseSPD=175, Chance=570_000_000,Income=192_936, SellPrice=208_370_880 },
	{ Name="Ice Death",      Rarity="Sovereign", Tier=8, Role="DPS",     BaseHP=13000, BaseATK=4500, BaseDEF=1300, BaseSPD=170, Chance=780_000_000,Income=241_170, SellPrice=260_463_600 },


	-- TIER 9: TRANSCENDANT (Sell Mult: 1140)
	{ Name="Shilder Baddie", Rarity="Transcendant", Tier=9, Role="Tank",    BaseHP=20000, BaseATK=5000, BaseDEF=3500, BaseSPD=140, Chance=860_000_000,  Income=337_640, SellPrice=384_909_600 },
	{ Name="Firen Baddie",   Rarity="Transcendant", Tier=9, Role="DPS",     BaseHP=18000, BaseATK=6500, BaseDEF=2000, BaseSPD=190, Chance=2_150_000_000,Income=422_050, SellPrice=481_137_000 },
	{ Name="Idol Baddie",    Rarity="Transcendant", Tier=9, Role="Support", BaseHP=21000, BaseATK=4800, BaseDEF=3000, BaseSPD=175, Chance=4_300_000_000,Income=540_224, SellPrice=615_855_360 },
	{ Name="Zaphkiel",       Rarity="Transcendant", Tier=9, Role="Control", BaseHP=19500, BaseATK=6200, BaseDEF=2500, BaseSPD=200, Chance=6_800_000_000,Income=675_280, SellPrice=769_819_200 },
	{ Name="Curse King",     Rarity="Transcendant", Tier=9, Role="DPS",     BaseHP=22000, BaseATK=7200, BaseDEF=2800, BaseSPD=195, Chance=9_400_000_000,Income=844_100, SellPrice=962_274_000 },


	-- TIER 10: SECRET (Sell Mult: 1200)
	{ Name="Hero King",      Rarity="Secret", Tier=10, Role="DPS",     BaseHP=30000, BaseATK=9000,  BaseDEF=3500, BaseSPD=200, Chance=10_300_000_000, Income=1_181_740, SellPrice=1_418_088_000 },
	{ Name="Diona Baddie",   Rarity="Secret", Tier=10, Role="Support", BaseHP=34000, BaseATK=7500,  BaseDEF=5000, BaseSPD=210, Chance=25_700_000_000, Income=1_477_175, SellPrice=1_772_610_000 },
	{ Name="Shadow Monarch", Rarity="Secret", Tier=10, Role="DPS",     BaseHP=38000, BaseATK=11000, BaseDEF=4000, BaseSPD=205, Chance=51_500_000_000, Income=1_890_784, SellPrice=2_268_940_800 },
	{ Name="Archieve Baddie",Rarity="Secret", Tier=10, Role="Control", BaseHP=40000, BaseATK=9500,  BaseDEF=5500, BaseSPD=215, Chance=82_500_000_000, Income=2_363_480, SellPrice=2_836_176_000 },
	{ Name="Cutsleeve Baddie",Rarity="Secret", Tier=10, Role="Tank",   BaseHP=50000, BaseATK=8500,  BaseDEF=8000, BaseSPD=160, Chance=113_500_000_000,Income=2_954_350, SellPrice=3_545_220_000 }

}


-- ==========================================
-- 🥚 5. EGGS & PETS (STATIC LUCK & CHANCES)
-- ==========================================

GameConfig.Eggs = {

	{
		Name = "Basic Egg", Price = 500_000,
		Pets = {
			{ Chance = 54.0, LuckBoost = 0.03 },
			{ Chance = 25.0, LuckBoost = 0.05 },
			{ Chance = 15.0, LuckBoost = 0.10 },
			{ Chance = 5.0,  LuckBoost = 0.30 },
			{ Chance = 0.9,  LuckBoost = 0.70 },
			{ Chance = 0.1,  LuckBoost = 2.00 }
		}
	},

	{

		Name = "Advanced Egg", Price = 7_500_000,
		Pets = {
			{ Chance = 54.0, LuckBoost = 0.10 },
			{ Chance = 25.0, LuckBoost = 0.17 },
			{ Chance = 15.0, LuckBoost = 0.35 },
			{ Chance = 5.0,  LuckBoost = 1.05 },
			{ Chance = 0.9,  LuckBoost = 2.45 },
			{ Chance = 0.1,  LuckBoost = 7.00 }
		}
	},

	{
		Name = "Elite Egg", Price = 112_500_000,
		Pets = {
			{ Chance = 54.0, LuckBoost = 0.36 },
			{ Chance = 25.0, LuckBoost = 0.61 },
			{ Chance = 15.0, LuckBoost = 1.22 },
			{ Chance = 5.0,  LuckBoost = 3.67 },
			{ Chance = 0.9,  LuckBoost = 8.57 },
			{ Chance = 0.1,  LuckBoost = 24.50 }
		}
	},

	{
		Name = "Primal Egg", Price = 1_680_000_000,
		Pets = {
			{ Chance = 54.0, LuckBoost = 1.27 },
			{ Chance = 25.0, LuckBoost = 2.12 },
			{ Chance = 15.0, LuckBoost = 4.25 },
			{ Chance = 5.0,  LuckBoost = 12.75 },
			{ Chance = 0.9,  LuckBoost = 29.75 },
			{ Chance = 0.1,  LuckBoost = 85.00 }
		}
	},
	
	{
		Name = "Void Egg", Price = 25_300_000_000,
		Pets = {
			{ Chance = 54.0, LuckBoost = 4.50 },
			{ Chance = 25.0, LuckBoost = 7.50 },
			{ Chance = 15.0, LuckBoost = 15.00 },
			{ Chance = 5.0,  LuckBoost = 45.00 },
			{ Chance = 0.9,  LuckBoost = 105.00 },
			{ Chance = 0.1,  LuckBoost = 300.00 }
		}
	},

	{

		Name = "Genesis Egg", Price = 379_000_000_000,
		Pets = {
			{ Chance = 54.0, LuckBoost = 15.0 },
			{ Chance = 25.0, LuckBoost = 25.0 },
			{ Chance = 15.0, LuckBoost = 50.0 },
			{ Chance = 5.0,  LuckBoost = 150.0 },
			{ Chance = 0.9,  LuckBoost = 350.0 },
			{ Chance = 0.1,  LuckBoost = 1000.0 }
		}
	}
}


-- ==========================================
-- 🧪 6. UPGRADES & POTIONS (STATIC COST & REQ)
-- ==========================================

GameConfig.Potions = {
	MinorMoney = { Multiplier = 2.0, Duration = 1800, PriceCoin = 1_500_000 },
	MajorMoney = { Multiplier = 3.0, Duration = 1800, PriceCoin = 25_000_000 },
	MinorLuck  = { Multiplier = 2.0, Duration = 1800, PriceCoin = 2_500_000 },
	MajorLuck  = { Multiplier = 3.0, Duration = 1800, PriceCoin = 35_000_000 }
}


GameConfig.Upgrades = {
	Coin = {
		Name = "COIN MULTIPLIER", MaxLevel = 20,
		Tiers = {
			[1]  = { BonusPercent = 1.0,  RebirthReq = 0,  Cost = 100_000 },
			[2]  = { BonusPercent = 2.0,  RebirthReq = 1,  Cost = 450_000 },
			[3]  = { BonusPercent = 3.0,  RebirthReq = 2,  Cost = 2_000_000 },
			[4]  = { BonusPercent = 4.0,  RebirthReq = 3,  Cost = 9_000_000 },
			[5]  = { BonusPercent = 5.0,  RebirthReq = 4,  Cost = 40_000_000 },
			[6]  = { BonusPercent = 6.0,  RebirthReq = 5,  Cost = 180_000_000 },
			[7]  = { BonusPercent = 7.0,  RebirthReq = 6,  Cost = 800_000_000 },
			[8]  = { BonusPercent = 8.0,  RebirthReq = 7,  Cost = 3_700_000_000 },
			[9]  = { BonusPercent = 9.0,  RebirthReq = 8,  Cost = 16_500_000_000 },
			[10] = { BonusPercent = 10.0, RebirthReq = 9,  Cost = 75_000_000_000 },
			[11] = { BonusPercent = 11.0, RebirthReq = 10, Cost = 340_000_000_000 },
			[12] = { BonusPercent = 12.0, RebirthReq = 11, Cost = 1_500_000_000_000 },
			[13] = { BonusPercent = 13.0, RebirthReq = 12, Cost = 6_800_000_000_000 },
			[14] = { BonusPercent = 14.0, RebirthReq = 13, Cost = 31_000_000_000_000 },
			[15] = { BonusPercent = 15.0, RebirthReq = 14, Cost = 140_000_000_000_000 },
			[16] = { BonusPercent = 16.0, RebirthReq = 15, Cost = 620_000_000_000_000 },
			[17] = { BonusPercent = 17.0, RebirthReq = 16, Cost = 2_800_000_000_000_000 },
			[18] = { BonusPercent = 18.0, RebirthReq = 17, Cost = 12_500_000_000_000_000 },
			[19] = { BonusPercent = 19.0, RebirthReq = 18, Cost = 57_000_000_000_000_000 },
			[20] = { BonusPercent = 20.0, RebirthReq = 19, Cost = 250_000_000_000_000_000 }
		}
	},

	Luck = {
		Name = "LUCK MULTIPLIER", MaxLevel = 20,
		Tiers = {
			[1]  = { BonusPercent = 1.0,  RebirthReq = 0,  Cost = 150_000 },
			[2]  = { BonusPercent = 2.0,  RebirthReq = 1,  Cost = 675_000 },
			[3]  = { BonusPercent = 3.0,  RebirthReq = 2,  Cost = 3_000_000 },
			[4]  = { BonusPercent = 4.0,  RebirthReq = 3,  Cost = 13_500_000 },
			[5]  = { BonusPercent = 5.0,  RebirthReq = 4,  Cost = 60_000_000 },
			[6]  = { BonusPercent = 6.0,  RebirthReq = 5,  Cost = 270_000_000 },
			[7]  = { BonusPercent = 7.0,  RebirthReq = 6,  Cost = 1_200_000_000 },
			[8]  = { BonusPercent = 8.0,  RebirthReq = 7,  Cost = 5_550_000_000 },
			[9]  = { BonusPercent = 9.0,  RebirthReq = 8,  Cost = 24_750_000_000 },
			[10] = { BonusPercent = 10.0, RebirthReq = 9,  Cost = 112_500_000_000 },
			[11] = { BonusPercent = 11.0, RebirthReq = 10, Cost = 510_000_000_000 },
			[12] = { BonusPercent = 12.0, RebirthReq = 11, Cost = 2_250_000_000_000 },
			[13] = { BonusPercent = 13.0, RebirthReq = 12, Cost = 10_200_000_000_000 },
			[14] = { BonusPercent = 14.0, RebirthReq = 13, Cost = 46_500_000_000_000 },
			[15] = { BonusPercent = 15.0, RebirthReq = 14, Cost = 210_000_000_000_000 },
			[16] = { BonusPercent = 16.0, RebirthReq = 15, Cost = 930_000_000_000_000 },
			[17] = { BonusPercent = 17.0, RebirthReq = 16, Cost = 4_200_000_000_000_000 },
			[18] = { BonusPercent = 18.0, RebirthReq = 17, Cost = 18_750_000_000_000_000 },
			[19] = { BonusPercent = 19.0, RebirthReq = 18, Cost = 85_500_000_000_000_000 },
			[20] = { BonusPercent = 20.0, RebirthReq = 19, Cost = 375_000_000_000_000_000 }
		}
	}
}


-- ==========================================
-- ⛈️ 7. MUTATIONS & WEATHER EVENTS
-- ==========================================

GameConfig.Mutations = {
	{ Name = "Void",    Multiplier = 7.0, BaseChance = 0.1, WeatherBoostName = "Void Eclipse", WeatherBoostMult = 10.0 },
	{ Name = "Diamond", Multiplier = 4.0, BaseChance = 1.0, WeatherBoostName = "Diamond Snow", WeatherBoostMult = 5.0 },
	{ Name = "Ruby",    Multiplier = 2.5, BaseChance = 5.0, WeatherBoostName = "Blood Moon",   WeatherBoostMult = 3.0 },
	{ Name = "Emerald", Multiplier = 1.5, BaseChance = 15.0,WeatherBoostName = "Emerald Rain", WeatherBoostMult = 2.0 },
	{ Name = "Candy",   Multiplier = 1.2, BaseChance = 30.0,WeatherBoostName = "Candy Breeze", WeatherBoostMult = 1.5 }
}


-- ==========================================
-- ⚔️ 8. COMBAT & HELPER FUNCTIONS
-- ==========================================

GameConfig.CombatSettings = {
	MaxEnergy = 3, DamageReductionDenom = 120, SpeedCapBonus = 20
}


-- ==========================================
-- 😈 9. ENEMY / NPC DATA & ZONES
-- ==========================================

GameConfig.Zones = {
	["Forest"] = { DifficultyMult = 1.0 },
	["Desert"] = { DifficultyMult = 1.5 },
	["Volcano"]= { DifficultyMult = 2.5 },
}


GameConfig.NPCData = {
	["NPC_Slime"] = { Name = "Forest Slime", Zone = "Forest", HP = 100500, ATK = 120, DEF = 50, SPD = 85, AI = "Basic" },
	["NPC_Goblin"] = { Name = "Goblin Boss",  Zone = "Forest", HP = 4500, ATK = 250, DEF = 80, SPD = 95, AI = "Aggressive" }
}


function GameConfig.GetNPCData(name)
	return GameConfig.NPCData[name]
end


-- ==========================================
-- ⭐ 10. STAR MULTIPLIERS (TAMBAHKAN INI)
-- ==========================================

GameConfig.StarMultipliers = {
	[0] = 1.0,
	[1] = 1.2,
	[2] = 1.5,
	[3] = 2.0,
	[4] = 3.0,
	[5] = 5.0
}


function GameConfig.GetBaddieData(name)
	for _, b in ipairs(GameConfig.BaddiesData) do
		if b.Name == name then return b end
	end
	return nil
end


return GameConfig