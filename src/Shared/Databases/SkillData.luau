local SkillData = {}

SkillData.Dictionary = {
	["Basic_Attack"] = {
		Name = "Basic Attack",
		TargetRule = "Single_Enemy",
		EnergyCost = 0,
		EnergyGain = 1,
		VisualTag = "Anim_Melee_Hit",
		Effects = {
			{ Type = "Damage", Multiplier = 1.0 }
		}
	},

	["Heavy_Strike"] = {
		Name = "Heavy Strike",
		TargetRule = "Single_Enemy",
		EnergyCost = 0,
		EnergyGain = 1,
		VisualTag = "Anim_Heavy_Smash",
		Effects = {
			{ Type = "Damage", Multiplier = 1.5 }
		}
	},

	["Taunt_Guard"] = {
		Name = "Taunt Guard",
		TargetRule = "Self",
		EnergyCost = 0,
		EnergyGain = 1,
		VisualTag = "VFX_Shield_Up",
		Effects = {
			{ Type = "Shield", Multiplier = 2.0, Duration = 2, MaxStacks = 2 },
			{ Type = "ApplyStatus", Status = "Taunt", Duration = 2, MaxStacks = 1 }
		}
	},

	["Party_Heal"] = {
		Name = "Party Heal",
		TargetRule = "All_Allies_Exclude_Self",
		EnergyCost = 0,
		EnergyGain = 1,
		VisualTag = "VFX_Party_Heal",
		Effects = {
			{ Type = "Heal", Multiplier = 1.2 }
		}
	},

	["Speed_Boost"] = {
		Name = "Speed Boost",
		TargetRule = "Lowest_Speed_Ally",
		EnergyCost = 0,
		EnergyGain = 1,
		VisualTag = "VFX_Speed_Buff",
		Effects = {
			{ Type = "Buff", BuffType = "Speed", Amount = 35, Duration = 2 }
		}
	},

	["Ult_Meteor"] = {
		Name = "Meteor Strike",
		TargetRule = "Single_Enemy",
		EnergyCost = 3,
		EnergyGain = 0,
		VisualTag = "Cinematic_Meteor_Drop",
		Effects = {
			{ Type = "Damage", Multiplier = 3.0 },
			{ Type = "ApplyStatus", Status = "Burn", Duration = 2, Value = 0.5 }
		}
	},

	["Wisteria_Poison"] = {
		Name = "Wisteria Poison",
		Cooldown = 2,
		TargetRule = "Single_Enemy",
		EnergyCost = 0,
		EnergyGain = 1,
		VisualTag = "Anim_Melee_Hit",
		Effects = {
			{ Type = "Damage", Multiplier = 1.2 },
			{ Type = "ApplyStatus", Status = "Stun", Duration = 1, Chance = 20 }
		}
	},

	["Hemokinesis"] = {
		Name = "Hemokinesis",
		Cooldown = 2,
		TargetRule = "Single_Enemy",
		EnergyCost = 0,
		EnergyGain = 1,
		VisualTag = "Anim_Heavy_Smash",
		Effects = {
			{ Type = "Damage", Multiplier = 1.5 }
		}
	},

	["BrazillianPhonk"] = {
		Name = "Brazillian Phonk",
		Cooldown = 3,
		TargetRule = "All_Allies",
		EnergyCost = 0,
		EnergyGain = 1,
		VisualTag = "VFX_Speed_Buff",
		Effects = {} -- Handled purely by SpecialSkill
	},

	["SmugCut"] = {
		Name = "Smug Cut",
		Cooldown = 4,
		TargetRule = "Single_Enemy",
		EnergyCost = 0,
		EnergyGain = 1,
		VisualTag = "Anim_Melee_Hit",
		Effects = {} -- Handled purely by SpecialSkill
	},

	["FollowMyLead"] = {
		Name = "Follow My Lead!",
		Cooldown = 4,
		TargetRule = "All_Allies",
		EnergyCost = 0,
		EnergyGain = 1,
		VisualTag = "VFX_Shield_Up",
		Effects = {} -- Handled purely by SpecialSkill
	}
}

return SkillData