local LeaderstatsService = {}

local Players = game:GetService("Players")
local DataService = require(script.Parent.DataService)

function LeaderstatsService:Init() end

function LeaderstatsService:Start()
	Players.PlayerAdded:Connect(function(player)
		local leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player

		-- Order matters: Rebirths first, then Cash
		local rebirths = Instance.new("IntValue")
		rebirths.Name = "Rebirths"
		rebirths.Parent = leaderstats

		local cash = Instance.new("NumberValue") 
		cash.Name = "Cash"
		cash.Parent = leaderstats
	end)

	-- Sync data every 2 seconds to avoid lag
	task.spawn(function()
		while true do
			task.wait(2)
			for _, player in ipairs(Players:GetPlayers()) do
				local profile = DataService:GetProfile(player)
				if profile then
					local leaderstats = player:FindFirstChild("leaderstats")
					if leaderstats then
						leaderstats.Rebirths.Value = profile.Data.RebirthLevel
						leaderstats.Cash.Value = profile.Data.Cash
					end
				end
			end
		end
	end)
end

return LeaderstatsService