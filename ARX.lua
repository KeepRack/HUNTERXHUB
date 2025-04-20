local LoadingSystem = loadstring(game:HttpGet("https://raw.githubusercontent.com/KeepRack/HUNTERXHUB/refs/heads/main/Loading.lua"))() or {
    Loading = {
        Completed = false
    }
}

if not _G.ScriptStartTime then
    _G.ScriptStartTime = tick()
end

while not LoadingSystem.Loading.Completed do
    task.wait(0.1)
    if tick() - _G.ScriptStartTime > 5 then
        break
    end
end

_G.VoteMode = _G.VoteMode or "Retry"

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")
local VirtualUser = game:GetService("VirtualUser")

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
        UpgradeTarget = nil,
        NewGameDetected = false,
        VoteSent = false,
        VoteAttempts = 0
    },
    PrintFlags = {
        ClickStarted = false,
        ClickStopped = false,
        ClickFunction = false
    },
    UnitUpgrade = {
        paused = false,
        lastPausedReason = "",
        upgradeInProgress = false,
        needsRestart = false
    },
    Services = {
        VirtualInputManager = VirtualInputManager,
        Players = Players,
        VirtualUser = VirtualUser
    },
    Config = {
        YenCheckInterval = 0.5,
        UpgradeRetryInterval = 1.0,
        MaxUpgradeAttempts = 3,
        AfterGameDelay = 5,
        AfterVoteDelay = 2,
        VoteCheckInterval = 1.0,
        MaxVoteAttempts = 5,
        DebugMode = false,
        VoteMode = _G.VoteMode or "Retry"
    }
}

function SetupAntiAFK()
    local LocalPlayer = HUNTER_X.Services.Players.LocalPlayer

    if not LocalPlayer then
        for i = 1, 10 do
            LocalPlayer = HUNTER_X.Services.Players.LocalPlayer
            if LocalPlayer then break end
            wait(0.5)
        end
    end

    if not LocalPlayer then
        if HUNTER_X.Config.DebugMode then
            print("❌ Failed to get LocalPlayer for Anti-AFK")
        end
        return
    end
    
    LocalPlayer.Idled:Connect(function()
        HUNTER_X.Services.VirtualUser:Button2Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
        wait(1)
        HUNTER_X.Services.VirtualUser:Button2Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
        task.wait(1.5)
        if HUNTER_X.Config.DebugMode then
            print("✅ Anti-AFK Activated")
        end
    end)
end

local hasPrinted = false
local hasPrintedYen = false
local hasVoted = false
local unitData = {}
local unitUpgradeCosts = {}
local maxUpgradeAttempts = HUNTER_X.Config.MaxUpgradeAttempts

while not Players.LocalPlayer do wait(0.1) end
local player = Players.LocalPlayer

function debugLog(message)
    if HUNTER_X.Config.DebugMode then
        print("[DEBUG] " .. tostring(message))
    end
end

function debugWarn(message)
    if HUNTER_X.Config.DebugMode then
        warn("[DEBUG] " .. tostring(message))
    end
end

spawn(function()
    wait(5)
    while not Players.LocalPlayer do wait(0.5) end
    SetupAntiAFK()
    debugLog("Anti-AFK system initialized")
end)

spawn(function()
    wait(1)
    if player and player.PlayerGui then
        HUNTER_X.Paths.RewardsUIPath = player.PlayerGui:FindFirstChild("RewardsUI")
        if not HUNTER_X.Paths.RewardsUIPath then
            for i = 1, 10 do
                HUNTER_X.Paths.RewardsUIPath = player.PlayerGui:FindFirstChild("RewardsUI")
                if HUNTER_X.Paths.RewardsUIPath then break end
                wait(0.5)
            end
        end
        
        if not HUNTER_X.Paths.RewardsUIPath then
            player.PlayerGui.ChildAdded:Connect(function(child)
                if child and child.Name == "RewardsUI" then
                    HUNTER_X.Paths.RewardsUIPath = child
                end
            end)
        end
    end
end)

local voteSent = false

function sendVotePlaying()
    if not voteSent then
        ReplicatedStorage.Remote.Server.OnGame.Voting.VotePlaying:FireServer()
        debugLog("VotePlaying vote sent (single time)")
        voteSent = true
        
        hasVoted = true
        hasPrinted = true
        
        spawn(checkYen)
        spawn(checkUnits)
        
        spawn(function()
            wait(5)
            HUNTER_X.States.NewGameDetected = true
            startUpgradeProcess()
        end)
    end
end

spawn(function()
    local waitTime = 0
    while not (player and player.PlayerGui) do
        wait(0.1)
        waitTime = waitTime + 0.1
        if waitTime > 10 then break end
    end
    
    if not player or not player.PlayerGui then return end
    
    while not (player.PlayerGui:FindFirstChild("HUD") and 
              player.PlayerGui.HUD:FindFirstChild("InGame") and 
              player.PlayerGui.HUD.InGame:FindFirstChild("VotePlaying") and 
              player.PlayerGui.HUD.InGame.VotePlaying:FindFirstChild("Frame") and 
              player.PlayerGui.HUD.InGame.VotePlaying.Frame:FindFirstChild("Vote")) do
        wait(0.1)
        waitTime = waitTime + 0.1
        if waitTime > 15 then return end
    end
    
    if player.PlayerGui.HUD.InGame.VotePlaying.Frame.Vote.Visible then
        sendVotePlaying()
    end
    
    player.PlayerGui.HUD.InGame.VotePlaying.Frame.Vote:GetPropertyChangedSignal("Visible"):Connect(function()
        if player.PlayerGui.HUD.InGame.VotePlaying.Frame.Vote.Visible then
            sendVotePlaying()
        else
            voteSent = false
            debugLog("Vote button no longer visible - resetting vote status for next round")
        end
    end)
end)

spawn(function()
    while wait(2) do
        if HUNTER_X.States.NewGameDetected then
            voteSent = false
            debugLog("New game detected - vote status reset")
        end
    end
end)

function getYen()
    if player and player:FindFirstChild("Yen") and player.Yen:IsA("ValueBase") then
        return player.Yen.Value
    end
    return 0
end

function checkYen()
    local yenCheckAttempts = 0
    local maxAttempts = 10
    
    wait(2)
    
    while not (player and player:FindFirstChild("Yen")) do
        wait(0.5)
        yenCheckAttempts = yenCheckAttempts + 1
        
        if yenCheckAttempts >= maxAttempts then
            debugWarn("ERROR: Cannot find Yen in player")
            return
        end
    end
    
    if player.Yen:IsA("ValueBase") then
        if not hasPrintedYen then
            debugLog("Current Yen: " .. tostring(player.Yen.Value))
            hasPrintedYen = true
        end
        
        HUNTER_X.States.CurrentYen = player.Yen.Value
        
        player.Yen.Changed:Connect(function(newValue)
            HUNTER_X.States.CurrentYen = newValue
            
            if HUNTER_X.States.WaitingForYen and newValue >= HUNTER_X.States.YenTargetAmount then
                debugLog("Sufficient Yen accumulated! Resuming upgrade process")
                HUNTER_X.States.WaitingForYen = false
                
                spawn(function()
                    wait(0.5)
                    resumeUpgradeProcess()
                end)
            end
        end)
    else
        debugWarn("ERROR: Yen is not a ValueBase object")
    end
end

function checkUnits()
    wait(1)
    
    if not player or not player:FindFirstChild("UnitsFolder") then
        debugWarn("ERROR: Cannot find UnitsFolder")
        return {}
    end
    
    local count = 0
    debugLog("Found Units:")
    unitData = {}
    unitUpgradeCosts = {}
    
    for _, unit in pairs(player.UnitsFolder:GetChildren()) do
        count = count + 1
        debugLog(count .. ". " .. unit.Name)
        table.insert(unitData, unit.Name)
        
        if unit:FindFirstChild("Upgrade_Folder") and unit.Upgrade_Folder:FindFirstChild("Upgrade_Cost") then
            local cost = unit.Upgrade_Folder.Upgrade_Cost.Value
            unitUpgradeCosts[unit.Name] = cost
            debugLog("   - Upgrade cost: " .. tostring(cost))
        else
            unitUpgradeCosts[unit.Name] = math.huge
            debugLog("   - Unable to find upgrade cost")
        end
    end
    
    debugLog("Total Units: " .. tostring(count))
    return unitData
end

function sortUnitsByCost()
    local sortedUnits = {}
    for _, unitName in ipairs(unitData) do
        table.insert(sortedUnits, {name = unitName, cost = unitUpgradeCosts[unitName] or math.huge})
    end
    
    table.sort(sortedUnits, function(a, b)
        return a.cost < b.cost
    end)
    
    local result = {}
    for _, unit in ipairs(sortedUnits) do
        table.insert(result, unit.name)
    end
    
    debugLog("Units sorted from lowest to highest cost")
    for i, unitName in ipairs(result) do
        local costText = unitUpgradeCosts[unitName] == math.huge and "Unknown" or tostring(unitUpgradeCosts[unitName])
        debugLog(i .. ". " .. unitName .. " - Cost: " .. costText)
    end
    
    return result
end

function upgradeUnit(unitName)
    if HUNTER_X.UnitUpgrade.paused then
        debugLog("Unit upgrading is currently paused: " .. tostring(HUNTER_X.UnitUpgrade.lastPausedReason))
        return false
    end

    if not player:FindFirstChild("UnitsFolder") then
        debugWarn("ERROR: Cannot find UnitsFolder")
        return false
    end
    
    if not player.UnitsFolder:FindFirstChild(unitName) then
        debugWarn("ERROR: Cannot find unit: " .. tostring(unitName))
        return false
    end
    
    local args = {
        [1] = player.UnitsFolder[unitName]
    }
    
    ReplicatedStorage.Remote.Server.Units.Upgrade:FireServer(unpack(args))
    debugLog("Upgrade request sent for: " .. tostring(unitName))
    return true
end

function isUnitMaxLevel(unitName)
    if HUNTER_X.UnitUpgrade.paused then
        debugLog("Unit upgrading is currently paused: " .. tostring(HUNTER_X.UnitUpgrade.lastPausedReason))
        return true
    end

    local unit = player.UnitsFolder:FindFirstChild(unitName)
    if not unit then return true end
    
    if not unit:FindFirstChild("Upgrade_Folder") or not unit.Upgrade_Folder:FindFirstChild("Upgrade_Cost") then
        return true
    end
    
    local currentCost = unit.Upgrade_Folder.Upgrade_Cost.Value
    local currentYen = getYen()
    
    if currentYen >= currentCost then
        local oldCost = currentCost
        
        upgradeUnit(unitName)
        wait(0.5)
        
        if unit:FindFirstChild("Upgrade_Folder") and unit.Upgrade_Folder:FindFirstChild("Upgrade_Cost") then
            local newCost = unit.Upgrade_Folder.Upgrade_Cost.Value
            
            if newCost == oldCost then
                local attempts = 0
                while attempts < maxUpgradeAttempts do
                    upgradeUnit(unitName)
                    wait(0.5)
                    attempts = attempts + 1
                    
                    if unit:FindFirstChild("Upgrade_Folder") and unit.Upgrade_Folder:FindFirstChild("Upgrade_Cost") then
                        if unit.Upgrade_Folder.Upgrade_Cost.Value ~= oldCost then
                            return false
                        end
                    end
                end
                
                debugLog(tostring(unitName) .. " appears to be at MAX level")
                return true
            else
                return false
            end
        end
    else
        debugLog("Not enough Yen to check if " .. tostring(unitName) .. " is maxed")
        
        HUNTER_X.States.WaitingForYen = true
        HUNTER_X.States.YenTargetAmount = currentCost
        HUNTER_X.States.UpgradeTarget = unitName
        
        debugLog("Waiting for " .. tostring(currentCost) .. " Yen to continue upgrading " .. tostring(unitName))
        return false
    end
    
    return false
end

function pauseUpgradeProcess(reason)
    if not HUNTER_X.UnitUpgrade.paused then
        HUNTER_X.UnitUpgrade.paused = true
        HUNTER_X.UnitUpgrade.lastPausedReason = reason or "No reason specified"
        debugLog("Unit upgrade process paused: " .. tostring(HUNTER_X.UnitUpgrade.lastPausedReason))
    end
end

function resumeUpgradeProcess()
    if HUNTER_X.UnitUpgrade.paused then
        HUNTER_X.UnitUpgrade.paused = false
        debugLog("Unit upgrade process resumed after: " .. tostring(HUNTER_X.UnitUpgrade.lastPausedReason))
        HUNTER_X.UnitUpgrade.lastPausedReason = ""
        
        if HUNTER_X.States.UpgradeTarget and not HUNTER_X.UnitUpgrade.upgradeInProgress then
            debugLog("Resuming upgrade for: " .. tostring(HUNTER_X.States.UpgradeTarget))
            startUpgradeProcess(HUNTER_X.States.UpgradeTarget)
        end
    end
end

function startUpgradeProcess(resumeFromUnit)
    if HUNTER_X.UnitUpgrade.upgradeInProgress then
        debugLog("Upgrade process is already in progress")
        return
    end
    
    if HUNTER_X.UnitUpgrade.paused and not HUNTER_X.UnitUpgrade.needsRestart then
        debugLog("Cannot start upgrade process while paused: " .. tostring(HUNTER_X.UnitUpgrade.lastPausedReason))
        return
    end

    if HUNTER_X.UnitUpgrade.needsRestart then
        HUNTER_X.UnitUpgrade.needsRestart = false
        debugLog("Starting upgrade process after restart was requested")
    end

    if HUNTER_X.UnitUpgrade.paused then
        HUNTER_X.UnitUpgrade.paused = false
        debugLog("Forced resume of upgrade process: " .. tostring(HUNTER_X.UnitUpgrade.lastPausedReason))
        HUNTER_X.UnitUpgrade.lastPausedReason = ""
    end
    
    HUNTER_X.UnitUpgrade.upgradeInProgress = true
    HUNTER_X.States.WaitingForYen = false
    
    debugLog("Starting unit upgrade process...")

    checkUnits()
    wait(1)
    
    local sortedUnits = sortUnitsByCost()
    debugLog("Units sorted by upgrade cost (lowest to highest):")
    for i, unitName in ipairs(sortedUnits) do
        local costText = unitUpgradeCosts[unitName] == math.huge and "Unknown" or tostring(unitUpgradeCosts[unitName])
        debugLog(i .. ". " .. unitName .. " - Cost: " .. costText)
    end
    
    local startIndex = 1
    if resumeFromUnit then
        for i, unitName in ipairs(sortedUnits) do
            if unitName == resumeFromUnit then
                startIndex = i
                break
            end
        end
    end
    
    for i = startIndex, #sortedUnits do
        local unitName = sortedUnits[i]
        
        if HUNTER_X.UnitUpgrade.paused then
            debugLog("Unit upgrade process paused during execution")
            break
        end
        
        debugLog("Working on unit: " .. tostring(unitName))
        
        local maxReached = false
        local noYenReported = false
        
        while not maxReached and not HUNTER_X.UnitUpgrade.paused do
            local unit = player.UnitsFolder:FindFirstChild(unitName)
            if not unit then
                debugLog("Unit " .. tostring(unitName) .. " no longer exists, skipping")
                break
            end
            
            if not unit:FindFirstChild("Upgrade_Folder") or not unit.Upgrade_Folder:FindFirstChild("Upgrade_Cost") then
                debugLog("Cannot find upgrade cost for " .. tostring(unitName) .. ", skipping")
                break
            end
            
            local currentCost = unit.Upgrade_Folder.Upgrade_Cost.Value
            local currentYen = getYen()
            
            if currentYen >= currentCost then
                if noYenReported then
                    debugLog("Sufficient Yen accumulated, continuing upgrade for " .. tostring(unitName))
                    noYenReported = false
                end
                
                debugLog("Upgrading " .. tostring(unitName) .. " (Cost: " .. tostring(currentCost) .. ", Yen: " .. tostring(currentYen) .. ")")
                
                upgradeUnit(unitName)
                wait(0.5)
                
                maxReached = isUnitMaxLevel(unitName)
            else
                if not noYenReported then
                    debugLog("Not enough Yen to upgrade " .. tostring(unitName) .. " (Need: " .. tostring(currentCost) .. ", Have: " .. tostring(currentYen) .. ")")
                    noYenReported = true
                    
                    HUNTER_X.States.WaitingForYen = true
                    HUNTER_X.States.YenTargetAmount = currentCost
                    HUNTER_X.States.UpgradeTarget = unitName
                    
                    spawn(function()
                        waitForYenAndResume(unitName, currentCost)
                    end)
                    
                    pauseUpgradeProcess("Waiting for Yen")
                end
                
                break
            end
            
            wait(0.2)
        end
        
        if not HUNTER_X.UnitUpgrade.paused then
            debugLog("Finished with " .. tostring(unitName) .. ", moving to next unit")
        end
        
        wait(0.5)
    end
    
    debugLog("Unit upgrade process " .. (HUNTER_X.UnitUpgrade.paused and "paused!" or "completed!"))
    
    if not HUNTER_X.UnitUpgrade.paused then
        HUNTER_X.UnitUpgrade.upgradeInProgress = false
        HUNTER_X.States.UpgradeTarget = nil
    end
end

function waitForYenAndResume(unitName, targetAmount)
    if not HUNTER_X.States.WaitingForYen then return end
    
    local waitCycles = 0
    
    while HUNTER_X.States.WaitingForYen and HUNTER_X.UnitUpgrade.paused do
        local currentYen = getYen()
        
        if waitCycles % 10 == 0 then
            debugLog("Waiting for Yen: Have " .. tostring(currentYen) .. " / Need " .. tostring(targetAmount))
        end
        
        if currentYen >= targetAmount then
            debugLog("Sufficient Yen accumulated! Resuming upgrade process")
            HUNTER_X.States.WaitingForYen = false
            resumeUpgradeProcess()
            break
        end
        
        wait(HUNTER_X.Config.YenCheckInterval)
        waitCycles = waitCycles + 1
    end
end

function sendVote()
    local voteMode = HUNTER_X.Config.VoteMode
    
    if voteMode == "Next" then
        ReplicatedStorage.Remote.Server.OnGame.Voting.VoteNext:FireServer()
        debugLog("VoteNext sent: Attempt " .. tostring(HUNTER_X.States.VoteAttempts))
    else
        ReplicatedStorage.Remote.Server.OnGame.Voting.VoteRetry:FireServer()
        debugLog("VoteRetry sent: Attempt " .. tostring(HUNTER_X.States.VoteAttempts))
    end
    
    HUNTER_X.States.VoteSent = true
    HUNTER_X.UnitUpgrade.needsRestart = true
    HUNTER_X.States.NewGameDetected = true
end

function CheckVisualsAndAutoClick()
    local isRewardsUIVisible = false
    
    pcall(function() 
        isRewardsUIVisible = HUNTER_X.Paths.RewardsUIPath and HUNTER_X.Paths.RewardsUIPath.Enabled
    end)
    
    if isRewardsUIVisible then
        if not HUNTER_X.States.GameEnded then
            HUNTER_X.States.GameEnded = true
            HUNTER_X.States.VoteAttempts = 0
            debugLog("Game has ended! Detected RewardsUI")
        end
        
        if HUNTER_X.States.ClickActive then
            HUNTER_X.States.ClickActive = false
            HUNTER_X.PrintFlags.ClickStarted = false
            HUNTER_X.PrintFlags.ClickFunction = false
            if not HUNTER_X.PrintFlags.ClickStopped then
                HUNTER_X.PrintFlags.ClickStopped = true
                debugLog("Auto-clicking stopped: Rewards UI is visible")
            end
        end
        
        if not HUNTER_X.UnitUpgrade.paused then
            pauseUpgradeProcess("Rewards UI is visible (Game Ended)")
        end
        
        CheckAndVote()
        
        return
    end

    if HUNTER_X.States.GameEnded and not isRewardsUIVisible then
        HUNTER_X.States.GameEnded = false
        debugLog("New game detected! Rewards UI is no longer visible")

        HUNTER_X.States.NewGameDetected = true
        HUNTER_X.UnitUpgrade.needsRestart = true
        
        spawn(function()
            debugLog("Will start a new upgrade cycle in " .. tostring(HUNTER_X.Config.AfterGameDelay) .. " seconds")
            wait(HUNTER_X.Config.AfterGameDelay)

            if HUNTER_X.States.NewGameDetected then
                HUNTER_X.States.NewGameDetected = false

                if HUNTER_X.UnitUpgrade.paused then
                    HUNTER_X.UnitUpgrade.paused = false
                    HUNTER_X.UnitUpgrade.lastPausedReason = ""
                end
                HUNTER_X.UnitUpgrade.upgradeInProgress = false

                debugLog("Starting fresh upgrade process after game end")
                startUpgradeProcess()
            end
        end)
    end
    
    local visualGemExists = workspace:FindFirstChild("Visual") and workspace.Visual:FindFirstChild("Gem")
    local visualExpExists = workspace:FindFirstChild("Visual") and workspace.Visual:FindFirstChild("Exp")
    local visualGoldExists = workspace:FindFirstChild("Visual") and workspace.Visual:FindFirstChild("Gold")
    
    if visualGemExists or visualExpExists or visualGoldExists then
        if not HUNTER_X.States.ClickActive then
            HUNTER_X.States.ClickActive = true
            HUNTER_X.PrintFlags.ClickStopped = false
            if not HUNTER_X.PrintFlags.ClickStarted then
                HUNTER_X.PrintFlags.ClickStarted = true
                debugLog("Auto-clicking started: Visual items detected")
            end
        end
    end
    
    if HUNTER_X.States.ClickActive then
        if not HUNTER_X.PrintFlags.ClickFunction then
            HUNTER_X.PrintFlags.ClickFunction = true
            debugLog("Auto-clicking function active")
        end
        
        local viewportSize = workspace.CurrentCamera.ViewportSize
        local centerX = viewportSize.X / 2
        local centerY = viewportSize.Y / 2
        
        pcall(function()
            HUNTER_X.Services.VirtualInputManager:SendMouseButtonEvent(centerX, centerY, 0, true, game, 1)
            HUNTER_X.Services.VirtualInputManager:SendMouseButtonEvent(centerX, centerY, 0, false, game, 1)
        end)
    end
end

function CheckAndVote()
    local isRewardsUIVisible = false
    
    pcall(function()
        isRewardsUIVisible = HUNTER_X.Paths.RewardsUIPath and HUNTER_X.Paths.RewardsUIPath.Enabled
    end)
    
    if isRewardsUIVisible then
        if not HUNTER_X.States.RetryActionExecuted then
            HUNTER_X.States.VoteAttempts = HUNTER_X.States.VoteAttempts + 1
            sendVote()
            HUNTER_X.States.RetryActionExecuted = true
            
            local voteType = HUNTER_X.Config.VoteMode == "Next" and "VoteNext" or "VoteRetry"
            debugLog(voteType .. " sent: Attempt " .. tostring(HUNTER_X.States.VoteAttempts))

            HUNTER_X.UnitUpgrade.needsRestart = true
            HUNTER_X.States.NewGameDetected = true
            
            spawn(function()
                local timeBetweenVotes = 0.5
                for i = 1, 8 do
                    wait(timeBetweenVotes)
                    pcall(function()
                        if isRewardsUIVisible and HUNTER_X.States.VoteAttempts < HUNTER_X.Config.MaxVoteAttempts then
                            HUNTER_X.States.VoteAttempts = HUNTER_X.States.VoteAttempts + 1
                            sendVote()
                            
                            local voteType = HUNTER_X.Config.VoteMode == "Next" and "VoteNext" or "VoteRetry"
                            debugLog("Additional " .. voteType .. " sent: Attempt " .. tostring(HUNTER_X.States.VoteAttempts))
                        end
                    end)
                end
                
                wait(HUNTER_X.Config.AfterVoteDelay)
                HUNTER_X.States.RetryActionExecuted = false
            end)
        end
    elseif not isRewardsUIVisible then
        if HUNTER_X.States.RetryActionExecuted then
            HUNTER_X.States.RetryActionExecuted = false
            debugLog("Ready for next Vote: RewardsUI is no longer visible")
        end
    end
end

spawn(function()
    while wait(1) do
        if not HUNTER_X.Paths.RewardsUIPath and player and player.PlayerGui then
            HUNTER_X.Paths.RewardsUIPath = player.PlayerGui:FindFirstChild("RewardsUI")
        end
    end
end)

spawn(function()
    while wait(1) do
        pcall(function()
            if player and player.PlayerGui and player.PlayerGui:FindFirstChild("RewardsUI") then
                HUNTER_X.Paths.RewardsUIPath = player.PlayerGui.RewardsUI
                
                if HUNTER_X.Paths.RewardsUIPath.Enabled and not HUNTER_X.States.RetryActionExecuted then
                    CheckAndVote()
                end
            end
        end)
    end
end)

spawn(function()
    while true do
        if HUNTER_X.Paths.RewardsUIPath then
            break
        end
        wait(0.5)
    end
    
    debugLog("Auto-Vote system initialized (Mode: " .. tostring(HUNTER_X.Config.VoteMode) .. ")")
    
    HUNTER_X.Paths.RewardsUIPath:GetPropertyChangedSignal("Enabled"):Connect(function()
        if HUNTER_X.Paths.RewardsUIPath.Enabled then
            CheckAndVote()
        end
    end)
end)

spawn(function()
    debugLog("Auto-click system initialized")
    while wait(0.1) do
        pcall(CheckVisualsAndAutoClick)
    end
end)

spawn(function()
    debugLog("Auto-retry upgrade system initialized")
    while wait(HUNTER_X.Config.UpgradeRetryInterval) do
        pcall(function()
            if HUNTER_X.States.VoteSent and HUNTER_X.UnitUpgrade.needsRestart and not HUNTER_X.States.GameEnded then
                debugLog("Attempting to restart upgrade process after vote")
                HUNTER_X.States.VoteSent = false

                if player and player:FindFirstChild("UnitsFolder") and #player.UnitsFolder:GetChildren() > 0 then
                    debugLog("Units found, restarting upgrade process")

                    HUNTER_X.UnitUpgrade.paused = false
                    HUNTER_X.UnitUpgrade.lastPausedReason = ""
                    HUNTER_X.UnitUpgrade.upgradeInProgress = false
                    HUNTER_X.States.WaitingForYen = false
                    HUNTER_X.States.UpgradeTarget = nil

                    spawn(function()
                        wait(2)
                        startUpgradeProcess()
                    end)
                end
            end
            
            if HUNTER_X.States.WaitingForYen and HUNTER_X.UnitUpgrade.paused and HUNTER_X.States.UpgradeTarget then
                local targetUnit = HUNTER_X.States.UpgradeTarget
                local targetAmount = HUNTER_X.States.YenTargetAmount
                local currentYen = getYen()
                
                if currentYen >= targetAmount then
                    debugLog("Sufficient Yen detected for " .. tostring(targetUnit) .. "! Resuming upgrade process")
                    HUNTER_X.States.WaitingForYen = false
                    resumeUpgradeProcess()
                end
            end
        end)
    end
end)

spawn(function()
    debugLog("Active vote system initialized (Mode: " .. tostring(HUNTER_X.Config.VoteMode) .. ")")
    while wait(HUNTER_X.Config.VoteCheckInterval) do
        pcall(function()
            local isRewardsUIVisible = false
            pcall(function() 
                isRewardsUIVisible = HUNTER_X.Paths.RewardsUIPath and HUNTER_X.Paths.RewardsUIPath.Enabled 
            end)
            
            if isRewardsUIVisible then
                if not HUNTER_X.States.RetryActionExecuted or HUNTER_X.States.VoteAttempts < HUNTER_X.Config.MaxVoteAttempts then
                    sendVote() 
                    HUNTER_X.States.VoteAttempts = HUNTER_X.States.VoteAttempts + 1
                    
                    local voteType = HUNTER_X.Config.VoteMode == "Next" and "VoteNext" or "VoteRetry"
                    debugLog("Proactive " .. voteType .. " sent: Attempt " .. HUNTER_X.States.VoteAttempts)
                    HUNTER_X.States.VoteSent = true
                end
            end
        end)
    end
end)
