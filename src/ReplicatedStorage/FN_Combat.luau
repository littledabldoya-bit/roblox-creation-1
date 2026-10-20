-- Shared combat rules; damage and ownership are enforced exclusively by the server.
local Combat={}

function Combat.canUse(config,owned,name)
    local weapon=config.Weapons[name]
    return weapon~=nil and (not weapon.PassKey or (owned and owned[name]==true))
end

function Combat.damage(weapon,headshot,shield)
    local amount=math.floor(weapon.Damage*(headshot and (weapon.HeadMultiplier or 1.4) or 1))
    local absorbed=weapon.ShieldPiercing and 0 or math.min(math.max(0,shield),amount)
    return amount-absorbed,shield-absorbed
end

function Combat.pelletDirection(forward,right,up,pellet,spread,random)
    -- The visible primary tracer must use the exact crosshair ray, never a random pellet.
    if pellet==1 or spread==0 then return forward end
    local radius=math.sqrt(random:NextNumber())*spread
    local angle=random:NextNumber(0,math.pi*2)
    return (forward+right*(math.cos(angle)*radius)+up*(math.sin(angle)*radius)).Unit
end

return Combat
