-- FART-NIGHT v2 | over-the-shoulder camera and aim alignment
-- Installs independently from FN_Client. Does not override the standard Roblox camera.
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local UserInputService=game:GetService("UserInputService")
local player=Players.LocalPlayer
-- Keep the shoulder camera outside the avatar: Roblox hides the local head and
-- attached wearables when the default camera enters first person.
player.CameraMinZoomDistance=5
player.CameraMaxZoomDistance=math.max(player.CameraMaxZoomDistance,18)
local character, humanoid, root
local defaultOffset=Vector3.zero
local fieldOfView=73
local lastShotAt=0
local recoil=0
local function bindCharacter(char)
    character=char
    humanoid=char:WaitForChild("Humanoid",8)
    root=char:WaitForChild("HumanoidRootPart",8)
    if humanoid then
        defaultOffset=Vector3.zero
    end
end
if player.Character then task.spawn(bindCharacter,player.Character) end
player.CharacterAdded:Connect(bindCharacter)
local function hasGun()
    if not character then return false end
    for _,obj in ipairs(character:GetChildren()) do
        if obj:IsA("Tool") and type(obj:GetAttribute("FNWeapon"))=="string" then
            return true
        end
    end
    return false
end
RunService:BindToRenderStep("FN_v2_ShoulderAim",Enum.RenderPriority.Camera.Value+2,function(dt)
    local hum=humanoid
    local hrp=root
    if not hum or not hrp or hum.Health<=0 or not character or character~=player.Character then return end
    local camera=workspace.CurrentCamera
    if not camera then return end
    -- Roblox's camera transparency controller runs before this callback. Its
    -- cached fade can hide the local head/accessories despite third-person zoom.
    -- Our shoulder view keeps these visible without changing server transparency.
    local head=character:FindFirstChild("Head")
    if head and head:IsA("BasePart") then head.LocalTransparencyModifier=0 end
    local crown=character:FindFirstChild("FN_WornCrown")
    if crown then
        for _,part in ipairs(crown:GetDescendants()) do
            if part:IsA("BasePart") then part.LocalTransparencyModifier=0 end
        end
    end
    local equipped=hasGun() and not player:GetAttribute("FN_MenuOpen")
    local rightAim=equipped and (UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) or player:GetAttribute("FN_GamepadAim")==true)
    local target=equipped and (rightAim and Vector3.new(2.25,.75,0) or Vector3.new(1.75,.4,0)) or defaultOffset
    hum.CameraOffset=hum.CameraOffset:Lerp(target,math.clamp(dt*13,0,1))
    fieldOfView+=( (rightAim and 53 or 73) - fieldOfView)*math.clamp(dt*11,0,1)
    camera.FieldOfView=fieldOfView
    local shotAt=player:GetAttribute("FN_ShotAt") or 0
    if shotAt>lastShotAt then lastShotAt=shotAt;recoil=math.min(recoil+.35,.7) end
    recoil*=math.exp(-dt*18)
    if equipped and not player:GetAttribute("FN_ReducedMotion") then camera.CFrame*=CFrame.Angles(math.rad(recoil),0,0) end
    if rightAim and not UserInputService.TouchEnabled then
        local look=camera.CFrame.LookVector
        local flat=Vector3.new(look.X,0,look.Z)
        if flat.Magnitude>.01 then
            hum.AutoRotate=false
            local wanted=CFrame.lookAt(hrp.Position,hrp.Position+flat.Unit)
            hrp.CFrame=hrp.CFrame:Lerp(wanted,math.clamp(dt*14,0,1))
        end
    elseif not hum.AutoRotate then
        hum.AutoRotate=true
    end
end)
