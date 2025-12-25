-- BOOTH CLAIMER DEBUG VERSION
-- Standalone for easier debugging

local Players = game:GetService("Players")
local VirtualInputManager = game:GetService("VirtualInputManager")
local player = Players.LocalPlayer

local BOOTH_CHECK_POSITION = Vector3.new(165, 0, 311)
local MAX_BOOTH_DISTANCE = 92
local HOLD_E_DURATION = 3
local MAX_CLAIM_ATTEMPTS = 5

-- Wait for character
if not player.Character then player.CharacterAdded:Wait() end
player.Character:WaitForChild("HumanoidRootPart")

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

local function holdE(duration)
    print("[BOOTH] Holding E for " .. duration .. " seconds...")
    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
    task.wait(duration)
    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
end

local function verifyClaim(boothLocation, boothNum)
    local boothUI = boothLocation:FindFirstChild("BoothUI")
    if not boothUI then return false end
    local boothFrame = boothUI:FindFirstChild("BoothUI" .. boothNum)
    if not boothFrame then return false end
    local details = boothFrame:FindFirstChild("Details")
    if not details then return false end
    local owner = details:FindFirstChild("Owner")
    if not owner then return false end
    local ownerText = owner.Text
    print("[DEBUG] Owner text for booth #"..boothNum..": ", ownerText)
    return string.find(ownerText, player.DisplayName) ~= nil or string.find(ownerText, player.Name) ~= nil
end

local function claimBooth()
    print("=== BOOTH CLAIMER DEBUG ===")
    local boothLocation = getBoothLocation()
    if not boothLocation then
        print("[BOOTH] ERROR: Could not find booth UI!")
        return nil
    end
    local unclaimed = findUnclaimedBooths(boothLocation)
    print("[BOOTH] Found " .. #unclaimed .. " unclaimed booth(s)")
    if #unclaimed == 0 then
        print("[BOOTH] ERROR: No booths available!")
        return nil
    end
    for i, booth in ipairs(unclaimed) do
        if i > MAX_CLAIM_ATTEMPTS then break end
        print("[BOOTH] Trying Booth #" .. booth.number .. "...")
        teleportTo(booth.cframe)
        task.wait(0.3)
        holdE(HOLD_E_DURATION)
        task.wait(1)
        local success = verifyClaim(boothLocation, booth.number)
        print("[DEBUG] verifyClaim result for booth #"..booth.number..": ", success)
        if success then
            print("[BOOTH] SUCCESS! Claimed Booth #" .. booth.number)
            print("[BOOTH] Position: " .. tostring(booth.position))
            return booth.position
        else
            print("[BOOTH] Failed, trying next...")
        end
    end
    print("[BOOTH] ERROR: Could not claim any booth!")
    return nil
end

-- RUN DEBUG
local pos = claimBooth()
if pos then
    print("[RESULT] Claimed booth at:", pos)
else
    print("[RESULT] Failed to claim any booth.")
end
