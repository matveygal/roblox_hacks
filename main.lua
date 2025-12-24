local Players = cloneref(game:GetService("Players"))
local TPService = cloneref(game:GetService("TeleportService"))
local HttpService = cloneref(game:GetService("HttpService"))
local VirtualInputManager = game:GetService("VirtualInputManager")
local httprequest = (syn and syn.request) or http and http.request or http_request or (fluxus and fluxus.request) or request

local PlaceId = 8737602449
local TargetCords = Vector3.new(267, 3, 303)
local MaxHops = 5
local MinPlayers = 13
local MaxPlayersAllowed = 24

local queueFunc = queueonteleport or queue_on_teleport or (syn and syn.queue_on_teleport) or function() warn("Queue not supported!") end

-- === SPRINT & ANTI-STUCK SYSTEM ===
local SPRINT_KEY = Enum.KeyCode.LeftShift
local STUCK_THRESHOLD = 3
local STUCK_CHECK_TIME = 4
local MAX_JUMP_TRIES = 3
local JUMP_DURATION = 0.8
local MAX_RANDOM_TRIES = 5
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
        if (root.Position - pos).Magnitude <= 12 then
            if sprint then stopSprinting() end
            return true
        end

        humanoid:MoveTo(pos)
        local moved = (root.Position - lastPos).Magnitude
        if moved < STUCK_THRESHOLD then 
            stuckTime += 0.1 
        else 
            stuckTime = 0
            lastPos = root.Position 
        end

        if stuckTime >= STUCK_CHECK_TIME then
            if jumpTries < MAX_JUMP_TRIES then
                jumpTries += 1
                print("[ANTI-STUCK] Jump #"..jumpTries)
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

local function moveToTarget()
    local character = Players.LocalPlayer.Character or Players.LocalPlayer.CharacterAdded:Wait()
    local humanoid = character:WaitForChild("Humanoid")
    local root = character:WaitForChild("HumanoidRootPart")

    print("[MOVE] Running to target with sprint + anti-stuck...")
    local success = performMove(humanoid, root, function() return TargetCords end, true)
    
    if success then
        print("[MOVE] Reached coordinates!")
    else
        warn("[MOVE] Failed to reach after anti-stuck attempts.")
    end
end

-- === MAIN HOP FUNCTION ===
local function doHop()
    local teleportData = TPService:GetLocalPlayerTeleportData()
    local currentHop = (teleportData and teleportData.hopCount) or 0

    if currentHop >= MaxHops then
        print("DONE! Completed " .. MaxHops .. " hops.")
        return
    end

    print("Hop " .. (currentHop + 1) .. "/" .. MaxHops .. ": Moving to coordinates...")

    moveToTarget()

    print("Fetching servers...")

    local cursor = ""
    local hopped = false

    while not hopped do
        local url = string.format(
            "https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100%s",
            PlaceId,
            cursor ~= "" and "&cursor=" .. cursor or ""
        )
        
        local req = httprequest({Url = url})
        local success, body = pcall(function() return HttpService:JSONDecode(req.Body) end)
        
        if success and body and body.data then
            local servers = {}
            for _, server in pairs(body.data) do
                if server.id ~= game.JobId and server.playing >= MinPlayers and server.playing <= MaxPlayersAllowed then
                    -- REMOVED: and server.playing < server.maxPlayers
                    -- Some servers may not return maxPlayers reliably, causing nil errors
                    table.insert(servers, server)
                end
            end
            
            if #servers > 0 then
                table.sort(servers, function(a,b) return (a.playing or 0) > (b.playing or 0) end)  -- Safe sort
                
                for _, selected in ipairs(servers) do
                    local playing = selected.playing or "?"
                    local maxP = selected.maxPlayers or "?"
                    print("Trying server " .. selected.id .. " (" .. playing .. "/" .. maxP .. ")")
                    
                    -- Queue the script for the next server
                    queueFunc([[loadstring(game:HttpGet("https://raw.githubusercontent.com/matveygal/roblox_hacks/main/main.lua"))()]])
                    
                    local tpOk, err = pcall(function()
                        TPService:TeleportToPlaceInstance(PlaceId, selected.id, Players.LocalPlayer, {hopCount = currentHop + 1})
                    end)
                    
                    if tpOk then
                        print("Teleport initiated successfully!")
                        hopped = true
                        task.wait(10)  -- Give time for teleport to start
                        break
                    else
                        warn("Teleport failed (" .. tostring(err) .. ") - trying next server...")
                        task.wait(1)
                    end
                end
            end
            
            if body.nextPageCursor and not hopped then
                cursor = body.nextPageCursor
                print("No success yet - moving to next page...")
            else
                if not hopped then
                    warn("No suitable servers worked after all pages. Retrying full search in 10s...")
                    task.wait(10)
                    cursor = ""
                end
            end
        else
            warn("API request failed, retrying in 5s...")
            task.wait(5)
            cursor = ""
        end
    end
end

-- === START ===
doHop()