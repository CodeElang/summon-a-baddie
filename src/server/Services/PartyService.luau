local PartyService = {}
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataService = require(script.Parent.DataService)
local Network = ReplicatedStorage.Network

local SwapPartyEvent = Network:FindFirstChild("SwapPartySlot") or Instance.new("RemoteFunction")
SwapPartyEvent.Name = "SwapPartySlot"
SwapPartyEvent.Parent = Network

function PartyService:Init() end

function PartyService:Start()
	SwapPartyEvent.OnServerInvoke = function(player, slotNum, targetBaddieId)
		local profile = DataService:GetProfile(player)
		if not profile then return false end

		if not profile.Data.Party then
			profile.Data.Party = {Slot1="", Slot2="", Slot3="", Slot4=""}
		end
		if not profile.Data.CombatHotbar then
			profile.Data.CombatHotbar = {Slot1="", Slot2="", Slot3="", Slot4="", Slot5="", Slot6="", Slot7="", Slot8=""}
		end

		local partySlotKey = "Slot" .. tostring(slotNum)
		-- Simpan data Baddie yang saat ini ada di slot Party
		local oldPartyBaddieId = profile.Data.Party[partySlotKey]

		if targetBaddieId == "" or targetBaddieId == nil then
			profile.Data.Party[partySlotKey] = ""
		else
			local hasBaddie = false
			for _, b in ipairs(profile.Data.Baddies) do
				if b.Id == targetBaddieId then hasBaddie = true break end
			end
			if not hasBaddie then return false end

			-- Cari dari Hotbar mana Baddie ini berasal
			local sourceHotbarKey = nil
			for k, v in pairs(profile.Data.CombatHotbar) do
				if v == targetBaddieId then
					sourceHotbarKey = k
					break
				end
			end

			-- Hapus Baddie ini jika dia terpasang di Slot Party lain (mencegah duplikat internal)
			for k, v in pairs(profile.Data.Party) do
				if k ~= partySlotKey and v == targetBaddieId then 
					profile.Data.Party[k] = "" 
				end
			end

			-- EKSEKUSI SWAP
			profile.Data.Party[partySlotKey] = targetBaddieId

			if sourceHotbarKey then
				-- Jika berasal dari Hotbar, taruh Baddie Party yang lama ke Hotbar tersebut
				profile.Data.CombatHotbar[sourceHotbarKey] = oldPartyBaddieId or ""
			end
		end

		return true
	end
end

return PartyService