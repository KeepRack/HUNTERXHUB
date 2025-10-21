local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")

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

local cam = workspace.CurrentCamera
local FAR_STUDS = 120000
local keepCamConn

local savedCam = {
	CameraType = cam.CameraType,
	CameraSubject = cam.CameraSubject,
	CFrame = cam.CFrame,
}

local function setFarCamera()
	local pos = Vector3.new(FAR_STUDS, FAR_STUDS, FAR_STUDS)
	local lookAt = pos + Vector3.new(0, 0, -1)
	savedCam.CameraType = cam.CameraType
	savedCam.CameraSubject = cam.CameraSubject
	savedCam.CFrame = cam.CFrame

	cam.CameraType = Enum.CameraType.Scriptable
	cam.CameraSubject = nil
	cam.CFrame = CFrame.new(pos, lookAt)

	if keepCamConn then keepCamConn:Disconnect() end
	keepCamConn = RunService.RenderStepped:Connect(function()
		cam.CameraType = Enum.CameraType.Scriptable
		cam.CameraSubject = nil
		cam.CFrame = CFrame.new(pos, lookAt)
	end)
end

local function restoreCamera()
	if keepCamConn then keepCamConn:Disconnect() keepCamConn = nil end
	cam.CameraType = savedCam.CameraType
	cam.CameraSubject = savedCam.CameraSubject
	cam.CFrame = savedCam.CFrame
end

local function toggleWhiteScreen()
	whiteScreenEnabled = not whiteScreenEnabled

	if whiteScreenEnabled then
		whiteFrame.Visible = true

		for _, gui in pairs(playerGui:GetChildren()) do
			if gui ~= screenGui then
				gui.Enabled = false
			end
		end

		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)
		setFarCamera()

		print("White Screen ON - Camera moved far away - Scripts untouched")
	else
		whiteFrame.Visible = false

		for gui, wasEnabled in pairs(savedGuiStates) do
			if gui and gui.Parent then
				gui.Enabled = wasEnabled
			end
		end

		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, true)
		restoreCamera()

		print("White Screen OFF - Camera restored - Normal Mode")
	end
end

setFarCamera()
StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)
whiteFrame.Visible = true
print("Maximum CPU optimization (camera-only). Press F1 to toggle.")

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if not gameProcessed and input.KeyCode == Enum.KeyCode.F1 then
		toggleWhiteScreen()
	end
end)

player.CharacterAdded:Connect(function()
	if whiteScreenEnabled then
		task.defer(setFarCamera)
	end
end)
