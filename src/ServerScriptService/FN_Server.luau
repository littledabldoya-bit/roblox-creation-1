-- FART-NIGHT / ServerScriptService / FN_Server
-- Designed for one server-owned game script, no third-party assets or packages.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")

local Config = require(ReplicatedStorage:WaitForChild("FN_Config"))
local Economy = require(ReplicatedStorage:WaitForChild("FN_Economy"))
local Combat = require(ReplicatedStorage:WaitForChild("FN_Combat"))
local HttpService = game:GetService("HttpService")
local SESSION_SECONDS = 180
local Arena = workspace:WaitForChild("FartNightArena")
local Remotes = ReplicatedStorage:WaitForChild("FN_Remotes")
local Shoot = Remotes:WaitForChild("Shoot")
local Reload = Remotes:WaitForChild("Reload")
local Sync = Remotes:WaitForChild("Sync")
local RequestSync = Remotes:WaitForChild("RequestSync")
local Shop = Remotes:WaitForChild("Shop")
local Notice = Remotes:WaitForChild("Notice")
local FX = Remotes:WaitForChild("FX")
local Storm = Remotes:WaitForChild("Storm")
local Sprint = Remotes:WaitForChild("Sprint")
local SelectWeapon = Remotes:WaitForChild("SelectWeapon")
local HitConfirm = Remotes:WaitForChild("HitConfirm")
local Slide = Remotes:WaitForChild("Slide")

Players.RespawnTime = Config.RespawnSeconds
-- Offline Studio play should never block combat or loadout initialization.
local store
local storeOk, storeResult = pcall(function()
    return DataStoreService:GetDataStore("FartNight_Profile_V1")
end)
if storeOk then store = storeResult else
    warn("[FART-NIGHT] Profile service unavailable; combat will still work.", storeResult)
end
local sessions = {}
local rng = Random.new()
local byCosmetic = {}
for _, skin in ipairs(Config.Cosmetics) do byCosmetic[skin.Id] = skin end

local function defaultData()
    return {Coins = 0, XP = 0, KOs = 0, Deaths = 0, Unlocks = {Mint = true}, Equipped = "Mint", EquippedCrown = "None", Receipts = {}}
end
local function normalized(value)
    return Economy.normalize(value, byCosmetic)
end
local function sync(player)
    local s = sessions[player]
    if not s then return end
    Sync:FireClient(player, {
        Coins = s.data.Coins, XP = s.data.XP, Level = math.floor(s.data.XP/300)+1, KOs = s.data.KOs, Deaths = s.data.Deaths,
        Unlocks = s.data.Unlocks, Equipped = s.data.Equipped, VIP = s.VIP,
        Crowns = s.Crowns, EquippedCrown = s.data.EquippedCrown, PremiumWeapons = s.PremiumWeapons,
        DoubleCoins = s.DoubleCoins, Ready = s.persistReady and os.time() < s.leaseUntil,
        Ammo = s.ammo, Reloads = s.reloading,
    })
end
local function stats(player, s)
    local board = player:FindFirstChild("leaderstats")
    if board then
        board.Coins.Value = math.max(0, math.floor(s.data.Coins))
        board.Level.Value = math.floor(s.data.XP/300)+1
        board.KOs.Value = s.data.KOs
        board.Streak.Value = s.streak
    end
    sync(player)
end
local function takeLock(s)
    while s.busy do task.wait(0.05) end
    s.busy = true
end
local function releaseLock(s) s.busy = false end

local function settleSave(s)
    local attempt=s.saveAttempt
    if not attempt then return end
    s.pendingCoins-=attempt.Coins
    s.pendingXP-=attempt.XP
    s.pendingKOs-=attempt.KOs
    s.pendingDeaths-=attempt.Deaths
    for id in pairs(attempt.Unlocks) do s.pendingUnlocks[id]=nil end
    s.saveAttempt=nil
end

local function save(player, closing)
    local s = sessions[player]
    if not s or not s.persistReady or not store then return false end
    takeLock(s)
    if s.closed then releaseLock(s); return true end
    if closing and s.saveAttempt and not s.saveAttempt.Closing then
        -- Settle an uncertain autosave before snapshotting newer progress for departure.
        releaseLock(s)
        if not save(player,false) then return false end
        return save(player,true)
    end
    -- Reuse the same delta transaction after an uncertain network failure.
    -- An UpdateAsync can commit even when its response fails to reach this server.
    if not s.saveAttempt then
        s.saveSequence=(s.saveSequence or 0)+1
        s.saveAttempt={Id=s.owner..":"..s.saveSequence, Closing=closing==true, Coins=s.pendingCoins, XP=s.pendingXP,
            KOs=s.pendingKOs, Deaths=s.pendingDeaths, Unlocks=table.clone(s.pendingUnlocks), Equipped=s.data.Equipped, EquippedCrown=s.data.EquippedCrown}
    end
    local attempt=s.saveAttempt
    local deltaCoins,deltaXP,deltaKOs,deltaDeaths=attempt.Coins,attempt.XP,attempt.KOs,attempt.Deaths
    local newUnlocks,equipped=attempt.Unlocks,attempt.Equipped
    local success, result = pcall(function()
        return store:UpdateAsync("User_" .. player.UserId, function(old)
            local d = normalized(old)
            if closing and d.LastSaveId==attempt.Id and not d.Session then return d end
            if not d.Session or d.Session.Owner ~= s.owner then return nil end
            if d.LastSaveId~=attempt.Id then
                d.Coins = math.max(0, d.Coins + deltaCoins)
                d.XP = math.max(0, d.XP + deltaXP)
                d.KOs += deltaKOs
                d.Deaths += deltaDeaths
                for id in pairs(newUnlocks) do d.Unlocks[id] = true end
                if d.Unlocks[equipped] or (equipped == "Prismatic" and s.VIP) then d.Equipped = equipped end
                if Economy.canEquipCrown(Config.Crowns, s.Crowns, attempt.EquippedCrown) then
                    d.EquippedCrown=attempt.EquippedCrown
                end
                d.LastSaveId=attempt.Id
            end
            if closing then d.Session = nil else d.Session = {Owner = s.owner, Expires = os.time() + SESSION_SECONDS} end
            return d
        end)
    end)
    if success and result then
        settleSave(s)
        s.leaseUntil = closing and 0 or result.Session.Expires
        s.closed = closing == true
        s.data.Coins = math.max(0, result.Coins + s.pendingCoins)
        s.data.Receipts = result.Receipts
    else
        if success then s.persistReady = false end -- Another session owns the record.
        warn("[FART-NIGHT] Profile save failed for", player.Name, result)
    end
    releaseLock(s)
    if not closing and player.Parent then sync(player) end
    return success and result ~= nil
end
local function grantCoins(player, amount)
    local s = sessions[player]
    if not s then return end
    local actual = math.floor(amount * (s.DoubleCoins and 2 or 1))
    s.data.Coins += actual
    s.pendingCoins += actual
    stats(player, s)
end
local function grantXP(player, amount)
    local s=sessions[player]
    if not s then return end
    local before=math.floor(s.data.XP/300)+1
    s.data.XP+=math.max(0,math.floor(amount))
    s.pendingXP+=math.max(0,math.floor(amount))
    local after=math.floor(s.data.XP/300)+1
    stats(player,s)
    if after>before then Notice:FireClient(player,"RANK UP! LEVEL "..after.." / +"..amount.." XP") end
end
local function spendCoins(player, amount)
    local s = sessions[player]
    if not s or s.data.Coins < amount then return false end
    s.data.Coins -= amount
    s.pendingCoins -= amount
    stats(player, s)
    return true
end

local function weaponOfTool(tool)
    if not tool or not tool:IsA("Tool") then return nil end
    local attribute = tool:GetAttribute("FNWeapon")
    if type(attribute) == "string" and Config.Weapons[attribute] then return attribute end
    local marker = tool:FindFirstChild("FN_WeaponId")
    if marker and marker:IsA("StringValue") and Config.Weapons[marker.Value] then
        return marker.Value
    end
    return nil
end

local function findWeaponTool(player, weaponName)
    local function scan(container)
        if not container then return nil end
        for _, instance in ipairs(container:GetChildren()) do
            if weaponOfTool(instance) == weaponName then return instance end
        end
        return nil
    end
    return scan(player.Character) or scan(player:FindFirstChildOfClass("Backpack"))
end


-- FART-NIGHT 1.2: high-detail procedural weapon bodies built on the server.
-- No toolbox assets, broken asset IDs, or client-only models. Uses handle-relative welded shapes.
local StarterPack = game:GetService("StarterPack")
local function finishWeapon(tool, weaponName)
    local spec = Config.Weapons[weaponName]
    if not spec then return end
    tool.Name = spec.Display
    tool.RequiresHandle = true
    tool.CanBeDropped = false
    tool.Enabled = true
    tool.ManualActivationOnly = false
    tool:SetAttribute("FNWeapon", weaponName)
    tool.ToolTip = "FART-NIGHT | "..spec.Display
    local marker = tool:FindFirstChild("FN_WeaponId")
    if not marker then marker = Instance.new("StringValue"); marker.Name="FN_WeaponId"; marker.Parent=tool end
    marker.Value = weaponName
    local grip = tool:FindFirstChild("Handle")
    if not grip or not grip:IsA("BasePart") then
        if grip then grip:Destroy() end
        grip=Instance.new("Part"); grip.Name="Handle"; grip.Parent=tool
    end
    grip.Size=Vector3.new(.36,.54,.72)
    grip.Material=Enum.Material.Metal
    grip.Color=Color3.fromRGB(28,33,47)
    grip.CanCollide=false;grip.CanTouch=false;grip.CanQuery=false
    grip.Anchored=false;grip.Massless=true
    -- Cleanup first, because v1.1 could have a single unwelded cube called Barrel.
    for _,child in ipairs(tool:GetChildren()) do
        if child:IsA("BasePart") and child~=grip then child:Destroy() end
        if child.Name=="FN_BuiltModel" or child.Name=="FN_ImportedModel" then child:Destroy() end
    end
    tool.Grip=CFrame.new(0,-.12,-.22) -- forward-facing, no accidental 90-degree yaw
    local decorative=Instance.new("Folder")
    decorative.Name="FN_BuiltModel"
    decorative.Parent=tool
    local dark=Color3.fromRGB(26,31,45)
    local steel=Color3.fromRGB(59,73,92)
    local chrome=Color3.fromRGB(172,186,207)
    local accent=spec.Color
    local function piece(label,offset,size,col,mat,shape,tilt)
        -- Scale each welded component in handle-local space so all guns fit an avatar.
        offset=offset*.64
        size=size*.64
        local p=Instance.new("Part")
        p.Name=label
        p.Size=size
        p.Material=mat or Enum.Material.Metal
        p.Color=col
        if shape then p.Shape=shape end
        p.Anchored=false; p.CanCollide=false; p.CanTouch=false; p.CanQuery=false
        p.Massless=true; p.CastShadow=false
        p.CFrame=grip.CFrame*CFrame.new(offset)*(tilt or CFrame.new())
        p.Parent=tool
        local weld=Instance.new("WeldConstraint")
        weld.Name="FN_BodyWeld";weld.Part0=grip;weld.Part1=p;weld.Parent=p
        return p
    end
    local function prism(label,x,y,z,sx,sy,sz,col,mat)
        return piece(label,Vector3.new(x,y,z),Vector3.new(sx,sy,sz),col,mat)
    end
    local cylTilt=CFrame.Angles(0,math.pi/2,0)
    local function tube(label,x,y,z,diam,length,col,mat)
        return piece(label,Vector3.new(x,y,z),Vector3.new(length,diam,diam),col,mat,Enum.PartType.Cylinder,cylTilt)
    end
    -- All profiles point along local -Z, the muzzle is on the true 3-D gun barrel.
    prism("CoreReceiver",0,.35,-.36,.96,.84,2.02,steel)
    prism("ArmorTop",0,.79,-.45,.85,.21,1.92,dark)
    prism("SideLeft",-.51,.29,-.42,.12,.53,1.52,dark)
    prism("SideRight",.51,.29,-.42,.12,.53,1.52,dark)
    prism("TriggerGuard",0,-.49,-.16,.42,.13,.67,chrome)
    prism("PistolGrip",0,-.67,.38,.4,.91,.45,dark)
    prism("EnergyCore",.0,.34,-.35,.69,.24,1.1,accent,Enum.Material.Neon)
    prism("PowerRail",0,.69,-.42,.55,.11,1.58,chrome)
    prism("RearStock",0,.11,1.29,.64,.55,1.48,dark)
    prism("StockEnd",0,.11,1.98,.75,.71,.19,steel)
    prism("AmmoMagazine",0,-.56,-.83,.58,.9,.61,steel)
    prism("MagLight",0,-.6,-1.15,.3,.48,.07,accent,Enum.Material.Neon)
    prism("SafetySwitch",.57,.37,.19,.09,.13,.19,chrome)
    prism("CheekRest",0,.44,1.44,.53,.14,.77,dark)
    prism("ChargeIndicator",-.54,.42,.05,.07,.27,.39,accent,Enum.Material.Neon)
    prism("ReceiverScrewL",-.57,.14,-.06,.075,.075,.075,chrome)
    prism("ReceiverScrewR",.57,.14,-.06,.075,.075,.075,chrome)
    prism("ChargingHandle",.26,.87,.23,.28,.13,.34,steel)
    local muzzleZ=-2.75
    if weaponName=="BeanBlaster" then
        -- Compact rapid-fire plasma rifle: long dual side rails, suppressor, vents.
        prism("ForeShroud",0,.36,-1.72,.83,.7,1.61,dark)
        prism("ShroudStripeLeft",-.43,.45,-1.8,.08,.16,1.3,accent,Enum.Material.Neon)
        prism("ShroudStripeRight",.43,.45,-1.8,.08,.16,1.3,accent,Enum.Material.Neon)
        tube("PrimaryBarrel",0,.33,-2.75,.31,2.25,chrome)
        tube("MuzzleBrake",0,.33,-3.67,.53,.40,dark)
        tube("MuzzleRing",0,.33,-3.89,.57,.13,accent,Enum.Material.Neon)
        prism("FrontSight",0,.93,-2.8,.15,.48,.16,chrome)
        prism("RearSight",0,1.0,.35,.18,.34,.25,chrome)
        muzzleZ=-3.99
    elseif weaponName=="BurpCannon" then
        -- Heavy twin-barrel scattergun: big pump grip, pressure drums, double bores.
        prism("WideChamber",0,.34,-1.37,1.18,.91,1.28,dark)
        prism("GoldenPump",0,-.16,-1.92,.95,.31,1.06,accent)
        tube("UpperBore",-.25,.52,-2.62,.48,2.6,chrome)
        tube("LowerBore",.25,.16,-2.62,.48,2.6,chrome)
        tube("UpperMuzzle",-.25,.52,-3.87,.57,.23,accent,Enum.Material.Neon)
        tube("LowerMuzzle",.25,.16,-3.87,.57,.23,accent,Enum.Material.Neon)
        tube("PressureDrum",.62,.33,-.88,.54,.96,steel)
        prism("PumpRibLeft",-.48,-.11,-1.99,.12,.31,.82,chrome)
        prism("PumpRibRight",.48,-.11,-1.99,.12,.31,.82,chrome)
        muzzleZ=-4.02
    elseif weaponName=="ToxicTagger" then
        -- Long precision rail rifle: free-floating barrel, real scope silhouette.
        prism("LongHandguard",0,.42,-2.02,.77,.48,2.2,dark)
        tube("FloatingBarrel",0,.34,-3.42,.24,3.35,chrome)
        tube("MuzzleHider",0,.34,-5.05,.39,.47,dark)
        tube("MuzzleGlow",0,.34,-5.31,.43,.11,accent,Enum.Material.Neon)
        prism("ScopeMount",0,1.03,-.23,.33,.32,.72,steel)
        tube("OpticTube",0,1.35,-.25,.55,1.48,dark)
        tube("OpticFront",0,1.35,-1.02,.67,.2,accent,Enum.Material.Neon)
        tube("OpticRear",0,1.35,.52,.65,.19,chrome)
        prism("BipodLeft",-.34,-.37,-3.06,.12,.91,.16,steel)
        prism("BipodRight",.34,-.37,-3.06,.12,.91,.16,steel)
        prism("RailLeft",-.43,.48,-2.03,.1,.14,1.78,accent,Enum.Material.Neon)
        prism("RailRight",.43,.48,-2.03,.1,.14,1.78,accent,Enum.Material.Neon)
        muzzleZ=-5.40
    elseif weaponName=="VoidReaper" then
        -- Heavy split-rail accelerator: armored stock, scope, capacitors and barrel cage.
        prism("ReaperReceiver",0,.4,-1.1,1.22,1.06,2.4,dark)
        prism("ReaperStock",0,.18,1.8,.92,.86,1.55,steel)
        prism("ShoulderPad",0,.18,2.65,1.04,1.08,.24,dark)
        prism("CapacitorMagazine",0,-.8,-.75,.84,1.45,.82,steel)
        tube("AcceleratorCore",0,.38,-3.7,.26,4.7,chrome)
        for side=-1,1,2 do
            prism("SplitRail",side*.48,.4,-3.5,.18,.6,4.3,steel)
            prism("RailConductor",side*.58,.4,-3.5,.06,.2,3.8,accent,Enum.Material.Neon)
            for i=1,7 do
                prism("CoolingFin",side*.68,.4,-1.65-i*.4,.28,.72,.10,dark)
                prism("ReceiverBolt",side*.65,.58,-.4-i*.19,.07,.1,.1,chrome)
            end
        end
        for i=1,5 do tube("InductionRing",0,.38,-2-i*.64,.93,.12,steel) end
        prism("ScopeBase",0,1.14,-.35,.4,.35,1.15,chrome)
        tube("LongScope",0,1.46,-.45,.59,2.0,dark)
        tube("ScopeGlass",0,1.46,-1.5,.62,.08,accent,Enum.Material.Neon)
        tube("ReaperMuzzle",0,.38,-6.07,.67,.32,dark)
        tube("ReaperMuzzleRing",0,.38,-6.26,.71,.07,accent,Enum.Material.Neon)
        muzzleZ=-6.34
    elseif weaponName=="IonStriker" then
        -- Twin energy rails with exposed coils, segmented foregrip, optic and side canisters.
        prism("IonChamber",0,.38,-1.0,1.08,.95,2.0,steel)
        prism("IonStock",0,.22,1.6,.73,.66,1.6,dark)
        prism("StockVent",0,.5,1.9,.57,.12,.83,chrome)
        tube("IonBarrel",0,.35,-2.9,.30,3.45,chrome)
        for side=-1,1,2 do
            prism("IonRail",side*.43,.44,-2.4,.16,.45,2.7,dark)
            prism("IonStrip",side*.53,.44,-2.4,.05,.14,2.4,accent,Enum.Material.Neon)
            tube("EnergyCanister",side*.68,.32,-.58,.35,1.25,accent)
            for i=1,6 do
                prism("GripSegment",side*.37,-.15,-1.4-i*.25,.2,.48,.12,dark)
                prism("VentLouvre",side*.59,.72,-.4-i*.16,.16,.12,.06,chrome)
            end
        end
        for i=1,4 do tube("IonCoil",0,.35,-2.0-i*.48,.66,.15,steel) end
        prism("ReflexBase",0,1.0,-.15,.36,.27,.67,dark)
        prism("ReflexFrame",0,1.27,-.35,.57,.40,.11,steel)
        prism("ReflexGlass",0,1.27,-.42,.40,.26,.025,accent)
        tube("IonBrake",0,.35,-4.6,.58,.45,dark)
        tube("IonAperture",0,.35,-4.85,.48,.06,accent,Enum.Material.Neon)
        muzzleZ=-4.93
    end
    local muzzle=grip:FindFirstChild("FN_Muzzle")
    if not muzzle then muzzle=Instance.new("Attachment");muzzle.Name="FN_Muzzle";muzzle.Parent=grip end
    muzzle.Position=Vector3.new(0,.35,muzzleZ)*.64
    local flash=Instance.new("ParticleEmitter")
    flash.Name="FN_Flash"
    flash.Enabled=false;flash.Rate=0
    flash.Lifetime=NumberRange.new(.07,.13)
    flash.Speed=NumberRange.new(3,7)
    flash.SpreadAngle=Vector2.new(18,18)
    flash.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,.65),NumberSequenceKeypoint.new(1,0)})
    flash.Color=ColorSequence.new(accent)
    flash.LightEmission=1
    flash.Parent=muzzle
    -- Optional vetted Creator Store meshes: purely cosmetic models, NEVER adopt untrusted scripts.
    local folder=ReplicatedStorage:FindFirstChild("FN_WeaponArt")
    local source=folder and folder:FindFirstChild(weaponName)
    if source and source:IsA("Model") then
        local visual=source:Clone()
        visual.Name="FN_ImportedModel"
        local hasPart=false
        for _,instance in ipairs(visual:GetDescendants()) do
            if instance:IsA("LuaSourceContainer") or instance:IsA("RemoteEvent") or instance:IsA("RemoteFunction") then
                instance:Destroy()
            elseif instance:IsA("BasePart") then
                hasPart=true
                instance.Anchored=false;instance.CanCollide=false;instance.CanTouch=false;instance.CanQuery=false
                instance.Massless=true
            end
        end
        if hasPart then
            -- Creator art must be front-facing (-Z), centered around its pivot at the receiver.
            visual:PivotTo(grip.CFrame * CFrame.new(0,.22,-1))
            for _,p in ipairs(visual:GetDescendants()) do
                if p:IsA("BasePart") then
                    local wc=Instance.new("WeldConstraint")
                    wc.Part0=grip;wc.Part1=p;wc.Parent=p
                end
            end
            visual.Parent=tool
            for _,p in ipairs(tool:GetChildren()) do
                if p:IsA("BasePart") and p~=grip then p:Destroy() end
            end
            -- Optional attachment can be set at the gun's true muzzle by the asset artist.
            local customTip=visual:FindFirstChild("FN_Muzzle",true)
            if customTip and customTip:IsA("Attachment") then
                muzzle.Position=grip.CFrame:PointToObjectSpace(customTip.WorldPosition)
            end
        else
            visual:Destroy()
        end
    end
    tool:SetAttribute("FN_ModelV",5)
    return tool
end
local function ensureWeapon(player, weaponName)
    local s=sessions[player]
    if not s or not Combat.canUse(Config,s.PremiumWeapons,weaponName) then return nil end
    local function scan(container)
        if not container then return nil end
        for _,object in ipairs(container:GetChildren()) do
            if object:IsA("Tool") and (object:GetAttribute("FNWeapon")==weaponName
                or (object:FindFirstChild("FN_WeaponId") and object.FN_WeaponId.Value==weaponName)) then
                return object
            end
        end
    end
    local existing=scan(player.Character) or scan(player:FindFirstChildOfClass("Backpack"))
    if existing then
        if existing:GetAttribute("FN_ModelV")~=5 then finishWeapon(existing,weaponName) end
        return existing
    end
    local template=StarterPack:FindFirstChild(Config.Weapons[weaponName].Display)
    local tool=template and template:Clone() or Instance.new("Tool")
    finishWeapon(tool,weaponName)
    tool.Parent=player:WaitForChild("Backpack")
    return tool
end
-- Upgrade StarterPack before its templates are cloned at spawn; server also repairs old copies.
for _, weaponName in ipairs(Config.WeaponOrder) do
    local desc=Config.Weapons[weaponName]
    if desc.PassKey then continue end
    local tool=StarterPack:FindFirstChild(desc.Display)
    if not tool or not tool:IsA("Tool") then
        tool=Instance.new("Tool"); tool.Name=desc.Display;tool.Parent=StarterPack
    end
    finishWeapon(tool,weaponName)
end

local function giveTool(player, weaponName)
    return ensureWeapon(player, weaponName)
end

-- Cosmetic-only crown geometry, welded to the head without collisions or mass.
local function applyCrown(player)
    local s=sessions[player]
    local char=player.Character
    local head=char and char:FindFirstChild("Head")
    if not s or not head then return end
    local old=char:FindFirstChild("FN_WornCrown")
    if old then old:Destroy() end
    local id=s.data.EquippedCrown
    if id=="None" or not Economy.canEquipCrown(Config.Crowns,s.Crowns,id) then return end
    local selected
    for _,crown in ipairs(Config.Crowns) do if crown.Id==id then selected=crown;break end end
    if not selected then return end
    local model=Instance.new("Model");model.Name="FN_WornCrown"
    local radius=math.max(head.Size.X,head.Size.Z)*.48
    local height=head.Size.Y*.5+.12
    local function piece(kind,name,size,offset,color)
        local p=Instance.new(kind);p.Name=name;p.Size=size;p.CFrame=head.CFrame*offset
        p.Color=color;p.Material=Enum.Material.Metal
        p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.Massless=true;p.CastShadow=false
        p.Parent=model
        local weld=Instance.new("WeldConstraint");weld.Part0=head;weld.Part1=p;weld.Parent=p
    end
    for i=1,12 do
        local angle=(i-1)*math.tau/12
        local offset=CFrame.new(math.cos(angle)*radius,height,math.sin(angle)*radius)*CFrame.Angles(0,-angle,0)
        piece("Part","Band",Vector3.new(.14,.16,radius*.54),offset,selected.Color)
        if i%2==0 then
            piece("WedgePart","Point",Vector3.new(.18,.46,radius*.38),offset*CFrame.new(0,.25,0),selected.Color)
            piece("Part","Gem",Vector3.new(.16,.16,.16),offset*CFrame.new(.08,.05,0),Color3.fromRGB(193,220,235))
        end
    end
    model.Parent=char
end

local function applyCosmetic(player)
    local s = sessions[player]
    local char = player.Character
    if not s or not char then return end
    local skin = byCosmetic[s.data.Equipped] or byCosmetic.Mint
    local root = char:FindFirstChild("HumanoidRootPart")
    local head = char:FindFirstChild("Head")
    if not root or not head then return end
    applyCrown(player)
    local old = root:FindFirstChild("FN_GasAura")
    if old then old:Destroy() end
    local att = Instance.new("Attachment")
    att.Name = "FN_GasAura"
    att.Position = Vector3.new(0, -1.1, 0)
    att.Parent = root
    local p = Instance.new("ParticleEmitter")
    p.Name = "PuffTrail"
    p.Rate = 9
    p.Lifetime = NumberRange.new(0.45, 0.9)
    p.Speed = NumberRange.new(1, 2.5)
    p.SpreadAngle = Vector2.new(65, 65)
    p.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 0)})
    p.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1)})
    p.Color = ColorSequence.new(skin.Color)
    p.LightEmission = 0.6
    p.Parent = att
    local oldTag = head:FindFirstChild("FN_Nameplate")
    if oldTag then oldTag:Destroy() end
    if s.VIP then
        local billboard = Instance.new("BillboardGui")
        billboard.Name = "FN_Nameplate"
        billboard.Size = UDim2.fromOffset(130, 28)
        billboard.StudsOffset = Vector3.new(0, 3, 0)
        billboard.AlwaysOnTop = true
        billboard.Parent = head
        local txt = Instance.new("TextLabel")
        txt.Size = UDim2.fromScale(1, 1)
        txt.BackgroundTransparency = 1
        txt.Text = "★ VIP TOOTER ★"
        txt.TextColor3 = Color3.fromRGB(255, 232, 95)
        txt.Font = Enum.Font.GothamBlack
        txt.TextScaled = true
        txt.TextStrokeTransparency = 0.3
        txt.Parent = billboard
    end
end

local function onDied(player, humanoid)
    local s = sessions[player]
    if not s then return end
    s.data.Deaths += 1
    s.pendingDeaths += 1
    s.streak = 0
    stats(player, s)
    local userId = humanoid:GetAttribute("FN_LastHit")
    local hitAt = humanoid:GetAttribute("FN_LastHitAt")
    if typeof(userId) == "number" and typeof(hitAt) == "number" and (os.clock() - hitAt) < 9 and userId ~= player.UserId then
        local killer = Players:GetPlayerByUserId(userId)
        local k = killer and sessions[killer]
        if k then
            k.data.KOs += 1
            k.pendingKOs += 1
            k.streak += 1
            grantCoins(killer, Config.KillCoins)
            grantXP(killer, 75)
            stats(killer, k)
            Notice:FireClient(killer, "+" .. tostring(Config.KillCoins * (k.DoubleCoins and 2 or 1)) .. " coins | ELIMINATION!")
            FX:FireAllClients("Elimination", killer.DisplayName, player.DisplayName)
            FX:FireAllClients("Elim", player.Character and player.Character:GetPivot().Position or Vector3.zero, k.streak)
        end
    end
end
local function handleSpawn(player, character)
    local s = sessions[player]
    if not s then return end
    s.ammo, s.reloading, s.lastFire = {}, {}, {}
    for _, weaponName in ipairs(Config.WeaponOrder) do s.ammo[weaponName] = Config.Weapons[weaponName].Magazine end
    local hum = character:WaitForChild("Humanoid", 8)
    if not hum then return end
    hum.MaxHealth, hum.Health = 100, 100
    hum:SetAttribute("FN_Shield", 0)
    s.stamina = 100
    s.sprintRequested = false
    player:SetAttribute("FN_Stamina", 100)
    local ff = Instance.new("ForceField")
    ff.Name = "FN_SpawnShield"
    ff.Visible = true
    ff.Parent = character
    task.delay(Config.SpawnShieldSeconds, function() if ff.Parent then ff:Destroy() end end)
    local root = character:WaitForChild("HumanoidRootPart", 8)
    if root then
        -- Roblox can choose edge spawn pads in old games. Reposition server-side to the permanent safe core.
        local a = (player.UserId%12)*math.tau/12 + rng:NextNumber(-.24,.24)
        local landing = Vector3.new(math.cos(a)*Config.SafeSpawnRadius, 11, math.sin(a)*Config.SafeSpawnRadius)
        character:PivotTo(CFrame.lookAt(landing, Vector3.new(0,landing.Y,0)))
        hum:SetAttribute("FN_ProtectedUntil", os.clock()+Config.SpawnShieldSeconds)
        root.Touched:Connect(function(part)
            if part.Name == "FN_Bounce" and part:IsDescendantOf(Arena) and hum.Health > 0 then
                root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, 85, root.AssemblyLinearVelocity.Z)
            end
        end)
    end
    task.delay(0.65, function()
        if player.Character ~= character or hum.Health <= 0 then return end
        -- Repair missing tools rather than creating duplicates of StarterPack tools.
        for _, weaponName in ipairs(Config.WeaponOrder) do
            giveTool(player, weaponName)
        end
        local tool = findWeaponTool(player, Config.WeaponOrder[1])
        if tool and hum.Parent and not character:FindFirstChildOfClass("Tool") then
            hum:EquipTool(tool)
        end
    end)
    applyCosmetic(player)
    sync(player)
    hum.Died:Connect(function() onDied(player, hum) end)
end

local function load(player)
    local board = Instance.new("Folder")
    board.Name = "leaderstats"
    board.Parent = player
    for _, name in ipairs({"KOs", "Coins", "Streak", "Level"}) do
        local v = Instance.new("IntValue")
        v.Name = name
        v.Parent = board
    end
    local s = {
        data = defaultData(), persistReady = false,
        owner = HttpService:GenerateGUID(false), leaseUntil = 0, closed = false,
        pendingCoins = 0, pendingXP=0, pendingKOs = 0, pendingDeaths = 0, pendingUnlocks = {},
        VIP = false, DoubleCoins = false, Crowns = {}, PremiumWeapons = {}, busy = false, streak = 0,
        ammo = {}, reloading = {}, lastFire = {}, stamina=100, sprintRequested=false,
    }
    local studioPreview=Config.StudioPremiumPreview and RunService:IsStudio()
    if studioPreview then
        for _,name in ipairs(Config.WeaponOrder) do
            if Config.Weapons[name].PassKey then s.PremiumWeapons[name]=true end
        end
    end
    sessions[player] = s
    player.CharacterAdded:Connect(function(char)
        task.spawn(handleSpawn, player, char)
    end)
    if player.Character then task.spawn(handleSpawn, player, player.Character) end
    -- Profile I/O may fail or take time. Weapons and HUD must work either way.
    local data
    for _ = 1, (store and 3 or 0) do
        local ok, response = pcall(function()
            return store:UpdateAsync("User_" .. player.UserId, function(old)
                local record = normalized(old)
                if not player.Parent or not Economy.canClaim(record, s.owner, os.time()) then return nil end
                record.Session = {Owner = s.owner, Expires = os.time() + SESSION_SECONDS}
                return record
            end)
        end)
        if ok and response then
            data = normalized(response)
            s.persistReady = true
            s.leaseUntil = data.Session.Expires
            break
        end
        task.wait(1)
    end
    if sessions[player] ~= s or not player.Parent then
        -- Release a lease acquired while this player was leaving.
        if s.persistReady then
            pcall(function()
                store:UpdateAsync("User_" .. player.UserId, function(old)
                    if type(old) ~= "table" or not old.Session or old.Session.Owner ~= s.owner then return nil end
                    old.Session = nil
                    return old
                end)
            end)
        end
        return
    end
    if s.persistReady then
        -- Merge awards earned while profile data was loading into the loaded snapshot.
        data.Coins = math.max(0, data.Coins + s.pendingCoins)
        data.XP = math.max(0,data.XP + s.pendingXP)
        data.KOs += s.pendingKOs
        data.Deaths += s.pendingDeaths
        for id in pairs(s.pendingUnlocks) do data.Unlocks[id] = true end
        if s.pendingEquipped then data.Equipped = s.pendingEquipped end
        s.data = data
    else
        warn("[FART-NIGHT] Data unavailable; paid purchases disabled and earned cosmetics are temporary:", player.Name)
        Notice:FireClient(player, "SAVE SERVICE OFFLINE: progress is temporary; Robux spending disabled.")
    end
    local function owns(passId)
        if passId == 0 then return false end
        local success, value = pcall(function() return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId) end)
        return success and value or false
    end
    s.VIP = owns(Config.Passes.VIP)
    s.DoubleCoins = owns(Config.Passes.DoubleCoins)
    for _,name in ipairs(Config.WeaponOrder) do
        local spec=Config.Weapons[name]
        if spec.PassKey then
            s.PremiumWeapons[name]=studioPreview or owns(Config.Passes[spec.PassKey])
            if s.PremiumWeapons[name] and player.Character then giveTool(player,name) end
        end
    end
    for _,crown in ipairs(Config.Crowns) do s.Crowns[crown.Id]=owns(crown.PassId) end
    if s.data.Equipped == "Prismatic" and not s.VIP then s.data.Equipped = "Mint" end
    stats(player, s)
    applyCosmetic(player)
    player:SetAttribute("FN_DataReady", s.persistReady)
end

-- Server-validated gunfire. Clients do not choose weapon/damage/ammo/hit targets.
local function handleShot(player, direction)
    local s = sessions[player]
    local char = player.Character
    if not s or not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local head = char:FindFirstChild("Head")
    if not hum or hum.Health <= 0 or not head then return end
    local tool = char:FindFirstChildOfClass("Tool")
    local name = weaponOfTool(tool)
    local w = name and Config.Weapons[name]
    if not w or not Combat.canUse(Config,s.PremiumWeapons,name) or typeof(direction) ~= "Vector3" then return end
    if direction.X ~= direction.X or direction.Y ~= direction.Y or direction.Z ~= direction.Z then return end
    -- Direction parameter is a world-space point selected by a client camera ray.
    -- It is NEVER treated as an authoritative hit: the server raycasts every pellet.
    if direction.Magnitude > 100000 or direction.Magnitude < 0.001 then return end
    local now = os.clock()
    if now - (s.lastFire[name] or -1000) < w.FireDelay * 0.93 then return end
    if s.reloading[name] or (s.ammo[name] or 0) <= 0 then return end
    s.lastFire[name] = now
    if not s.firstShotLogged then
        s.firstShotLogged=true
        print("[FART-NIGHT v5] Server accepted first shot for",player.Name,"with",name)
    end
    s.ammo[name] -= 1
    local ff = char:FindFirstChild("FN_SpawnShield")
    if ff then ff:Destroy() end
    local handle=tool:FindFirstChild("Handle")
    local tip=handle and handle:FindFirstChild("FN_Muzzle")
    local muzzle=tip and tip.WorldPosition or (head.Position + Vector3.new(0,.2,0))
    -- Distance/aim sanity check prevents degenerate inputs; raycasting remains server-authoritative.
    local aimVector=direction - muzzle
    if aimVector.Magnitude < 1.5 then return end
    local shotDirection=aimVector.Unit
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {char}
    params.IgnoreWater = true
    local aimFrame=CFrame.lookAt(muzzle,direction)
    local impacts={}
    local endPos = muzzle + shotDirection * w.Range
    local first = true
    local didHit, wasHeadshot = false, false
    for pellet = 1, w.Pellets do
        local dir = Combat.pelletDirection(shotDirection,aimFrame.RightVector,aimFrame.UpVector,pellet,w.Spread,rng)
        local ray = workspace:Raycast(muzzle, dir * w.Range, params)
        local impact = ray and ray.Position or (muzzle + dir * w.Range)
        table.insert(impacts,impact)
        if first then endPos = impact; first = false end
        if ray then
            local hitModel = ray.Instance:FindFirstAncestorOfClass("Model")
            local hitHum = hitModel and hitModel:FindFirstChildOfClass("Humanoid")
            if hitHum and hitHum.Health > 0 and hitHum ~= hum then
                local enemy = Players:GetPlayerFromCharacter(hitModel)
                if enemy then
                    if not hitModel:FindFirstChildOfClass("ForceField") then
                        hitHum:SetAttribute("FN_LastHit", player.UserId)
                        hitHum:SetAttribute("FN_LastHitAt", os.clock())
                        local isHead = ray.Instance.Name == "Head"
                        local shield = hitHum:GetAttribute("FN_Shield") or 0
                        local hpDamage,remainingShield=Combat.damage(w,isHead,shield)
                        if remainingShield~=shield then hitHum:SetAttribute("FN_Shield",remainingShield) end
                        if hpDamage > 0 then hitHum:TakeDamage(hpDamage) end
                        didHit = true
                        wasHeadshot = wasHeadshot or isHead
                    end
                elseif (hitModel:GetAttribute("FN_TargetDummy") or string.sub(hitModel.Name,1,15)=="PracticeTarget_") then
                    hitHum:TakeDamage(w.Damage)
                    if hitHum.Health <= 0 and not hitModel:GetAttribute("FN_Paid") then
                        hitModel:SetAttribute("FN_Paid", true)
                        grantCoins(player, Config.TargetCoins)
                        grantXP(player,12)
                        Notice:FireClient(player, "+5 coins | PRACTICE TARGET")
                    end
                end
            end
        end
    end
    if didHit then HitConfirm:FireClient(player,wasHeadshot) end
    FX:FireAllClients("Shot", muzzle, endPos, name, player.UserId, impacts)
    if tip then
        local emitter=tip:FindFirstChild("FN_Flash")
        if emitter then emitter:Emit(9) end
    end
    sync(player)
end

SelectWeapon.OnServerEvent:Connect(function(player, weaponName)
    if type(weaponName)~="string" or not Config.Weapons[weaponName] then return end
    local char=player.Character
    local hum=char and char:FindFirstChildOfClass("Humanoid")
    local s=sessions[player]
    if not s or not hum or hum.Health<=0 or not Combat.canUse(Config,s.PremiumWeapons,weaponName) then return end
    if os.clock()-(s.lastSelect or -10)<.15 then return end
    s.lastSelect=os.clock()
    local tool=giveTool(player,weaponName)
    if tool then hum:EquipTool(tool) end
    sync(player)
end)

Shoot.OnServerEvent:Connect(handleShot)
Reload.OnServerEvent:Connect(function(player)
    local s = sessions[player]
    local char = player.Character
    local tool = char and char:FindFirstChildOfClass("Tool")
    local name = weaponOfTool(tool)
    local w = name and Config.Weapons[name]
    if not s or not w or not Combat.canUse(Config,s.PremiumWeapons,name) or s.reloading[name] or s.ammo[name] == w.Magazine then return end
    s.reloading[name] = os.clock() + w.Reload
    sync(player)
    task.delay(w.Reload, function()
        if sessions[player] ~= s then return end
        if s.reloading[name] then
            s.ammo[name] = w.Magazine
            s.reloading[name] = nil
            sync(player)
        end
    end)
end)
RequestSync.OnServerEvent:Connect(function(player)
    local s = sessions[player]
    if not s or os.clock() - (s.lastSyncRequest or -10) < .25 then return end
    s.lastSyncRequest = os.clock()
    sync(player)
end)
Shop.OnServerEvent:Connect(function(player, action, cosmeticId)
    if action ~= "Buy" and action ~= "Equip" and action ~= "EquipCrown" then return end
    if type(cosmeticId) ~= "string" then return end
    local s = sessions[player]
    local cosmetic = byCosmetic[cosmeticId]
    if not s or s.closed then return end
    if os.clock() - (s.lastShopRequest or -10) < .3 then return end
    s.lastShopRequest = os.clock()
    if not s.persistReady or os.time() >= s.leaseUntil then
        Notice:FireClient(player, "Your progress is still connecting. Try the shop again shortly.")
        return
    end
    if action=="EquipCrown" then
        if not Economy.canEquipCrown(Config.Crowns,s.Crowns,cosmeticId) then return end
        s.data.EquippedCrown=cosmeticId
        applyCrown(player);sync(player)
        Notice:FireClient(player,cosmeticId=="None" and "Crown removed." or "Crown equipped!")
        return
    end
    if not cosmetic then return end
    if cosmetic.Id == "Prismatic" then
        if not s.VIP then return end
    elseif not s.data.Unlocks[cosmetic.Id] then
        if action ~= "Buy" or cosmetic.Cost < 0 then return end
        if not spendCoins(player, cosmetic.Cost) then
            Notice:FireClient(player, "Not enough coins! Earn coins in the arena.")
            return
        end
        s.data.Unlocks[cosmetic.Id] = true
        s.pendingUnlocks[cosmetic.Id] = true
    end
    s.data.Equipped = cosmetic.Id
    if not s.persistReady then s.pendingEquipped = cosmetic.Id end
    applyCosmetic(player)
    stats(player, s)
    Notice:FireClient(player, "Equipped " .. cosmetic.Name .. "!")
end)

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
    if not purchased or passId <= 0 then return end
    local purchasedCrown
    for _,crown in ipairs(Config.Crowns) do
        if crown.PassId>0 and crown.PassId==passId then purchasedCrown=crown;break end
    end
    local purchasedWeapon
    for _,name in ipairs(Config.WeaponOrder) do
        local spec=Config.Weapons[name]
        if spec.PassKey and Config.Passes[spec.PassKey]==passId then purchasedWeapon=name;break end
    end
    if passId ~= Config.Passes.VIP and passId ~= Config.Passes.DoubleCoins and not purchasedCrown and not purchasedWeapon then return end
    -- The server event is authoritative; confirm entitlement before applying perks.
    local ok, owned = pcall(function()
        return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
    end)
    local s = sessions[player]
    if not s or not ok or not owned then return end
    if passId == Config.Passes.VIP then s.VIP = true end
    if passId == Config.Passes.DoubleCoins then s.DoubleCoins = true end
    if purchasedCrown then
        s.Crowns[purchasedCrown.Id]=true
        s.data.EquippedCrown=purchasedCrown.Id
    end
    if purchasedWeapon then
        s.PremiumWeapons[purchasedWeapon]=true
        local tool=player.Character and giveTool(player,purchasedWeapon)
        local hum=player.Character and player.Character:FindFirstChildOfClass("Humanoid")
        if tool and hum and hum.Health>0 then hum:EquipTool(tool) end
    end
    applyCosmetic(player)
    sync(player)
    Notice:FireClient(player, "Pass unlocked! Your perks are ready.")
end)

-- A receipt and its award commit together, under the same player session lease.
-- Purchase prompt completion is never used to award developer products.
MarketplaceService.ProcessReceipt = function(receipt)
    local retry = Enum.ProductPurchaseDecision.NotProcessedYet
    local player = Players:GetPlayerByUserId(receipt.PlayerId)
    local s = player and sessions[player]
    if not store or not s or not s.persistReady or s.closed then return retry end
    local award = Economy.productAward(Config, receipt.ProductId)
    if not award or type(receipt.PurchaseId) ~= "string" or receipt.PurchaseId == "" then return retry end
    takeLock(s)
    if s.closed then releaseLock(s); return retry end
    local alreadyKnown = s.data.Receipts[receipt.PurchaseId] == true
    local ok, result = pcall(function()
        return store:UpdateAsync("User_" .. player.UserId, function(old)
            local d = normalized(old)
            if not d.Session or d.Session.Owner ~= s.owner then return nil end
            Economy.grantReceipt(d, receipt.PurchaseId, award)
            d.Session.Expires = os.time() + SESSION_SECONDS
            return d
        end)
    end)
    local committed = ok and result and result.Receipts[receipt.PurchaseId] == true
    if committed then
        if s.saveAttempt and result.LastSaveId==s.saveAttempt.Id then settleSave(s) end
        s.data.Receipts = result.Receipts
        -- Pending gameplay income/spending is not part of the receipt transaction.
        s.data.Coins = math.max(0, result.Coins + s.pendingCoins)
        s.leaseUntil = result.Session.Expires
    else
        warn("[FART-NIGHT] Receipt persistence deferred for", receipt.PurchaseId, result)
    end
    releaseLock(s)
    if not committed then return retry end
    stats(player, s)
    if not alreadyKnown then Notice:FireClient(player, "Coins delivered! +" .. award .. " coins") end
    return Enum.ProductPurchaseDecision.PurchaseGranted
end

-- Coins are continuous, not tied to matches. Physical pickups are server-owned.
for _, p in ipairs(Arena:GetDescendants()) do
    if p:IsA("BasePart") and p.Name == "FN_Coin" then
        local available = true
        p.Touched:Connect(function(hit)
            if not available then return end
            local char = hit:FindFirstAncestorOfClass("Model")
            local player = char and Players:GetPlayerFromCharacter(char)
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if not player or not hum or hum.Health <= 0 then return end
            if not sessions[player] then return end
            available = false
            p.Transparency = 1
            -- availability gate blocks duplicate pickups
            grantCoins(player, Config.CoinPickupValue)
            Notice:FireClient(player, "+" .. Config.CoinPickupValue * (sessions[player].DoubleCoins and 2 or 1) .. " coins")
            task.delay(Config.CoinRespawnSeconds, function()
                if p.Parent then p.Transparency = 0; available = true end
            end)
        end)
    end
end

-- Health and shield pickups add tactical roaming without resetting the match.
for _, p in ipairs(Arena:GetDescendants()) do
    if p:IsA("BasePart") and (p.Name == "FN_Health" or p.Name == "FN_Shield") then
        local available = true
        p.Touched:Connect(function(hit)
            if not available then return end
            local char = hit:FindFirstAncestorOfClass("Model")
            local player = char and Players:GetPlayerFromCharacter(char)
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if not player or not hum or hum.Health <= 0 then return end
            local isShield = p.Name == "FN_Shield"
            local current = isShield and (hum:GetAttribute("FN_Shield") or 0) or hum.Health
            local max = isShield and 100 or hum.MaxHealth
            if current >= max then return end
            if isShield then hum:SetAttribute("FN_Shield", math.min(100, current + 35))
            else hum.Health = math.min(hum.MaxHealth, current + 35) end
            available = false; p.Transparency = 1; -- availability gate blocks duplicate pickups
            Notice:FireClient(player, isShield and "+35 SHIELD" or "+35 HEALTH")
            task.delay(23, function()
                if p.Parent then p.Transparency = 0; available = true end
            end)
        end)
    end
end

-- A looping toxic cloud shrinks and resets, but NEVER ends the game or wipes KOs.
local oldRing = workspace:FindFirstChild("FN_StormVisual")
if oldRing then oldRing:Destroy() end
local ring = Instance.new("Folder")
ring.Name = "FN_StormVisual"
ring.Parent = workspace
local ringParts = {}
for i = 1, 48 do
    local p = Instance.new("Part")
    p.Name = "GasLine"
    p.Anchored = true; p.CanCollide = false; p.CanQuery = false
    p.Material = Enum.Material.Neon
    p.Color = Color3.fromRGB(188, 93, 255)
    p.Transparency = 0.25
    p.Parent = ring
    ringParts[i] = p
end
local stormStarted = os.clock()
task.spawn(function()
    while task.wait(1) do
        local period = Config.StormPeriod
        local elapsed = (os.clock() - stormStarted) % period
        local radius = Config.StormMaxRadius - (Config.StormMaxRadius-Config.StormMinRadius) * (elapsed / period)
        local center = Vector3.new(math.sin(os.clock() / 55)*Config.StormCenterWander, 6.6, math.cos(os.clock() / 49)*Config.StormCenterWander)
        for i, p in ipairs(ringParts) do
            local a = (i-1)*math.tau/#ringParts
            local b = i*math.tau/#ringParts
            local pa = center + Vector3.new(math.cos(a)*radius,0,math.sin(a)*radius)
            local pb = center + Vector3.new(math.cos(b)*radius,0,math.sin(b)*radius)
            p.Size = Vector3.new(1.1, 2.7, (pb-pa).Magnitude + 0.25)
            p.CFrame = CFrame.lookAt((pa+pb)/2, pb)
        end
        Storm:FireAllClients(math.floor(period-elapsed), math.floor(radius))
        for player, session in pairs(sessions) do
            local char = player.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            local root = char and char:FindFirstChild("HumanoidRootPart")
            if root and hum and hum.Health > 0 then
                if root.Position.Y < -30 then
                    hum.Health = 0
                elseif not char:FindFirstChildOfClass("ForceField") and
                    os.clock() >= (hum:GetAttribute("FN_ProtectedUntil") or 0) and
                    (Vector3.new(root.Position.X,center.Y,root.Position.Z)-center).Magnitude > radius then
                    hum:TakeDamage(5)
                end
            end
        end
    end
end)

Slide.OnServerEvent:Connect(function(player)
    local s=sessions[player]
    local char=player.Character
    local hum=char and char:FindFirstChildOfClass("Humanoid")
    local root=char and char:FindFirstChild("HumanoidRootPart")
    if not s or not hum or not root or hum.Health<=0 then return end
    local now=os.clock()
    if (now-(s.lastSlide or -100))<4 or s.stamina<17 then return end
    if hum.FloorMaterial==Enum.Material.Air or hum.MoveDirection.Magnitude<0.5 then return end
    s.lastSlide=now; s.stamina-=17
    local d=hum.MoveDirection.Unit
    root.AssemblyLinearVelocity=Vector3.new(d.X*58,math.max(2,root.AssemblyLinearVelocity.Y),d.Z*58)
    player:SetAttribute("FN_Stamina",math.floor(s.stamina))
end)
Sprint.OnServerEvent:Connect(function(player, enabled)
    local s = sessions[player]
    if not s or type(enabled) ~= "boolean" then return end
    s.sprintRequested = enabled
end)
task.spawn(function()
    while task.wait(0.2) do
        for player, s in pairs(sessions) do
            local char = player.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 then
                local running = s.sprintRequested and s.stamina > 1 and hum.MoveDirection.Magnitude > 0.1
                s.stamina = math.clamp(s.stamina + (running and -5 or 3.4),0,100)
                hum.WalkSpeed = running and 26 or 16
                player:SetAttribute("FN_Stamina", math.floor(s.stamina))
            end
        end
    end
end)

-- Practice targets instantly reset after a short cooldown, even in solo Studio play.
local function bindDummy(dummy)
    local h = dummy:FindFirstChildOfClass("Humanoid")
    if not h then return end
    local healthyTemplate = dummy:Clone()
    h.Died:Connect(function()
        dummy:SetAttribute("FN_Paid", true)
        task.delay(5, function()
            if not dummy.Parent then return end
            local newDummy = healthyTemplate:Clone()
            newDummy.Parent = dummy.Parent
            newDummy:SetAttribute("FN_Paid", false)
            dummy:Destroy()
            bindDummy(newDummy)
        end)
    end)
end
for _, dummy in ipairs(Arena:GetDescendants()) do
    if dummy:IsA("Model") and (dummy:GetAttribute("FN_TargetDummy") or string.sub(dummy.Name,1,15)=="PracticeTarget_") then
        bindDummy(dummy)
    end
end

Players.PlayerAdded:Connect(function(player) task.spawn(load, player) end)
Players.PlayerRemoving:Connect(function(player)
    for attempt=1,3 do
        if save(player, true) then break end
        if attempt<3 then task.wait(attempt) end
    end
    sessions[player] = nil
end)
for _, player in ipairs(Players:GetPlayers()) do task.spawn(load, player) end
task.spawn(function()
    while task.wait(45) do
        for player in pairs(sessions) do task.spawn(save, player) end
    end
end)
game:BindToClose(function()
    local pending = 0
    for player in pairs(sessions) do
        pending += 1
        task.spawn(function()
            save(player, true)
            pending -= 1
        end)
    end
    local deadline = os.clock() + 25
    while pending > 0 and os.clock() < deadline do task.wait(.1) end
end)
print("[FART-NIGHT v5] Endless FFA active | server-validated hits, headshots, sliding, collectible cosmetics.")
