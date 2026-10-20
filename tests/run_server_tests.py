#!/usr/bin/env python3
"""Exercise the real server persistence/receipt functions with a simulated DataStore.

This is not a Roblox engine test. Only the persistence section is loaded; world
startup and engine services are replaced with explicit test doubles.
"""
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
server = (ROOT / 'src/ServerScriptService/FN_Server.luau').read_text()
prefix = server.split('-- Coins are continuous,')[0]
harness = r'''
local Economy=require('../src/ReplicatedStorage/FN_Economy')
local Combat=require('../src/ReplicatedStorage/FN_Combat')
local config={Cosmetics={{Id='Mint',Name='Mint',Cost=0}},WeaponOrder={},Products={Coin250=101},ProductAwards={Coin250=250},Passes={VIP=0,DoubleCoins=0},RespawnSeconds=3}
config.Passes.VoidReaper=301;config.Passes.IonStriker=302
config.Weapons={VoidReaper={PassKey='VoidReaper',Display='VOID REAPER'},IonStriker={PassKey='IonStriker',Display='ION STRIKER'}}
config.WeaponOrder={'VoidReaper','IonStriker'}
local record=nil
local fail=false
local loseResponse=false
local calls=0
local duringUpdate=nil
local store={}
function store:UpdateAsync(key,callback)
    calls+=1
    if fail then error('simulated DataStore outage') end
    if duringUpdate then local fn=duringUpdate;duringUpdate=nil;fn() end
    local proposed=callback(record)
    if proposed then record=proposed end
    if loseResponse then loseResponse=false;error("simulated lost response after commit") end
    return proposed
end
local player={UserId=42,Name='TestOperator',Parent=true,FindFirstChild=function() return nil end}
local passFinished
local ownsPass=false
local market={PromptGamePassPurchaseFinished={Connect=function(_,callback) passFinished=callback end},
    UserOwnsGamePassAsync=function() return ownsPass end}
local event={OnServerEvent={Connect=function() end},FireClient=function() end}
local remoteEvents={}
local remotes={WaitForChild=function(_,name)
    if not remoteEvents[name] then
        local signal={FireClient=function() end}
        signal.OnServerEvent={Connect=function(_,callback) signal.Callback=callback end}
        remoteEvents[name]=signal
    end
    return remoteEvents[name]
end}
local replicated={WaitForChild=function(_,name) if name=='FN_Remotes' then return remotes end return name end}
local services={Players={GetPlayerByUserId=function(_,id) return id==42 and player or nil end},
    ReplicatedStorage=replicated,DataStoreService={GetDataStore=function() return store end},MarketplaceService=market}
local game={GetService=function(_,name) return services[name] or {} end}
local workspace={WaitForChild=function() return {} end}
local Random={new=function() return {} end}
local Enum={ProductPurchaseDecision={NotProcessedYet='retry',PurchaseGranted='granted'}}
local warn=function() end
local task={wait=function() end}
local require=function(name) if name=='FN_Config' then return config elseif name=='FN_Economy' then return Economy elseif name=='FN_Combat' then return Combat end error(name) end
local api=(function()
'''+prefix+r'''
return {save=save,sessions=sessions}
end)()
local state
local function reset()
    record=Economy.normalize(nil,{Mint=true});record.Session={Owner='owner-A',Expires=os.time()+180}
    state={data=Economy.normalize(record,{Mint=true}),owner='owner-A',persistReady=true,leaseUntil=os.time()+180,
        PremiumWeapons={},pendingCoins=0,pendingXP=0,pendingKOs=0,pendingDeaths=0,pendingUnlocks={},ammo={},reloading={},busy=false,streak=0}
    api.sessions[player]=state;ownsPass=false;fail=false;loseResponse=false;calls=0;duringUpdate=nil
end
local passed=0
local function test(name,fn)
    reset();local ok,err=pcall(fn)
    if not ok then error(name..': '..tostring(err)) end
    passed+=1;print('PASS '..name)
end
local receipt={PlayerId=42,ProductId=101,PurchaseId='receipt-1'}
test('receipt commits before acknowledging, duplicate delivery stays idempotent',function()
    assert(market.ProcessReceipt(receipt)=='granted' and record.Coins==250 and state.data.Coins==250)
    assert(record.Receipts['receipt-1'])
    assert(market.ProcessReceipt(receipt)=='granted' and record.Coins==250 and state.data.Coins==250)
end)
test('DataStore failure does not acknowledge or locally award a purchase',function()
    fail=true;assert(market.ProcessReceipt(receipt)=='retry')
    assert(record.Coins==0 and state.data.Coins==0 and not state.busy)
    fail=false;assert(market.ProcessReceipt(receipt)=='granted' and record.Coins==250)
end)
test('another session cannot fulfill a receipt or overwrite progress',function()
    record.Session.Owner='owner-B'
    assert(market.ProcessReceipt(receipt)=='retry' and record.Coins==0)
    state.pendingCoins=10
    assert(not api.save(player) and record.Coins==0 and state.pendingCoins==10)
end)
test('unloaded players and unknown products wait without writing',function()
    state.persistReady=false;assert(market.ProcessReceipt(receipt)=='retry' and calls==0)
    state.persistReady=true
    assert(market.ProcessReceipt({PlayerId=42,ProductId=999,PurchaseId='x'})=='retry' and calls==0)
end)
test('coin packs are not multiplied by double-coins pass',function()
    state.DoubleCoins=true
    assert(market.ProcessReceipt(receipt)=='granted' and record.Coins==250)
end)
test('receipts preserve unsaved gameplay income without persisting it twice',function()
    state.pendingCoins=25;state.data.Coins=25
    assert(market.ProcessReceipt(receipt)=='granted' and record.Coins==250 and state.data.Coins==275)
    assert(api.save(player) and record.Coins==275 and state.pendingCoins==0)
    assert(market.ProcessReceipt(receipt)=='granted' and record.Coins==275 and state.data.Coins==275)
end)
test('failed save retains pending income for the next attempt',function()
    state.pendingCoins=25;state.data.Coins=25;fail=true
    assert(not api.save(player) and state.pendingCoins==25 and record.Coins==0 and not state.busy)
    fail=false;assert(api.save(player) and record.Coins==25 and state.pendingCoins==0)
end)
test('income arriving during a save remains pending for the next save',function()
    state.pendingCoins=25;state.data.Coins=25
    duringUpdate=function() state.pendingCoins+=5;state.data.Coins+=5 end
    assert(api.save(player) and record.Coins==25 and state.pendingCoins==5 and state.data.Coins==30)
    assert(api.save(player) and record.Coins==30 and state.pendingCoins==0)
end)
test('lost save response never applies the same coin delta twice',function()
    state.pendingCoins=25;state.data.Coins=25;loseResponse=true
    assert(not api.save(player) and record.Coins==25 and state.pendingCoins==25)
    assert(api.save(player) and record.Coins==25 and state.pendingCoins==0 and state.data.Coins==25)
end)
test('lost closing response can finish without reacquiring or duplicating a save',function()
    state.pendingCoins=25;state.data.Coins=25;loseResponse=true
    assert(not api.save(player,true) and record.Coins==25 and not record.Session)
    assert(api.save(player,true) and record.Coins==25 and state.closed)
end)
test('lost receipt response is safely retried after durable commit',function()
    loseResponse=true
    assert(market.ProcessReceipt(receipt)=='retry' and record.Coins==250 and state.data.Coins==0)
    assert(market.ProcessReceipt(receipt)=='granted' and record.Coins==250 and state.data.Coins==250)
end)
test('a receipt reconciles an uncertain autosave without inflating spendable balance',function()
    state.pendingCoins=25;state.data.Coins=25;loseResponse=true
    assert(not api.save(player) and record.Coins==25)
    assert(market.ProcessReceipt(receipt)=='granted' and record.Coins==275 and state.data.Coins==275 and state.pendingCoins==0)
end)
test('departure settles an uncertain autosave and flushes newer income',function()
    state.pendingCoins=25;state.data.Coins=25;loseResponse=true
    assert(not api.save(player) and record.Coins==25)
    state.pendingCoins+=5;state.data.Coins+=5
    assert(api.save(player,true) and record.Coins==30 and state.pendingCoins==0 and not record.Session)
end)
test('closing saves release the session and cannot save twice'  ,function()
    state.pendingCoins=10;state.data.Coins=10
    assert(api.save(player,true) and not record.Session and state.closed and record.Coins==10)
    local before=calls;assert(api.save(player,true) and calls==before)
end)
test('removed crown pass IDs grant no game item',function()
    ownsPass=true;passFinished(player,201,true)
    assert(not state.PremiumWeapons.VoidReaper and not state.PremiumWeapons.IonStriker)
    assert(state.data.EquippedCrown==nil and state.Crowns==nil)
end)
test('premium gun passes require server confirmation before unlocking',function()
    passFinished(player,301,false);assert(not state.PremiumWeapons.VoidReaper)
    passFinished(player,301,true);assert(not state.PremiumWeapons.VoidReaper)
    ownsPass=true;passFinished(player,301,true)
    assert(state.PremiumWeapons.VoidReaper and not state.PremiumWeapons.IonStriker)
    passFinished(player,302,true);assert(state.PremiumWeapons.IonStriker)
end)
print(tostring(passed)..' server persistence tests passed (simulated services)')
'''
output = ROOT / 'tests/.server.generated.luau'
try:
    output.write_text(harness)
    subprocess.run(['/workspace/roblox-tools/luau/build/luau', str(output)], cwd=ROOT, check=True)
finally:
    output.unlink(missing_ok=True)
