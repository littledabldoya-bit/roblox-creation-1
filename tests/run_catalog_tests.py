#!/usr/bin/env python3
"""Validate the actual launch catalog with the Luau runtime (Color3 test double)."""
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
source = (ROOT / 'src/ReplicatedStorage/FN_Config.luau').read_text()
harness = 'local Color3={fromRGB=function(...) return {...} end}\nlocal config=(function()\n' + source + '\nend)()\n' + r'''
assert(config.Version=='6.0.0' and config.StudioPremiumPreview==false)
local expected={VIP={2040029198,149},DoubleCoins={2036219448,99},IonStriker={2040425005,249},VoidReaper={2037023377,499},Vanguard={2040730906,499},Sovereign={2041832815,799},Eclipse={2037179505,999},Coin250={3720387393,19},Coin1200={3720387708,79},Coin4000={3720387802,189}}
for key,entry in pairs(expected) do
    local id=config.Passes[key] or config.Products[key]
    for _,crown in ipairs(config.Crowns) do if crown.Id==key then id=crown.PassId end end
    assert(id==entry[1] and config.LaunchPrices[key]==entry[2], 'Creator Hub catalog mismatch: '..key)
end
assert(config.ProductAwards.Coin250==250 and config.ProductAwards.Coin1200==1200 and config.ProductAwards.Coin4000==4000)
local count=0
local passIds={}
local function price(key)
    local value=config.LaunchPrices[key]
    assert(type(value)=='number' and value>0 and value%1==0,'Missing/invalid launch price: '..key)
    count+=1
end
local function pass(id)
    assert(type(id)=='number' and id>0 and id%1==0,'Invalid game pass ID')
    if id>0 then assert(not passIds[id],'A pass ID cannot grant two different items');passIds[id]=true end
end
for key,id in pairs(config.Passes) do price(key);pass(id) end
for _,crown in ipairs(config.Crowns) do price(crown.Id);pass(crown.PassId) end
for key,id in pairs(config.Products) do
    price(key)
    assert(type(id)=='number' and id>0 and id%1==0,'Invalid product ID')
    assert(config.ProductAwards[key]>0,'Missing product delivery quantity')
end
assert(count==10,'Expected prices for four passes, three crowns, and three coin packs')
print('PASS every monetized item has a valid launch price and catalog entry')
local small=config.LaunchPrices.Coin250/config.ProductAwards.Coin250
local medium=config.LaunchPrices.Coin1200/config.ProductAwards.Coin1200
local large=config.LaunchPrices.Coin4000/config.ProductAwards.Coin4000
assert(small>medium and medium>large,'Bulk coin packs must give a better per-coin price')
print('PASS bulk packs offer progressively better value per coin')
assert(config.LaunchPrices.Vanguard<config.LaunchPrices.Sovereign and config.LaunchPrices.Sovereign<config.LaunchPrices.Eclipse)
print('PASS crown prices follow the entry/middle/premium tiers')
assert(type(config.Music.SoundId)=='number' and config.Music.SoundId>=0 and config.Music.SoundId%1==0)
assert(config.Music.Volume>0 and config.Music.Volume<=.5)
print('PASS music has a configurable asset ID and bounded background volume')
'''
output = ROOT / 'tests/.catalog.generated.luau'
try:
    output.write_text(harness)
    subprocess.run(['/workspace/roblox-tools/luau/build/luau', str(output)], cwd=ROOT, check=True)
finally:
    output.unlink(missing_ok=True)
