local SettingsController = {}

local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer

-- ============================================
-- 🎵 PENGATURAN BGM (BACKGROUND MUSIC)
-- ============================================
-- MASUKKAN ID LAGU ANDA DI SINI!!!
-- Contoh format: "rbxassetid://ANGKA_ID"
local BGM_ASSET_ID = "rbxassetid://88485966093165" 
-- ============================================

-- Local Settings State
local Config = {
    HideMyBaseBaddies = false,
    HideOthersBaseBaddies = false,
    BGMVolume = 0.5,
    IsMuted = false
}

-- References
local CurrentZonePlot = nil
local PlayerGui = nil
local PlotsFolder = nil
local BGM_Sound = nil

function SettingsController:Init()
    -- Hindari error yield di root, kita letakkan pencarian folder di dalam Init
    PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
    PlotsFolder = Workspace:WaitForChild("Plots")

    -- Setup BGM Audio otomatis ke SoundService
    BGM_Sound = SoundService:FindFirstChild("BGM_Settings_Audio")
    if not BGM_Sound then
        BGM_Sound = Instance.new("Sound")
        BGM_Sound.Name = "BGM_Settings_Audio"
        BGM_Sound.SoundId = BGM_ASSET_ID
        BGM_Sound.Looped = true
        BGM_Sound.Volume = Config.BGMVolume
        BGM_Sound.Parent = SoundService
    else
        BGM_Sound.SoundId = BGM_ASSET_ID
    end

    -- Create Modern Glassmorphism UI
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "SettingsUI"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = PlayerGui

    -- Open Button
    local openBtn = Instance.new("TextButton")
    openBtn.Name = "OpenSettingsBtn"
    openBtn.Size = UDim2.new(0, 50, 0, 50)
    openBtn.Position = UDim2.new(1, -60, 0, 10)
    openBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    openBtn.BackgroundTransparency = 0.5
    openBtn.Text = "⚙️"
    openBtn.TextScaled = true
    openBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    openBtn.Parent = screenGui
    local cornerUIBtn = Instance.new("UICorner", openBtn)
    cornerUIBtn.CornerRadius = UDim.new(1, 0)

    -- Main Panel
    local panel = Instance.new("Frame")
    panel.Name = "MainPanel"
    panel.Size = UDim2.new(0, 350, 0, 260)
    panel.Position = UDim2.new(0.5, -175, 0.5, -130)
    panel.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
    panel.BackgroundTransparency = 0.2
    panel.Visible = false
    panel.Parent = screenGui
    local cornerPanel = Instance.new("UICorner", panel)
    cornerPanel.CornerRadius = UDim.new(0, 12)
    local strokePanel = Instance.new("UIStroke", panel)
    strokePanel.Color = Color3.fromRGB(100, 100, 120)
    strokePanel.Thickness = 1.5

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 40)
    title.Position = UDim2.new(0, 0, 0, 5)
    title.BackgroundTransparency = 1
    title.Text = "SETTINGS & OPTIMIZE"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 20
    title.Parent = panel

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 30, 0, 30)
    closeBtn.Position = UDim2.new(1, -40, 0, 10)
    closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    closeBtn.Text = "X"
    closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.Parent = panel
    Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)

    -- Option: BGM Toggle
    local bgmBtn = Instance.new("TextButton")
    bgmBtn.Size = UDim2.new(0.9, 0, 0, 40)
    bgmBtn.Position = UDim2.new(0.05, 0, 0, 55)
    bgmBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    bgmBtn.Text = "🎵 Mute Background Music: OFF"
    bgmBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    bgmBtn.Font = Enum.Font.GothamSemibold
    bgmBtn.TextSize = 14
    bgmBtn.Parent = panel
    Instance.new("UICorner", bgmBtn).CornerRadius = UDim.new(0, 6)

    -- Option: Hide My Base Baddies
    local hideMyBtn = Instance.new("TextButton")
    hideMyBtn.Size = UDim2.new(0.9, 0, 0, 40)
    hideMyBtn.Position = UDim2.new(0.05, 0, 0, 105)
    hideMyBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    hideMyBtn.Text = "👁️ Hide My Base Baddies: OFF"
    hideMyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    hideMyBtn.Font = Enum.Font.GothamSemibold
    hideMyBtn.TextSize = 14
    hideMyBtn.Parent = panel
    Instance.new("UICorner", hideMyBtn).CornerRadius = UDim.new(0, 6)

    -- Option: Hide Others Base Baddies
    local hideOtherBtn = Instance.new("TextButton")
    hideOtherBtn.Size = UDim2.new(0.9, 0, 0, 40)
    hideOtherBtn.Position = UDim2.new(0.05, 0, 0, 155)
    hideOtherBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    hideOtherBtn.Text = "👁️ Hide Others Baddies: OFF"
    hideOtherBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    hideOtherBtn.Font = Enum.Font.GothamSemibold
    hideOtherBtn.TextSize = 14
    hideOtherBtn.Parent = panel
    Instance.new("UICorner", hideOtherBtn).CornerRadius = UDim.new(0, 6)
    
    local disclaimer = Instance.new("TextLabel")
    disclaimer.Size = UDim2.new(0.9, 0, 0, 30)
    disclaimer.Position = UDim2.new(0.05, 0, 0, 210)
    disclaimer.BackgroundTransparency = 1
    disclaimer.Text = "*Baddies you hid will automatically fade IN if you enter their plot area."
    disclaimer.TextColor3 = Color3.fromRGB(150, 150, 150)
    disclaimer.Font = Enum.Font.GothamMedium
    disclaimer.TextSize = 12
    disclaimer.TextWrapped = true
    disclaimer.Parent = panel

    -- Logic Buttons
    openBtn.MouseButton1Click:Connect(function()
        panel.Visible = not panel.Visible
    end)
    closeBtn.MouseButton1Click:Connect(function()
        panel.Visible = false
    end)

    bgmBtn.MouseButton1Click:Connect(function()
        Config.IsMuted = not Config.IsMuted
        bgmBtn.Text = "🎵 Mute Background Music: " .. (Config.IsMuted and "ON" or "OFF")
        bgmBtn.BackgroundColor3 = Config.IsMuted and Color3.fromRGB(150, 60, 60) or Color3.fromRGB(40, 40, 50)
        
        if BGM_Sound then
            BGM_Sound.Volume = Config.IsMuted and 0 or Config.BGMVolume
        end
    end)

    hideMyBtn.MouseButton1Click:Connect(function()
        Config.HideMyBaseBaddies = not Config.HideMyBaseBaddies
        hideMyBtn.Text = "👁️ Hide My Base Baddies: " .. (Config.HideMyBaseBaddies and "ON" or "OFF")
        hideMyBtn.BackgroundColor3 = Config.HideMyBaseBaddies and Color3.fromRGB(60, 120, 60) or Color3.fromRGB(40, 40, 50)
        self:ForceUpdateVisuals()
    end)

    hideOtherBtn.MouseButton1Click:Connect(function()
        Config.HideOthersBaseBaddies = not Config.HideOthersBaseBaddies
        hideOtherBtn.Text = "👁️ Hide Others Baddies: " .. (Config.HideOthersBaseBaddies and "ON" or "OFF")
        hideOtherBtn.BackgroundColor3 = Config.HideOthersBaseBaddies and Color3.fromRGB(60, 120, 60) or Color3.fromRGB(40, 40, 50)
        self:ForceUpdateVisuals()
    end)
end

function SettingsController:ForceUpdateVisuals()
    if not PlotsFolder then return end
    for _, plot in ipairs(PlotsFolder:GetChildren()) do
        self:UpdatePlotVisuals(plot)
    end
end

function SettingsController:UpdatePlotVisuals(plot)
    local isMyPlot = false
    local ownerVal = plot:FindFirstChild("Owner")
    if ownerVal and ownerVal.Value == LocalPlayer.Name then
        isMyPlot = true
    end

    local shouldHide = false
    
    if plot ~= CurrentZonePlot then
        if isMyPlot and Config.HideMyBaseBaddies then
            shouldHide = true
        elseif not isMyPlot and Config.HideOthersBaseBaddies then
            shouldHide = true
        end
    end

    local targetTransparency = shouldHide and 1 or 0
    
    local slotsFolder = plot:FindFirstChild("Slots")
    if slotsFolder then
        -- Iterate through each specific slot (e.g. Slot1, Slot2) to find SlotBaddie
        for _, slot in ipairs(slotsFolder:GetChildren()) do
            for _, baddieGroup in ipairs(slot:GetChildren()) do
                if baddieGroup.Name == "SlotBaddie" then
                    -- Hide mesh parts using LocalTransparencyModifier to not break physical traits
                    for _, part in ipairs(baddieGroup:GetDescendants()) do
                        if part:IsA("BasePart") or part:IsA("Decal") then
                            part.LocalTransparencyModifier = targetTransparency
                        elseif part:IsA("BillboardGui") then
                            if part.Name == "Stats" or part.Name == "BaddieInfo" then
                                part.Enabled = not shouldHide
                            end
                        end
                    end
                end
            end
        end
    end
end

function SettingsController:Start()
    if BGM_Sound and not BGM_Sound.IsPlaying then
        BGM_Sound:Play()
    end

    -- Proximity Loop Check (Performance heavy so we do it slowly)
    task.spawn(function()
        while true do
            task.wait(0.5)
            
            local char = LocalPlayer.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            
            if not root or not PlotsFolder then
                CurrentZonePlot = nil
                self:ForceUpdateVisuals()
                continue
            end
            
            local closestPlot = nil
            local minDistance = 120 -- Radius threshold (studs)
            
            for _, plot in ipairs(PlotsFolder:GetChildren()) do
                local core = plot:FindFirstChild("CoreMechanics")
                local spawnPt = core and core:FindFirstChild("SpawnPoint")
                
                if spawnPt then
                    local dist = (root.Position - spawnPt.Position).Magnitude
                    if dist < minDistance then
                        minDistance = dist
                        closestPlot = plot
                    end
                end
            end
            
            if CurrentZonePlot ~= closestPlot then
                CurrentZonePlot = closestPlot
                -- Update visuals because zone changed!
                self:ForceUpdateVisuals()
            end
        end
    end)
    
    -- Detect newly added/removed baddies in plots dynamically
    if PlotsFolder then
        for _, plot in ipairs(PlotsFolder:GetChildren()) do
            local slotsFolder = plot:FindFirstChild("Slots")
            if slotsFolder then
                slotsFolder.DescendantAdded:Connect(function(descendant)
                    if descendant.Name == "SlotBaddie" then
                        task.wait(0.2) -- allow children (parts/meshes) to load before checking
                        self:UpdatePlotVisuals(plot)
                    end
                end)
            end
        end
    end
end

return SettingsController
