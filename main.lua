-- BOOTH FINDER & CLAIMER (Please Donate)
-- Uses physical interaction (hold E) to claim booths

local Players = game:GetService("Players")
local VirtualInputManager = game:GetService("VirtualInputManager")
local LocalPlayer = Players.LocalPlayer

-- Wait for character to fully load
if not LocalPlayer.Character then
    print("Waiting for character to load...")
    LocalPlayer.CharacterAdded:Wait()
end
local character = LocalPlayer.Character
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
local humanoid = character:WaitForChild("Humanoid")
print("Character loaded!")

-- ============ CONFIGURATION ============
local MAIN_CHECK_POSITION = Vector3.new(165, 0, 311)  -- Center point to search around
local MAX_BOOTH_DISTANCE = 92                          -- Max studs from check position
local HOLD_E_DURATION = 2                              -- Seconds to hold E key
local CLAIM_VERIFY_DELAY = 0.5                         -- Seconds to wait after releasing E
local MAX_CLAIM_ATTEMPTS = 5                           -- Max booths to try before giving up

-- Movement settings
local SPRINT_KEY = Enum.KeyCode.LeftShift
local TARGET_DISTANCE = 5                              -- How close to get to booth
local STUCK_THRESHOLD = 0.5                            -- Min movement to not be "stuck"
local STUCK_CHECK_TIME = 1                             -- Seconds before anti-stuck kicks in
local JUMP_DURATION = 0.3                              -- How long to hold jump
local MAX_JUMP_TRIES = 3                               -- Max jumps before random dodge
local MAX_RANDOM_TRIES = 3                             -- Max random dodges before giving up
-- ========================================

local isSprinting = false

-- Get booth UI location (handles both map layouts)
local function getBoothLocation()
    local boothLocation = nil
    
    pcall(function()
        boothLocation = LocalPlayer:WaitForChild('PlayerGui', 5)
            :WaitForChild('MapUIContainer', 5)
            :WaitForChild('MapUI', 5)
    end)
    
    if not boothLocation then
        boothLocation = workspace:WaitForChild('MapUI', 5)
    end
    
    return boothLocation
end

-- Find all unclaimed booths near the check position
local function findUnclaimedBooths(boothLocation)
    local unclaimed = {}
    local boothUI = boothLocation:WaitForChild("BoothUI", 5)
    local interactions = workspace:WaitForChild("BoothInteractions", 5)
    
    if not boothUI or not interactions then
        return unclaimed
    end
    
    local mainPos2D = Vector3.new(MAIN_CHECK_POSITION.X, 0, MAIN_CHECK_POSITION.Z)
    
    for _, uiFrame in ipairs(boothUI:GetChildren()) do
        if uiFrame:FindFirstChild("Details") and uiFrame.Details:FindFirstChild("Owner") then
            if uiFrame.Details.Owner.Text == "unclaimed" then
                local boothNum = tonumber(uiFrame.Name:match("%d+"))
                
                if boothNum then
                    for _, interact in ipairs(interactions:GetChildren()) do
                        if interact:GetAttribute("BoothSlot") == boothNum then
                            local pos2D = Vector3.new(interact.Position.X, 0, interact.Position.Z)
                            local distance = (pos2D - mainPos2D).Magnitude
                            
                            if distance < MAX_BOOTH_DISTANCE then
                                table.insert(unclaimed, {
                                    number = boothNum,
                                    position = interact.Position,
                                    cframe = interact.CFrame,
                                    interactPart = interact,
                                    distance = distance
                                })
                            end
                            break
                        end
                    end
                end
            end
        end
    end
    
    table.sort(unclaimed, function(a, b)
        return a.distance < b.distance
    end)
    
    return unclaimed
end

-- Verify if we successfully claimed the booth
local function verifyClaim(boothLocation, boothNum)
    task.wait(CLAIM_VERIFY_DELAY)
    local boothUI = boothLocation.BoothUI:FindFirstChild("BoothUI" .. boothNum)
    if boothUI and boothUI.Details and boothUI.Details.Owner then
        local ownerText = boothUI.Details.Owner.Text
        return ownerText ~= "unclaimed" and string.find(ownerText, LocalPlayer.DisplayName) ~= nil
    end
    return false
end

-- Sprint control
local function startSprinting()
    if isSprinting then return end
    VirtualInputManager:SendKeyEvent(true, SPRINT_KEY, false, game)
    isSprinting = true
end

local function stopSprinting()
    if not isSprinting then return end
    VirtualInputManager:SendKeyEvent(false, SPRINT_KEY, false, game)
    isSprinting = false
end

-- Walk to a position with anti-stuck logic
local function performMove(getPos, sprint)
    if sprint then startSprinting() end
    local lastPos = humanoidRootPart.Position
    local stuckTime = 0
    local jumpTries = 0
    local randTries = 0

    while true do
        task.wait(0.1)
        local pos = getPos()
        if (humanoidRootPart.Position - pos).Magnitude <= TARGET_DISTANCE then
            if sprint then stopSprinting() end
            return true
        end

        humanoid:MoveTo(pos)
        local moved = (humanoidRootPart.Position - lastPos).Magnitude
        if moved < STUCK_THRESHOLD then 
            stuckTime = stuckTime + 0.1 
        else 
            stuckTime = 0
            lastPos = humanoidRootPart.Position 
        end

        if stuckTime >= STUCK_CHECK_TIME then
            if jumpTries < MAX_JUMP_TRIES then
                jumpTries = jumpTries + 1
                print("[ANTI-STUCK] Jump unstick #" .. jumpTries)
                VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
                task.wait(JUMP_DURATION)
                VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
                task.wait(0.5)
            else
                randTries = randTries + 1
                print("[ANTI-STUCK] Random dodge #" .. randTries)
                local a = math.random() * math.pi * 2
                local dodge = pos + Vector3.new(math.cos(a) * 80, 0, math.sin(a) * 80)
                humanoid:MoveTo(dodge)
                task.wait(3)
                if randTries >= MAX_RANDOM_TRIES then
                    if sprint then stopSprinting() end
                    return false
                end
            end
            stuckTime = 0
            lastPos = humanoidRootPart.Position
        end
    end
end

-- Walk player to booth
local function walkToBooth(booth)
    print("Walking to Booth #" .. booth.number .. "...")
    
    local success = performMove(function()
        return booth.position
    end, true)  -- true = sprint
    
    if success then
        print("Arrived at booth position")
    else
        print("Failed to reach booth (got stuck)")
    end
    
    return success
end

-- Simulate holding E key to claim booth
local function holdEKey()
    print("Holding E to claim...")
    
    -- Method 1: VirtualInputManager (if available)
    local vim = nil
    pcall(function()
        vim = game:GetService("VirtualInputManager")
    end)
    
    if vim then
        -- Press E
        vim:SendKeyEvent(true, Enum.KeyCode.E, false, game)
        task.wait(HOLD_E_DURATION)
        -- Release E
        vim:SendKeyEvent(false, Enum.KeyCode.E, false, game)
        print("Released E (VirtualInputManager)")
        return true
    end
    
    -- Method 2: keypress/keyrelease (executor functions)
    if keypress and keyrelease then
        keypress(0x45)  -- E key
        task.wait(HOLD_E_DURATION)
        keyrelease(0x45)
        print("Released E (keypress/keyrelease)")
        return true
    end
    
    -- Method 3: Direct proximity prompt firing
    local success = pcall(function()
        for _, interact in ipairs(workspace.BoothInteractions:GetChildren()) do
            local prompt = interact:FindFirstChildOfClass("ProximityPrompt")
            if prompt then
                local dist = (humanoidRootPart.Position - interact.Position).Magnitude
                if dist < 15 then
                    print("Found nearby ProximityPrompt, triggering...")
                    if fireproximityprompt then
                        fireproximityprompt(prompt, HOLD_E_DURATION)
                    else
                        prompt:InputHoldBegin()
                        task.wait(HOLD_E_DURATION)
                        prompt:InputHoldEnd()
                    end
                    return
                end
            end
        end
    end)
    
    if success then
        return true
    end
    
    print("WARNING: Could not simulate E key - try holding E manually!")
    task.wait(HOLD_E_DURATION)
    return false
end

-- ============ MAIN FUNCTION ============
local function find_claim_booth()
    print("=== BOOTH CLAIMER ===")
    
    local boothLocation = getBoothLocation()
    if not boothLocation then
        print("ERROR: Could not find booth UI location!")
        return nil
    end
    print("Found booth UI location: " .. boothLocation:GetFullName())
    
    local unclaimed = findUnclaimedBooths(boothLocation)
    print("Found " .. #unclaimed .. " unclaimed booth(s) nearby")
    
    if #unclaimed == 0 then
        print("ERROR: No unclaimed booths available!")
        return nil
    end
    
    print("--- Available Booths ---")
    for i, booth in ipairs(unclaimed) do
        print(string.format("  %d. Booth #%d (%.1f studs away)", i, booth.number, booth.distance))
    end
    print("------------------------")
    
    -- Try to claim booths
    local claimedBooth = nil
    local attempts = 0
    
    for _, booth in ipairs(unclaimed) do
        if attempts >= MAX_CLAIM_ATTEMPTS then
            break
        end
        attempts = attempts + 1
        
        print("\n>> Attempting Booth #" .. booth.number .. " <<")
        
        -- Step 1: Walk to the booth
        local reached = walkToBooth(booth)
        if not reached then
            print("Could not reach Booth #" .. booth.number .. ", trying next...")
            goto continue
        end
        
        -- Step 2: Hold E to claim
        holdEKey()
        
        ::continue::
        
        -- Step 3: Verify claim
        if verifyClaim(boothLocation, booth.number) then
            claimedBooth = booth
            print("SUCCESS: Claimed Booth #" .. booth.number .. "!")
            break
        else
            print("Failed to claim Booth #" .. booth.number .. ", trying next...")
        end
    end
    
    if not claimedBooth then
        print("\nERROR: Could not claim any booth!")
        return nil
    end
    
    -- Output booth coordinates
    local pos = claimedBooth.position
    print("\n=== BOOTH COORDINATES ===")
    print("Booth Number: " .. claimedBooth.number)
    print("Vector3.new(" .. math.floor(pos.X) .. ", " .. math.floor(pos.Y) .. ", " .. math.floor(pos.Z) .. ")")
    print("Full Position: " .. tostring(pos))
    print("Distance from center: " .. string.format("%.1f", claimedBooth.distance) .. " studs")
    print("=========================")
    
    return claimedBooth
end

-- ============ RUN ============
local result = find_claim_booth()

if result then
    print("\nReturned booth data:")
    print("  .number   = " .. result.number)
    print("  .position = " .. tostring(result.position))
    print("  .cframe   = " .. tostring(result.cframe))
    print("  .distance = " .. result.distance)
end