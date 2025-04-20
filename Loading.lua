local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local HUNTER_X = {
    Paths = {
        RewardsUIPath = nil
    },
    States = {
        ClickActive = false,
        RetryActionExecuted = false,
        GameEnded = false,
        WaitingForYen = false,
        YenTargetAmount = 0,
        CurrentYen = 0,
        UpgradeTarget = nil
    },
    PrintFlags = {
        ClickStarted = false,
        ClickStopped = false,
        ClickFunction = false
    },
    UnitUpgrade = {
        paused = false,
        lastPausedReason = "",
        upgradeInProgress = false
    },
    Services = {
        VirtualInputManager = game:GetService("VirtualInputManager")
    },
    Config = {
        YenCheckInterval = 0.5,
        UpgradeRetryInterval = 1.0,
        MaxUpgradeAttempts = 3,
        AfterGameDelay = 5,
        DebugMode = false,
        LoadingDelay = 5
    },
    Loading = {
        Started = false,
        Completed = false,
        Progress = 0
    }
}

local function createLoadingUI()
    local player = Players.LocalPlayer
    if not player then return end

    if player.PlayerGui:FindFirstChild("HunterXLoading") then
        player.PlayerGui:FindFirstChild("HunterXLoading"):Destroy()
    end

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "HunterXLoading"
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.ResetOnSpawn = false
    screenGui.Parent = player.PlayerGui

    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(0, 300, 0, 150)
    mainFrame.Position = UDim2.new(0.5, -150, 0.5, -75)
    mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = screenGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = mainFrame

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Name = "Title"
    titleLabel.Size = UDim2.new(1, 0, 0, 40)
    titleLabel.Position = UDim2.new(0, 0, 0, 10)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.Text = "HUNTER X HUB"
    titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    titleLabel.TextSize = 24
    titleLabel.Parent = mainFrame
    
    local subtitleLabel = Instance.new("TextLabel")
    subtitleLabel.Name = "Subtitle"
    subtitleLabel.Size = UDim2.new(1, 0, 0, 20)
    subtitleLabel.Position = UDim2.new(0, 0, 0, 50)
    subtitleLabel.BackgroundTransparency = 1
    subtitleLabel.Font = Enum.Font.Gotham
    subtitleLabel.Text = "ANIME RANAGERS"
    subtitleLabel.TextColor3 = Color3.fromRGB(35, 222, 180)
    subtitleLabel.TextSize = 16
    subtitleLabel.Parent = mainFrame
    
    local progressBarBg = Instance.new("Frame")
    progressBarBg.Name = "ProgressBarBg"
    progressBarBg.Size = UDim2.new(0.8, 0, 0, 10)
    progressBarBg.Position = UDim2.new(0.1, 0, 0.7, 0)
    progressBarBg.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    progressBarBg.BorderSizePixel = 0
    progressBarBg.Parent = mainFrame

    local progressCorner = Instance.new("UICorner")
    progressCorner.CornerRadius = UDim.new(0, 4)
    progressCorner.Parent = progressBarBg

    local progressBarFill = Instance.new("Frame")
    progressBarFill.Name = "ProgressBarFill"
    progressBarFill.Size = UDim2.new(0, 0, 1, 0)
    progressBarFill.BackgroundColor3 = Color3.fromRGB(35, 222, 180)
    progressBarFill.BorderSizePixel = 0
    progressBarFill.Parent = progressBarBg

    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(0, 4)
    fillCorner.Parent = progressBarFill

    local statusLabel = Instance.new("TextLabel")
    statusLabel.Name = "Status"
    statusLabel.Size = UDim2.new(1, 0, 0, 20)
    statusLabel.Position = UDim2.new(0, 0, 0.85, 0)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Font = Enum.Font.Gotham
    statusLabel.Text = "Initializing..."
    statusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    statusLabel.TextSize = 14
    statusLabel.Parent = mainFrame
    
    return {
        ScreenGui = screenGui,
        ProgressBar = progressBarFill,
        StatusLabel = statusLabel
    }
end

local function updateLoadingProgress(ui, progress, status)
    if not ui then return end

    local tween = TweenService:Create(
        ui.ProgressBar,
        TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {Size = UDim2.new(progress, 0, 1, 0)}
    )
    tween:Play()

    if status then
        ui.StatusLabel.Text = status
    end
end

local function startLoading()
    if HUNTER_X.Loading.Started then return end
    HUNTER_X.Loading.Started = true

    local ui = createLoadingUI()
    if not ui then
        warn("Failed to create loading UI")
        HUNTER_X.Loading.Completed = true
        return
    end

    local loadingSteps = {
        {progress = 0.1, status = "Connecting to game...", delay = 0.5},
        {progress = 0.3, status = "Loading resources...", delay = 0.5},
        {progress = 0.5, status = "Initializing services...", delay = 0.5},
        {progress = 0.7, status = "Preparing auto-upgrade system...", delay = 0.5},
        {progress = 0.9, status = "Finalizing...", delay = 0.5},
        {progress = 1.0, status = "Complete!", delay = 0.5}
    }

    spawn(function()
        for i, step in ipairs(loadingSteps) do
            updateLoadingProgress(ui, step.progress, step.status)
            HUNTER_X.Loading.Progress = step.progress
            wait(step.delay)
        end

        wait(0.5)
        ui.StatusLabel.Text = "Ready!"

        wait(1)

        local fadeOut = TweenService:Create(
            ui.ScreenGui.MainFrame,
            TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {BackgroundTransparency = 1}
        )
        fadeOut:Play()

        for _, v in pairs(ui.ScreenGui.MainFrame:GetDescendants()) do
            if v:IsA("TextLabel") then
                TweenService:Create(
                    v,
                    TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                    {TextTransparency = 1}
                ):Play()
            elseif v:IsA("Frame") and v.Name ~= "MainFrame" then
                TweenService:Create(
                    v,
                    TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                    {BackgroundTransparency = 1}
                ):Play()
            end
        end

        wait(0.6)

        ui.ScreenGui:Destroy()

        HUNTER_X.Loading.Completed = true

        warn("---------------------------------------------------")
        warn("      HUNTER X HUB - ANIME RANAGERS SCRIPTS")
        warn("---------------------------------------------------")
        warn("Status: Loaded Successfully!")
        warn("---------------------------------------------------")
    end)
end

function debugLog(message)
    if HUNTER_X.Config.DebugMode then
        warn("[HUNTER X HUB] " .. message)
    end
end

function debugWarn(message)
    if HUNTER_X.Config.DebugMode then
        warn("[HUNTER X ERROR] " .. message)
    end
end

local player
spawn(function()
    while not Players.LocalPlayer do wait(0.1) end
    player = Players.LocalPlayer
    debugLog("Player found: " .. player.Name)

    startLoading()
end)

local function waitForLoading()
    local startTime = tick()
    local timeout = HUNTER_X.Config.LoadingDelay + 10
    
    repeat
        wait(0.1)
        if (tick() - startTime) > timeout then
            debugWarn("Loading timed out after " .. timeout .. " seconds")
            return false
        end
    until HUNTER_X.Loading.Completed
    
    debugLog("Loading completed successfully")
    return true
end

local function initializeMainScript()
    debugLog("Initializing main script...")

    wait(HUNTER_X.Config.LoadingDelay)

    spawn(function()
        wait(2)
        if player and player.PlayerGui then
            HUNTER_X.Paths.RewardsUIPath = player.PlayerGui:FindFirstChild("RewardsUI")
            debugLog("RewardsUI Path: " .. (HUNTER_X.Paths.RewardsUIPath and "Found" or "Not Found"))
        end
    end)

    debugLog("Main script initialized successfully")
end

waitForLoading()
initializeMainScript()

return HUNTER_X
