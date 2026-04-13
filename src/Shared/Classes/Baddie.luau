local Baddie = {}
Baddie.__index = Baddie 



local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)



function Baddie.new(id, name, rarity)
	local self = setmetatable({}, Baddie)
	self.Id = id or "UID_000" 
	self.Name = name or "Unknown Baddie"
	self.Rarity = rarity or "Common"



	self.Stars = 0 
	self.Mutations = {} 
	self.Relics = {

		Slot1 = nil,
		Slot2 = nil

	}


	return self

end


function Baddie:CalculateIncome()
	local bCfg = GameConfig.GetBaddieData(self.Name)
	local baseIncome = bCfg and bCfg.BaseIncome or 10
	local starMultiplier = 1 + (self.Stars * 0.5)
	return baseIncome * starMultiplier

end



function Baddie:Ascend()
	if self.Stars < 5 then
		self.Stars = self.Stars + 1
		return true
	end
	return false
end



function Baddie:AddMutation(mutationName)
	if #self.Mutations < 3 then
		table.insert(self.Mutations, mutationName)
		return true
	end
	return false
end



function Baddie:EquipRelic(slot, relicData)
	if slot == 1 or slot == 2 then
		self.Relics["Slot" .. slot] = relicData
		return true
	end
	return false
end


return Baddie