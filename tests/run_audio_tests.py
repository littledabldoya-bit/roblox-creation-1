#!/usr/bin/env python3
"""Run the real client effect/footstep functions with simulated Roblox services.

Checks event logic and cleanup, not actual engine playback or sound quality.
"""
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
client = (ROOT / 'src/StarterPlayerScripts/FN_Client.luau').read_text()
audio = client.split('-- Engine-bundled effects work')[1].split('-- Competitive arena visual system:')[0]
audio = '-- Engine-bundled effects work' + audio
config = (ROOT / 'src/ReplicatedStorage/FN_Config.luau').read_text()
prefix = r'''
local Color3={fromRGB=function(...) return {...} end}
local Config=(function()
''' + config + r'''
end)()
local function signal()
    local callbacks={}
    return {Connect=function(_,fn)
        local entry={fn=fn,active=true};table.insert(callbacks,entry)
        return {Disconnect=function() entry.active=false end}
    end,Fire=function(_,...)
        for _,entry in ipairs(callbacks) do if entry.active then entry.fn(...) end end
    end}
end
local Vector3={}
local mt={}
mt.__index=function(v,key) if key=='Magnitude' then return math.sqrt(v.X*v.X+v.Y*v.Y+v.Z*v.Z) end end
mt.__sub=function(a,b) return Vector3.new(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
function Vector3.new(x,y,z) return setmetatable({X=x,Y=y,Z=z},mt) end
local function typeof(v) return getmetatable(v)==mt and 'Vector3' or type(v) end
local objects={}
local Instance={new=function(class)
    local o={ClassName=class,Destroying=signal(),Ended=signal(),Parent=nil,IsPlaying=false,Volume=0}
    function o:IsA(name) return self.ClassName==name end
    function o:Play() self.IsPlaying=true;self.PlayCount=(self.PlayCount or 0)+1 end
    function o:Stop() self.IsPlaying=false end
    function o:Destroy() self.Destroying:Fire();self.Parent=nil;self.IsPlaying=false end
    function o:GetPropertyChangedSignal() return signal() end
    table.insert(objects,o);return o
end}
local SoundService={}
local game={GetService=function() return SoundService end}
local workspace={CurrentCamera={CFrame={Position=Vector3.new(0,0,0)}}}
local Enum={RollOffMode={InverseTapered='distance'},Material={Air='air',Concrete='ground'}}
local gui={Destroying=signal()}
local Debris={AddItem=function() end}
local RunService={Heartbeat=signal()}
local Players={PlayerAdded=signal(),PlayerRemoving=signal(),GetPlayers=function() return {} end}
local task={spawn=function(fn,...) fn(...) end}
local api=(function()
''' + audio + r'''
return {shot=shotSound,character=characterAudio,stop=stopFootsteps,states=footsteps}
end)()
local passed=0
local function test(name,fn)
    local ok,err=pcall(fn);if not ok then error(name..': '..tostring(err)) end
    passed+=1;print('PASS '..name)
end
local function sounds()
    local result={}
    for _,o in ipairs(objects) do if o.ClassName=='Sound' and o.Parent then table.insert(result,o) end end
    return result
end
local function clearShots()
    for _,o in ipairs(objects) do if o.Name=='FN_ShotAudio' and o.Parent then o:Destroy() end end
end
test('each weapon emits an immediate effect with distinct playback pitch',function()
    local pitches={}
    for name in pairs(Config.Audio.Weapons) do
        local before=#sounds();api.shot(name,Vector3.new(0,0,0))
        local current=sounds();assert(#current==before+1 and current[#current].IsPlaying)
        pitches[current[#current].PlaybackSpeed]=true
    end
    local count=0;for _ in pairs(pitches) do count+=1 end;assert(count==3)
    clearShots()
end)
test('distant or unknown shots are culled',function()
    local before=#objects
    api.shot('BeanBlaster',Vector3.new(1000,0,0));api.shot('Fake',Vector3.new(0,0,0))
    assert(#objects==before)
end)
test('effect voices are capped and cleanup returns voice capacity',function()
    for _=1,30 do api.shot('BeanBlaster',Vector3.new(0,0,0)) end
    local active=0
    for _,o in ipairs(objects) do if o.Name=='FN_ShotAudio' and o.Parent then active+=1 end end
    assert(active==24)
    clearShots();local before=#objects
    api.shot('BeanBlaster',Vector3.new(0,0,0));assert(#objects>before)
    clearShots()
end)
local humanoid={Health=100,Sit=false,FloorMaterial='ground'}
local root={Parent=true,Position=Vector3.new(0,0,0),AssemblyLinearVelocity=Vector3.new(16,0,0)}
local original=Instance.new('Sound');original.Name='Running';original.Volume=.65;original.Parent=root
local character={Parent=true,DescendantAdded=signal(),AncestryChanged=signal(),
    WaitForChild=function(_,name) return name=='Humanoid' and humanoid or root end,
    GetDescendants=function() return {original} end}
test('walking starts footsteps and stationary or airborne movement stops them',function()
    api.character(character);local s=api.states[character].Sound
    assert(original.Volume==0)
    RunService.Heartbeat:Fire();assert(s.IsPlaying)
    local walking=s.PlaybackSpeed
    root.AssemblyLinearVelocity=Vector3.new(24,0,0);RunService.Heartbeat:Fire()
    assert(s.IsPlaying and s.PlaybackSpeed>walking)
    humanoid.FloorMaterial='air';RunService.Heartbeat:Fire();assert(not s.IsPlaying)
    humanoid.FloorMaterial='ground';root.AssemblyLinearVelocity=Vector3.new(0,0,0)
    RunService.Heartbeat:Fire();assert(not s.IsPlaying)
end)
test('respawn cleanup removes the custom loop and restores default volume',function()
    api.stop(character);assert(not api.states[character] and original.Volume==.65)
    api.character(character);assert(api.states[character])
    gui.Destroying:Fire();assert(not api.states[character] and original.Volume==.65)
end)
print(tostring(passed)..' audio logic tests passed (simulated services)')
'''
output = ROOT / 'tests/.audio.generated.luau'
try:
    output.write_text(prefix)
    subprocess.run(['/workspace/roblox-tools/luau/build/luau', str(output)], cwd=ROOT, check=True)
finally:
    output.unlink(missing_ok=True)
