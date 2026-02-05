-- ==================== SERVER HOP TEST SCRIPT ====================
-- This script tests server hopping and logs everything to verify it works

local PLACE_ID = 8737602449
local MIN_PLAYERS = 4
local MAX_PLAYERS_ALLOWED = 24

local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local player = Players.LocalPlayer

local httprequest = (syn and syn.request) or http and http.request or http_request or (fluxus and fluxus.request) or request
local queueFunc = queueonteleport or queue_on_teleport or (syn and syn.queue_on_teleport) or function() print("[TEST] Queue not supported!") end

-- Check if this is a fresh start or after a hop
if _G.ServerHopTestRan then
    print("════════════════════════════════════════════════════════")
    print("✅ SERVER HOP TEST SUCCESSFUL!")
    print("✅ Script reloaded in new server!")
    print("✅ Current Server ID: " .. game.JobId)
    print("✅ Players in server: " .. #Players:GetPlayers())
    print("════════════════════════════════════════════════════════")
    return
else
    _G.ServerHopTestRan = true
    print("════════════════════════════════════════════════════════")
    print("🔄 STARTING SERVER HOP TEST")
    print("🔄 Current Server ID: " .. game.JobId)
    print("🔄 Players in server: " .. #Players:GetPlayers())
    print("════════════════════════════════════════════════════════")
end

-- Wait for character
if not player.Character then
    player.CharacterAdded:Wait()
    task.wait(2)
end

print("[TEST] Fetching server list...")

local url = string.format(
    "https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100",
    PLACE_ID
)

local success, response = pcall(function()
    return httprequest({Url = url})
end)

if not success or not response then
    print("[TEST] ❌ HTTP request failed: " .. tostring(response))
    return
end

if not response.Body then
    print("[TEST] ❌ Response has no Body field!")
    return
end

local bodySuccess, body = pcall(function() 
    return HttpService:JSONDecode(response.Body) 
end)

if not bodySuccess or not body or not body.data then
    print("[TEST] ❌ Failed to parse response")
    return
end

print("[TEST] Parsing server list...")

local servers = {}
for _, server in pairs(body.data) do
    if server.id ~= game.JobId 
        and server.playing >= MIN_PLAYERS 
        and server.playing <= MAX_PLAYERS_ALLOWED then
        table.insert(servers, server)
    end
end

if #servers == 0 then
    print("[TEST] ❌ No suitable servers found!")
    return
end

-- Sort by most players
table.sort(servers, function(a, b) return (a.playing or 0) > (b.playing or 0) end)

local selected = servers[1]
print("[TEST] Found " .. #servers .. " suitable servers")
print("[TEST] Selected server: " .. selected.id)
print("[TEST] Players: " .. (selected.playing or "?") .. "/" .. (selected.maxPlayers or "?"))

-- Queue this script to run in next server
print("[TEST] Queuing script for next server...")
queueFunc([[
    _G.ServerHopTestRan = true
    task.wait(3)
    loadstring(game:HttpGet("https://cdn.jsdelivr.net/gh/matveygal/roblox_hacks@main/serverhop_test.lua"))()
]])

print("[TEST] Attempting teleport...")
task.wait(2)

local teleportOptions = Instance.new("TeleportOptions")
teleportOptions.ShouldReserveServer = false

local tpOk, err = pcall(function()
    TeleportService:TeleportToPlaceInstance(PLACE_ID, selected.id, player, teleportOptions)
end)

if tpOk then
    print("[TEST] ✅ Teleport initiated successfully!")
    print("[TEST] Waiting for teleport to complete...")
    -- Keep script alive and log while waiting
    for i = 1, 60 do
        task.wait(1)
        print("[TEST] Waiting... " .. i .. "s")
    end
    print("[TEST] ⚠️ Still in original server after 60s - teleport may have failed")
else
    print("[TEST] ❌ Teleport failed: " .. tostring(err))
end
