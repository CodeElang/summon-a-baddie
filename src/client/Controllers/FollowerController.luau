local FollowerController = {}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local FormatNumber = require(ReplicatedStorage.Shared.Utils.FormatNumber)

local Network = ReplicatedStorage.Network
local GetInvEvent = Network:WaitForChild("GetInventory")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local FOLLOWER_GROUP = "FollowerBaddies"
local partyBaddies = {}
local partyBaddieFolder = workspace:FindFirstChild("LocalFollowers") or Instance.new("Folder")
partyBaddieFolder.Name = "LocalFollowers"
partyBaddieFolder.Parent = workspace

pcall(function()
	PhysicsService:RegisterCollisionGroup(FOLLOWER_GROUP)
end)
pcall(function()
	PhysicsService:CollisionGroupSetCollidable(FOLLOWER_GROUP, FOLLOWER_GROUP, false)
end)

function FollowerController:Init() end

function FollowerController:Start()
	local baseOffsets = {
		Vector3.new(-4, 0, 4),
		Vector3.new(4, 0, 4),
		Vector3.new(-7, 0, 7),
		Vector3.new(7, 0, 7)
	}

	local function CreatePartyBaddieBillboard(model, baddieData, tierCfg, baddieCfg)
		local head = model:FindFirstChild("Head", true) or model.PrimaryPart
		if not head then return end

		if head:FindFirstChild("PartyBaddieStats") then head.PartyBaddieStats:Destroy() end

		local chanceDisplay = "1 in " .. FormatNumber.Format(baddieCfg.Chance)

		local bb = Instance.new("BillboardGui")
		bb.Name = "PartyBaddieStats"
		bb.Size = UDim2.new(5, 0, 2.5, 0)
		bb.StudsOffset = Vector3.new(0, 3.5, 0)
		bb.AlwaysOnTop = false
		bb.MaxDistance = 75

		local tName = Instance.new("TextLabel", bb)
		tName.Size = UDim2.new(1, 0, 0.4, 0)
		tName.BackgroundTransparency = 1
		tName.TextColor3 = Color3.fromRGB(255, 255, 255)
		tName.Font = Enum.Font.GothamBlack
		tName.TextScaled = true
		tName.Text = baddieData.Name
		tName.TextStrokeTransparency = 0.2

		local tTier = Instance.new("TextLabel", bb)
		tTier.Size = UDim2.new(1, 0, 0.3, 0)
		tTier.Position = UDim2.new(0, 0, 0.4, 0)
		tTier.BackgroundTransparency = 1
		tTier.TextColor3 = tierCfg.Color
		tTier.Font = Enum.Font.GothamBold
		tTier.TextScaled = true
		tTier.Text = baddieData.Rarity .. " (" .. chanceDisplay .. ")"
		tTier.TextStrokeTransparency = 0.4

		bb.Parent = head
	end

	local function SetupGhostCollision(partyBaddieModel)
		local baddieRoot = partyBaddieModel:FindFirstChild("HumanoidRootPart")
		if not baddieRoot then return end

		for _, desc in ipairs(partyBaddieModel:GetDescendants()) do
			if desc:IsA("BasePart") then
				if desc.Name ~= "HumanoidRootPart" then
					desc.CanCollide = false
				else
					pcall(function()
						desc.CollisionGroup = FOLLOWER_GROUP
					end)
				end
			end
		end

		for _, p in ipairs(Players:GetPlayers()) do
			local char = p.Character
			if char then
				for _, part in ipairs(char:GetDescendants()) do
					if part:IsA("BasePart") then
						local nc = Instance.new("NoCollisionConstraint")
						nc.Part0 = baddieRoot
						nc.Part1 = part
						nc.Parent = partyBaddieModel
					end
				end
			end
		end
	end

	local function SpawnPartyBaddies()
		local baddies, _, _, partyData = GetInvEvent:InvokeServer()
		if not baddies or not partyData then return false end

		for _, partyBaddieData in ipairs(partyBaddies) do
			if partyBaddieData.Model then partyBaddieData.Model:Destroy() end
		end
		partyBaddies = {}

		local baddieDict = {}
		for _, b in ipairs(baddies) do baddieDict[b.Id] = b end

		for i = 1, 4 do
			local baddieId = partyData["Slot"..i]
			if baddieId and baddieId ~= "" and baddieDict[baddieId] then
				local bData = baddieDict[baddieId]
				local bCfg = GameConfig.GetBaddieData(bData.Name)
				local tierCfg = GameConfig.Tiers[bData.Rarity]

				if bCfg and tierCfg then
					local sourceFolder = ReplicatedStorage.Baddies:FindFirstChild(tierCfg.Folder)
					local sourceTool = sourceFolder and sourceFolder:FindFirstChild(bData.Name)

					if sourceTool then
						local minionCounter = 0

						for _, childModel in ipairs(sourceTool:GetChildren()) do
							if childModel:IsA("Model") and string.find(childModel.Name, "VisualModel") then

								local partyBaddieClone = childModel:Clone()
								partyBaddieClone.Name = "PartyBaddie_" .. baddieId .. "_" .. childModel.Name

								for _, desc in ipairs(partyBaddieClone:GetDescendants()) do
									if desc:IsA("WeldConstraint") or desc:IsA("Weld") then
										if (desc.Part0 and desc.Part0.Name == "Handle") or (desc.Part1 and desc.Part1.Name == "Handle") then
											desc:Destroy()
										end
									end

									if desc:IsA("BasePart") then
										desc.Anchored = false
									elseif desc:IsA("Humanoid") then
										desc.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
										desc.WalkSpeed = 16
									end
								end

								CreatePartyBaddieBillboard(partyBaddieClone, bData, tierCfg, bCfg)

								local baddieRootPart = partyBaddieClone:FindFirstChild("HumanoidRootPart") or partyBaddieClone.PrimaryPart
								local playerRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")

								local uniqueOffset = baseOffsets[i]
								if minionCounter > 0 then
									uniqueOffset = uniqueOffset + Vector3.new(3 * minionCounter, 0, 0)
								end

								if baddieRootPart and playerRoot then
									partyBaddieClone:PivotTo(playerRoot.CFrame * CFrame.new(uniqueOffset))
								end

								partyBaddieClone.Parent = partyBaddieFolder

								SetupGhostCollision(partyBaddieClone)

								local hum = partyBaddieClone:FindFirstChildOfClass("Humanoid")
								local animator = hum and (hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum))

								if hum and animator then
									local idleTrack, walkTrack
									local idleAnim = partyBaddieClone:FindFirstChild("IdleAnim", true)
									local walkAnim = partyBaddieClone:FindFirstChild("WalkAnim", true)

									if idleAnim then
										idleTrack = animator:LoadAnimation(idleAnim)
										idleTrack.Looped = true
										idleTrack:Play()
									end
									if walkAnim then
										walkTrack = animator:LoadAnimation(walkAnim)
										walkTrack.Looped = true
									end

									hum.Running:Connect(function(speed)
										if speed > 0.5 then
											if walkTrack and not walkTrack.IsPlaying then
												if idleTrack then idleTrack:Stop() end
												walkTrack:Play()
											end
										else
											if idleTrack and not idleTrack.IsPlaying then
												if walkTrack then walkTrack:Stop() end
												idleTrack:Play()
											end
										end
									end)
								end

								table.insert(partyBaddies, {
									Model = partyBaddieClone,
									Humanoid = hum,
									RootPart = baddieRootPart,
									TargetOffset = uniqueOffset
								})

								minionCounter += 1
							end
						end
					end
				end
			end
		end
		return true
	end

	local function SafeSpawnPartyBaddies()
		task.spawn(function()
			local attempts = 0
			while attempts < 10 do
				local success = SpawnPartyBaddies()
				if success then break end
				attempts += 1
				task.wait(1)
			end
		end)
	end

	Players.PlayerAdded:Connect(function(newPlayer)
		newPlayer.CharacterAdded:Connect(function(newChar)
			task.wait(1)
			for _, partyBaddieData in ipairs(partyBaddies) do
				local partyBaddieModel = partyBaddieData.Model
				if not partyBaddieModel then continue end

				local baddieRoot = partyBaddieModel:FindFirstChild("HumanoidRootPart")
				if not baddieRoot then continue end

				for _, part in ipairs(newChar:GetDescendants()) do
					if part:IsA("BasePart") then
						local nc = Instance.new("NoCollisionConstraint")
						nc.Part0 = baddieRoot
						nc.Part1 = part
						nc.Parent = partyBaddieModel
					end
				end
			end
		end)
	end)

	task.spawn(function()
		while task.wait(0.5) do
			local char = player.Character
			if not char or not char:FindFirstChild("HumanoidRootPart") then continue end

			local rootPos = char.HumanoidRootPart.CFrame

			local mainUI = playerGui:FindFirstChild("MainUI")
			local isCombat = mainUI and mainUI:FindFirstChild("TurnIndicator") and mainUI.TurnIndicator.Visible

			for _, partyBaddieData in ipairs(partyBaddies) do
				local model = partyBaddieData.Model
				local hum = partyBaddieData.Humanoid
				local root = partyBaddieData.RootPart
				local targetOffset = partyBaddieData.TargetOffset

				if model and hum and root then
					if isCombat then
						hum:MoveTo(root.Position)
						model:PivotTo(CFrame.new(0, -500, 0))
					else
						local targetCFrame = rootPos * CFrame.new(targetOffset)
						local targetPos = targetCFrame.Position

						local distance = (root.Position - char.HumanoidRootPart.Position).Magnitude

						if distance > 40 then
							model:PivotTo(targetCFrame)
						elseif distance > 3 then
							hum:MoveTo(targetPos)
						end
					end
				end
			end
		end
	end)

	player.CharacterAdded:Connect(function()
		SafeSpawnPartyBaddies()
	end)

	if player.Character then
		SafeSpawnPartyBaddies()
	end

	playerGui:GetAttributeChangedSignal("ForcePartyRefresh"):Connect(function()
		SpawnPartyBaddies()
	end)
end

return FollowerController