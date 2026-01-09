-- ==================== DEBUG: SERVER HOP API ====================
local PLACE_ID = 8737602449

-- ==================== SERVICES ====================
local HttpService = game:GetService("HttpService")

local httprequest = (syn and syn.request) or http and http.request or http_request or (fluxus and fluxus.request) or request

-- ==================== TEST ====================
print("=== SERVER HOP API DEBUG ===")
print("Place ID: " .. PLACE_ID)
print("")

local cursor = ""
local url = string.format(
    "https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100%s",
    PLACE_ID,
    cursor ~= "" and "&cursor=" .. cursor or ""
)

print("URL: " .. url)
print("")
print("Making HTTP request...")

local success, response = pcall(function()
    return httprequest({Url = url})
end)

if not success then
    warn("HTTP REQUEST FAILED!")
    warn("Error: " .. tostring(response))
    return
end

if not response then
    warn("Response is nil!")
    return
end

print("HTTP request successful!")
print("")
print("=== RESPONSE OBJECT ===")
print("Status Code: " .. tostring(response.StatusCode))
print("Status Message: " .. tostring(response.StatusMessage))
print("")
print("=== RAW BODY ===")
print(response.Body)
print("")
print("=== BODY TYPE ===")
print(type(response.Body))
print("")
print("=== BODY LENGTH ===")
print(#tostring(response.Body))
print("")

print("=== ATTEMPTING TO PARSE ===")
local bodySuccess, body = pcall(function() 
    return HttpService:JSONDecode(response.Body) 
end)

if not bodySuccess then
    warn("PARSE FAILED!")
    warn("Error: " .. tostring(body))
    print("")
    print("=== FIRST 500 CHARS OF BODY ===")
    print(string.sub(tostring(response.Body), 1, 500))
else
    print("PARSE SUCCESSFUL!")
    print("")
    print("=== PARSED DATA ===")
    print("Has 'data' field: " .. tostring(body.data ~= nil))
    if body.data then
        print("Number of servers: " .. #body.data)
        if #body.data > 0 then
            print("")
            print("=== FIRST SERVER ===")
            local first = body.data[1]
            for k, v in pairs(first) do
                print(k .. ": " .. tostring(v))
            end
        end
    end
    print("Has 'nextPageCursor' field: " .. tostring(body.nextPageCursor ~= nil))
    if body.nextPageCursor then
        print("Next cursor: " .. tostring(body.nextPageCursor))
    end
end

print("")
print("=== DEBUG COMPLETE ===")
