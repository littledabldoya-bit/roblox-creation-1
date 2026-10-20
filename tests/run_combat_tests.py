#!/usr/bin/env python3
"""Test actual configured combat rules, including the shotgun's center ray."""
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
config = (ROOT / 'src/ReplicatedStorage/FN_Config.luau').read_text()
harness = r'''
local Combat=require('../src/ReplicatedStorage/FN_Combat')
local Color3={fromRGB=function(...) return {...} end}
local config=(function()
''' + config + r'''
end)()
local V={};local mt={}
mt.__index=function(v,key)
    if key=='Magnitude' then return math.sqrt(v.x*v.x+v.y*v.y+v.z*v.z) end
    if key=='Unit' then local m=math.sqrt(v.x*v.x+v.y*v.y+v.z*v.z);return V.new(v.x/m,v.y/m,v.z/m) end
end
mt.__add=function(a,b) return V.new(a.x+b.x,a.y+b.y,a.z+b.z) end
mt.__mul=function(a,b) return V.new(a.x*b,a.y*b,a.z*b) end
function V.new(x,y,z) return setmetatable({x=x,y=y,z=z},mt) end
local forward,right,up=V.new(0,0,-1),V.new(1,0,0),V.new(0,1,0)
local passed=0
local function test(name,fn)
    local ok,err=pcall(fn);if not ok then error(name..': '..tostring(err)) end
    passed+=1;print('PASS '..name)
end
test('Burp Cannon primary pellet follows the crosshair exactly with no random bias',function()
    local random={NextNumber=function() error('Primary pellet must not use randomness') end}
    local result=Combat.pelletDirection(forward,right,up,1,config.Weapons.BurpCannon.Spread,random)
    assert(result==forward)
end)
test('secondary shotgun pellets stay normalized inside the configured cone',function()
    local seed=17
    local random={NextNumber=function(_,a,b)
        seed=(seed*48271)%2147483647
        local n=seed/2147483647
        return a and a+(b-a)*n or n
    end}
    for _=1,100 do
        local d=Combat.pelletDirection(forward,right,up,2,config.Weapons.BurpCannon.Spread,random)
        assert(math.abs(d.Magnitude-1)<.00001 and d.z<0)
        assert(math.sqrt(d.x*d.x+d.y*d.y)/(-d.z)<=config.Weapons.BurpCannon.Spread+.00001)
    end
end)
test('premium weapons cannot be used without server-confirmed ownership',function()
    assert(not Combat.canUse(config,{},'VoidReaper'))
    assert(not Combat.canUse(config,{},'IonStriker'))
    assert(not Combat.canUse(config,{VoidReaper=true},'IonStriker'))
    assert(Combat.canUse(config,{VoidReaper=true},'VoidReaper'))
    assert(Combat.canUse(config,{IonStriker=true},'IonStriker'))
    assert(not Combat.canUse(config,{},'Fake'))
end)
test('starter weapons remain available without paid ownership',function()
    for _,name in ipairs({'BeanBlaster','BurpCannon','ToxicTagger'}) do assert(Combat.canUse(config,{},name)) end
end)
test('Void Reaper delivers one 100-HP hit through full shields',function()
    for _,headshot in ipairs({false,true}) do
        local hp,shield=Combat.damage(config.Weapons.VoidReaper,headshot,100)
        assert(hp==100 and shield==100)
    end
end)
test('Ion Striker requires two hits against 100 HP, including headshots and shields',function()
    for _,headshot in ipairs({false,true}) do
        local hp,shield=Combat.damage(config.Weapons.IonStriker,headshot,100)
        assert(hp==50 and hp<100 and hp*2==100 and shield==100)
    end
end)
test('starter weapon shield absorption still precedes health damage',function()
    local hp,shield=Combat.damage(config.Weapons.BeanBlaster,false,10)
    assert(hp==2 and shield==0)
    hp,shield=Combat.damage(config.Weapons.BeanBlaster,false,100)
    assert(hp==0 and shield==88)
end)
print(tostring(passed)..' combat tests passed')
'''
output = ROOT / 'tests/.combat.generated.luau'
try:
    output.write_text(harness)
    subprocess.run(['/workspace/roblox-tools/luau/build/luau', str(output)], cwd=ROOT, check=True)
finally:
    output.unlink(missing_ok=True)
