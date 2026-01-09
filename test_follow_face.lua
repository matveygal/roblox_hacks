-- ==================== TEST SCRIPT: FOLLOW & FACE ====================
local TARGET_NAME = "BuilderNoob_4567"  -- SET THIS TO THE TARGET PLAYER NAME
local TEST_DURATION = 15              -- seconds to follow/face target
local MAX_WAIT_DISTANCE = 20          -- max distance before following player

-- ==================== SERVICES ====================
local Players = game:GetService("Players")
local VirtualInputManager = game:GetService("VirtualInputManager")
local player = Players.LocalPlayer

-- Wait for character
if not player.Character then
    print("Waiting for character...")
    player.CharacterAdded:Wait()
end
player.Character:WaitForChild("HumanoidRootPart")
print("Character loaded!")

-- ==================== FUNCTIONS ====================
local function faceTarget(t)
    if not player.Character or not t.Character or not t.Character:FindFirstChild("HumanoidRootPart") then return end
    local hrp = player.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local p = t.Character.HumanoidRootPart.Position
    local look = Vector3.new(p.X, hrp.Position.Y, p.Z)
    hrp.CFrame = CFrame.new(hrp.Position, look)
end

-- ==================== MAIN TEST ====================
print("=== FOLLOW & FACE TEST ===")
print("Duration: " .. TEST_DURATION .. " seconds")
print("Max Distance: " .. MAX_WAIT_DISTANCE .. " studs")

local target = Players:FindFirstChild(TARGET_NAME)
if not target then
    warn("Target player '" .. TARGET_NAME .. "' not found!")
    return
end

print("Target selected: " .. target.Name)
print("Starting test...")

local start = tick()
while tick() - start < TEST_DURATION do
    -- Check if target still exists
    if not target.Character or not target.Character:FindFirstChild("HumanoidRootPart") then
        warn("Target left! Test ended early.")
        break
    end
    
    -- Get player and target positions
    local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    local targetRoot = target.Character:FindFirstChild("HumanoidRootPart")
    
    if root and targetRoot then
        local distance = (root.Position - targetRoot.Position).Magnitude
        
        -- If target is too far, follow them
        if distance > MAX_WAIT_DISTANCE then
            print("[FOLLOW] Target moving away (distance: " .. math.floor(distance) .. "), following...")
            local humanoid = player.Character:FindFirstChild("Humanoid")
            if humanoid then
                humanoid:MoveTo(targetRoot.Position)
            end
            -- Don't call faceTarget here - let MoveTo control movement
        else
            print("[FACE] Facing target (distance: " .. math.floor(distance) .. ")")
            -- Only face when NOT moving
            faceTarget(target)
        end
    end
    
    task.wait(0.1)
end

print("=== TEST COMPLETE ===")
print("Total time: " .. math.floor(tick() - start) .. " seconds")
