-- Quick one-time server hop script
-- Use this to spread accounts across different servers before running main bot

local PLACE_ID = 8737602449
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local player = Players.LocalPlayer

local httprequest = (syn and syn.request) or http and http.request or http_request or (fluxus and fluxus.request) or request

print("═══════════════════════════════════════")
print("🔄 QUICK SERVER HOP")
print("═══════════════════════════════════════")

-- Random delay to stagger accounts (0-20 seconds)
local delay = math.random(0, 20)
print("⏳ Waiting " .. delay .. "s to stagger requests...")
task.wait(delay)

print("🌐 Fetching servers...")

local success, response = pcall(function()
    return httprequest({
        Url = string.format("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100", PLACE_ID)
    })
end)

if not success or not response or not response.Body then
    print("❌ Failed to fetch servers!")
    return
end

local body = HttpService:JSONDecode(response.Body)
if not body or not body.data then
    print("❌ Invalid server data!")
    return
end

-- Get all servers except current one
local servers = {}
for _, server in pairs(body.data) do
    if server.id ~= game.JobId and server.playing and server.playing > 0 then
        table.insert(servers, server)
    end
end

if #servers == 0 then
    print("❌ No other servers found!")
    return
end

-- Pick a random server
local selected = servers[math.random(#servers)]
print("✅ Found " .. #servers .. " servers")
print("🎯 Hopping to: " .. selected.id)
print("👥 Players: " .. (selected.playing or "?") .. "/" .. (selected.maxPlayers or "?"))

task.wait(2)

local teleportOptions = Instance.new("TeleportOptions")
teleportOptions.ShouldReserveServer = false

local tpOk, err = pcall(function()
    TeleportService:TeleportToPlaceInstance(PLACE_ID, selected.id, player, teleportOptions)
end)

if tpOk then
    print("✅ Hopping now...")
    task.wait(60)
    print("⚠️ Still here after 60s - may have failed")
else
    print("❌ Teleport failed: " .. tostring(err))
end
