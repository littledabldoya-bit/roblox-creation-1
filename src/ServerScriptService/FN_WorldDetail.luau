-- FART-NIGHT v2 : competitive sci-fi arena presentation
local TweenService=game:GetService("TweenService")
local Lighting=game:GetService("Lighting")
local arena=workspace:WaitForChild("FartNightArena")
Lighting.ClockTime=18.2
Lighting.Brightness=1.6
Lighting.ExposureCompensation=-.05
Lighting.Ambient=Color3.fromRGB(86,105,148)
Lighting.OutdoorAmbient=Color3.fromRGB(96,118,158)
Lighting.FogColor=Color3.fromRGB(50,68,108)
Lighting.FogEnd=750
local atmo=Lighting:FindFirstChild("FN_Atmosphere")
if not atmo then
    atmo=Instance.new("Atmosphere")
    atmo.Name="FN_Atmosphere";atmo.Density=.23;atmo.Offset=.04
    atmo.Color=Color3.fromRGB(162,182,226)
    atmo.Decay=Color3.fromRGB(58,75,119)
    atmo.Glare=0;atmo.Haze=.8;atmo.Parent=Lighting
end
local bloom=Lighting:FindFirstChild("FN_Bloom")
if not bloom then
    bloom=Instance.new("BloomEffect")
    bloom.Name="FN_Bloom";bloom.Intensity=.09;bloom.Size=12;bloom.Threshold=1.8;bloom.Parent=Lighting
end
local color=Lighting:FindFirstChild("FN_Color")
if not color then
    color=Instance.new("ColorCorrectionEffect")
    color.Name="FN_Color";color.Contrast=.04;color.Saturation=.03
    color.TintColor=Color3.fromRGB(224,233,255);color.Parent=Lighting
end
-- Apply settings even if an earlier effect already exists in the place.
bloom.Intensity=.09;bloom.Size=12;bloom.Threshold=1.8
atmo.Glare=0;atmo.Haze=.8
color.Contrast=.04;color.Saturation=.03
local signs={
    FN_Sign_HYPERMART={"HYPER MART","SPECIALIST ARMORY"},
    FN_Sign_GASWORKS={"GASWORKS","PRESSURE DISTRICT"},
    FN_Sign_SKYDOCK={"SKY DOCK","CONTAINERS + ROOFTOPS"},
    FN_Sign_NEONMILE={"NEON MILE","HIGH GROUND = HIGH RISK"},
    FN_Sign_CENTER={"FART / NIGHT","NEON CITY · ARENA ONLINE"}
}
for _,p in ipairs(arena:GetDescendants()) do
    if p:IsA("BasePart") then
        -- Broad surfaces and pickups reflect light instead of emitting glare.
        local accent=p.Name=="FN_SpawnGlow" or p.Name=="FN_PavementLight" or p.Name=="FN_CoverGlow"
        if p.Material==Enum.Material.Neon and not accent then p.Material=Enum.Material.SmoothPlastic end
        if accent then p.Color=Color3.fromRGB(48,145,175) end
        local pickup=p.Name=="FN_Health" and "+ HEALTH" or p.Name=="FN_Shield" and "+ SHIELD"
        if pickup and not p:FindFirstChild("FN_PickupLabel") then
            local badge=Instance.new("BillboardGui")
            badge.Name="FN_PickupLabel";badge.Size=UDim2.fromOffset(110,22)
            badge.StudsOffsetWorldSpace=Vector3.new(0,2.6,0);badge.MaxDistance=55;badge.AlwaysOnTop=false;badge.Parent=p
            local function availability() badge.Enabled=p.Transparency<1 end
            p:GetPropertyChangedSignal("Transparency"):Connect(availability);availability()
            local text=Instance.new("TextLabel")
            text.Size=UDim2.fromScale(1,1);text.BackgroundTransparency=1;text.Text=pickup
            text.TextColor3=p.Name=="FN_Health" and Color3.fromRGB(117,255,188) or Color3.fromRGB(108,209,255)
            text.Font=Enum.Font.GothamBold;text.TextSize=12;text.TextStrokeTransparency=.35;text.Parent=badge
        end
        local cfg=signs[p.Name]
        if cfg then
            local old=p:FindFirstChild("FN_SignDisplay");if old then old:Destroy() end
            local g=Instance.new("SurfaceGui")
            g.Name="FN_SignDisplay";g.Face=Enum.NormalId.Front;g.PixelsPerStud=18;g.LightInfluence=0
            g.AlwaysOnTop=false;g.Parent=p
            local back=Instance.new("Frame")
            back.Size=UDim2.fromScale(1,1);back.BackgroundColor3=Color3.fromRGB(14,21,43);back.BorderSizePixel=0;back.Parent=g
            local title=Instance.new("TextLabel")
            title.Size=UDim2.fromScale(1,.7);title.BackgroundTransparency=1;title.Text=cfg[1]
            title.TextScaled=true;title.TextColor3=Color3.fromRGB(95,226,255)
            title.TextStrokeTransparency=.4;title.Font=Enum.Font.GothamBlack;title.Parent=back
            local subtitle=Instance.new("TextLabel")
            subtitle.Position=UDim2.fromScale(0,.69);subtitle.Size=UDim2.fromScale(1,.24)
            subtitle.BackgroundTransparency=1;subtitle.Text=cfg[2];subtitle.TextScaled=true
            subtitle.TextColor3=Color3.fromRGB(184,205,230);subtitle.Font=Enum.Font.GothamBold;subtitle.Parent=back
        elseif p.Name=="FN_Vent" then
            local a=Instance.new("Attachment");a.Position=Vector3.new(0,p.Size.Y/2,0);a.Parent=p
            local smoke=Instance.new("ParticleEmitter");smoke.Name="ToxicVapor";smoke.Rate=4
            smoke.Speed=NumberRange.new(2,5);smoke.Lifetime=NumberRange.new(2,3.8)
            smoke.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,.5),NumberSequenceKeypoint.new(1,3)})
            smoke.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.5),NumberSequenceKeypoint.new(1,1)})
            smoke.Color=ColorSequence.new(Color3.fromRGB(109,255,184));smoke.Parent=a
        elseif p.Name=="FN_NeonLight" then
            local light=Instance.new("PointLight");light.Color=p.Color;light.Range=14;light.Brightness=.26;light.Parent=p
        end
    end
end
print("[FART-NIGHT v5] World details and illuminated district signs online")
