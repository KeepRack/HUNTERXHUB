repeat wait(12) until game:IsLoaded()

-- _G.Enable = true -- true, false
-- _G.VotePlay = true -- true, false
-- _G.VoteMode = "Retry" -- Retry, Next, Leave
-- _G.Upgrade = true -- true, false
-- _G.Debug = false -- DebugLog Check

-- -- _G.Kaitun = false -- true, false
-- -- _G.World = "OnePiece" -- OnePiece, Namek, DemonSlayer, Naruto, DemonSlayer
-- -- _G.Chapter = "1" -- Selected Chapter 1-10 or All
-- -- _G.Difficuly = "Normal" -- Normal, Hard, Nightmare

-- -- _G.RangerMode = true -- true, false
-- -- _G.ChallengeMode = true -- true, false

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")
local Workspace = game:GetService("Workspace")
local VirtualUser = game:GetService("VirtualUser")
local player = Players.LocalPlayer

local Remotes = {
    VotePlaying = ReplicatedStorage.Remote.Server.OnGame.Voting.VotePlaying,
    VoteRetry = ReplicatedStorage.Remote.Server.OnGame.Voting.VoteRetry,
    VoteNext = ReplicatedStorage.Remote.Server.OnGame.Voting.VoteNext,
    UnitUpgrade = ReplicatedStorage.Remote.Server.Units.Upgrade
}

local SystemState = {
    antiAFKSetup = false,
    
    voteCheckCompleted = false,
    hasVotedEndGame = false,
    lastVoteAction = nil,
    
    unitsFolder = player.UnitsFolder,
    unitUpgradeCosts = {},
    unitMaxUpgradeStatus = {},
    currentUpgradingUnit = nil,
    hasCheckedUnits = false,
    currentUpgradeTarget = nil,
    waitingForMoney = false,
    upgradeSystemStarted = false,
    upgradeSystemReset = false,
    lastGameState = nil,

    upgradeDelayActive = false,
    upgradeDelayStartTime = 0,
    upgradeDelayDuration = 0,
    
    autoClick = {
        clickActive = false,
        gameEnded = false,
        newGameDetected = false,
        printFlags = {
            clickStarted = false,
            clickStopped = false,
            clickFunction = false
        }
    }
}

local function debugLog(message)
    if _G.Debug then
        print("[DEBUG] " .. message)
    end
end

local function setupAntiAFK()
    if SystemState.antiAFKSetup or not _G.Enable then return end
    
    debugLog("Setting up Anti-AFK system")
    
    player.Idled:Connect(function()
        if not _G.Enable then return end
        debugLog("Anti-AFK triggered, simulating activity")
        VirtualUser:Button2Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
        wait(1)
        VirtualUser:Button2Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
    end)
    
    SystemState.antiAFKSetup = true
    debugLog("Anti-AFK system active")
end

local function setUpgradeDelay()
    SystemState.upgradeDelayActive = true
    SystemState.upgradeDelayStartTime = os.time()
    debugLog("Setting upgrade delay: " .. SystemState.upgradeDelayDuration .. " seconds")
end

local function isUpgradeDelayActive()
    if not SystemState.upgradeDelayActive then
        return false
    end
    
    local currentTime = os.time()
    local elapsedTime = currentTime - SystemState.upgradeDelayStartTime
    
    if elapsedTime >= SystemState.upgradeDelayDuration then
        SystemState.upgradeDelayActive = false
        debugLog("Upgrade delay completed. Resuming upgrades.")
        return false
    end
    
    return true
end

local function AutoVotePlaying()
    if not player or not _G.Enable or not _G.VotePlay then 
        return false 
    end
    
    local success, result = pcall(function()
        local VoteFrame = player.PlayerGui.HUD.InGame.VotePlaying.Frame.Vote
        
        if VoteFrame.Visible then
            Remotes.VotePlaying:FireServer()
            debugLog("Vote playing sent successfully")

            setUpgradeDelay()
            
            return true
        else
            return false
        end
    end)
    
    if success then
        return result
    else
        warn("Error in AutoVotePlaying:", result)
        return true
    end
end

local function AutoVoteEndGame()
    if not _G.Enable or not _G.VotePlay then return false end
    
    SystemState.hasVotedEndGame = false
    
    local success, result = pcall(function()
        local RewardsUI = player.PlayerGui:FindFirstChild("RewardsUI")
        
        if RewardsUI and RewardsUI.Enabled then
            local voteAction = ""
            
            if _G.VoteMode == "Retry" then
                debugLog("Sending Vote Retry")
                Remotes.VoteRetry:FireServer()
                voteAction = "Retry"
            else
                debugLog("Sending Vote Next")
                Remotes.VoteNext:FireServer()
                voteAction = "Next"
            end
            
            if SystemState.lastVoteAction ~= voteAction then
                SystemState.lastVoteAction = voteAction
                debugLog("Vote action " .. voteAction .. " - Flagging upgrade system for reset")
                SystemState.upgradeSystemReset = true

                setUpgradeDelay()
            end
            
            SystemState.hasVotedEndGame = true
            return true
        else
            return false
        end
    end)
    
    if success then
        return result
    else
        warn("Error in AutoVoteEndGame:", result)
        return false
    end
end

local function checkPlayerMoney()
    if not _G.Enable then return 0 end
    
    local success, result = pcall(function()
        return player.Yen.Value
    end)
    
    if success then
        return result
    else
        -- warn("Error checking money:", result)
        return 0
    end
end

local function checkAllUnits()
    if not _G.Enable or not _G.Upgrade then return {} end
    
    local unitCount = 0
    local unitList = {}
    
    local success, result = pcall(function()
        if not SystemState.unitsFolder or not SystemState.unitsFolder:IsDescendantOf(game) then
            SystemState.unitsFolder = player.UnitsFolder
            debugLog("Reattaching units folder reference")
        end
        
        if not SystemState.unitsFolder then
            debugLog("Units folder not found")
            return {}
        end
        
        for _, unit in pairs(SystemState.unitsFolder:GetChildren()) do
            if unit:IsA("Folder") or unit:IsA("Model") then
                table.insert(unitList, unit.Name)
                unitCount = unitCount + 1
            end
        end
        
        if not SystemState.hasCheckedUnits and #unitList > 0 and _G.Debug then
            debugLog("--------- Unit Check Results ---------")
            for i, unitName in ipairs(unitList) do
                debugLog(i .. " - Found Unit: " .. unitName)
            end
            debugLog("Total Units Found: " .. unitCount)
            SystemState.hasCheckedUnits = true
        end
        
        return unitList
    end)
    
    if success then
        return result or {}
    else
        warn("Error checking units:", result)
        return {}
    end
end

local function checkUpgradeCosts()
    if not _G.Enable or not _G.Upgrade then return {} end
    
    SystemState.unitUpgradeCosts = {}
    
    local success, result = pcall(function()
        if not SystemState.unitsFolder or not SystemState.unitsFolder:IsDescendantOf(game) then
            SystemState.unitsFolder = player.UnitsFolder
            debugLog("Reattaching units folder reference in checkUpgradeCosts")
        end
        
        if not SystemState.unitsFolder then
            debugLog("Units folder not found in checkUpgradeCosts")
            return {}
        end
        
        local unitsList = checkAllUnits()
        if #unitsList == 0 then
            return {}
        end
        
        for _, unitName in pairs(unitsList) do
            local unitFolder = SystemState.unitsFolder:FindFirstChild(unitName)
            if unitFolder and unitFolder:FindFirstChild("Upgrade_Folder") and unitFolder.Upgrade_Folder:FindFirstChild("Upgrade_Cost") then
                local cost = unitFolder.Upgrade_Folder.Upgrade_Cost.Value
                SystemState.unitUpgradeCosts[unitName] = cost
            end
        end
        return SystemState.unitUpgradeCosts
    end)
    
    if success then
        local sortedUnits = {}
        for unitName, cost in pairs(SystemState.unitUpgradeCosts) do
            table.insert(sortedUnits, {name = unitName, cost = cost})
        end
        
        table.sort(sortedUnits, function(a, b)
            return a.cost < b.cost
        end)
        
        if not SystemState.hasCheckedUnits and _G.Debug then
            debugLog("Units sorted by upgrade cost (lowest to highest):")
            for i, unit in ipairs(sortedUnits) do
                debugLog(i .. ". " .. unit.name .. " - Upgrade Cost: " .. unit.cost)
            end
        end
        
        return sortedUnits
    else
        warn("Error checking upgrade costs:", result)
        return {}
    end
end

local function getUnitUpgradeCost(unitName)
    if not _G.Enable or not _G.Upgrade then return 999999999 end
    
    if not unitName then
        debugLog("Unit name is nil in getUnitUpgradeCost")
        return 999999999
    end

    if not SystemState.unitsFolder or not SystemState.unitsFolder:IsDescendantOf(game) then
        SystemState.unitsFolder = player.UnitsFolder
        debugLog("Reattaching units folder reference in getUnitUpgradeCost")
    end
    
    if not SystemState.unitsFolder then
        debugLog("Units folder not found in getUnitUpgradeCost")
        return 999999999
    end
    
    local unit = SystemState.unitsFolder:FindFirstChild(unitName)
    if not unit then
        debugLog("Unit not found in getUnitUpgradeCost: " .. unitName)
        return 999999999
    end
    
    if not unit:FindFirstChild("Upgrade_Folder") or not unit.Upgrade_Folder:FindFirstChild("Upgrade_Cost") then
        debugLog("Upgrade data not found for unit: " .. unitName)
        return 999999999
    end
    
    return unit.Upgrade_Folder.Upgrade_Cost.Value
end

local function isUnitMaxUpgraded(unitName)
    if not _G.Enable or not _G.Upgrade then return true end
    
    if not unitName then
        debugLog("Unit name is nil in isUnitMaxUpgraded")
        return true
    end
    
    if not SystemState.unitsFolder or not SystemState.unitsFolder:IsDescendantOf(game) then
        SystemState.unitsFolder = player.UnitsFolder
        debugLog("Reattaching units folder reference in isUnitMaxUpgraded")
    end
    
    if not SystemState.unitsFolder then
        debugLog("Units folder not found in isUnitMaxUpgraded")
        return true
    end
    
    local unit = SystemState.unitsFolder:FindFirstChild(unitName)
    if not unit then
        debugLog("Unit not found in isUnitMaxUpgraded: " .. unitName)
        return true
    end
    
    if not unit:FindFirstChild("Upgrade_Folder") or not unit.Upgrade_Folder:FindFirstChild("Upgrade_Cost") then
        debugLog("Upgrade data not found for unit: " .. unitName)
        return true
    end
    
    local currentCost = unit.Upgrade_Folder.Upgrade_Cost.Value
    
    if SystemState.unitMaxUpgradeStatus[unitName] == nil then
        SystemState.unitMaxUpgradeStatus[unitName] = {
            lastCost = currentCost,
            checkCount = 0,
            isMax = false
        }
        return false
    end
    
    if currentCost == SystemState.unitMaxUpgradeStatus[unitName].lastCost then
        SystemState.unitMaxUpgradeStatus[unitName].checkCount = SystemState.unitMaxUpgradeStatus[unitName].checkCount + 1
        
        if SystemState.unitMaxUpgradeStatus[unitName].checkCount >= 3 then
            if not SystemState.unitMaxUpgradeStatus[unitName].isMax then
                SystemState.unitMaxUpgradeStatus[unitName].isMax = true
                debugLog("Unit " .. unitName .. " has reached maximum upgrade level")
                
                if SystemState.currentUpgradeTarget == unitName then
                    SystemState.currentUpgradeTarget = nil
                    SystemState.waitingForMoney = false
                end
            end
            return true
        end
    else
        SystemState.unitMaxUpgradeStatus[unitName].lastCost = currentCost
        SystemState.unitMaxUpgradeStatus[unitName].checkCount = 0
        SystemState.unitMaxUpgradeStatus[unitName].isMax = false
    end
    
    return SystemState.unitMaxUpgradeStatus[unitName].isMax
end

local function upgradeUnit(unitName)
    if not _G.Enable or not _G.Upgrade then return false end
    
    if not unitName then
        debugLog("Unit name is nil in upgradeUnit")
        return false
    end
    
    if not SystemState.unitsFolder or not SystemState.unitsFolder:IsDescendantOf(game) then
        SystemState.unitsFolder = player.UnitsFolder
        debugLog("Reattaching units folder reference in upgradeUnit")
    end
    
    if not SystemState.unitsFolder then
        debugLog("Units folder not found in upgradeUnit")
        return false
    end
    
    local unit = SystemState.unitsFolder:FindFirstChild(unitName)
    if not unit then
        debugLog("Unit not found in upgradeUnit: " .. unitName)
        return false
    end
    
    local success, result = pcall(function()
        local args = {
            [1] = unit
        }
        
        Remotes.UnitUpgrade:FireServer(unpack(args))
        return true
    end)
    
    if success then
        return result
    else
        warn("Error upgrading unit:", unitName, "-", result)
        return false
    end
end

local function updateCurrentUpgradingUnit(unitName)
    if not _G.Enable or not _G.Upgrade then return end
    
    if not unitName then
        debugLog("Unit name is nil in updateCurrentUpgradingUnit")
        return
    end
    
    if SystemState.currentUpgradingUnit ~= unitName then
        SystemState.currentUpgradingUnit = unitName
        debugLog("Currently upgrading unit: " .. unitName)
    end
end

local function startWaitingForMoney(unitName, requiredMoney)
    if not _G.Enable or not _G.Upgrade then return end
    
    if not unitName then
        debugLog("Unit name is nil in startWaitingForMoney")
        return
    end
    
    if not SystemState.waitingForMoney or SystemState.currentUpgradeTarget ~= unitName then
        SystemState.waitingForMoney = true
        SystemState.currentUpgradeTarget = unitName
        debugLog("Not enough money to upgrade " .. unitName .. " - Need " .. requiredMoney .. " - WAITING FOR MONEY")
    end
end

local function resetUpgradeSystemState()
    if not _G.Enable or not _G.Upgrade then return end
    
    debugLog("Resetting upgrade system state...")
    
    SystemState.unitUpgradeCosts = {}
    SystemState.unitMaxUpgradeStatus = {}
    SystemState.currentUpgradingUnit = nil
    SystemState.currentUpgradeTarget = nil
    SystemState.waitingForMoney = false
    SystemState.hasCheckedUnits = false
    
    SystemState.upgradeSystemReset = false

    setUpgradeDelay()
    
    if not SystemState.unitsFolder or not SystemState.unitsFolder:IsDescendantOf(game) then
        SystemState.unitsFolder = player.UnitsFolder
        debugLog("Reattaching units folder reference in resetUpgradeSystemState")
    end
    
    debugLog("Upgrade system reset complete - Will restart from lowest cost units")
end

local function CheckVisualsAndAutoClick()
    if not _G.Enable then return end

    local isRewardsUIVisible = false
    local success, err = pcall(function()
        local RewardsUI = player.PlayerGui:FindFirstChild("RewardsUI")
        isRewardsUIVisible = RewardsUI and RewardsUI.Enabled
    end)
    
    if not success then
        debugLog("Error checking RewardsUI: " .. tostring(err))
        return
    end

    local currentGameState = isRewardsUIVisible and "endgame" or "playing"
    if SystemState.lastGameState ~= currentGameState then
        debugLog("Game state changed from " .. tostring(SystemState.lastGameState) .. " to " .. currentGameState)
        
        if currentGameState == "playing" and SystemState.lastGameState == "endgame" then
            debugLog("Game state changed from endgame to playing - Forcing upgrade system reset")
            SystemState.upgradeSystemReset = true
            resetUpgradeSystemState()
        end
        
        SystemState.lastGameState = currentGameState
    end

    if isRewardsUIVisible then
        if not SystemState.autoClick.gameEnded then
            SystemState.autoClick.gameEnded = true
            SystemState.autoClick.newGameDetected = false
            debugLog("Game has ended! Detected RewardsUI")

            if not SystemState.hasVotedEndGame and _G.VotePlay then
                AutoVoteEndGame()
            end
        end
        
        if SystemState.autoClick.clickActive then
            SystemState.autoClick.clickActive = false
            SystemState.autoClick.printFlags.clickStarted = false
            SystemState.autoClick.printFlags.clickFunction = false
            if not SystemState.autoClick.printFlags.clickStopped then
                SystemState.autoClick.printFlags.clickStopped = true
                debugLog("Auto-clicking stopped: Rewards UI is visible")
            end
        end
        
        return
    end

    if SystemState.autoClick.gameEnded and not isRewardsUIVisible then
        SystemState.autoClick.gameEnded = false
        SystemState.autoClick.newGameDetected = true
        SystemState.hasVotedEndGame = false
        debugLog("New game detected! Rewards UI is no longer visible")
    end
    
    local visualGemExists = false
    local visualExpExists = false
    local visualGoldExists = false
    
    pcall(function()
        if workspace and workspace:FindFirstChild("Visual") then
            visualGemExists = workspace.Visual:FindFirstChild("Gem") ~= nil
            visualExpExists = workspace.Visual:FindFirstChild("Exp") ~= nil
            visualGoldExists = workspace.Visual:FindFirstChild("Gold") ~= nil
        end
    end)
    
    if visualGemExists or visualExpExists or visualGoldExists then
        if not SystemState.autoClick.clickActive then
            SystemState.autoClick.clickActive = true
            SystemState.autoClick.printFlags.clickStopped = false
            if not SystemState.autoClick.printFlags.clickStarted then
                SystemState.autoClick.printFlags.clickStarted = true
                debugLog("Auto-clicking started: Visual items detected")
            end
        end
    end
    
    if SystemState.autoClick.clickActive then
        if not SystemState.autoClick.printFlags.clickFunction then
            SystemState.autoClick.printFlags.clickFunction = true
            debugLog("Auto-clicking function active")
        end
        
        pcall(function()
            local camera = workspace.CurrentCamera
            if camera then
                local viewportSize = camera.ViewportSize
                local centerX = viewportSize.X / 2
                local centerY = viewportSize.Y / 2
                
                VirtualInputManager:SendMouseButtonEvent(centerX, centerY, 0, true, game, 1)
                VirtualInputManager:SendMouseButtonEvent(centerX, centerY, 0, false, game, 1)
            end
        end)
    end
end

local function detectGameStateChange()
    spawn(function()
        while wait(1) do
            if not _G.Enable then break end
            
            local inGame = false
            pcall(function()
                local HUD = player.PlayerGui:FindFirstChild("HUD")
                inGame = HUD and HUD:FindFirstChild("InGame") and HUD.InGame.Visible
            end)
            
            if inGame and SystemState.autoClick.newGameDetected then
                debugLog("Game state change confirmed - Forcing upgrade system reset")
                SystemState.upgradeSystemReset = true
                resetUpgradeSystemState()
                SystemState.autoClick.newGameDetected = false
            end
        end
    end)
end

local function runAutoUpgradeSystem()
    if SystemState.upgradeSystemStarted or not _G.Enable or not _G.Upgrade then
        return
    end
    
    SystemState.upgradeSystemStarted = true
    debugLog("Auto Upgrade System started")
    
    spawn(function()
        while wait(0.5) do
            if not _G.Enable or not _G.Upgrade then
                SystemState.upgradeSystemStarted = false
                debugLog("Auto Upgrade System stopped - Upgrade disabled")
                break
            end

            if isUpgradeDelayActive() then
                local remainingTime = SystemState.upgradeDelayDuration - (os.time() - SystemState.upgradeDelayStartTime)
                if remainingTime > 0 and remainingTime % 1 == 0 then
                    debugLog("Waiting for upgrade delay: " .. remainingTime .. " seconds remaining")
                end
                continue
            end
            
            if SystemState.upgradeSystemReset then
                resetUpgradeSystemState()
            end
            
            if SystemState.autoClick.newGameDetected then
                debugLog("New game detected - Resetting upgrade system")
                resetUpgradeSystemState()
                SystemState.autoClick.newGameDetected = false
            end
            
            if not SystemState.unitsFolder or not SystemState.unitsFolder:IsDescendantOf(game) then
                SystemState.unitsFolder = player.UnitsFolder
                debugLog("Reattaching units folder reference in autoUpgrade main loop")
                
                if not SystemState.unitsFolder then
                    debugLog("Units folder not available - Waiting...")
                    wait(1)
                    continue
                end
            end
            
            local playerMoney = checkPlayerMoney()
            local sortedUnits = checkUpgradeCosts()
            
            if #sortedUnits == 0 then
                debugLog("No units available for upgrade, waiting...")
                wait(1)
                continue
            end
            
            if SystemState.waitingForMoney and SystemState.currentUpgradeTarget then
                if not SystemState.unitsFolder:FindFirstChild(SystemState.currentUpgradeTarget) then
                    debugLog("Target unit no longer exists: " .. SystemState.currentUpgradeTarget)
                    SystemState.waitingForMoney = false
                    SystemState.currentUpgradeTarget = nil
                    continue
                end
                
                local currentCost = getUnitUpgradeCost(SystemState.currentUpgradeTarget)
                if currentCost == 999999999 then
                    debugLog("Cannot get upgrade cost for target unit: " .. SystemState.currentUpgradeTarget)
                    SystemState.waitingForMoney = false
                    SystemState.currentUpgradeTarget = nil
                    continue
                end
                
                if playerMoney >= currentCost then
                    debugLog("Now have enough money to upgrade " .. SystemState.currentUpgradeTarget)
                    SystemState.waitingForMoney = false
                    
                    updateCurrentUpgradingUnit(SystemState.currentUpgradeTarget)
                    local success = upgradeUnit(SystemState.currentUpgradeTarget)
                    
                    if success then
                        wait(0.2)
                        
                        if isUnitMaxUpgraded(SystemState.currentUpgradeTarget) then
                            debugLog("Unit " .. SystemState.currentUpgradeTarget .. " is now Max upgraded")
                            SystemState.currentUpgradeTarget = nil
                        else
                            local newCost = getUnitUpgradeCost(SystemState.currentUpgradeTarget)
                            startWaitingForMoney(SystemState.currentUpgradeTarget, newCost)
                        end
                    end
                else
                    if math.random(1, 10) == 1 and _G.Debug then
                        debugLog("Still waiting for money to upgrade " .. SystemState.currentUpgradeTarget)
                    end
                end
                
                continue
            end
            
            if not SystemState.waitingForMoney then
                local foundUnitToUpgrade = false
                
                for _, unitData in ipairs(sortedUnits) do
                    local unitName = unitData.name
                    local upgradeCost = unitData.cost
                    
                    if not SystemState.unitsFolder:FindFirstChild(unitName) then
                        debugLog("Unit no longer exists: " .. unitName)
                        continue
                    end
                    
                    if not isUnitMaxUpgraded(unitName) then
                        foundUnitToUpgrade = true
                        
                        if playerMoney >= upgradeCost then
                            SystemState.currentUpgradeTarget = unitName
                            updateCurrentUpgradingUnit(unitName)
                            
                            local success = upgradeUnit(unitName)
                            if success then
                                wait(0.2)
                                
                                if isUnitMaxUpgraded(unitName) then
                                    debugLog("Unit " .. unitName .. " is now Max upgraded")
                                    SystemState.currentUpgradeTarget = nil
                                else
                                    local newCost = getUnitUpgradeCost(unitName)
                                    if playerMoney < newCost then
                                        startWaitingForMoney(unitName, newCost)
                                    end
                                end
                            end
                        else
                            SystemState.currentUpgradeTarget = unitName
                            startWaitingForMoney(unitName, upgradeCost)
                        end
                        
                        break
                    end
                end
                
                if not foundUnitToUpgrade and not SystemState.currentUpgradeTarget then
                    debugLog("All units are already at maximum upgrade level!")
                    wait(5)
                end
            end
        end
    end)
end

local function runAutoClickSystem()
    spawn(function()
        debugLog("Auto-Click System started")
        while true do
            local success, err = pcall(function()
                if not _G.Enable then
                    debugLog("Auto-Click System stopped - Scripts disabled")
                    return "BREAK"
                end
                
                CheckVisualsAndAutoClick()
                wait(0.01)
            end)
            
            if not success then
                if err ~= "BREAK" then
                    debugLog("Error in Auto-Click System: " .. tostring(err))
                    wait(1)
                else
                    break
                end
            end
        end
    end)
end

local function runEndGameVoteSystem()
    if not _G.Enable or not _G.VotePlay then return end
    
    spawn(function()
        debugLog("End Game Vote System started (Mode: " .. _G.VoteMode .. ")")
        while wait(1) do
            if not _G.Enable or not _G.VotePlay then
                debugLog("End Game Vote System stopped - VotePlay disabled")
                break
            end
            
            if not SystemState.hasVotedEndGame then
                AutoVoteEndGame()
            end
        end
    end)
end

local function runMoneyCheckSystem()
    if not _G.Enable then return end
    
    spawn(function()
        debugLog("Money Check System started")
        while wait(0.1) do
            if not _G.Enable then
                debugLog("Money Check System stopped - Scripts disabled")
                break
            end
            
            checkPlayerMoney()
        end
    end)
end

local function StartAllSystems()
    if not _G.Enable then
        print("[Auto System] Scripts are disabled. Change _G.Enable to true to start.")
        return
    end
    
    debugLog("Starting all systems...")
    debugLog("Config settings:")
    debugLog("- Enable: " .. tostring(_G.Enable))
    debugLog("- Upgrade: " .. tostring(_G.Upgrade))
    debugLog("- VotePlay: " .. tostring(_G.VotePlay))
    debugLog("- Debug: " .. tostring(_G.Debug))
    debugLog("- VoteMode: " .. _G.VoteMode)
    debugLog("- Upgrade Delay: " .. tostring(SystemState.upgradeDelayDuration) .. " seconds")
    
    setupAntiAFK()
    detectGameStateChange()
    
    if _G.VotePlay then
        local voteCheckTimer = 0
        local maxVoteCheckTime = 10
        
        spawn(function()
            while not SystemState.voteCheckCompleted and voteCheckTimer < maxVoteCheckTime do
                local voteResult = AutoVotePlaying()
                
                if voteResult then
                    debugLog("Auto VotePlaying completed successfully")
                    SystemState.voteCheckCompleted = true

                    setUpgradeDelay()
                    break
                end
                
                voteCheckTimer = voteCheckTimer + 1
                wait(1)
            end
            
            if not SystemState.voteCheckCompleted then
                debugLog("Auto VotePlaying check timed out, proceeding with other systems")
                SystemState.voteCheckCompleted = true
            end
            
            runMoneyCheckSystem()
            if _G.VotePlay then
                runEndGameVoteSystem()
            end
            runAutoClickSystem()
            if _G.Upgrade then
                runAutoUpgradeSystem()
            end
        end)
    else
        SystemState.voteCheckCompleted = true
        runMoneyCheckSystem()
        runAutoClickSystem()

        setUpgradeDelay()
        
        if _G.Upgrade then
            runAutoUpgradeSystem()
        end
    end
end

spawn(function()
    local lastEnable = _G.Enable
    local lastUpgrade = _G.Upgrade
    local lastVotePlay = _G.VotePlay
    local lastDebug = _G.Debug
    local lastVoteMode = _G.VoteMode
    while wait(1) do
        if lastEnable ~= _G.Enable then
            print("[Auto System] Master switch changed to: " .. tostring(_G.Enable))
            lastEnable = _G.Enable
            
            if _G.Enable then
                print("[Auto System] Restarting all systems...")
                StartAllSystems()
            else
                print("[Auto System] Stopping all systems...")
            end
        end

        if _G.Enable then
            if lastUpgrade ~= _G.Upgrade then
                debugLog("Upgrade setting changed to: " .. tostring(_G.Upgrade))
                lastUpgrade = _G.Upgrade
                
                if _G.Upgrade and not SystemState.upgradeSystemStarted then
                    setUpgradeDelay()
                    runAutoUpgradeSystem()
                end
            end
            
            if lastVotePlay ~= _G.VotePlay then
                debugLog("VotePlay setting changed to: " .. tostring(_G.VotePlay))
                lastVotePlay = _G.VotePlay
                
                if _G.VotePlay then
                    runEndGameVoteSystem()
                end
            end
            if lastDebug ~= _G.Debug then
                print("[Auto System] Debug mode changed to: " .. tostring(_G.Debug))
                lastDebug = _G.Debug
            end
            
            if lastVoteMode ~= _G.VoteMode then
                debugLog("VoteMode changed to: " .. _G.VoteMode)
                lastVoteMode = _G.VoteMode
            end
        end
    end
end)

local function checkUnitsFolder()
    spawn(function()
        while wait(5) do
            if not _G.Enable then break end
            
            if not SystemState.unitsFolder or not SystemState.unitsFolder:IsDescendantOf(game) then
                local newUnitsFolder = player:FindFirstChild("UnitsFolder")
                if newUnitsFolder then
                    SystemState.unitsFolder = newUnitsFolder
                    debugLog("UnitsFolder reference restored")

                    SystemState.unitUpgradeCosts = {}
                    SystemState.unitMaxUpgradeStatus = {}
                    SystemState.hasCheckedUnits = false
                else
                    debugLog("Cannot find UnitsFolder, waiting...")
                end
            end
        end
    end)
end

local function SyntaxErrors()
    debugLog("Syntax errors fixed")
end

local function HUNTERXSTART()
    StartAllSystems()
    checkUnitsFolder()
    SyntaxErrors()
end

HUNTERXSTART()

print("HUNTER X HUB - SCRIPTS LOADING SUCCESS")
