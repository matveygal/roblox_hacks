-- BOOTH FINDER & CLAIMER (Please Donate)
-- Clean standalone function for educational/private server use

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- ============ CONFIGURATION ============
local MAIN_CHECK_POSITION = Vector3.new(165, 0, 311)  -- Center point to search around
local MAX_BOOTH_DISTANCE = 92                          -- Max studs from check position
local CLAIM_VERIFY_DELAY = 1                           -- Seconds to wait for claim verification
local MAX_CLAIM_ATTEMPTS = 5                           -- Max booths to try before giving up
-- ========================================

-- Get booth UI location (handles both map layouts)
local function getBoothLocation()
    local boothLocation = nil
    
    -- Try PlayerGui location first (shuffled maps)
    pcall(function()
        boothLocation = LocalPlayer:WaitForChild('PlayerGui', 5)
            :WaitForChild('MapUIContainer', 5)
            :WaitForChild('MapUI', 5)
    end)
    
    -- Fall back to workspace location
    if not boothLocation then
        boothLocation = workspace:WaitForChild('MapUI', 5)
    end
    
    return boothLocation
end

-- Get remotes folder
local function getRemotes()
    return LocalPlayer:WaitForChild("PlayerScripts")
        :WaitForChild("PlayerModule")
        :WaitForChild("Remotes")
end

-- Fire a remote event by name
local function fireRemote(remotes, eventName)
    local remote = remotes:FindFirstChild(eventName)
    if remote then
        return remote
    end
    return nil
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
        -- Check if booth UI has the expected structure
        if uiFrame:FindFirstChild("Details") and uiFrame.Details:FindFirstChild("Owner") then
            if uiFrame.Details.Owner.Text == "unclaimed" then
                -- Extract booth number from name (e.g., "BoothUI42" -> 42)
                local boothNum = tonumber(uiFrame.Name:match("%d+"))
                
                if boothNum then
                    -- Find the corresponding interaction part for position
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
    
    -- Sort by distance (closest first)
    table.sort(unclaimed, function(a, b)
        return a.distance < b.distance
    end)
    
    return unclaimed
end

-- Verify if we successfully claimed the booth
local function verifyClaim(boothLocation, boothNum)
    local boothUI = boothLocation.BoothUI:FindFirstChild("BoothUI" .. boothNum)
    if boothUI and boothUI.Details and boothUI.Details.Owner then
        return string.find(boothUI.Details.Owner.Text, LocalPlayer.DisplayName) ~= nil
    end
    return false
end

-- ============ MAIN FUNCTION ============
local function find_claim_booth()
    print("=== BOOTH CLAIMER ===")
    
    -- Get booth location
    local boothLocation = getBoothLocation()
    if not boothLocation then
        print("ERROR: Could not find booth UI location!")
        return nil
    end
    print("Found booth UI location: " .. boothLocation:GetFullName())
    
    -- Find unclaimed booths
    local unclaimed = findUnclaimedBooths(boothLocation)
    print("Found " .. #unclaimed .. " unclaimed booth(s) nearby")
    
    if #unclaimed == 0 then
        print("ERROR: No unclaimed booths available!")
        return nil
    end
    
    -- List all found booths
    print("--- Available Booths ---")
    for i, booth in ipairs(unclaimed) do
        print(string.format("  %d. Booth #%d (%.1f studs away)", i, booth.number, booth.distance))
    end
    print("------------------------")
    
    -- Get remotes for claiming
    local remotes = nil
    pcall(function()
        remotes = getRemotes()
    end)
    
    -- Try to claim a booth
    local claimedBooth = nil
    local attempts = 0
    
    for _, booth in ipairs(unclaimed) do
        if attempts >= MAX_CLAIM_ATTEMPTS then
            break
        end
        attempts = attempts + 1
        
        print("Attempting to claim Booth #" .. booth.number .. "...")
        
        -- Fire the claim remote
        local success = pcall(function()
            if remotes then
                local claimRemote = remotes:FindFirstChild("ClaimBooth")
                if claimRemote then
                    claimRemote:InvokeServer(booth.number)
                end
            end
        end)
        
        -- Wait and verify
        task.wait(CLAIM_VERIFY_DELAY)
        
        if verifyClaim(boothLocation, booth.number) then
            claimedBooth = booth
            print("SUCCESS: Claimed Booth #" .. booth.number .. "!")
            break
        else
            print("Failed to claim Booth #" .. booth.number .. ", trying next...")
        end
    end
    
    if not claimedBooth then
        print("ERROR: Could not claim any booth!")
        return nil
    end
    
    -- Output booth coordinates (like get_cords.lua style)
    local pos = claimedBooth.position
    print("=== BOOTH COORDINATES ===")
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
