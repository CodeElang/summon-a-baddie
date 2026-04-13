local AdminController = {}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NetworkFolder = ReplicatedStorage:WaitForChild("Network")
local AdminActionEvent = NetworkFolder:WaitForChild("AdminAction")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local isFlying = false
local flySpeed = 50
local flyBodyVelocity = nil
local flyBodyGyro = nil

function AdminController:Init() end

function AdminController:Start()
	player.CharacterAdded:Connect(function(newChar)
		local hum = newChar:WaitForChild("Humanoid", 5)
		if hum then camera.CameraSubject = hum end
	end)

	local playerGui = player:WaitForChild("PlayerGui")

	task.spawn(function()
		local adminUI = playerGui:WaitForChild("AdminPanelUI", 10)
		if not adminUI then return end

		local main = adminUI:WaitForChild("Main")
		local toggleBtnHUD = adminUI:WaitForChild("ToggleBtnHUD")
		local selector = adminUI:WaitForChild("SelectorPanel")

		local localPage = main:WaitForChild("LocalPage")
		local serverPage = main:WaitForChild("ServerPage")
		local localTab = main.Sidebar:WaitForChild("LocalTab")
		local serverTab = main.Sidebar:WaitForChild("ServerTab")

		local globalTarget = ""
		local selectedBaddie = ""
		local selectedBook = ""

		-- Toggle Logic
		toggleBtnHUD.MouseButton1Click:Connect(function() main.Visible = not main.Visible end)
		main.TopBar.CloseBtn.MouseButton1Click:Connect(function() main.Visible = false end)
		selector.CloseBtn.MouseButton1Click:Connect(function() selector.Visible = false end)

		local function switchTab(tabName)
			localPage.Visible = (tabName == "Local")
			serverPage.Visible = (tabName == "Server")
			localTab.BackgroundColor3 = tabName == "Local" and Color3.fromRGB(194, 26, 77) or Color3.fromRGB(30, 30, 30)
			serverTab.BackgroundColor3 = tabName == "Server" and Color3.fromRGB(194, 26, 77) or Color3.fromRGB(30, 30, 30)
			localTab.TextColor3 = tabName == "Local" and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(150, 150, 150)
			serverTab.TextColor3 = tabName == "Server" and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(150, 150, 150)
		end
		localTab.MouseButton1Click:Connect(function() switchTab("Local") end)
		serverTab.MouseButton1Click:Connect(function() switchTab("Server") end)

		-- Selector Logic
		local function openSelector(titleText, items, callback)
			selector.Title.Text = titleText
			for _, child in ipairs(selector.ItemList:GetChildren()) do
				if child:IsA("TextButton") then child:Destroy() end
			end

			selector.ItemList.AutomaticCanvasSize = Enum.AutomaticSize.Y
			selector.ItemList.CanvasSize = UDim2.new(0, 0, 0, 0)

			for _, itemName in ipairs(items) do
				local btn = Instance.new("TextButton", selector.ItemList)
				btn.Size = UDim2.new(1, 0, 0, 30)
				btn.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
				btn.TextColor3 = Color3.fromRGB(255, 255, 255)
				btn.Font = Enum.Font.GothamMedium
				btn.TextSize = 13
				btn.Text = itemName
				btn.ZIndex = 15 
				Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)

				btn.MouseButton1Click:Connect(function()
					selector.Visible = false
					callback(itemName)
				end)
			end
			selector.Visible = true
		end

		-- Baddie Dropdown
		serverPage.BaddieGroup.SelectBtn.MouseButton1Click:Connect(function()
			local baddieList = {}
			local baddiesFolder = ReplicatedStorage:FindFirstChild("Baddies")

			if baddiesFolder then
				for _, tier in ipairs(baddiesFolder:GetChildren()) do
					for _, baddie in ipairs(tier:GetChildren()) do
						if baddie:IsA("Tool") or baddie:IsA("Model") then 
							table.insert(baddieList, baddie.Name) 
						end
					end
				end
			end
			table.sort(baddieList)
			openSelector("SELECT BADDIE", baddieList, function(chosen)
				selectedBaddie = chosen
				serverPage.BaddieGroup.SelectBtn.Text = chosen
			end)
		end)

		serverPage.BaddieGroup.ActionBtn.MouseButton1Click:Connect(function()
			if selectedBaddie ~= "" then
				AdminActionEvent:FireServer("GiveBaddie", { TargetName = globalTarget, Value = selectedBaddie, Amount = serverPage.BaddieGroup.AmountInput.Text })
			end
		end)

		-- Book Dropdown
		local availableBooks = {"Basic", "Advanced", "Mystic", "Ethereal", "Celestial", "Sovereign", "Transcendant"}
		serverPage.BookGroup.SelectBtn.MouseButton1Click:Connect(function()
			openSelector("SELECT BOOK", availableBooks, function(chosen)
				selectedBook = chosen
				serverPage.BookGroup.SelectBtn.Text = chosen .. " Book"
			end)
		end)

		serverPage.BookGroup.ActionBtn.MouseButton1Click:Connect(function()
			if selectedBook ~= "" then
				AdminActionEvent:FireServer("GiveBook", { TargetName = globalTarget, Value = selectedBook, Amount = serverPage.BookGroup.AmountInput.Text })
			end
		end)

		-- Standard Actions
		serverPage.TargetGroup.ActionBtn.MouseButton1Click:Connect(function()
			globalTarget = serverPage.TargetGroup.Input.Text
			serverPage.TargetGroup.ActionBtn.Text = "TARGET: " .. (globalTarget == "" and "SELF" or globalTarget)
		end)

		serverPage.GiveCashGroup.ActionBtn.MouseButton1Click:Connect(function() AdminActionEvent:FireServer("GiveCash", { TargetName = globalTarget, Value = serverPage.GiveCashGroup.Input.Text }) end)
		serverPage.SetLuckGroup.ActionBtn.MouseButton1Click:Connect(function() AdminActionEvent:FireServer("SetLuck", { TargetName = globalTarget, Value = serverPage.SetLuckGroup.Input.Text }) end)
		serverPage.TeleportGroup.ActionBtn.MouseButton1Click:Connect(function() AdminActionEvent:FireServer("Teleport", { Value = serverPage.TeleportGroup.Input.Text }) end)

		local setRebirthGroup = serverPage:WaitForChild("SetRebirthGroup")
		if setRebirthGroup then
			setRebirthGroup.ActionBtn.MouseButton1Click:Connect(function() 
				AdminActionEvent:FireServer("SetRebirth", { TargetName = globalTarget, Value = setRebirthGroup.Input.Text }) 
			end)
		end

		-- Data Wipe Actions
		serverPage:WaitForChild("ResetCashBtn").MouseButton1Click:Connect(function() AdminActionEvent:FireServer("ResetCash", { TargetName = globalTarget }) end)
		serverPage:WaitForChild("ResetBaddiesBtn").MouseButton1Click:Connect(function() AdminActionEvent:FireServer("ResetBaddies", { TargetName = globalTarget }) end)
		serverPage:WaitForChild("WipeAllBtn").MouseButton1Click:Connect(function() AdminActionEvent:FireServer("WipeAll", { TargetName = globalTarget }) end)

		local resetRebirthBtn = serverPage:FindFirstChild("ResetRebirthBtn")
		if resetRebirthBtn then
			resetRebirthBtn.MouseButton1Click:Connect(function() AdminActionEvent:FireServer("ResetRebirth", { TargetName = globalTarget }) end)
		end

		-- 🔥 NEW: Reset Abilities Event Logic 🔥
		local resetAbilitiesBtn = serverPage:FindFirstChild("ResetAbilitiesBtn")
		if resetAbilitiesBtn then
			resetAbilitiesBtn.MouseButton1Click:Connect(function() AdminActionEvent:FireServer("ResetAbilities", { TargetName = globalTarget }) end)
		end

		-- Local Page Logic
		localPage.MorphGroup.ActionBtn.MouseButton1Click:Connect(function() AdminActionEvent:FireServer("Morph", { Value = localPage.MorphGroup.Input.Text }) end)

		local function setupSlider(sliderFrame, commandName, maxVal)
			local track = sliderFrame.Track
			local fill = track.Fill
			local valLbl = sliderFrame.ValueLabel
			local isDragging = false

			local function updateSlider(input)
				local relativeX = math.clamp((input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
				fill.Size = UDim2.new(relativeX, 0, 1, 0)
				local val = math.floor(relativeX * maxVal)
				valLbl.Text = tostring(val)
				AdminActionEvent:FireServer(commandName, { Value = val })
			end

			track.MouseButton1Down:Connect(function() isDragging = true end)
			UserInputService.InputEnded:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then isDragging = false end end)
			UserInputService.InputChanged:Connect(function(input) if isDragging and input.UserInputType == Enum.UserInputType.MouseMovement then updateSlider(input) end end)
		end

		setupSlider(localPage:WaitForChild("Walk SpeedSlider"), "SetSpeed", 250)
		setupSlider(localPage:WaitForChild("Jump PowerSlider"), "SetJump", 500)

		-- Fly Logic
		local flyCheckbox = localPage:WaitForChild("Fly ModeToggle").Checkbox
		flyCheckbox.MouseButton1Click:Connect(function()
			isFlying = not isFlying
			flyCheckbox.BackgroundColor3 = isFlying and Color3.fromRGB(194, 26, 77) or Color3.fromRGB(40, 40, 40)

			local char = player.Character
			if not char then return end
			local root = char:FindFirstChild("HumanoidRootPart")
			if not root then return end

			if isFlying then
				flyBodyVelocity = Instance.new("BodyVelocity")
				flyBodyVelocity.MaxForce = Vector3.new(100000, 100000, 100000)
				flyBodyVelocity.Parent = root
				flyBodyGyro = Instance.new("BodyGyro")
				flyBodyGyro.MaxTorque = Vector3.new(100000, 100000, 100000)
				flyBodyGyro.P = 10000
				flyBodyGyro.Parent = root
			else
				if flyBodyVelocity then flyBodyVelocity:Destroy() end
				if flyBodyGyro then flyBodyGyro:Destroy() end
			end
		end)

		RunService.RenderStepped:Connect(function()
			if isFlying and player.Character and flyBodyVelocity and flyBodyGyro then
				local root = player.Character:FindFirstChild("HumanoidRootPart")
				local hum = player.Character:FindFirstChildOfClass("Humanoid")
				if not root or not hum then return end

				local moveDir = hum.MoveDirection
				if moveDir.Magnitude > 0 then flyBodyVelocity.Velocity = camera.CFrame.LookVector * flySpeed else flyBodyVelocity.Velocity = Vector3.new(0, 0, 0) end
				flyBodyGyro.CFrame = camera.CFrame
			end
		end)
	end)
end

return AdminController