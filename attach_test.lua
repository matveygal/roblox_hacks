-- Simple attach test script
print("════════════════════════════════════════════════════════")
print("✅ EXECUTOR ATTACHED SUCCESSFULLY!")
print("✅ Script is running!")
print("════════════════════════════════════════════════════════")

local Players = game:GetService("Players")
local player = Players.LocalPlayer

-- Wait for character
if not player.Character then
    print("⏳ Waiting for character...")
    player.CharacterAdded:Wait()
end

local character = player.Character
local humanoid = character:FindFirstChild("Humanoid")

if humanoid then
    print("✅ Character found: " .. player.Name)
    print("🔄 Making character jump in 3 seconds...")
    task.wait(3)
    
    -- Make character jump 5 times
    for i = 1, 5 do
        print("🦘 Jump #" .. i)
        humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
        task.wait(1)
    end
    
    print("════════════════════════════════════════════════════════")
    print("✅ TEST COMPLETE! Executor is working properly!")
    print("════════════════════════════════════════════════════════")
else
    print("❌ ERROR: Could not find Humanoid")
end
