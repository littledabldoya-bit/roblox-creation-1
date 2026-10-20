-- FART-NIGHT / StarterPlayer / StarterPlayerScripts / FN_Client
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local StarterGui = game:GetService("StarterGui")
local player = Players.LocalPlayer
-- A native Roblox backpack hotbar occupies the same screen area as our custom weapon buttons.
-- Disable it only after the custom UI has initialized successfully.
local function hideDefaultBackpack()
    pcall(function()
        StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
    end)
end
player.CameraMinZoomDistance = 7
player.CameraMaxZoomDistance = 18
player.CameraMode = Enum.CameraMode.Classic
local Config = require(ReplicatedStorage:WaitForChild("FN_Config"))
local Remotes = ReplicatedStorage:WaitForChild("FN_Remotes")
local Shoot, Reload, Sync, RequestSync, Shop, Notice, FX =
    Remotes.Shoot, Remotes.Reload, Remotes.Sync, Remotes.RequestSync, Remotes.Shop, Remotes.Notice, Remotes.FX
local Storm, Sprint = Remotes.Storm, Remotes.Sprint
local SelectWeapon = Remotes:WaitForChild("SelectWeapon")
local HitConfirm = Remotes:WaitForChild("HitConfirm")
local Slide = Remotes:WaitForChild("Slide")

local data = {Coins = 0, XP = 0, Level = 1, KOs = 0, Deaths = 0, Unlocks = {Mint=true}, Equipped = "Mint", VIP=false, DoubleCoins=false, PremiumWeapons={}, Crowns={}, EquippedCrown="None", Ready=false, Ammo={}, Reloads={}}
local equipped, firing, lastLocalShot = nil, false, -1000
local lastNoGunToast = -1000
local firstShotSent = false
local touch = UserInputService.TouchEnabled
local gui = Instance.new("ScreenGui")
gui.Name = "FartNightUI"
gui.IgnoreGuiInset = true
gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
gui.ZIndexBehavior = Enum.ZIndexBehavior.Global
gui.ResetOnSpawn = false
gui.DisplayOrder = 4
gui.Parent = player:WaitForChild("PlayerGui")

-- Engine-bundled effects work without uploading separate Roblox audio assets.
local SoundService=game:GetService("SoundService")
local sfxGroup=Instance.new("SoundGroup")
sfxGroup.Name="FN_Effects";sfxGroup.Volume=Config.Audio.Volume;sfxGroup.Parent=SoundService
local voiceCount=0
local function effect(id,parent,volume,speed)
    local sound=Instance.new("Sound")
    sound.Name="FN_Effect";sound.SoundId=id;sound.SoundGroup=sfxGroup
    sound.Volume=volume;sound.PlaybackSpeed=speed or 1
    sound.RollOffMinDistance=8;sound.RollOffMaxDistance=140
    sound.RollOffMode=Enum.RollOffMode.InverseTapered;sound.Parent=parent
    return sound
end
local function shotSound(weapon,position)
    local definition=Config.Audio.Weapons[weapon]
    local camera=workspace.CurrentCamera
    if not definition or typeof(position)~="Vector3" or voiceCount>=24 then return end
    if camera and (camera.CFrame.Position-position).Magnitude>140 then return end
    local anchor=Instance.new("Part")
    anchor.Name="FN_ShotAudio";anchor.Size=Vector3.new(.1,.1,.1);anchor.Position=position
    anchor.Transparency=1;anchor.Anchored=true;anchor.CanCollide=false;anchor.CanTouch=false;anchor.CanQuery=false
    anchor.Parent=workspace
    local sound=effect(definition.SoundId,anchor,definition.Volume,definition.Speed)
    local eq=Instance.new("EqualizerSoundEffect")
    eq.LowGain=weapon=="BurpCannon" and 5 or -2;eq.MidGain=2;eq.HighGain=weapon=="ToxicTagger" and 4 or 0;eq.Parent=sound
    local distortion=Instance.new("DistortionSoundEffect")
    distortion.Level=.12;distortion.Parent=sound
    voiceCount+=1
    anchor.Destroying:Connect(function() voiceCount=math.max(0,voiceCount-1) end)
    sound.Ended:Connect(function() anchor:Destroy() end)
    sound:Play();Debris:AddItem(anchor,2.5)
end
local function uiEffect(id,speed,volume)
    local sound=effect(id,SoundService,volume,speed)
    sound.Ended:Connect(function() sound:Destroy() end)
    sound:Play();Debris:AddItem(sound,2)
end

local footsteps={}
local playerAudioConnections={}
local function stopFootsteps(character)
    local state=footsteps[character]
    if not state then return end
    footsteps[character]=nil
    for _,connection in ipairs(state.Connections) do connection:Disconnect() end
    for original,volume in pairs(state.Originals) do if original.Parent then original.Volume=volume end end
    state.Sound:Destroy()
end
local function characterAudio(character)
    local humanoid=character:WaitForChild("Humanoid",8)
    local root=character:WaitForChild("HumanoidRootPart",8)
    if not humanoid or not root or not character.Parent or footsteps[character] then return end
    local sound=effect(Config.Audio.Footsteps,root,.32,1.6)
    sound.Name="FN_Footsteps";sound.Looped=true;sound.RollOffMaxDistance=65
    local state={Sound=sound,Connections={},Originals={}}
    footsteps[character]=state
    local function muteDefault(object)
        if object:IsA("Sound") and object.Name=="Running" and not state.Originals[object] then
            state.Originals[object]=object.Volume
            object.Volume=0
            table.insert(state.Connections,object:GetPropertyChangedSignal("Volume"):Connect(function()
                if object.Volume~=0 then object.Volume=0 end
            end))
        end
    end
    for _,object in ipairs(character:GetDescendants()) do muteDefault(object) end
    table.insert(state.Connections,character.DescendantAdded:Connect(muteDefault))
    table.insert(state.Connections,character.AncestryChanged:Connect(function()
        if not character.Parent then stopFootsteps(character) end
    end))
    table.insert(state.Connections,RunService.Heartbeat:Connect(function()
        if not root.Parent then stopFootsteps(character);return end
        local velocity=root.AssemblyLinearVelocity
        local speed=Vector3.new(velocity.X,0,velocity.Z).Magnitude
        local camera=workspace.CurrentCamera
        local near=camera and (camera.CFrame.Position-root.Position).Magnitude<70
        local moving=humanoid.Health>0 and not humanoid.Sit and humanoid.FloorMaterial~=Enum.Material.Air and speed>1.5 and near
        if moving then
            sound.PlaybackSpeed=math.clamp(speed/16*1.6,.8,2.5)
            sound.Volume=math.clamp(speed/16*.32,.14,.42)
            if not sound.IsPlaying then sound:Play() end
        elseif sound.IsPlaying then sound:Stop() end
    end))
end
local function watchPlayerAudio(who)
    if playerAudioConnections[who] then return end
    playerAudioConnections[who]={
        who.CharacterAdded:Connect(function(character) task.spawn(characterAudio,character) end),
        who.CharacterRemoving:Connect(stopFootsteps),
    }
    if who.Character then task.spawn(characterAudio,who.Character) end
end
local audioAdded=Players.PlayerAdded:Connect(watchPlayerAudio)
local audioRemoved=Players.PlayerRemoving:Connect(function(who)
    if who.Character then stopFootsteps(who.Character) end
    for _,connection in ipairs(playerAudioConnections[who] or {}) do connection:Disconnect() end
    playerAudioConnections[who]=nil
end)
for _,who in ipairs(Players:GetPlayers()) do watchPlayerAudio(who) end
gui.Destroying:Connect(function()
    audioAdded:Disconnect();audioRemoved:Disconnect()
    for _,connections in pairs(playerAudioConnections) do for _,connection in ipairs(connections) do connection:Disconnect() end end
    local characters={}
    for character in pairs(footsteps) do table.insert(characters,character) end
    for _,character in ipairs(characters) do stopFootsteps(character) end
    sfxGroup:Destroy()
end)

-- Competitive arena visual system: readable information, generous targets, no external assets.
local C = {Panel=Color3.fromRGB(12,20,34), Card=Color3.fromRGB(22,34,52), Cyan=Color3.fromRGB(76,224,255),
    Muted=Color3.fromRGB(151,172,196), Gold=Color3.fromRGB(255,209,104), White=Color3.fromRGB(237,246,255)}
local function el(class, name, parent, properties)
    local o=Instance.new(class); o.Name=name
    for k,v in pairs(properties or {}) do o[k]=v end
    o.Parent=parent; return o
end
local function rounded(o, radius)
    el("UICorner","Corners",o,{CornerRadius=UDim.new(0,radius or 12)})
end
local function border(o,color,thick)
    return el("UIStroke","Outline",o,{Color=color or C.Cyan,Thickness=thick or 1,Transparency=.66})
end
local function lbl(name,parent,text,pos,size,fontSize,color)
    return el("TextLabel",name,parent,{BackgroundTransparency=1,Position=pos,Size=size,Font=Enum.Font.GothamBold,
        Text=text,TextColor3=color or C.White,TextSize=fontSize or 18,TextXAlignment=Enum.TextXAlignment.Left,
        TextYAlignment=Enum.TextYAlignment.Center})
end
local function btn(name,parent,text,pos,size,accent)
    local base=accent or C.Cyan
    local b=el("TextButton",name,parent,{Position=pos,Size=size,BackgroundColor3=base,BorderSizePixel=0,
        Font=Enum.Font.GothamBold,Text=text,TextColor3=C.Panel,TextSize=14,AutoButtonColor=false,Selectable=true})
    rounded(b,8)
    b.MouseEnter:Connect(function() TweenService:Create(b,TweenInfo.new(.12),{BackgroundTransparency=.15}):Play() end)
    b.MouseLeave:Connect(function() TweenService:Create(b,TweenInfo.new(.12),{BackgroundTransparency=0}):Play() end)
    return b
end
local function panel(name,parent,pos,size)
    local f=el("Frame",name,parent,{Position=pos,Size=size,BackgroundColor3=C.Panel,BackgroundTransparency=.06,BorderSizePixel=0})
    rounded(f,12);border(f);return f
end
local statsPanel=panel("Operator",gui,UDim2.fromOffset(18,18),UDim2.fromOffset(264,126))
local statsScale=el("UIScale","Responsive",statsPanel,{Scale=1})
local brand=lbl("Brand",statsPanel,"FART / NIGHT",UDim2.fromOffset(16,10),UDim2.fromOffset(234,28),23,C.White)
brand.Font=Enum.Font.GothamBlack
lbl("Mode",statsPanel,"NEON CITY  /  FREE-FOR-ALL",UDim2.fromOffset(17,39),UDim2.fromOffset(230,18),10,C.Cyan)
local statText=lbl("Values",statsPanel,"0 KOs   /   0 COINS   /   0 DEATHS",UDim2.fromOffset(17,64),UDim2.fromOffset(235,20),12)
local rankText=lbl("Rank",statsPanel,"LEVEL 1   /   0 / 300 XP",UDim2.fromOffset(17,88),UDim2.fromOffset(230,18),11,C.Muted)
local xpTrack=panel("XPTrack",statsPanel,UDim2.fromOffset(17,112),UDim2.fromOffset(230,3))
local xpFill=el("Frame","Fill",xpTrack,{Size=UDim2.fromScale(0,1),BackgroundColor3=C.Cyan,BorderSizePixel=0})
local stormLabel=lbl("Storm",gui,"SAFE ZONE  /  4:00",UDim2.new(.5,-165,0,18),UDim2.fromOffset(330,30),16,C.Cyan)
stormLabel.TextXAlignment=Enum.TextXAlignment.Center
local vitalPanel=panel("Vitals",gui,UDim2.fromOffset(18,205),UDim2.fromOffset(264,77))
local vitalsScale=el("UIScale","Responsive",vitalPanel,{Scale=1})
local shieldText=lbl("Shield",vitalPanel,"100 HP   /   0 SHIELD",UDim2.fromOffset(13,7),UDim2.fromOffset(240,23),13)
local healthTrack=panel("HealthTrack",vitalPanel,UDim2.fromOffset(13,36),UDim2.fromOffset(238,6))
local healthFill=el("Frame","Fill",healthTrack,{Size=UDim2.fromScale(1,1),BackgroundColor3=C.Cyan,BorderSizePixel=0})
local staminaTrack=panel("StaminaTrack",vitalPanel,UDim2.fromOffset(13,51),UDim2.fromOffset(238,4))
local staminaFill=el("Frame","Fill",staminaTrack,{Size=UDim2.fromScale(1,1),BackgroundColor3=C.Gold,BorderSizePixel=0})
lbl("Stamina",vitalPanel,"SPRINT ENERGY",UDim2.fromOffset(13,59),UDim2.fromOffset(238,12),8,C.Muted)
local notice=lbl("Notice",gui,"",UDim2.new(.5,-220,.19,0),UDim2.fromOffset(440,48),18,C.Gold)
notice.TextXAlignment=Enum.TextXAlignment.Center;notice.TextWrapped=true;notice.TextStrokeTransparency=.5
local noticeSerial=0
local function toast(message)
    noticeSerial+=1;local mine=noticeSerial
    notice.Text=tostring(message);notice.TextTransparency=0
    task.delay(3,function()
        if mine==noticeSerial then TweenService:Create(notice,TweenInfo.new(.35),{TextTransparency=1}):Play() end
    end)
end
local cross=el("Frame","Crosshair",gui,{Position=UDim2.fromScale(.5,.5),AnchorPoint=Vector2.new(.5,.5),Size=UDim2.fromOffset(4,4),BackgroundColor3=C.White,BorderSizePixel=0})
rounded(cross,4)
for i,shape in ipairs({{0,-12,2,6},{0,12,2,6},{-12,0,6,2},{12,0,6,2}}) do
    el("Frame","Arm"..i,cross,{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.new(.5,shape[1],.5,shape[2]),Size=UDim2.fromOffset(shape[3],shape[4]),BackgroundColor3=C.White,BorderSizePixel=0})
end
local hitmarker=lbl("HitMarker",gui,"×",UDim2.new(.5,-23,.5,-24),UDim2.fromOffset(46,46),38,C.White)
hitmarker.TextXAlignment=Enum.TextXAlignment.Center;hitmarker.TextTransparency=1
local confirmCounter=0
HitConfirm.OnClientEvent:Connect(function(headshot)
    uiEffect(Config.Audio.Hit,headshot and 2.8 or 2.2,.16)
    confirmCounter+=1;local mine=confirmCounter
    hitmarker.Text=headshot and "✦" or "×";hitmarker.TextColor3=headshot and C.Gold or C.White;hitmarker.TextTransparency=0
    task.delay(.18,function() if mine==confirmCounter then hitmarker.TextTransparency=1 end end)
end)
local ammoPanel=panel("AmmoPanel",gui,UDim2.new(1,-18,1,-18),UDim2.fromOffset(264,92))
ammoPanel.AnchorPoint=Vector2.new(1,1)
local ammoScale=el("UIScale","Responsive",ammoPanel,{Scale=1})
local gunName=lbl("GunName",ammoPanel,"BEAN BLASTER",UDim2.fromOffset(14,8),UDim2.fromOffset(235,22),13,C.Cyan)
local ammoText=lbl("Ammo",ammoPanel,"32 / 32",UDim2.fromOffset(14,34),UDim2.fromOffset(135,40),28)
ammoText.Font=Enum.Font.GothamBlack
local reloadButton=btn("Reload",ammoPanel,"RELOAD [R]",UDim2.fromOffset(148,42),UDim2.fromOffset(104,36),C.Cyan)
local shopButton=btn("ShopOpen",gui,"THE ARMORY  [M]",UDim2.fromOffset(18,154),UDim2.fromOffset(224,40),C.Gold)
local guide=lbl("Guide",gui,"RMB AIM   /   R RELOAD   /   SHIFT SPRINT   /   CTRL SLIDE",UDim2.new(.5,-275,1,-97),UDim2.fromOffset(550,18),10,C.Muted)
guide.TextXAlignment=Enum.TextXAlignment.Center
local gunButtons={}
local hotbar=el("Frame","Hotbar",gui,{AnchorPoint=Vector2.new(.5,1),Position=UDim2.new(.5,0,1,-18),Size=UDim2.fromOffset(500,68),BackgroundTransparency=1})
local hotbarScale=el("UIScale","Responsive",hotbar,{Scale=1})
for i,name in ipairs(Config.WeaponOrder) do
    local w=Config.Weapons[name]
    local b=btn(name,hotbar,i.."  /  "..w.Display,UDim2.fromOffset((i-1)*100,0),UDim2.fromOffset(94,68),C.Card)
    b.TextColor3=C.White;b.TextSize=10;b.TextWrapped=true;border(b,w.Color,1.5);gunButtons[name]=b
end

-- Earned cosmetics and optional Robux offers occupy separate tabs.
local darken=el("Frame","Darken",gui,{Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.fromRGB(3,8,17),BackgroundTransparency=.18,Visible=false,BorderSizePixel=0,ZIndex=10})
local blocker=el("TextButton","InputShield",darken,{Size=UDim2.fromScale(1,1),Text="",BackgroundTransparency=1,AutoButtonColor=false,Modal=true,ZIndex=10})
local shopPanel=panel("ShopPanel",darken,UDim2.fromScale(.5,.5),UDim2.fromOffset(720,580))
shopPanel.AnchorPoint=Vector2.new(.5,.5);shopPanel.ZIndex=11
local shopTitle=lbl("Title",shopPanel,"THE ARMORY",UDim2.fromOffset(20,14),UDim2.new(1,-80,0,32),26,C.White)
shopTitle.Font=Enum.Font.GothamBlack
local shopCoins=lbl("Balance",shopPanel,"0 COINS",UDim2.fromOffset(22,52),UDim2.new(1,-44,0,20),12,C.Gold)
local shopStatus=lbl("Status",shopPanel,"CONNECTING TO YOUR PROFILE…",UDim2.fromOffset(22,77),UDim2.new(1,-44,0,28),11,C.Muted)
shopStatus.TextWrapped=true
local closeButton=btn("Close",shopPanel,"×",UDim2.new(1,-58,0,16),UDim2.fromOffset(40,40),C.Card)
closeButton.TextColor3=C.White;closeButton.TextSize=24
local tabs={};local activeTab="Skins"
local tabStrip=el("ScrollingFrame","Tabs",shopPanel,{Position=UDim2.fromOffset(14,114),Size=UDim2.new(1,-28,0,42),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=3,ScrollingDirection=Enum.ScrollingDirection.X,CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.X})
el("UIListLayout","TabLayout",tabStrip,{FillDirection=Enum.FillDirection.Horizontal,Padding=UDim.new(0,6),SortOrder=Enum.SortOrder.LayoutOrder})
for i,key in ipairs({"Skins","Guns","Crowns","Passes","Coins","Settings"}) do
    local b=btn(key,tabStrip,string.upper(key),UDim2.new(),UDim2.fromOffset(96,38),C.Card)
    b.LayoutOrder=i;b.TextColor3=C.White;b.TextSize=11;tabs[key]=b
end
local shopScroll=el("ScrollingFrame","Offers",shopPanel,{Position=UDim2.fromOffset(16,166),Size=UDim2.new(1,-32,1,-216),BackgroundTransparency=1,ScrollBarThickness=4,ScrollBarImageColor3=C.Cyan,BorderSizePixel=0,CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y})
local layout=el("UIListLayout","Layout",shopScroll,{Padding=UDim.new(0,10),SortOrder=Enum.SortOrder.LayoutOrder})
el("UIPadding","Padding",shopScroll,{PaddingBottom=UDim.new(0,14)})
local footer=lbl("Footer",shopPanel,"PREMIUM GUNS HAVE COMBAT ADVANTAGES.",UDim2.new(0,20,1,-40),UDim2.new(1,-40,0,26),10,C.Muted)
footer.TextWrapped=true;footer.TextXAlignment=Enum.TextXAlignment.Center
local cosmeticButtons,paidOffers,cards={},{},{}
local function offer(name,desc,color,category,order)
    local frame=el("Frame",name,shopScroll,{Size=UDim2.new(1,-9,0,106),BackgroundColor3=C.Card,BorderSizePixel=0,LayoutOrder=order or 1})
    rounded(frame,9)
    local chip=el("Frame","Swatch",frame,{Position=UDim2.fromOffset(12,14),Size=UDim2.fromOffset(5,34),BackgroundColor3=color,BorderSizePixel=0})
    rounded(chip,3)
    lbl("Name",frame,name,UDim2.fromOffset(28,10),UDim2.new(1,-42,0,24),15)
    local description=lbl("Description",frame,desc,UDim2.fromOffset(28,34),UDim2.new(1,-42,0,28),11,C.Muted)
    description.TextWrapped=true
    table.insert(cards,{Frame=frame,Category=category})
    return frame
end
for i,skin in ipairs(Config.Cosmetics) do
    local frame=offer(skin.Name,skin.Id=="Prismatic" and "VIP cloud color · visual only" or "Cloud color · unlock with coins earned in combat",skin.Color,"Skins",i)
    local b=btn("Action",frame,"EQUIP",UDim2.new(1,-154,1,-40),UDim2.fromOffset(140,32),skin.Color)
    b.TextSize=11;cosmeticButtons[skin.Id]=b
    b.Activated:Connect(function()
        if not data.Ready then toast("Profile is connecting. Please try again shortly.");return end
        if skin.Id=="Prismatic" and not data.VIP then toast("Included with the VIP pass. View PASSES for details.");return end
        local owned=data.Unlocks[skin.Id] or (skin.Id=="Prismatic" and data.VIP)
        if not owned and data.Coins<skin.Cost then toast("Earn more coins in the arena, or view optional coin packs.");return end
        Shop:FireServer(owned and "Equip" or "Buy",skin.Id)
    end)
end
local pendingPurchase=nil
local shopOpen
local function refreshPaid()
    for _,entry in ipairs(paidOffers) do
        local owned=entry.Weapon and data.PremiumWeapons[entry.Key] or entry.CrownId and data.Crowns[entry.CrownId] or entry.Key=="VIP" and data.VIP or entry.Key=="DoubleCoins" and data.DoubleCoins
        local enabled=data.Ready and not pendingPurchase and ((owned and (entry.CrownId~=nil or entry.Weapon~=nil)) or (entry.Id>0 and entry.Available and not owned))
        entry.Button.Active=enabled;entry.Button.Selectable=enabled
        entry.Button.BackgroundColor3=enabled and C.Gold or C.Card
        entry.Button.TextColor3=enabled and C.Panel or C.Muted
        entry.Button.Text=owned and entry.Weapon and "EQUIP" or owned and entry.CrownId and (data.EquippedCrown==entry.CrownId and "REMOVE" or "WEAR") or owned and "OWNED" or entry.Id<=0 and "COMING SOON" or pendingPurchase and "PLEASE WAIT" or not data.Ready and "CONNECTING" or not entry.Available and "UNAVAILABLE" or entry.Price
    end
    shopStatus.Text=not data.Ready and "PRACTICE MODE · Saving and purchases are unavailable." or pendingPurchase and "Complete or cancel the Roblox prompt. Coins arrive after confirmation." or "PROGRESS SAVED ONLINE · Purchases are optional. Roblox confirms the final price."
end
local function previewModel(holder,folderName,modelName)
    task.spawn(function()
        local folder=ReplicatedStorage:WaitForChild(folderName,15)
        local source=folder and folder:WaitForChild(modelName,10)
        if not source or not holder.Parent then return end
        local viewport=el("ViewportFrame","ModelPreview",holder,{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,Ambient=Color3.fromRGB(175,185,210),LightColor=Color3.fromRGB(255,246,230),LightDirection=Vector3.new(-1,-1,-1)})
        local world=el("WorldModel","PreviewWorld",viewport)
        local model=el("Model","DisplayModel",world)
        local clone=source:Clone();clone.Parent=model
        for _,object in ipairs(clone:GetDescendants()) do
            if object:IsA("BasePart") then object.Anchored=true;object.CanCollide=false
            elseif object:IsA("LuaSourceContainer") then object:Destroy() end
        end
        local camera=el("Camera","PreviewCamera",viewport,{FieldOfView=35})
        viewport.CurrentCamera=camera
        model:PivotTo(CFrame.Angles(0,math.rad(25),math.rad(-12)))
        local bounds,size=model:GetBoundingBox()
        local distance=math.max(size.X,size.Y,size.Z)*.65/math.tan(math.rad(17.5))
        camera.CFrame=CFrame.lookAt(bounds.Position+Vector3.new(1,.65,1.5).Unit*distance,bounds.Position)
        holder.Fallback.Visible=false
    end)
end

local function robuxOffer(key,title,kind,id,description,order,crown)
    local weapon=Config.Weapons[key]
    local frame=offer(title,description,crown and crown.Color or weapon and weapon.Color or C.Gold,crown and "Crowns" or weapon and "Guns" or kind=="Pass" and "Passes" or "Coins",order)
    frame.Size=UDim2.new(1,-9,0,154)
    frame:FindFirstChild("Name").Position=UDim2.fromOffset(114,10)
    frame:FindFirstChild("Name").Size=UDim2.new(1,-128,0,36);frame:FindFirstChild("Name").TextWrapped=true;frame:FindFirstChild("Name").TextSize=13
    frame.Description.Position=UDim2.fromOffset(114,48)
    frame.Description.Size=UDim2.new(1,-128,0,48)
    local preview=el("Frame","ItemPreview",frame,{Position=UDim2.fromOffset(12,12),Size=UDim2.fromOffset(92,92),BackgroundColor3=C.Panel,BorderSizePixel=0})
    rounded(preview,8)
    local fallback=lbl("Fallback",preview,crown and "CROWN" or weapon and "GEAR" or key=="VIP" and "VIP" or key=="DoubleCoins" and "2×" or "COINS",UDim2.new(),UDim2.fromScale(1,1),16,crown and crown.Color or C.Gold)
    fallback.TextXAlignment=Enum.TextXAlignment.Center
    if weapon then previewModel(preview,"FN_WeaponModels",key)
    elseif crown then previewModel(preview,"FN_CrownModels",crown.Id) end
    local b=btn("Robux",frame,"COMING SOON",UDim2.new(1,-154,1,-40),UDim2.fromOffset(140,32),C.Gold)
    b.TextSize=11
    local entry={Key=key,Kind=kind,Id=id,Weapon=weapon,CrownId=crown and crown.Id,Button=b,Available=false,Price="UNAVAILABLE"}
    if id<=0 and Config.LaunchPrices[key] then
        lbl("LaunchPrice",frame,"PLANNED R$ "..Config.LaunchPrices[key],UDim2.new(0,28,1,-40),UDim2.new(1,-192,0,32),11,C.Gold)
    end
    table.insert(paidOffers,entry)
    if id>0 then
        task.spawn(function()
            local ok,info
            for attempt=1,3 do
                ok,info=pcall(function() return MarketplaceService:GetProductInfoAsync(id,kind=="Pass" and Enum.InfoType.GamePass or Enum.InfoType.Product) end)
                if ok and type(info)=="table" then break end
                task.wait(attempt*.5)
            end
            if ok and type(info)=="table" then
                if info.IsForSale~=false and type(info.PriceInRobux)=="number" then
                    entry.Available=true;entry.Price="R$ "..tostring(info.PriceInRobux)
                end
                if not weapon and not crown and type(info.IconImageAssetId)=="number" and info.IconImageAssetId>0 then
                    el("ImageLabel","RobloxItemIcon",preview,{Size=UDim2.fromScale(1,1),Image="rbxassetid://"..tostring(info.IconImageAssetId),BackgroundTransparency=1})
                end
            end
            refreshPaid()
        end)
    end
    b.Activated:Connect(function()
        if not b.Active or pendingPurchase or not data.Ready then return end
        if weapon and data.PremiumWeapons[key] then SelectWeapon:FireServer(key);shopOpen(false);return end
        if crown and data.Crowns[crown.Id] then
            Shop:FireServer("EquipCrown",data.EquippedCrown==crown.Id and "None" or crown.Id)
            return
        end
        if not entry.Available or id<=0 then return end
        if kind=="Pass" and ((key=="VIP" and data.VIP) or (key=="DoubleCoins" and data.DoubleCoins)) then return end
        pendingPurchase=entry;refreshPaid()
        local ok=pcall(function()
            if kind=="Pass" then MarketplaceService:PromptGamePassPurchase(player,id)
            else MarketplaceService:PromptProductPurchase(player,id) end
        end)
        if not ok then pendingPurchase=nil;refreshPaid();toast("The store is unavailable. Please try again later.") end
    end)
end
robuxOffer("VoidReaper","VOID REAPER","Pass",Config.Passes.VoidReaper,"Permanent · 100 HP/hit · shield piercing · slow fire · 3-shot magazine",1)
robuxOffer("IonStriker","ION STRIKER","Pass",Config.Passes.IonStriker,"Permanent · 50 HP/hit · shield piercing · two hits vs 100 HP",2)
robuxOffer("VIP","VIP OPERATOR","Pass",Config.Passes.VIP,"Permanent · Prism cloud + gold name tag. No combat boost.",1)
robuxOffer("DoubleCoins","DOUBLE COINS","Pass",Config.Passes.DoubleCoins,"Permanent · 2× earned gameplay coins. Purchased packs stay unchanged.",2)
robuxOffer("Coin250","250 COINS","Product",Config.Products.Coin250,"Repeatable · 250 coins for cosmetic unlocks",1)
robuxOffer("Coin1200","1,200 COINS","Product",Config.Products.Coin1200,"Repeatable · 1,200 coins for cosmetic unlocks",2)
robuxOffer("Coin4000","4,000 COINS","Product",Config.Products.Coin4000,"Repeatable · 4,000 coins for cosmetic unlocks",3)
for i,crown in ipairs(Config.Crowns) do
    robuxOffer(crown.Id,crown.Name,"Pass",crown.PassId,"Permanent wearable crown · cosmetic only · no combat boost",i,crown)
end
-- A client-owned Sound survives character respawns and has independent mute/ducking.
local musicId=Config.Music and Config.Music.SoundId or 0
local musicConfigured=type(musicId)=="number" and musicId>0
local musicMuted=false
local musicVolume=math.clamp(Config.Music and Config.Music.Volume or .22,0,.5)
local oldMusic=SoundService:FindFirstChild("FN_ArenaMusic")
if oldMusic then oldMusic:Destroy() end
local music=Instance.new("Sound")
music.Name="FN_ArenaMusic";music.Looped=true;music.Volume=0;music.Parent=SoundService
local musicFailed=false
local retryMusic
local volumeTween
local function updateMusic()
    if volumeTween then volumeTween:Cancel() end
    local target=musicMuted and 0 or (darken.Visible and musicVolume*.6 or musicVolume)
    volumeTween=TweenService:Create(music,TweenInfo.new(.7),{Volume=target})
    volumeTween:Play()
end
local musicFrame=offer("ARENA MUSIC","Original 152 BPM sci-fi instrumental · mute anytime",C.Cyan,"Settings",3)
local musicButton=btn("MusicToggle",musicFrame,musicConfigured and "ON" or "COMING SOON",UDim2.new(1,-154,1,-40),UDim2.fromOffset(140,32),C.Card)
musicButton.TextSize=11;musicButton.TextColor3=C.White
musicButton.Active=musicConfigured;musicButton.Selectable=musicConfigured
musicButton.Activated:Connect(function()
    if not musicConfigured then return end
    if musicFailed then retryMusic();return end
    musicMuted=not musicMuted;musicButton.Text=musicMuted and "OFF" or "ON"
    updateMusic()
end)
darken:GetPropertyChangedSignal("Visible"):Connect(updateMusic)
if musicConfigured then
    music.SoundId="rbxassetid://"..tostring(musicId)
    local attempt=0
    retryMusic=function()
        attempt+=1
        local current=attempt
        musicFailed=false;musicButton.Text=musicMuted and "OFF" or music.IsLoaded and "ON" or "LOADING"
        music:Stop();music:Play();updateMusic()
        task.delay(20,function()
            if current~=attempt or not music.Parent or music.IsLoaded then return end
            musicFailed=true;musicButton.Text="RETRY MUSIC"
            -- Keep retry available; a slow/failed request must not permanently disable music.
            warn("[FART-NIGHT] Music asset "..tostring(musicId).." failed to load in experience "..tostring(game.GameId)..". Check the Roblox Output error, asset moderation and experience audio permission.")
            toast("Music could not load. Settings → Retry Music. Check audio permission for this experience.")
        end)
    end
    music.Loaded:Connect(function()
        musicFailed=false
        musicButton.Text=musicMuted and "OFF" or "ON"
        if not music.IsPlaying then music:Play() end
        updateMusic()
    end)
    retryMusic()
end
gui.Destroying:Connect(function() if music.Parent then music:Destroy() end end)

local function setting(key,title,description,attribute,order)
    local frame=offer(title,description,C.Cyan,"Settings",order)
    local b=btn(key,frame,"OFF",UDim2.new(1,-154,1,-40),UDim2.fromOffset(140,32),C.Card)
    b.TextColor3=C.White
    b.Activated:Connect(function()
        local enabled=not player:GetAttribute(attribute)
        player:SetAttribute(attribute,enabled)
        b.Text=enabled and "ON" or "OFF"
        b.BackgroundColor3=enabled and C.Cyan or C.Card
        b.TextColor3=enabled and C.Panel or C.White
    end)
end
setting("Motion","REDUCED CAMERA MOTION","Disable camera recoil. Applies for this session.","FN_ReducedMotion",1)
setting("Effects","REDUCED EFFECTS","Fewer impact particles. Applies for this session.","FN_LowFX",2)
setting("SoundEffects","MUTE SOUND EFFECTS","Mute weapons, reloads, hit markers and footsteps.","FN_MuteSFX",4)
player:GetAttributeChangedSignal("FN_MuteSFX"):Connect(function()
    sfxGroup.Volume=player:GetAttribute("FN_MuteSFX") and 0 or Config.Audio.Volume
end)
local function selectTab(key)
    activeTab=key
    for _,card in ipairs(cards) do card.Frame.Visible=card.Category==key end
    for name,b in pairs(tabs) do b.BackgroundColor3=name==key and C.Cyan or C.Card;b.TextColor3=name==key and C.Panel or C.White end
    shopScroll.CanvasPosition=Vector2.zero
end
for key,b in pairs(tabs) do b.Activated:Connect(function() selectTab(key) end) end
selectTab("Skins");refreshPaid()
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(who,id,purchased)
    if who~=player or not pendingPurchase or pendingPurchase.Kind~="Pass" or pendingPurchase.Id~=id then return end
    pendingPurchase=nil;refreshPaid()
    if purchased then toast("Purchase received. Verifying your pass…");RequestSync:FireServer() end
end)
MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId,id,purchased)
    if userId~=player.UserId or not pendingPurchase or pendingPurchase.Kind~="Product" or pendingPurchase.Id~=id then return end
    pendingPurchase=nil;refreshPaid()
    if purchased then toast("Purchase received. Your coins are being confirmed…") end
end)
shopOpen=function(yes)
    darken.Visible=yes;player:SetAttribute("FN_MenuOpen",yes)
    firing=false;Sprint:FireServer(false);player:SetAttribute("FN_GamepadAim",false)
    UserInputService.MouseBehavior=Enum.MouseBehavior.Default
    if yes then refreshPaid() end
    if UserInputService.GamepadEnabled then
        game:GetService("GuiService").SelectedObject=yes and tabs[activeTab] or nil
    end
end
shopButton.Activated:Connect(function() shopOpen(not darken.Visible) end)
closeButton.Activated:Connect(function() shopOpen(false) end)
blocker.Activated:Connect(function() shopOpen(false) end)
-- Keep all modal descendants above the input shield and gameplay controls.
local function modalLayer(o)
    if o:IsA("GuiObject") then o.ZIndex=12 end
end
for _,o in ipairs(shopPanel:GetDescendants()) do modalLayer(o) end
shopPanel.DescendantAdded:Connect(modalLayer)

-- First-spawn briefing is dismissible and never interrupts a match after respawn.
local briefing=panel("Briefing",gui,UDim2.new(.5,0,.32,0),UDim2.fromOffset(350,164))
briefing.AnchorPoint=Vector2.new(.5,0);briefing.ZIndex=5
lbl("Eyebrow",briefing,"OPERATOR BRIEFING",UDim2.fromOffset(18,12),UDim2.fromOffset(314,20),11,C.Cyan)
lbl("Title",briefing,"DROP IN. STAND OUT.",UDim2.fromOffset(18,37),UDim2.fromOffset(314,27),22)
local instructions=lbl("Instructions",briefing,"Eliminate rivals. Collect coins. Stay inside the gas ring. Three starter guns. Premium weapons in the Armory.",UDim2.fromOffset(18,68),UDim2.fromOffset(314,42),12,C.Muted)
instructions.TextWrapped=true
local deploy=btn("Deploy",briefing,"LET'S PLAY",UDim2.fromOffset(18,119),UDim2.fromOffset(314,32),C.Cyan)
for _,o in ipairs(briefing:GetDescendants()) do if o:IsA("GuiObject") then o.ZIndex=6 end end
local function dismissBriefing() briefing.Visible=false end
deploy.Activated:Connect(dismissBriefing)
task.delay(12,dismissBriefing)

local feed=el("Frame","EliminationFeed",gui,{AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-18,0,65),Size=UDim2.fromOffset(260,116),BackgroundTransparency=1})
el("UIListLayout","FeedLayout",feed,{Padding=UDim.new(0,5),SortOrder=Enum.SortOrder.LayoutOrder,VerticalAlignment=Enum.VerticalAlignment.Top})
local feedOrder=0
local feedItems={}
FX.OnClientEvent:Connect(function(kind,killer,victim)
    if kind~="Elimination" or type(killer)~="string" or type(victim)~="string" then return end
    feedOrder-=1
    local line=lbl("Elimination",feed,killer.."  >  "..victim,UDim2.new(),UDim2.new(1,0,0,24),11,C.White)
    line.LayoutOrder=feedOrder;line.TextXAlignment=Enum.TextXAlignment.Right;line.TextTruncate=Enum.TextTruncate.AtEnd
    table.insert(feedItems,line)
    if #feedItems>4 then local oldest=table.remove(feedItems,1);oldest:Destroy() end
    task.delay(5,function()
        local index=table.find(feedItems,line)
        if index then table.remove(feedItems,index);line:Destroy() end
    end)
end)
local function resizeHUD()
    local camera=workspace.CurrentCamera;if not camera then return end
    local size=camera.ViewportSize
    local compact=size.X<1000
    local scale=compact and math.min(.78,math.max(.5,(size.X-180)/264)) or 1
    statsScale.Scale=scale;vitalsScale.Scale=scale;ammoScale.Scale=compact and .78 or 1;hotbarScale.Scale=compact and math.min(.78,(size.X-24)/500) or 1
    shopButton.Position=UDim2.fromOffset(18,compact and 126 or 154)
    shopButton.Size=UDim2.fromOffset(compact and 206 or 224,36)
    shopButton.Text=touch and "THE ARMORY" or UserInputService.GamepadEnabled and "ARMORY [SELECT]" or "THE ARMORY [M]"
    reloadButton.Text=touch and "RELOAD" or UserInputService.GamepadEnabled and "RELOAD [X]" or "RELOAD [R]"
    vitalPanel.Position=UDim2.fromOffset(18,compact and 174 or 205)
    shopPanel.Size=UDim2.fromOffset(math.min(720,size.X-24),math.min(580,size.Y-76))
    guide.Visible=not touch and not compact
    feed.Visible=size.X>=1000 and size.Y>=600
    if UserInputService.GamepadEnabled then guide.Text="RT FIRE  /  LT AIM  /  X RELOAD  /  B SLIDE  /  SELECT ARMORY" end
    stormLabel.Position=compact and UDim2.new(1,-156,0,18) or UDim2.new(.5,-165,0,18)
    stormLabel.Size=UDim2.fromOffset(compact and 144 or 330,30)
    stormLabel.TextSize=compact and 11 or 16
    ammoPanel.Position=UDim2.new(1,-18,1,compact and -88 or -18)
    notice.Size=UDim2.fromOffset(math.min(440,size.X-36),48)
    notice.Position=UDim2.new(.5,-math.min(440,size.X-36)/2,.19,0)
    briefing.Size=UDim2.fromOffset(math.min(350,size.X-30),164)
    instructions.Size=UDim2.new(1,-36,0,42);deploy.Size=UDim2.new(1,-36,0,32)
end
local viewportConnection
local function watchViewport()
    if viewportConnection then viewportConnection:Disconnect() end
    if workspace.CurrentCamera then viewportConnection=workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(resizeHUD) end
    resizeHUD()
end
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchViewport);watchViewport()

-- Mobile fire input: taps are optional; Roblox default movement sticks stay intact.
local fireButton
if touch then
    fireButton=btn("MobileFire",gui,"FIRE",UDim2.new(1,-118,1,-282),UDim2.fromOffset(99,99),Color3.fromRGB(132,250,142))
    rounded(fireButton,50)
    fireButton.TextSize=23
    local sprintButton=btn("MobileSprint",gui,"SPRINT",UDim2.new(1,-116,1,-346),UDim2.fromOffset(95,48),Color3.fromRGB(149,207,255))
    sprintButton.TextSize=15
    sprintButton.MouseButton1Down:Connect(function() Sprint:FireServer(true) end)
    sprintButton.MouseButton1Up:Connect(function() Sprint:FireServer(false) end)
    sprintButton.MouseLeave:Connect(function() Sprint:FireServer(false) end)
    local slideButton=btn("MobileSlide",gui,"SLIDE",UDim2.new(1,-226,1,-313),UDim2.fromOffset(94,47),Color3.fromRGB(215,152,251))
    slideButton.TextSize=14
    slideButton.MouseButton1Click:Connect(function() Slide:FireServer() end)
end
local function weaponOfTool(tool)
    if not tool or not tool:IsA("Tool") then return nil end
    local attribute = tool:GetAttribute("FNWeapon")
    if type(attribute)=="string" and Config.Weapons[attribute] then return attribute end
    local marker=tool:FindFirstChild("FN_WeaponId")
    if marker and marker:IsA("StringValue") and Config.Weapons[marker.Value] then
        return marker.Value
    end
    return nil
end
local function activeTool()
    local char=player.Character
    local tool=char and char:FindFirstChildOfClass("Tool")
    local name=weaponOfTool(tool)
    return name and Config.Weapons[name] and name or nil
end
local function fireOnce()
    if darken.Visible then return end
    local name=activeTool()
    local w=name and Config.Weapons[name]
    if not w then
        if os.clock()-lastNoGunToast>5 then
            lastNoGunToast=os.clock()
            toast("Select a weapon from your loadout to deploy.")
        end
        return
    end
    local now=os.clock()
    if now-lastLocalShot < w.FireDelay*.92 then return end
    if data.Reloads and data.Reloads[name] then return end
    if data.Ammo and data.Ammo[name] and data.Ammo[name]<=0 then
        Reload:FireServer()
        return
    end
    local camera=workspace.CurrentCamera
    if not camera then return end
    local middle=cross.AbsolutePosition+cross.AbsoluteSize*.5
    local ray=camera:ScreenPointToRay(middle.X,middle.Y)
    local cast=RaycastParams.new()
    cast.FilterType=Enum.RaycastFilterType.Exclude
    cast.FilterDescendantsInstances={player.Character}
    cast.IgnoreWater=true
    local hit=workspace:Raycast(ray.Origin,ray.Direction*w.Range,cast)
    local aim=hit and hit.Position or (ray.Origin+ray.Direction*w.Range)
    lastLocalShot=now
    player:SetAttribute("FN_ShotAt",now)
    local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if root then shotSound(name,root.Position) end
    Shoot:FireServer(aim)
    if not firstShotSent then
        firstShotSent=true
        print("[FART-NIGHT v6] Client fired with",name)
    end
    cross.BackgroundColor3=w.Color
    task.delay(.07,function() if cross.Parent then cross.BackgroundColor3=Color3.new(1,1,1) end end)
end
local function beginFire()
    if firing or darken.Visible then return end
    dismissBriefing()
    firing=true
    task.spawn(function()
        repeat
            fireOnce()
            local name=activeTool()
            if not name or not Config.Weapons[name].Automatic then break end
            task.wait(0.04)
        until not firing
    end)
end
local function endFire() firing=false end
if fireButton then
    fireButton.MouseButton1Down:Connect(beginFire)
    fireButton.MouseButton1Up:Connect(endFire)
    fireButton.MouseLeave:Connect(endFire)
end
local boundTools={}
local function onTool(tool)
    if not weaponOfTool(tool) or boundTools[tool] then return end
    boundTools[tool]=true
    tool.Destroying:Connect(function() boundTools[tool]=nil end)
    tool.Equipped:Connect(function()
        equipped=weaponOfTool(tool)
        -- Keep the cursor free so clickable weapon buttons and SHOP actually work.
        if not touch then UserInputService.MouseBehavior=Enum.MouseBehavior.Default end
        RequestSync:FireServer()
    end)
    tool.Unequipped:Connect(function()
        endFire()
        equipped=nil
        if not touch then UserInputService.MouseBehavior=Enum.MouseBehavior.Default end
    end)
    tool.Activated:Connect(beginFire)
    tool.Deactivated:Connect(endFire)
end
local function watch(container)
    for _,o in ipairs(container:GetChildren()) do onTool(o) end
    container.ChildAdded:Connect(onTool)
end
watch(player:WaitForChild("Backpack"))
player.CharacterAdded:Connect(function(char)
    endFire()
    watch(char)
    task.delay(1,function() RequestSync:FireServer() end)
end)
if player.Character then watch(player.Character) end
local function equipWeapon(name)
    local spec=Config.Weapons[name]
    if not spec then return end
    if spec.PassKey and not data.PremiumWeapons[name] then
        shopOpen(true);selectTab("Guns");toast("This weapon requires its permanent game pass.")
        return
    end
    if darken.Visible then shopOpen(false) end
    local hum=player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    local tool
    for _,container in ipairs({player.Backpack,player.Character}) do
        if container then
            for _,o in ipairs(container:GetChildren()) do
                if o:IsA("Tool") and weaponOfTool(o)==name then tool=o;break end
            end
        end
        if tool then break end
    end
    if tool then hum:EquipTool(tool) end
    -- Server backup: replication or StarterPack timing can lag behind local UI clicks.
    SelectWeapon:FireServer(name)
end
for name,b in pairs(gunButtons) do b.Activated:Connect(function() equipWeapon(name) end) end

local function autoEquip(char)
    task.delay(0.9, function()
        if char ~= player.Character then return end
        local hum=char:FindFirstChildOfClass("Humanoid")
        if hum and hum.Health>0 and not activeTool() then
            equipWeapon(Config.WeaponOrder[1])
        end
    end)
end
player.CharacterAdded:Connect(autoEquip)
if player.Character then autoEquip(player.Character) end
hideDefaultBackpack()
task.delay(2, hideDefaultBackpack)
-- Diagnostic UI so players see an actionable state instead of nonresponding buttons.
task.delay(4, function()
    if not player.Parent then return end
    local total=0
    for _,container in ipairs({player:FindFirstChildOfClass("Backpack"),player.Character}) do
        if container then
            for _,t in ipairs(container:GetChildren()) do
                if weaponOfTool(t) then total+=1 end
            end
        end
    end
    if total==0 then
        toast("Loadout is taking longer than usual. Please rejoin if it does not appear.")
    elseif not activeTool() then
        toast("Click BEAN BLASTER or press 1 to equip your starting weapon")
    end
end)
reloadButton.Activated:Connect(function() Reload:FireServer() end)
UserInputService.InputBegan:Connect(function(input,gameProcessed)
    if UserInputService:GetFocusedTextBox() then return end
    if input.UserInputType==Enum.UserInputType.MouseButton1 and not gameProcessed and not darken.Visible then
        beginFire()
        return
    end
    if not gameProcessed and input.UserInputType==Enum.UserInputType.MouseButton2 and not darken.Visible then
        UserInputService.MouseBehavior=Enum.MouseBehavior.LockCenter
        return
    end
    if darken.Visible and input.KeyCode~=Enum.KeyCode.M and input.KeyCode~=Enum.KeyCode.Escape then return end
    if gameProcessed then return end
    if input.KeyCode==Enum.KeyCode.Escape and darken.Visible then shopOpen(false);return end
    if input.KeyCode==Enum.KeyCode.One then equipWeapon(Config.WeaponOrder[1]); return end
    if input.KeyCode==Enum.KeyCode.Two then equipWeapon(Config.WeaponOrder[2]); return end
    if input.KeyCode==Enum.KeyCode.Three then equipWeapon(Config.WeaponOrder[3]); return end
    if input.KeyCode==Enum.KeyCode.Four then equipWeapon(Config.WeaponOrder[4]); return end
    if input.KeyCode==Enum.KeyCode.Five then equipWeapon(Config.WeaponOrder[5]); return end
    if gameProcessed then return end
    if input.KeyCode==Enum.KeyCode.R then Reload:FireServer() end
    if input.KeyCode==Enum.KeyCode.LeftShift then Sprint:FireServer(true) end
    if input.KeyCode==Enum.KeyCode.LeftControl or input.KeyCode==Enum.KeyCode.C then Slide:FireServer() end
    if input.KeyCode==Enum.KeyCode.M then shopOpen(not darken.Visible) end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton1 then endFire() end
    if input.UserInputType==Enum.UserInputType.MouseButton2 and not touch then
        UserInputService.MouseBehavior=Enum.MouseBehavior.Default
    end
    if input.KeyCode==Enum.KeyCode.LeftShift then Sprint:FireServer(false) end
end)
-- Console input shares the same server-validated combat actions as keyboard/touch.
local ContextActionService=game:GetService("ContextActionService")
local function padAction(action,state)
    local began=state==Enum.UserInputState.Begin
    local ended=state==Enum.UserInputState.End or state==Enum.UserInputState.Cancel
    if action=="FN_Menu" then
        if began then dismissBriefing();shopOpen(not darken.Visible) end
        return Enum.ContextActionResult.Sink
    end
    if darken.Visible then
        if action=="FN_Slide" and began then shopOpen(false);return Enum.ContextActionResult.Sink end
        return Enum.ContextActionResult.Pass
    end
    if action=="FN_Fire" then if began then beginFire() elseif ended then endFire() end
    elseif action=="FN_Aim" then if began or ended then player:SetAttribute("FN_GamepadAim",began) end
    elseif action=="FN_Reload" and began then Reload:FireServer()
    elseif action=="FN_Sprint" then if began or ended then Sprint:FireServer(began) end
    elseif action=="FN_Slide" and began then Slide:FireServer()
    elseif (action=="FN_Next" or action=="FN_Previous") and began then
        local available={}
        for _,name in ipairs(Config.WeaponOrder) do
            if not Config.Weapons[name].PassKey or data.PremiumWeapons[name] then table.insert(available,name) end
        end
        local current=table.find(available,activeTool()) or 1
        local delta=action=="FN_Next" and 1 or -1
        equipWeapon(available[(current-1+delta)%#available+1])
    end
    return Enum.ContextActionResult.Sink
end
for action,key in pairs({FN_Fire=Enum.KeyCode.ButtonR2,FN_Aim=Enum.KeyCode.ButtonL2,FN_Reload=Enum.KeyCode.ButtonX,
    FN_Sprint=Enum.KeyCode.ButtonL3,FN_Slide=Enum.KeyCode.ButtonB,FN_Menu=Enum.KeyCode.ButtonSelect,
    FN_Next=Enum.KeyCode.ButtonR1,FN_Previous=Enum.KeyCode.ButtonL1}) do
    ContextActionService:BindAction(action,padAction,false,key)
end
UserInputService.WindowFocusReleased:Connect(function()
    endFire();Sprint:FireServer(false);player:SetAttribute("FN_GamepadAim",false)
    UserInputService.MouseBehavior=Enum.MouseBehavior.Default
end)

Storm.OnClientEvent:Connect(function(seconds,radius)
    if type(seconds)~="number" or type(radius)~="number" then return end
    stormLabel.Text=string.format("GAS %d:%02d / %dm",math.floor(seconds/60),seconds%60,radius)
end)
local function refresh()
    statText.Text=string.format("%d KOs    %d COINS    %d DEATHS",data.KOs,data.Coins,data.Deaths)
    rankText.Text=string.format("LEVEL %d    •    %d / 300 XP",data.Level or 1,(data.XP or 0)%300)
    shopCoins.Text=tostring(data.Coins).." COINS  /  YOUR BALANCE"
    xpFill.Size=UDim2.fromScale(((data.XP or 0)%300)/300,1)
    refreshPaid()
    for _,skin in ipairs(Config.Cosmetics) do
        local b=cosmeticButtons[skin.Id]
        local owned=data.Unlocks[skin.Id] or (skin.Id=="Prismatic" and data.VIP)
        b.Text=(data.Equipped==skin.Id and "EQUIPPED") or (owned and "EQUIP") or (skin.Cost==-1 and "VIP ONLY") or (skin.Cost.." COINS")
        b.BackgroundColor3=owned and skin.Color or Color3.fromRGB(132,138,156)
    end
end
local lastReloads={}
Sync.OnClientEvent:Connect(function(newData)
    if type(newData)~="table" then return end
    if type(newData.Reloads)=="table" then
        for name,reloading in pairs(newData.Reloads) do
            if reloading and not lastReloads[name] then uiEffect(Config.Audio.Reload,1.7,.22) end
        end
        lastReloads=table.clone(newData.Reloads)
    end
    for key,value in pairs(newData) do data[key]=value end
    refresh()
end)
Notice.OnClientEvent:Connect(toast)

local function burst(pos,color,count)
    if typeof(pos)~="Vector3" then return end
    local anchor=Instance.new("Part")
    anchor.Name="FNPuff"
    anchor.Position=pos
    anchor.Anchored=true;anchor.CanCollide=false;anchor.CanQuery=false;anchor.Transparency=1
    anchor.Size=Vector3.new(.1,.1,.1)
    anchor.Parent=workspace
    local p=Instance.new("ParticleEmitter")
    p.Rate=0;p.Color=ColorSequence.new(color)
    p.Lifetime=NumberRange.new(.3,.7)
    p.Speed=NumberRange.new(5,12)
    p.SpreadAngle=Vector2.new(180,180)
    p.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,.5),NumberSequenceKeypoint.new(1,0)})
    p.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0.08),NumberSequenceKeypoint.new(1,1)})
    p.Parent=anchor;p:Emit(player:GetAttribute("FN_LowFX") and math.min(count or 9,3) or (count or 9))
    Debris:AddItem(anchor,1.4)
end
FX.OnClientEvent:Connect(function(kind,a,b,c,shooterId,pelletImpacts)
    if kind=="Shot" and typeof(a)=="Vector3" and typeof(b)=="Vector3" then
        if shooterId~=player.UserId then shotSound(c,a) end
        local w=Config.Weapons[c]
        local col=w and w.Color or Color3.new(1,1,1)
        local points=type(pelletImpacts)=="table" and pelletImpacts or {b}
        for i,impact in ipairs(points) do
            if i>8 then break end
            if typeof(impact)~="Vector3" then continue end
        local delta=impact-a
        if delta.Magnitude<.05 then continue end
        local tracer=Instance.new("Part")
        tracer.Name="FN_Tracer"
        tracer.Anchored=true;tracer.CanCollide=false;tracer.CanQuery=false;tracer.CanTouch=false
        tracer.Material=Enum.Material.Neon
        tracer.Color=col
        tracer.Transparency=.18
        -- Tracer begins at the REAL muzzle instead of being centered far away.
        local length=math.min(delta.Magnitude,110)
        local aim=delta.Unit
        tracer.Size=Vector3.new(.075,.075,length)
        tracer.CFrame=CFrame.lookAt(a+aim*(length*.5),impact)
        tracer.Parent=workspace
        Debris:AddItem(tracer,.075)
        burst(impact,col,2)
        end
    elseif kind=="Elim" and typeof(a)=="Vector3" then
        burst(a,Color3.fromRGB(154,255,105),35)
    end
end)

RunService.RenderStepped:Connect(function()
    local name=activeTool()
    equipped=name
    local char=player.Character
    local hum=char and char:FindFirstChildOfClass("Humanoid")
    local health=hum and hum.Health or 0
    shieldText.Text=string.format("%d HP   /   %d SHIELD",math.ceil(health),hum and (hum:GetAttribute("FN_Shield") or 0) or 0)
    healthFill.Size=UDim2.fromScale(math.clamp(health/(hum and hum.MaxHealth or 100),0,1),1)
    healthFill.BackgroundColor3=health<=30 and Color3.fromRGB(255,100,113) or C.Cyan
    staminaFill.Size=UDim2.fromScale(math.clamp((player:GetAttribute("FN_Stamina") or 100)/100,0,1),1)
    cross.Visible=name~=nil and not darken.Visible
    if fireButton then fireButton.Visible=name~=nil and not darken.Visible end
    for n,b in pairs(gunButtons) do
        local locked=Config.Weapons[n].PassKey and not data.PremiumWeapons[n]
        b.Text=(locked and "LOCKED\n" or tostring(table.find(Config.WeaponOrder,n)).." / ")..Config.Weapons[n].Display
        b.TextColor3=locked and C.Muted or C.White
        b.BackgroundColor3=n==name and Color3.fromRGB(32,83,104) or C.Card
    end
    local w=name and Config.Weapons[name]
    if w then
        gunName.Text=w.Display
        local remain=data.Ammo and data.Ammo[name] or w.Magazine
        local isReloading=data.Reloads and data.Reloads[name] and data.Reloads[name]>0
        ammoText.Text=isReloading and "RELOADING" or string.format("%d / %d",remain,w.Magazine)
        ammoText.TextSize=isReloading and 19 or 28
        ammoText.TextColor3=remain<=math.ceil(w.Magazine*.2) and C.Gold or C.White
    else
        gunName.Text="EQUIP A WEAPON"
        ammoText.Text="-- / --"
    end
end)
RequestSync:FireServer()
toast("Welcome to Neon City. Your starter loadout is ready. Make your mark.")
