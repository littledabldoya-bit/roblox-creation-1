-- Run in Studio's SERVER command bar while playing, after the loadout appears.
-- This test requires the Roblox engine; it has NOT been executed in the cloud.
local Players=game:GetService("Players")
local player=Players:GetPlayers()[1]
assert(player,"Start a playtest first")
local barrels={"PrimaryBarrel","UpperBore","LowerBore","FloatingBarrel","AcceleratorCore","IonBarrel"}
local checked=0
for _,container in ipairs({player:WaitForChild("Backpack"),player.Character}) do
    for _,tool in ipairs(container:GetChildren()) do
        if tool:IsA("Tool") and tool:GetAttribute("FNWeapon") then
            local handle=tool:FindFirstChild("Handle")
            local muzzle=handle and handle:FindFirstChild("FN_Muzzle")
            assert(muzzle,"Weapon lacks muzzle: "..tool.Name)
            for _,name in ipairs(barrels) do
                local barrel=tool:FindFirstChild(name)
                if barrel then
                    assert(barrel.Shape==Enum.PartType.Cylinder,"Expected cylinder: "..name)
                    assert(barrel.Size.X>barrel.Size.Y,"Barrel length must use cylinder local X")
                    assert(barrel.CFrame.RightVector:Dot(handle.CFrame.LookVector)>.999,"Barrel points across gun: "..name)
                    assert((muzzle.WorldPosition-barrel.Position):Dot(handle.CFrame.LookVector)>0,"Muzzle behind barrel center")
                    checked+=1
                end
            end
        end
    end
end
assert(checked>=4,"Expected starter barrels; wait for loadout initialization")
print("PASS: "..checked.." forward barrels and muzzle positions. Test actual firing separately.")
