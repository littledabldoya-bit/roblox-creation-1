#!/usr/bin/env python3
"""Execute the complete shipped server/client sources against deterministic services.

The XML scene supplies instance names/content dependencies. Roblox rendering,
physics/raycast geometry, audio delivery and live Commerce APIs are not emulated.
"""
from pathlib import Path
import json
import subprocess
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]

def literal(text):
    assert ']====]' not in text
    return '[====[' + text + ']====]'

def q(text):
    return json.dumps(text, ensure_ascii=False)

def scene_source():
    root = ET.parse(ROOT / 'fartnightv6.rbxlx').getroot()
    lines = ['local nodes={}']
    def walk(item, parent=None):
        idx = len(nodes) + 1
        nodes.append(item)
        props = item.find('Properties')
        name_node = props.find("string[@name='Name']")
        name = name_node.text if name_node is not None else item.get('class')
        cls = item.get('class')
        if parent is None:
            value = 'sim.workspace' if cls == 'Workspace' else f'sim.services[{q(cls)}]'
        else:
            value = f'sim:object({q(cls)},{q(name)},nodes[{parent}])'
        lines.append(f'nodes[{idx}]={value}')
        lines.append(f'nodes[{idx}].Name={q(name)}')
        for prop in props:
            key = prop.get('name')
            if key in {'Name', 'Source'}:
                continue
            value = None
            if prop.tag in {'float', 'double', 'int', 'int64'}:
                value = prop.text
            elif prop.tag == 'bool':
                value = prop.text
            elif prop.tag == 'string' and key == 'Value':
                value = q(prop.text or '')
            elif prop.tag == 'Vector3':
                value = 'sim.env.Vector3.new(' + ','.join(prop.findtext(axis, '0') for axis in 'XYZ') + ')'
            elif prop.tag == 'CoordinateFrame':
                # Scene positions only. Actual weapon/model rotations execute in the simulator.
                value = 'sim.env.CFrame.new(' + ','.join(prop.findtext(axis, '0') for axis in 'XYZ') + ')'
            if value:
                lines.append(f'nodes[{idx}][{q(key)}]={value}')
        for child in item.findall('Item'):
            walk(child, idx)
    nodes = []
    for item in root.findall('Item'):
        walk(item)
    return '\n'.join(lines)

config = (ROOT / 'src/ReplicatedStorage/FN_Config.luau').read_text()
server = (ROOT / 'src/ServerScriptService/FN_Server.luau').read_text()
client = (ROOT / 'src/StarterPlayerScripts/FN_Client.luau').read_text()
world = (ROOT / 'src/ServerScriptService/FN_WorldDetail.luau').read_text()
camera = (ROOT / 'src/StarterPlayerScripts/FN_ShoulderAim_v2.luau').read_text()
modules = '\n'.join(f'sim.modules[{q(name)}]=sim:run({literal((ROOT / f"src/ReplicatedStorage/{name}.luau").read_text())},{q(name)})'
                    for name in ['FN_Config', 'FN_Economy', 'FN_Combat'])
bootstrap = f'''
local Sim=require('./roblox_sim')
local sim=Sim.new()
{scene_source()}
{modules}
local config=sim.modules.FN_Config
assert(config.Version=='6.0.0' and not config.StudioPremiumPreview and config.Crowns==nil)
local player=sim:addPlayer('Owner',42)
local opponent=sim:addPlayer('Rival',43)
sim.owned[42]={{}}
for _,id in pairs(config.Passes) do sim.owned[42][id]=true end
for key,id in pairs(config.Passes) do sim.metadata[id]={{PriceInRobux=config.LaunchPrices[key],IsForSale=true,IconImageAssetId=id+100}} end
for key,id in pairs(config.Products) do sim.metadata[id]={{PriceInRobux=config.LaunchPrices[key],IsForSale=true,IconImageAssetId=id+100}} end
sim:run({literal(server)},'FN_Server')
sim:run({literal(world)},'FN_WorldDetail')
sim:run({literal(client)},'FN_Client')
sim:step(0)
sim:spawnCharacter(player);sim:spawnCharacter(opponent)
sim:run({literal(camera)},'FN_ShoulderAim_v2')
sim:step(2)
'''
tests = r'''
local passed=0
local function test(name,fn)
    local ok,err=pcall(fn);if not ok then error(name..': '..tostring(err)) end
    passed+=1;print('PASS '..name)
end
local gui=player.PlayerGui:WaitForChild('FartNightUI')
local armory=gui.Darken.ShopPanel
local remotes=sim.services.ReplicatedStorage.FN_Remotes
test('whole server and client start, hydrate profiles and initialize the first loadout',function()
    assert(player:GetAttribute('FN_DataReady'))
    assert(gui.Operator and gui.AmmoPanel and gui.Hotbar)
    assert(player.Character:FindFirstChildOfClass('Tool'))
    assert(#sim.errors==0,'Unexpected startup warning')
end)
test('all five detailed weapons exist; crown assets are removed from the running game',function()
    local bank=sim.services.ReplicatedStorage.FN_WeaponModels
    assert(#bank:GetChildren()==5)
    for _,name in ipairs(config.WeaponOrder) do
        local tool=bank:FindFirstChild(name);assert(tool and tool.Handle.FN_Muzzle)
        local parts=0
        for _,p in ipairs(tool:GetDescendants()) do if p:IsA('BasePart') then
            parts+=1;assert(not p.CanCollide and not p.CanQuery and p.Massless)
        end end
        assert(parts>=25,'Detailed geometry missing: '..name)
    end
    assert(not sim.services.ReplicatedStorage:FindFirstChild('FN_CrownModels'))
    assert(not player.Character:FindFirstChild('FN_WornCrown') and not player.Character.Head:FindFirstChild('FN_CrownBadge'))
end)
test('owned loadout includes five weapons while nonowners receive exactly three free guns',function()
    local function count(p)
        local n=0
        for _,container in ipairs({p.Backpack,p.Character}) do for _,o in ipairs(container:GetChildren()) do if o:IsA('Tool') then n+=1 end end end
        return n
    end
    assert(count(player)==5 and count(opponent)==3)
    remotes.SelectWeapon.OnServerEvent:Fire(opponent,'VoidReaper');sim:step(0)
    assert(not opponent.Backpack:FindFirstChild('VOID REAPER'))
    assert(opponent.Character:FindFirstChildOfClass('Tool'):GetAttribute('FNWeapon')=='BeanBlaster')
end)
test('all seven paid catalog items and all seven cloud cosmetics are present in the Armory',function()
    local names={'VOID REAPER','ION STRIKER','VIP OPERATOR','DOUBLE COINS','250 COINS','1,200 COINS','4,000 COINS'}
    for _,name in ipairs(names) do
        local card=armory.Offers:FindFirstChild(name)
        assert(card and card.ItemPreview and card.Robux)
        assert(card.Robux.Text~='COMING SOON' and card.Robux.Text~='UNAVAILABLE','Missing metadata: '..name)
    end
    for _,skin in ipairs(config.Cosmetics) do assert(armory.Offers:FindFirstChild(skin.Name)) end
end)
test('both premium weapon cards contain real 3D previews and crown shop tab is removed',function()
    for _,name in ipairs({'IonStriker','VoidReaper'}) do assert(armory.Offers:FindFirstChild(config.Weapons[name].Display).ItemPreview.ModelPreview) end
    assert(not armory.Tabs:FindFirstChild('Crowns'))
end)
test('coin purchase prompts use the correct developer product and cancel cleanly',function()
    local card=armory.Offers:FindFirstChild('250 COINS')
    card.Robux.Activated:Fire();sim:step(0)
    assert(sim.prompts[#sim.prompts].Id==config.Products.Coin250 and sim.prompts[#sim.prompts].Kind=='Product')
    sim.services.MarketplaceService.PromptProductPurchaseFinished:Fire(42,config.Products.Coin250,false);sim:step(0)
    assert(card.Robux.Active and card.Robux.Text=='R$ 19')
end)
test('all three real product IDs deliver exact coins and reject duplicate receipts',function()
    local expected=0
    for key,id in pairs(config.Products) do
        local receipt={PlayerId=42,ProductId=id,PurchaseId='integration-'..key}
        local result=sim.services.MarketplaceService.ProcessReceipt(receipt)
        assert(result==sim.Enum.ProductPurchaseDecision.PurchaseGranted)
        expected+=config.ProductAwards[key]
        assert(sim.store.User_42.Coins==expected)
        assert(sim.services.MarketplaceService.ProcessReceipt(receipt)==result and sim.store.User_42.Coins==expected)
    end
    sim:step(0)
    assert(armory.Balance.Text:find(tostring(expected),1,true))
end)
test('no crown passes, purchase offers, preview models or equip UI are exposed',function()
    assert(config.Crowns==nil)
    assert(not sim.services.ReplicatedStorage:FindFirstChild('FN_CrownModels'))
    assert(not player.Character:FindFirstChild('FN_WornCrown'))
    assert(not player.Character.Head:FindFirstChild('FN_CrownBadge'))
    assert(not armory.Tabs:FindFirstChild('Crowns'))
    assert(not armory.Offers:FindFirstChild('VANGUARD CROWN'))
    assert(not armory.Offers:FindFirstChild('SOVEREIGN CROWN'))
    assert(not armory.Offers:FindFirstChild('ECLIPSE CROWN'))
end)
test('desktop, phone and tablet shop dimensions fit their viewports',function()
    local camera=sim.workspace.CurrentCamera
    for _,size in ipairs({{360,780},{844,390},{768,1024},{1280,720}}) do
        camera.ViewportSize=sim.env.Vector2.new(size[1],size[2]);camera:GetPropertyChangedSignal('ViewportSize'):Fire();sim:step(0)
        assert(armory.Size.X.Offset<=size[1]-24 and armory.Size.Y.Offset<=size[2]-40)
        assert(armory.Tabs.ScrollingDirection==sim.Enum.ScrollingDirection.X)
    end
end)
test('music ID is assigned, playback is requested, and mute toggles independently',function()
    local sound=sim.services.SoundService.FN_ArenaMusic
    assert(sound.SoundId=='rbxassetid://86882641437260' and sound.IsPlaying)
    local button=armory.Offers:FindFirstChild('ARENA MUSIC').MusicToggle
    button.Activated:Fire();sim:step(0);assert(sound.Volume==0)
    button.Activated:Fire();sim:step(0);assert(sound.Volume>0)
    sound.IsLoaded=false;sim:step(21)
    assert(button.Active and button.Text=='RETRY MUSIC')
    button.Activated:Fire();sim:step(0)
    assert(button.Text=='LOADING' and sound.IsPlaying)
    sound.IsLoaded=true;sound.Loaded:Fire();sim:step(0)
    assert(button.Text=='ON' and sound.Volume>0)
end)
test('every weapon fires through the actual server handler and Burp Cannon casts eight aligned pellets',function()
    sim:step(7)
    for _,name in ipairs(config.WeaponOrder) do
        remotes.SelectWeapon.OnServerEvent:Fire(player,name);sim:step(.2)
        local before=#sim.rays
        remotes.Shoot.OnServerEvent:Fire(player,sim.env.Vector3.new(0,12,-200));sim:step(0)
        assert(#sim.rays-before==config.Weapons[name].Pellets,'Wrong ray count: '..name)
        sim:step(config.Weapons[name].FireDelay+.1)
    end
end)
test('reload finishes on the same character and an old reload cannot refill a respawned character',function()
    remotes.SelectWeapon.OnServerEvent:Fire(player,'BeanBlaster');sim:step(.2)
    remotes.Shoot.OnServerEvent:Fire(player,sim.env.Vector3.new(0,12,-200));sim:step(0)
    remotes.Reload.OnServerEvent:Fire(player);sim:step(0)
    sim:spawnCharacter(player);sim:step(.7)
    remotes.Shoot.OnServerEvent:Fire(player,sim.env.Vector3.new(0,12,-200));sim:step(0)
    local state
    remotes.Sync.OnClientEvent:Connect(function(value) state=value end)
    sim:step(config.Weapons.BeanBlaster.Reload+.1)
    remotes.RequestSync.OnServerEvent:Fire(player);sim:step(0)
    assert(state and state.Ammo.BeanBlaster==config.Weapons.BeanBlaster.Magazine-1,'Stale reload refilled new character')
    remotes.Reload.OnServerEvent:Fire(player);sim:step(config.Weapons.BeanBlaster.Reload+.1)
    assert(state.Ammo.BeanBlaster==config.Weapons.BeanBlaster.Magazine)
end)
test('premium hits respect spawn protection, pierce shields, and deliver the advertised damage',function()
    local hum=opponent.Character.Humanoid
    local target=opponent.Character.Head
    sim.rayResult={Instance=target,Position=target.Position}
    sim:object('ForceField','TestProtection',opponent.Character)
    remotes.SelectWeapon.OnServerEvent:Fire(player,'IonStriker');sim:step(.2)
    remotes.Shoot.OnServerEvent:Fire(player,sim.env.Vector3.new(0,12,-200));sim:step(0)
    assert(hum.Health==100)
    opponent.Character.TestProtection:Destroy();hum:SetAttribute('FN_Shield',100)
    sim:step(config.Weapons.IonStriker.FireDelay+.1)
    remotes.Shoot.OnServerEvent:Fire(player,sim.env.Vector3.new(0,12,-200));sim:step(0)
    assert(hum.Health==50 and hum:GetAttribute('FN_Shield')==100)
    sim:step(config.Weapons.IonStriker.FireDelay+.1)
    remotes.Shoot.OnServerEvent:Fire(player,sim.env.Vector3.new(0,12,-200));sim:step(0)
    assert(hum.Health==0)
    hum.Health=100
    remotes.SelectWeapon.OnServerEvent:Fire(player,'VoidReaper');sim:step(.2)
    remotes.Shoot.OnServerEvent:Fire(player,sim.env.Vector3.new(0,12,-200));sim:step(0)
    assert(hum.Health==0)
    sim.rayResult=nil
end)
test('a newly purchased premium gun pass delivers its weapon to a former nonowner',function()
    sim:spawnCharacter(opponent);sim:step(.7)
    sim.owned[43]={[config.Passes.IonStriker]=true}
    sim.services.MarketplaceService.PromptGamePassPurchaseFinished:Fire(opponent,config.Passes.IonStriker,true);sim:step(0)
    assert(opponent.Character:FindFirstChildOfClass('Tool'):GetAttribute('FNWeapon')=='IonStriker')
end)
print(tostring(passed)..' full-source integration simulations passed (not Roblox engine tests)')
'''
output = ROOT / 'tests/.integration.generated.luau'
try:
    output.write_text(bootstrap + tests)
    subprocess.run(['/workspace/roblox-tools/luau/build/luau', str(output)], cwd=ROOT, check=True)
finally:
    output.unlink(missing_ok=True)
