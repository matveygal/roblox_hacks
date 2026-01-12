-- Test booth claiming by trying all unclaimed booths
local Players = game:GetService("Players")
local player = Players.LocalPlayer

-- Setup file logging
local logLines = {}
local function log(msg)
    print(msg)
    table.insert(logLines, msg)
end

local function saveLog()
    local content = table.concat(logLines, "\n")
    writefile("booth_debug_log.txt", content)
    print("[FILE] Log saved to booth_debug_log.txt")
end

log("[TEST] Attempting to claim booths one by one...")
log("")

-- Constants from main.lua
local BOOTH_CHECK_POSITION = Vector3.new(165, 0, 311)
local MAX_BOOTH_DISTANCE = 92

-- Helper functions from main.lua
local function getBoothLocation()
    local boothLocation = nil
    pcall(function()
        boothLocation = player:WaitForChild('PlayerGui', 5)
            :WaitForChild('MapUIContainer', 5)
            :WaitForChild('MapUI', 5)
    end)
    if not boothLocation then
        boothLocation = workspace:WaitForChild('MapUI', 5)
    end
    return boothLocation
end

local function findUnclaimedBooths(boothLocation)
    local unclaimed = {}
    local boothUI = boothLocation:WaitForChild("BoothUI", 5)
    local interactions = workspace:WaitForChild("BoothInteractions", 5)
    if not boothUI or not interactions then return unclaimed end
    local mainPos2D = Vector3.new(BOOTH_CHECK_POSITION.X, 0, BOOTH_CHECK_POSITION.Z)
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
    table.sort(unclaimed, function(a, b) return a.distance < b.distance end)
    return unclaimed
end

local function teleportTo(cframe)
    local root = player.Character:FindFirstChild("HumanoidRootPart")
    if root then
        root.CFrame = cframe
        task.wait(0.1)
    end
end

local function verifyClaim(boothLocation, boothNum)
    local boothUI = boothLocation.BoothUI or boothLocation:FindFirstChild("BoothUI")
    if not boothUI then return false end
    local boothFrame = boothUI:FindFirstChild("BoothUI" .. boothNum)
    if not boothFrame then return false end
    local details = boothFrame:FindFirstChild("Details")
    if not details then return false end
    local owner = details:FindFirstChild("Owner")
    if not owner then return false end
    local ownerText = owner.Text
    log("[VERIFY] Owner text for booth #"..boothNum..": " .. ownerText)
    return string.find(ownerText, player.DisplayName) ~= nil or string.find(ownerText, player.Name) ~= nil
end

-- Get booth location
local boothLocation = getBoothLocation()
if not boothLocation then
    log("[ERROR] Could not find booth UI!")
    saveLog()
    return
end

-- Find unclaimed booths
local unclaimed = findUnclaimedBooths(boothLocation)
log("[FOUND] " .. #unclaimed .. " unclaimed booth(s)")

if #unclaimed == 0 then
    log("[ERROR] No unclaimed booths available!")
    saveLog()
    return
end

-- Get BoothInteractions reference
local boothInteractions = workspace:FindFirstChild("BoothInteractions")
if not boothInteractions then
    log("[ERROR] BoothInteractions not found in Workspace!")
    saveLog()
    return
end

log("[READY] Starting booth claiming attempts...")
log("")

-- Try each booth one by one
for i, booth in ipairs(unclaimed) do
    log("═══════════════════════════════════════════════")
    log("[ATTEMPT " .. i .. "/" .. #unclaimed .. "] Trying Booth #" .. booth.number)
    log("[INFO] Distance: " .. math.floor(booth.distance) .. " studs")
    
    -- Find the ProximityPrompt for THIS specific booth
    local myBoothInteraction = nil
    for _, interact in ipairs(boothInteractions:GetChildren()) do
        if interact:GetAttribute("BoothSlot") == booth.number then
            myBoothInteraction = interact
            log("[FOUND] This booth's interaction object: " .. interact.Name)
            break
        end
    end
    
    if not myBoothInteraction then
        log("[ERROR] Couldn't find interaction object for booth #" .. booth.number)
        continue
    end
    
    -- Find ProximityPrompt in this booth's interaction
    local claimPrompt = nil
    for _, child in ipairs(myBoothInteraction:GetChildren()) do
        if child:IsA("ProximityPrompt") and child.Name == "Claim" then
            claimPrompt = child
            log("[FOUND] ProximityPrompt: " .. child.Name .. " | MaxDistance: " .. tostring(child.MaxActivationDistance))
            break
        end
    end
    
    if not claimPrompt then
        log("[ERROR] No ProximityPrompt found for booth #" .. booth.number)
        continue
    end
    
    -- Try claiming this booth up to 3 times
    local claimed = false
    for attempt = 1, 3 do
        -- Teleport closer to the ProximityPrompt's parent (the booth interaction part)
        local targetCFrame = myBoothInteraction.CFrame * CFrame.new(0, 0, 2)  -- Teleport 2 studs in front
        teleportTo(targetCFrame)
        task.wait(0.5)  -- Let physics settle
        
        -- Check distance to ProximityPrompt
        local root = player.Character:FindFirstChild("HumanoidRootPart")
        if root then
            local distance = (root.Position - myBoothInteraction.Position).Magnitude
            log("[DISTANCE] " .. math.floor(distance * 10) / 10 .. " studs from booth interaction")
        end
        
        -- Trigger ProximityPrompt
        log("[ACTION] Triggering " .. claimPrompt.Name .. " (attempt " .. attempt .. "/3)...")
        local success, err = pcall(function()
            fireproximityprompt(claimPrompt)
        end)
        
        if not success then
            log("[ERROR] ProximityPrompt trigger failed: " .. tostring(err))
        else
            log("[ACTION] ProximityPrompt triggered!")
        end
        
        -- Wait longer for server to process
        task.wait(2)
        
        -- Verify claim
        claimed = verifyClaim(boothLocation, booth.number)
        if claimed then
            log("╔═══════════════════════════════════════════════")
            log("║ [SUCCESS] CLAIMED BOOTH #" .. booth.number .. "!")
            log("║ Position: " .. tostring(booth.position))
            log("╚═══════════════════════════════════════════════")
            saveLog()
            return
        else
            if attempt < 3 then
                log("[RETRY] Claim didn't register, retrying...")
            end
        end
    end
    
    log("[FAILED] Booth #" .. booth.number .. " failed after 3 attempts, trying next...")
    log("")
end

log("[FINAL] All booths tried, none claimed!")
log("")
saveLog()
