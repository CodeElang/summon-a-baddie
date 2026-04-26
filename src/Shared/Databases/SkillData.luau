local SkillData = {}

SkillData.Dictionary = {
	["Basic_Attack"] = {
		Name = "Basic Attack",
		Description = "A standard attack dealing 1x ATK damage.",
		TargetType = "SingleEnemy",
		EnergyCost = 0,
		EnergyGain = 1,
		VisualTag = "Anim_Melee_Hit",
		IsSpecial = false,
		Effects = {
			{ Type = "Damage", Multiplier = 1.0 }
		}
	},

	["Heavy_Strike"] = {
		Name = "Heavy Strike",
		Description = "A powerful blow dealing 1.5x ATK damage. 3 turn cooldown.",
		TargetType = "SingleEnemy",
		BaseCooldown = 3,
		EnergyCost = 0,
		EnergyGain = 1,
		VisualTag = "Anim_Heavy_Smash",
		IsSpecial = false,
		Effects = {
			{ Type = "Damage", Multiplier = 1.5 }
		}
	},

	["Taunt_Guard"] = {
		Name = "Taunt Guard",
		Description = "Shields self for 20% MaxHP and forces enemies to target you for 2 turns.",
		TargetType = "Self",
		BaseCooldown = 3,
		EnergyCost = 0,
		EnergyGain = 1,
		VisualTag = "VFX_Shield_Up",
		IsSpecial = false,
		Effects = {
			{ Type = "Shield", ShieldPct = 0.20, Duration = 2, MaxStacks = 2 },
			{ Type = "ApplyStatus", Status = "Taunt", Duration = 2, MaxStacks = 1 }
		}
	},

	["Party_Heal"] = {
		Name = "Party Heal",
		Description = "Heals all allies for 15% of their missing HP.",
		TargetType = "AllAllies",
		BaseCooldown = 3,
		EnergyCost = 0,
		EnergyGain = 1,
		VisualTag = "VFX_Party_Heal",
		IsSpecial = false,
		Effects = {
			{ Type = "Heal", MissingHPPct = 0.15 }
		}
	},

	["Controller_Ult"] = {
		Name = "Temporal Break",
		Description = "Deals 0.8x ATK to all enemies. Delays and reduces ATK by 30%.",
		TargetType = "AllEnemies",
		EnergyCost = 3,
		EnergyGain = 0,
		VisualTag = "Anim_Heavy_Smash",
		IsSpecial = false,
		Effects = {
			{ Type = "Damage", Multiplier = 0.8 },
			{ Type = "Delay", Amount = 0.30, Chance = 100 },
			{ Type = "ApplyStatus", Status = "ATK_Down", Value = 0.30, Duration = 2, Chance = 100 }
		}
	},

	["Hemokinesis"] = {
		Name = "Hemokinesis",
		Description = "Blood magic: Deals 1.8x ATK damage at the cost of 8% of own Max HP.",
		TargetType = "SingleEnemy",
		BaseCooldown = 2,
		EnergyCost = 0,
		EnergyGain = 1,
		VisualTag = "Anim_Melee_Hit",
		IsSpecial = false,
		Effects = {
			{ Type = "HPCost", MaxHPPct = 0.08 },
			{ Type = "Damage", Multiplier = 1.8 }
		}
	},

	["Wisteria_Poison"] = {
		Name = "Wisteria Poison",
		Description = "Poisons the target, applying a Burn DoT for 3 turns.",
		TargetType = "SingleEnemy",
		BaseCooldown = 3,
		EnergyCost = 0,
		EnergyGain = 1,
		VisualTag = "Anim_Melee_Hit",
		IsSpecial = false,
		Effects = {
			{ Type = "Damage", Multiplier = 0.6 },
			{ Type = "ApplyStatus", Status = "Burn", Value = 0.50, Duration = 3, MaxStacks = 1, Chance = 100 }
		}
	},

	["Cat_Noises"] = {
		Name = "Cat Noises",
		Description = "Scratches with fury! Deals 1.4x ATK damage and has a 50% chance to reduce DEF.",
		TargetType = "SingleEnemy",
		BaseCooldown = 2,
		EnergyCost = 0,
		EnergyGain = 1,
		VisualTag = "Anim_Melee_Hit",
		IsSpecial = false,
		Effects = {
			{ Type = "Damage", Multiplier = 1.4 },
			{ Type = "ApplyStatus", Status = "DEF_Down", Value = 0.20, Duration = 2, Chance = 50 }
		}
	},

	["Depression"] = {
		Name = "Depression",
		Description = "Channels dark energy dealing 1.6x ATK. 40% chance to Stun for 1 turn.",
		TargetType = "SingleEnemy",
		BaseCooldown = 3,
		EnergyCost = 0,
		EnergyGain = 1,
		VisualTag = "Anim_Heavy_Smash",
		IsSpecial = false,
		Effects = {
			{ Type = "Damage", Multiplier = 1.6 },
			{ Type = "ApplyStatus", Status = "Stun", Duration = 1, MaxStacks = 1, Chance = 40 }
		}
	},

	["Powa_Hamma"] = {
		Name = "Powa Hamma",
		Description = "Massive hammer slam dealing 2.0x ATK damage.",
		TargetType = "SingleEnemy",
		BaseCooldown = 3,
		EnergyCost = 0,
		EnergyGain = 1,
		VisualTag = "Anim_Heavy_Smash",
		IsSpecial = false,
		Effects = {
			{ Type = "Damage", Multiplier = 2.0 }
		}
	},

	["Trip"] = {
		Name = "Trip",
		Description = "Clumsily trips into the enemy, dealing 0.8x damage but healing all allies for 10% missing HP.",
		TargetType = "SingleEnemy",
		BaseCooldown = 3,
		EnergyCost = 0,
		EnergyGain = 1,
		VisualTag = "Anim_Melee_Hit",
		IsSpecial = true
	},

	["Last Scene"] = {
		Name = "Last Scene",
		Description = "Taunts all enemies and gains a massive 30% MaxHP shield for 2 turns.",
		TargetType = "Self",
		BaseCooldown = 4,
		EnergyCost = 0,
		EnergyGain = 1,
		VisualTag = "VFX_Shield_Up",
		IsSpecial = false,
		Effects = {
			{ Type = "Shield", ShieldPct = 0.30, Duration = 2, MaxStacks = 2 },
			{ Type = "ApplyStatus", Status = "Taunt", Duration = 2, MaxStacks = 1 }
		}
	},

	-- Migrated Skills (no longer external SpecialSkill modules)
	["BrazillianPhonk"] = {
		Name = "Brazillian Phonk",
		Description = "Buffs all allies with +20% Speed for 3 turns.",
		TargetType = "AllAllies",
		BaseCooldown = 3,
		EnergyGain = 1,
		VisualTag = "VFX_Speed_Buff",
		IsSpecial = false,
		Effects = {
			{ Type = "Buff", BuffType = "Speed", SPDPct = 0.20, Duration = 3, MaxStacks = 2 }
		}
	},

	["FollowMyLead"] = {
		Name = "Follow My Lead!",
		Description = "Shields all allies for 10% of caster's MaxHP and buffs Speed by 10%.",
		TargetType = "AllAllies",
		BaseCooldown = 3,
		EnergyGain = 1,
		VisualTag = "VFX_Shield_Up",
		IsSpecial = false,
		Effects = {
			{ Type = "Shield", MaxHPPct = 0.10, Duration = 2, MaxStacks = 2 },
			{ Type = "Buff", BuffType = "Speed", SPDPct = 0.10, Duration = 2, MaxStacks = 2 }
		}
	},

	["SmugCut"] = {
		Name = "Smug Cut",
		Description = "Slashes with style: 1x ATK + 5% of target's Max HP as bonus damage.",
		TargetType = "SingleEnemy",
		BaseCooldown = 2,
		EnergyGain = 1,
		IsSpecial = true
	}
}

return SkillData