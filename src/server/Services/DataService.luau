local DataService = {}
DataService.Profiles = {}

local Players = game:GetService("Players")

local ServerScriptService = game:GetService("ServerScriptService")
local ProfileService = require(ServerScriptService:WaitForChild("Modules"):WaitForChild("ProfileService"))

local ProfileTemplate = {
	Cash = 0,
	Baddies = {},
	EquippedBaddies = {},
	CombatHotbar = {Slot1="", Slot2="", Slot3="", Slot4="", Slot5="", Slot6="", Slot7="", Slot8=""},
	Party = {Slot1="", Slot2="", Slot3="", Slot4=""},
	RebirthLevel = 0,
	LuckBoost = 1,
	Upgrades = {},
	PersonalShop = {},
	Books = {},
	EquippedPets = {},
	ActiveBuffs = {}
}

local ProfileStore = ProfileService.GetProfileStore(
	"SummonABaddieDataStore_v1",
	ProfileTemplate
)

function DataService:Init()
	print("[DataService] Init")
end

function DataService:Start()
	print("[DataService] Start")
	
	local function PlayerAdded(player)
		local profile = ProfileStore:LoadProfileAsync("Player_" .. player.UserId)
		if profile ~= nil then
			profile:AddUserId(player.UserId)
			profile:Reconcile()
			
			profile:ListenToRelease(function()
				DataService.Profiles[player] = nil
				player:Kick("Profile was loaded in another Roblox server. Please rejoin.")
			end)
			
			if player:IsDescendantOf(Players) == true then
				DataService.Profiles[player] = profile
			else
				profile:Release()
			end
		else
			player:Kick("Profile could not be loaded. Please try rejoining.")
		end
	end
	
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(PlayerAdded, player)
	end
	
	Players.PlayerAdded:Connect(PlayerAdded)
	
	Players.PlayerRemoving:Connect(function(player)
		local profile = DataService.Profiles[player]
		if profile ~= nil then
			profile:Release()
		end
	end)
end

function DataService:GetProfile(player)
	return DataService.Profiles[player]
end

function DataService:WaitForProfile(player)
	local timeout = 15
	local timeElapsed = 0
	while not DataService.Profiles[player] and timeElapsed < timeout do
		task.wait(0.1)
		timeElapsed += 0.1
		if not player or not player.Parent then
			return nil
		end
	end
	return DataService.Profiles[player]
end

return DataService
