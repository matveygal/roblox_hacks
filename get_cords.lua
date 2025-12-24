-- ONE-TIME POSITION LOGGER (Roblox)
-- Run this to instantly print your exact coordinates!

local Players = game:GetService("Players")
local player = Players.LocalPlayer

if not player.Character then
    player.CharacterAdded:Wait()
    task.wait(1)
end

if player.Character:FindFirstChild("HumanoidRootPart") then
    local pos = player.Character.HumanoidRootPart.Position
    print("=== YOUR EXACT POSITION ===")
    print("Vector3.new(" .. math.floor(pos.X) .. ", " .. math.floor(pos.Y) .. ", " .. math.floor(pos.Z) .. ")")
    print("Full: " .. tostring(pos))
    print("==========================")
else
    print("ERROR: No HumanoidRootPart found!")
end
