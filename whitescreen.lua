local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local whiteScreenEnabled = true
local savedGuiStates = {}

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "WhiteScreenMax"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 999999
screenGui.Parent = playerGui

local whiteFrame = Instance.new("Frame")
whiteFrame.Size = UDim2.new(1, 0, 1, 0)
whiteFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
whiteFrame.BorderSizePixel = 0
whiteFrame.Parent = screenGui

for _, gui in pairs(playerGui:GetChildren()) do
    if gui ~= screenGui then
        savedGuiStates[gui] = gui.Enabled
        gui.Enabled = false
    end
end

local function toggleWhiteScreen()
    whiteScreenEnabled = not whiteScreenEnabled
    
    if whiteScreenEnabled then
        RunService:Set3dRenderingEnabled(false)
        whiteFrame.Visible = true

        for _, gui in pairs(playerGui:GetChildren()) do
            if gui ~= screenGui then
                gui.Enabled = false
            end
        end

        local StarterGui = game:GetService("StarterGui")
        StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)

        settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
        workspace.StreamingEnabled = false

        if player.Character then
            for _, part in pairs(player.Character:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                    part.Anchored = true
                elseif part:IsA("Script") or part:IsA("LocalScript") then
                    part.Enabled = false
                end
            end
        end
        
        workspace:SetAttribute("PhysicsDisabled", true)
        
        print("White Screen ON - 3D Rendering OFF - CPU Optimized")
    else
        RunService:Set3dRenderingEnabled(true)
        whiteFrame.Visible = false

        for gui, wasEnabled in pairs(savedGuiStates) do
            if gui and gui.Parent then
                gui.Enabled = wasEnabled
            end
        end

        local StarterGui = game:GetService("StarterGui")
        StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, true)

        settings().Rendering.QualityLevel = Enum.QualityLevel.Automatic
        workspace.StreamingEnabled = true

        if player.Character then
            for _, part in pairs(player.Character:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.Anchored = false
                elseif part:IsA("Script") or part:IsA("LocalScript") then
                    part.Enabled = true
                end
            end
        end
        
        workspace:SetAttribute("PhysicsDisabled", false)
        
        print("White Screen OFF - 3D Rendering ON - Normal Mode")
    end
end

RunService:Set3dRenderingEnabled(false)
local StarterGui = game:GetService("StarterGui")
StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)
workspace.StreamingEnabled = false
settings().Rendering.QualityLevel = Enum.QualityLevel.Level01

if player.Character then
    for _, part in pairs(player.Character:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = false
            part.Anchored = true
        elseif part:IsA("Script") or part:IsA("LocalScript") then
            part.Enabled = false
        end
    end
end

workspace:SetAttribute("PhysicsDisabled", true)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed and input.KeyCode == Enum.KeyCode.F1 then
        toggleWhiteScreen()
    end
end)

print("Maximum CPU optimization complete - Press F1 to toggle - 3D Rendering OFF")
