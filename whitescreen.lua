local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer
local cam = workspace.CurrentCamera

local whiteScreenEnabled = true
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

local function toggleFarMode()
	whiteScreenEnabled = not whiteScreenEnabled
	if whiteScreenEnabled then
		setFarCamera()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)
		print("Far Camera ON - Rendering minimized - Scripts untouched")
	else
		restoreCamera()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, true)
		print("Far Camera OFF - Normal mode")
	end
end

setFarCamera()
StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)
print("Far Camera optimization active. Press F1 to toggle.")

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if not gameProcessed and input.KeyCode == Enum.KeyCode.F1 then
		toggleFarMode()
	end
end)

player.CharacterAdded:Connect(function()
	if whiteScreenEnabled then
		task.defer(setFarCamera)
	end
end)
