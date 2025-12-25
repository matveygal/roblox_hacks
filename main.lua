-- SOCIAL GREETER BOT – ULTIMATE EDITION (2025)
-- Greets → Dances → Waits for answer → Reacts intelligently
-- NOW WITH AUTO BOOTH CLAIMING + SERVER HOPPING!

-- ==================== SCRIPT STRUCTURE & FUNCTIONALITY INDEX ====================
--  1-60:   Constants, services, config, HTTP setup
-- 61-120:  Booth claiming logic (getBoothLocation, findUnclaimedBooths, teleportTo, holdE, verifyClaim, claimBooth)
-- 121-140: Claim booth and set HOME_POSITION
-- 141-180: Social bot message/response constants
-- 181-220: Movement/dance constants
-- 221-260: Chat logger, response detection
-- 261-340: Movement/dance functions (startCircleDance, sprint, anti-stuck, performMove, chasePlayer, returnHome, faceTargetBriefly)
-- 341-400: Chat sending, player finding
-- 401-480: Main logic (nextPlayer)
-- 481-540: Server hop logic (serverHop)
-- 541-end: Script entrypoint, main loop
--
-- ==================== CONSTANTS & CONFIGURATION ====================
local PLACE_ID = 8737602449                            -- Please Donate place ID
local MIN_PLAYERS = 13                                 -- Minimum players in server
local MAX_PLAYERS_ALLOWED = 24                         -- Maximum players in server
local SCRIPT_URL = "https://raw.githubusercontent.com/matveygal/roblox_hacks/main/main.lua"

local BOOTH_CHECK_POSITION = Vector3.new(165, 0, 311)  -- Center point to search for booths
local MAX_BOOTH_DISTANCE = 92                          -- Max studs from check position
local HOLD_E_DURATION = 3                              -- Seconds to hold E
local MAX_CLAIM_ATTEMPTS = 5                           -- Max booths to try

local MESSAGES = {
    "Hey there! Can you donate?", "Hi :) Donation please?", "How's it going? Any loose robux?", "Nice to meet you! GIMME MONEY!!!",
    "Yo! Robux please?", "What's up? Any robux for me?", "Love your vibe and your robux. Can I have some?", "GG! DONATE!", "You're awesome! Any money for me?"
}

local WAIT_FOR_ANSWER_TIME = 7        -- seconds to wait for reply
local YES_LIST = {"yes", "yeah", "yep", "sure", "ok", "okay", "y", "follow", "come", "lets go", "go"}
local NO_LIST = {"no", "nope", "nah", "don't", "dont", "n", "stop", "leave", "no thanks"}

local MSG_FOLLOW_ME = "Follow me!"
local MSG_HERE_IS_HOUSE = "Here is my booth!"
local MSG_OK_FINE = "Ok fine :("

local JUMP_TIME         = 5
local CIRCLE_COOLDOWN   = 4
local NORMAL_COOLDOWN   = 5
local CIRCLE_STEP_TIME  = 0.1
local TARGET_DISTANCE   = 12
local STUCK_THRESHOLD   = 3
local STUCK_CHECK_TIME  = 4
local MAX_JUMP_TRIES    = 3
local JUMP_DURATION     = 0.8
local MAX_RANDOM_TRIES  = 5
local SPRINT_KEY        = Enum.KeyCode.LeftShift

-- ==================== SERVICES & HTTP SETUP ====================
local Players               = game:GetService("Players")
local PathfindingService    = game:GetService("PathfindingService")
local TextChatService       = game:GetService("TextChatService")
local ReplicatedStorage     = game:GetService("ReplicatedStorage")
local VirtualInputManager   = game:GetService("VirtualInputManager")
local TeleportService       = game:GetService("TeleportService")
local HttpService           = game:GetService("HttpService")
local player                = Players.LocalPlayer
local ignoreList = {}

local httprequest = (syn and syn.request) or http and http.request or http_request or (fluxus and fluxus.request) or request
local queueFunc = queueonteleport or queue_on_teleport or (syn and syn.queue_on_teleport) or function() warn("[HOP] Queue not supported!") end

-- Wait for character to fully load
if not player.Character then
    print("Waiting for character to load...")
    player.CharacterAdded:Wait()
end
player.Character:WaitForChild("HumanoidRootPart")
print("Character loaded!")

-- ==================== BOOTH CLAIMER ====================
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
    local boothUI = boothLocation.BoothUI or boothLocation:FindFirstChild("BoothUI")
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
    print("=== BOOTH CLAIMER ===")
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

-- CLAIM BOOTH AND SET HOME POSITION
local HOME_POSITION = claimBooth()
if not HOME_POSITION then
    warn("[BOOTH] Failed to claim booth! Using default position.")
    HOME_POSITION = Vector3.new(94, 4, 281)  -- Fallback position
end
print("=== HOME SET TO: " .. tostring(HOME_POSITION) .. " ===")

-- ==================== SOCIAL BOT LOGIC ====================
-- ========= CHAT LOGGER + RESPONSE DETECTION =========
local lastSpeaker = nil
local lastMessage = nil
local responseReceived = false

local function resetResponse()
    lastSpeaker = nil
    lastMessage = nil
    responseReceived = false
end

-- Hook Legacy Chat
spawn(function()
    local legacy = ReplicatedStorage:WaitForChild("DefaultChatSystemChatEvents", 5)
    if legacy then
        local ev = legacy:FindFirstChild("OnMessageDoneFiltering")
        if ev then
            ev.OnClientEvent:Connect(function(data)
                local speaker = data.FromSpeaker
                local msg = (data.Message or data.OriginalMessage or ""):lower()
                print(speaker .. ": " .. msg)
                if speaker and speaker ~= player.Name then
                    lastSpeaker = speaker
                    lastMessage = msg
                    responseReceived = true
                end
            end)
        end
    end
end)

-- Hook TextChatService
spawn(function()
    if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
        local channels = TextChatService:WaitForChild("TextChannels", 10)
        if channels then
            local function hook(ch)
                if ch:IsA("TextChannel") then
                    ch.MessageReceived:Connect(function(msgObj)
                        local source = msgObj.TextSource
                        if source then
                            local speaker = source.Name
                            local text = (msgObj.Text or ""):lower()
                            print(speaker .. ": " .. text)
                            if speaker ~= player.Name then
                                lastSpeaker = speaker
                                lastMessage = text
                                responseReceived = true
                            end
                        end
                    end)
                end
            end
            for _, ch in pairs(channels:GetChildren()) do hook(ch) end
            channels.ChildAdded:Connect(hook)
        end
    end
end)

-- Your own chat (just in case)
player.Chatted:Connect(function(msg)
    print(player.Name .. ": " .. msg)
end)

-- ========= MOVEMENT & DANCE (unchanged, proven) =========
local DIRECTION_KEYS = {
    {Enum.KeyCode.W}, {Enum.KeyCode.W, Enum.KeyCode.D}, {Enum.KeyCode.D},
    {Enum.KeyCode.D, Enum.KeyCode.S}, {Enum.KeyCode.S}, {Enum.KeyCode.S, Enum.KeyCode.A},
    {Enum.KeyCode.A}, {Enum.KeyCode.A, Enum.KeyCode.W},
}

local function startCircleDance(duration)
    print("[CIRCLE] Starting circle dance...")
    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
    local startTime = tick()
    local step = 1
    task.spawn(function()
        while tick() - startTime < duration do
            for _, k in DIRECTION_KEYS[step] do VirtualInputManager:SendKeyEvent(true, k, false, game) end
            task.wait(CIRCLE_STEP_TIME)
            for _, k in DIRECTION_KEYS[step] do VirtualInputManager:SendKeyEvent(false, k, false, game) end
            step = step % 8 + 1
        end
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
        print("[CIRCLE] Done")
    end)
end

local isSprinting = false
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

local function performMove(humanoid, root, getPos, sprint)
    if sprint then startSprinting() end
    local lastPos = root.Position
    local stuckTime = 0
    local jumpTries = 0
    local randTries = 0

    while true do
        task.wait(0.1)
        local pos = getPos()
        if (root.Position - pos).Magnitude <= TARGET_DISTANCE then
            if sprint then stopSprinting() end
            return true
        end

        humanoid:MoveTo(pos)
        local moved = (root.Position - lastPos).Magnitude
        if moved < STUCK_THRESHOLD then stuckTime += 0.1 else stuckTime = 0; lastPos = root.Position end

        if stuckTime >= STUCK_CHECK_TIME then
            if jumpTries < MAX_JUMP_TRIES then
                jumpTries += 1
                print("[ANTI-STUCK] Jump unstick #"..jumpTries)
                VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
                task.wait(JUMP_DURATION)
                VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
                task.wait(0.5)
            else
                randTries += 1
                print("[ANTI-STUCK] Random dodge #"..randTries)
                local a = math.random() * math.pi * 2
                local dodge = pos + Vector3.new(math.cos(a)*80, 0, math.sin(a)*80)
                humanoid:MoveTo(dodge)
                task.wait(3)
                if randTries >= MAX_RANDOM_TRIES then
                    if sprint then stopSprinting() end
                    return false
                end
            end
            stuckTime = 0
            lastPos = root.Position
        end
    end
end

local function chasePlayer(t)
    if not t.Character or not t.Character:FindFirstChild("HumanoidRootPart") then return false end
    if not player.Character then player.CharacterAdded:Wait(); task.wait(2) end
    local h = player.Character:FindFirstChild("Humanoid")
    local r = player.Character:FindFirstChild("HumanoidRootPart")
    if not h or not r then return false end
    print("[CHASE] Going to " .. t.Name)
    return performMove(h, r, function() return t.Character.HumanoidRootPart.Position end, true)
end

local function returnHome()
    if not player.Character then player.CharacterAdded:Wait(); task.wait(2) end
    local h = player.Character:FindFirstChild("Humanoid")
    local r = player.Character:FindFirstChild("HumanoidRootPart")
    if not h or not r then return false end
    print("[HOME] Returning home...")
    return performMove(h, r, function() return HOME_POSITION end, false)
end

local function faceTargetBriefly(t)
    if not player.Character then return end
    local hrp = player.Character:FindFirstChild("HumanoidRootPart")
    if not hrp or not t.Character then return end
    local p = t.Character.HumanoidRootPart.Position
    local look = Vector3.new(p.X, hrp.Position.Y, p.Z)
    hrp.CFrame = CFrame.new(hrp.Position, look)
    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.W, false, game)
    task.wait(0.1)
    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.W, false, game)
end

local function sendChat(msg)
    if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
        local ch = TextChatService.TextChannels.RBXGeneral
        if ch then pcall(function() ch:SendAsync(msg) end) end
    end
    local say = ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents")
                and ReplicatedStorage.DefaultChatSystemChatEvents:FindFirstChild("SayMessageRequest")
    if say then pcall(function() say:FireServer(msg, "All") end) end
end

local function findClosest()
    if not player.Character then return nil end
    local root = player.Character:FindFirstChild("HumanoidRootPart")
    if not root then return nil end
    local best, bestT = nil, math.huge
    local allPlayers = Players:GetPlayers()
    if not allPlayers then
        warn("[DEBUG] Players:GetPlayers() returned nil!")
        return nil
    end
    for _, p in ipairs(allPlayers) do
        if p and p ~= player and p.UserId and not ignoreList[p.UserId] and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
            local path = PathfindingService:CreatePath()
            path:ComputeAsync(root.Position, p.Character.HumanoidRootPart.Position)
            if path.Status == Enum.PathStatus.Success then
                local dist = 0
                local wp = path:GetWaypoints()
                for i = 2, #wp do dist += (wp[i].Position - wp[i-1].Position).Magnitude end
                local t = dist / 16
                if t < bestT then bestT, best = t, p end
            end
        elseif not p then
            warn("[DEBUG] Nil player object in Players:GetPlayers()!")
        elseif not p.UserId then
            warn("[DEBUG] Player without UserId: ", p)
        end
    end
    return best
end

-- ========= MAIN LOGIC WITH CHAT RESPONSE =========
local function nextPlayer()
    local target = findClosest()
    if not target then
        print("[MAIN] Everyone greeted — going home")
        returnHome()
        return false
    end

    print("[MAIN] Target → " .. target.Name)

    if chasePlayer(target) then
        sendChat(target.Name .. " " .. MESSAGES[math.random(#MESSAGES)])
        startCircleDance(CIRCLE_COOLDOWN)
        task.wait(CIRCLE_COOLDOWN)
        faceTargetBriefly(target)
        task.wait(NORMAL_COOLDOWN)

        -- === WAIT FOR RESPONSE ===
        resetResponse()
        print("[WAIT] Waiting " .. WAIT_FOR_ANSWER_TIME .. "s for " .. target.Name .. "'s reply...")
        local start = tick()
        while tick() - start < WAIT_FOR_ANSWER_TIME do
            if responseReceived and lastSpeaker == target.Name then
                local msg = lastMessage
                print("[RESPONSE] " .. target.Name .. " said: " .. msg)

                local saidYes = false
                for _, word in ipairs(YES_LIST) do
                    if msg:find(word) then saidYes = true; break end
                end
                local saidNo = false
                for _, word in ipairs(NO_LIST) do
                    if msg:find(word) then saidNo = true; break end
                end

                if saidYes then
                    sendChat(MSG_FOLLOW_ME)
                    returnHome()
                    sendChat(MSG_HERE_IS_HOUSE)
                    ignoreList[target.UserId] = true
                    task.wait(2)
                    return true
                elseif saidNo then
                    sendChat(MSG_OK_FINE)
                    ignoreList[target.UserId] = true
                    task.wait(1)
                    return true
                end
            end
            task.wait(0.1)
        end

        -- No reply or unclear
        print("[WAIT] No valid reply from " .. target.Name .. " — moving on")
        ignoreList[target.UserId] = true
    else
        ignoreList[target.UserId] = true
    end

    task.wait(1)
    return true
end

-- ==================== SERVER HOP FUNCTION ====================
local function serverHop()
    print("[HOP] Starting server hop...")
    
    -- First return home before hopping
    returnHome()
    task.wait(1)
    
    local cursor = ""
    local hopped = false
    
    while not hopped do
        local url = string.format(
            "https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100%s",
            PLACE_ID,
            cursor ~= "" and "&cursor=" .. cursor or ""
        )
        
        local success, response = pcall(function()
            return httprequest({Url = url})
        end)
        
        if not success or not response then
            warn("[HOP] HTTP request failed, retrying in 5s...")
            task.wait(5)
            cursor = ""
            continue
        end
        
        local bodySuccess, body = pcall(function() 
            return HttpService:JSONDecode(response.Body) 
        end)
        
        if bodySuccess and body and body.data then
            local servers = {}
            for _, server in pairs(body.data) do
                if server.id ~= game.JobId 
                    and server.playing >= MIN_PLAYERS 
                    and server.playing <= MAX_PLAYERS_ALLOWED then
                    table.insert(servers, server)
                end
            end
            
            -- Sort by most players (more players = more donations potential)
            table.sort(servers, function(a, b) return (a.playing or 0) > (b.playing or 0) end)
            
            if #servers > 0 then
                print("[HOP] Found " .. #servers .. " suitable servers")
                
                for _, selected in ipairs(servers) do
                    local playing = selected.playing or "?"
                    local maxP = selected.maxPlayers or "?"
                    print("[HOP] Trying server " .. selected.id .. " (" .. playing .. "/" .. maxP .. ")")
                    
                    -- Queue the script for next server
                    queueFunc('loadstring(game:HttpGet("' .. SCRIPT_URL .. '"))()')
                    
                    local tpOk, err = pcall(function()
                        TeleportService:TeleportToPlaceInstance(PLACE_ID, selected.id, player)
                    end)
                    
                    if tpOk then
                        print("[HOP] Teleport initiated! See you on the other side...")
                        hopped = true
                        task.wait(15)  -- Wait for teleport to process
                        break
                    else
                        warn("[HOP] Teleport failed: " .. tostring(err) .. " - trying next...")
                        task.wait(1)
                    end
                end
            else
                print("[HOP] No suitable servers on this page")
            end
            
            if body.nextPageCursor and not hopped then
                cursor = body.nextPageCursor
                print("[HOP] Checking next page...")
            else
                if not hopped then
                    warn("[HOP] No suitable servers found. Retrying in 10s...")
                    task.wait(10)
                    cursor = ""
                end
            end
        else
            warn("[HOP] Failed to parse response, retrying in 5s...")
            task.wait(5)
            cursor = ""
        end
    end
end

-- ========= START =========
print("=== SOCIAL GREETER BOT – ULTIMATE EDITION ===")
print("=== AUTO BOOTH CLAIM + SERVER HOP ===")
if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then
    player.CharacterAdded:Wait()
    task.wait(2)
end

-- Main loop: greet everyone, then hop
while nextPlayer() do end

print("[MAIN] Everyone greeted on this server!")
print("[MAIN] Initiating server hop...")
serverHop()

print("=== BOT FINISHED ===")