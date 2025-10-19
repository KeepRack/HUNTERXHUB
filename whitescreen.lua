local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local screenGui = Instance.new("ScreenGui")
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 999999

local whiteFrame = Instance.new("Frame")
whiteFrame.Size = UDim2.new(1, 0, 1, 0)
whiteFrame.BackgroundColor3 = Color3.new(1, 1, 1)
whiteFrame.BorderSizePixel = 0
whiteFrame.Parent = screenGui

screenGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable
workspace.CurrentCamera.CFrame = CFrame.new(0, 999999, 0)

game:GetService("Lighting").GlobalShadows = false
game:GetService("Lighting").FogEnd = 0
game:GetService("Lighting").Brightness = 0

settings().Rendering.QualityLevel = Enum.QualityLevel.Level01

RunService:Set3dRenderingEnabled(false)

for _, connection in next, getconnections(RunService.Heartbeat) do
    connection:Disable()
end

for _, connection in next, getconnections(RunService.RenderStepped) do
    connection:Disable()
end

for _, connection in next, getconnections(RunService.Stepped) do
    connection:Disable()
end
