-- Deterministic service/model simulator for source-level integration checks.
-- It is NOT Roblox: it does not render, play audio, simulate physics or make purchases.
local Sim={}
local function copy(value)
    if type(value)~="table" or getmetatable(value) then return value end
    local result={};for k,v in pairs(value) do result[k]=copy(v) end;return result
end
local function vector(dim,...)
    local values={...};local v={X=values[1] or 0,Y=values[2] or 0,Z=dim==3 and (values[3] or 0) or nil}
    local mt={__type="Vector"..dim}
    mt.__index=function(self,key)
        if key=="Magnitude" then return math.sqrt(self.X^2+self.Y^2+(self.Z or 0)^2) end
        if key=="Unit" then return self/self.Magnitude end
        if key=="Dot" then return function(a,b) return a.X*b.X+a.Y*b.Y+(a.Z or 0)*(b.Z or 0) end end
        if key=="Cross" then return function(a,b) return vector(3,a.Y*b.Z-a.Z*b.Y,a.Z*b.X-a.X*b.Z,a.X*b.Y-a.Y*b.X) end end
        if key=="Lerp" then return function(a,b,t) return a+(b-a)*t end end
    end
    mt.__add=function(a,b) return vector(dim,a.X+b.X,a.Y+b.Y,(a.Z or 0)+(b.Z or 0)) end
    mt.__sub=function(a,b) return vector(dim,a.X-b.X,a.Y-b.Y,(a.Z or 0)-(b.Z or 0)) end
    mt.__unm=function(a) return a*-1 end
    mt.__mul=function(a,b) if type(a)=="number" then a,b=b,a end;return vector(dim,a.X*b,a.Y*b,(a.Z or 0)*b) end
    mt.__div=function(a,b) return a*(1/b) end
    return setmetatable(v,mt)
end
local V3={new=function(...) return vector(3,...) end}
V3.zero=V3.new();local V2={new=function(...) return vector(2,...) end};V2.zero=V2.new()
local CF={};local cfmt={__type="CFrame"}
local function cf(p,r) return setmetatable({p=p,r=r or {1,0,0,0,1,0,0,0,1}},cfmt) end
local function rotate(r,v) return V3.new(r[1]*v.X+r[2]*v.Y+r[3]*v.Z,r[4]*v.X+r[5]*v.Y+r[6]*v.Z,r[7]*v.X+r[8]*v.Y+r[9]*v.Z) end
function CF.new(x,y,z) return cf(type(x)=="table" and x or V3.new(x,y,z)) end
function CF.Angles(x,y,z)
    local cx,sx,cy,sy,cz,sz=math.cos(x),math.sin(x),math.cos(y),math.sin(y),math.cos(z),math.sin(z)
    return cf(V3.zero,{cy*cz,-cy*sz,sy,cx*sz+sx*sy*cz,cx*cz-sx*sy*sz,-sx*cy,sx*sz-cx*sy*cz,sx*cz+cx*sy*sz,cx*cy})
end
function CF.lookAt(p,target)
    local forward=(target-p).Unit;local right=forward:Cross(V3.new(0,1,0)).Unit;local up=right:Cross(forward)
    return cf(p,{right.X,up.X,-forward.X,right.Y,up.Y,-forward.Y,right.Z,up.Z,-forward.Z})
end
cfmt.__mul=function(a,b)
    if getmetatable(b)~=cfmt then return a.p+rotate(a.r,b) end
    local r={};for i=0,2 do for j=0,2 do r[i*3+j+1]=0;for k=0,2 do r[i*3+j+1]+=a.r[i*3+k+1]*b.r[k*3+j+1] end end end
    return cf(a.p+rotate(a.r,b.p),r)
end
cfmt.__index=function(a,key)
    if key=="Position" then return a.p end
    if key=="LookVector" then return V3.new(-a.r[3],-a.r[6],-a.r[9]) end
    if key=="RightVector" then return V3.new(a.r[1],a.r[4],a.r[7]) end
    if key=="UpVector" then return V3.new(a.r[2],a.r[5],a.r[8]) end
    if key=="Inverse" then return function(self) local r={self.r[1],self.r[4],self.r[7],self.r[2],self.r[5],self.r[8],self.r[3],self.r[6],self.r[9]};return cf(-rotate(r,self.p),r) end end
    if key=="PointToObjectSpace" then return function(self,v) return self:Inverse()*v end end
    if key=="VectorToWorldSpace" then return function(self,v) return rotate(self.r,v) end end
    if key=="Lerp" then return function(self,b,t) return cf(self.p:Lerp(b.p,t),self.r) end end
end
local function udim(s,o) return {Scale=s or 0,Offset=o or 0} end
local function udim2(xs,xo,ys,yo) return {X=udim(xs,xo),Y=udim(ys,yo)} end
local Color3={new=function(r,g,b) return {R=r,G=g,B=b} end,fromRGB=function(r,g,b) return {R=r/255,G=g/255,B=b/255} end}

function Sim.new()
    local self=setmetatable({now=0,queue={},objects={},errors={},prompts={},remotes={},metadata={},owned={},store={},rays={},rayResult=nil},{__index=Sim})
    function self:schedule(delay,fn,...)
        table.insert(self.queue,{at=self.now+delay,co=coroutine.create(fn),args={...}})
    end
    function self:step(seconds)
        local target=self.now+seconds;local steps=0
        while true do
            table.sort(self.queue,function(a,b) return a.at<b.at end)
            local item=self.queue[1];if not item or item.at>target then break end
            table.remove(self.queue,1);self.now=item.at;steps+=1;assert(steps<20000,"Simulation scheduling runaway")
            local ok,delay=coroutine.resume(item.co,table.unpack(item.args));item.args={}
            if not ok then error(delay) end
            if coroutine.status(item.co)~="dead" then item.at=self.now+(delay or .03);table.insert(self.queue,item) end
        end
        self.now=target
    end
    function self:signal()
        local listeners={};local signal={}
        function signal:Connect(fn) local entry={fn=fn,on=true};table.insert(listeners,entry);return {Disconnect=function() entry.on=false end} end
        function signal:Once(fn) local connection;connection=self:Connect(function(...) connection:Disconnect();fn(...) end);return connection end
        function signal:Fire(...) for _,entry in ipairs(listeners) do if entry.on then self._sim:schedule(0,entry.fn,...) end end end
        signal._sim=self;return signal
    end
    local enumValues={Air=0,Neon=288,SmoothPlastic=272,Metal=1088,Camera=200}
    self.Enum=setmetatable({},{__index=function(t,category)
        local e=setmetatable({},{__index=function(c,key) local value={Name=key,Value=enumValues[key] or 1};rawset(c,key,value);return value end})
        rawset(t,category,e);return e
    end})
    local baseParts={Part=true,WedgePart=true,MeshPart=true,SpawnLocation=true}
    local guiClasses={Frame=true,TextLabel=true,TextButton=true,ImageLabel=true,ImageButton=true,ScrollingFrame=true,ViewportFrame=true}
    local methods={}
    function self:object(class,name,parent)
        local obj={_props={ClassName=class,Name=name or class,Visible=true,Active=true,Volume=.5,Health=100,MaxHealth=100,WalkSpeed=16,Text="",Transparency=0,Value=0,
            CFrame=CF.new(),Position=V3.zero,Size=baseParts[class] and V3.new(2,1,1) or udim2(0,100,0,100),AbsoluteSize=V2.new(300,100),AbsolutePosition=V2.zero,
            AssemblyLinearVelocity=V3.zero,MoveDirection=V3.zero,FloorMaterial=self.Enum.Material.SmoothPlastic,CanvasPosition=V2.zero,
            IsPlaying=false,IsLoaded=true,ViewportSize=V2.new(1280,720),FieldOfView=73},_children={},_attrs={},_signals={},_sim=self}
        setmetatable(obj,{
            __index=function(o,k)
                if methods[k] then return methods[k] end
                if k=="WorldPosition" and o.ClassName=="Attachment" then return o.Parent.CFrame*o.Position end
                if o._props[k]~=nil then return o._props[k] end
                for _,child in ipairs(o._children) do if child.Name==k then return child end end
                if k:match("^On") or ({Activated=true,MouseEnter=true,MouseLeave=true,MouseButton1Down=true,MouseButton1Up=true,MouseButton1Click=true,Destroying=true,DescendantAdded=true,ChildAdded=true,CharacterAdded=true,CharacterRemoving=true,AncestryChanged=true,Equipped=true,Unequipped=true,Deactivated=true,Touched=true,Died=true,Ended=true,Loaded=true,InputBegan=true,InputEnded=true,WindowFocusReleased=true,Heartbeat=true,RenderStepped=true,PlayerAdded=true,PlayerRemoving=true,PromptGamePassPurchaseFinished=true,PromptProductPurchaseFinished=true})[k] then
                    if not o._signals[k] then o._signals[k]=self:signal() end;return o._signals[k]
                end
                return nil
            end,
            __newindex=function(o,k,value)
                local old=o._props[k]
                if k=="Parent" then
                    if old then local i=table.find(old._children,o);if i then table.remove(old._children,i) end end
                    o._props.Parent=value
                    if value then
                        table.insert(value._children,o);value.ChildAdded:Fire(o)
                        local ancestor=value;while ancestor do ancestor.DescendantAdded:Fire(o);ancestor=ancestor.Parent end
                    end
                    o.AncestryChanged:Fire(o,value)
                else o._props[k]=value end
                if k=="CFrame" then o._props.Position=value.Position end
                if k=="Position" and baseParts[o.ClassName] then o._props.CFrame=CF.new(value) end
                if old~=value and o._signals[k] then o._signals[k]:Fire() end
            end})
        table.insert(self.objects,obj);if parent then obj.Parent=parent end;return obj
    end
    function methods:IsA(class) return self.ClassName==class or class=="BasePart" and baseParts[self.ClassName] or class=="GuiObject" and guiClasses[self.ClassName] or class=="LuaSourceContainer" and ({Script=true,LocalScript=true,ModuleScript=true})[self.ClassName] or false end
    function methods:GetChildren() return table.clone(self._children) end
    function methods:GetDescendants() local result={};local function walk(o) for _,v in ipairs(o._children) do table.insert(result,v);walk(v) end end;walk(self);return result end
    function methods:FindFirstChild(name,recursive) for _,v in ipairs(recursive and self:GetDescendants() or self._children) do if v.Name==name then return v end end end
    function methods:WaitForChild(name,timeout) local value=self:FindFirstChild(name);if not value and not timeout then error("Missing dependency: "..self.Name.."/"..name) end;return value end
    function methods:FindFirstChildOfClass(class) for _,v in ipairs(self._children) do if v:IsA(class) then return v end end end
    function methods:FindFirstAncestorOfClass(class) local p=self.Parent;while p do if p:IsA(class) then return p end;p=p.Parent end end
    function methods:IsDescendantOf(parent) local p=self.Parent;while p do if p==parent then return true end;p=p.Parent end;return false end
    function methods:SetAttribute(k,v) self._attrs[k]=v;if self._signals['attr:'..k] then self._signals['attr:'..k]:Fire() end end
    function methods:GetAttribute(k) return self._attrs[k] end
    function methods:GetAttributeChangedSignal(k) return self:GetPropertyChangedSignal('attr:'..k) end
    function methods:GetPropertyChangedSignal(k) if not self._signals[k] then self._signals[k]=self._sim:signal() end;return self._signals[k] end
    function methods:Destroy() if self._props.Destroyed then return end;self.Destroying:Fire();for _,c in ipairs(self:GetChildren()) do c:Destroy() end;self.Parent=nil;self._props.Destroyed=true end
    function methods:Clone()
        local remap={}
        local function duplicate(o) local n=self._sim:object(o.ClassName,o.Name);n._props=table.clone(o._props);n._props.Parent=nil;n._attrs=copy(o._attrs);remap[o]=n;for _,c in ipairs(o._children) do duplicate(c).Parent=n end;return n end
        local result=duplicate(self)
        for _,n in pairs(remap) do for k,v in pairs(n._props) do if remap[v] then n._props[k]=remap[v] end end end
        return result
    end
    function methods:GetBoundingBox()
        local lo,hi=V3.new(math.huge,math.huge,math.huge),V3.new(-math.huge,-math.huge,-math.huge)
        local count=0
        for _,p in ipairs(self:GetDescendants()) do if p:IsA("BasePart") then
            count+=1;local a=p.CFrame.r;local s=p.Size*.5
            local e=V3.new(math.abs(a[1])*s.X+math.abs(a[2])*s.Y+math.abs(a[3])*s.Z,math.abs(a[4])*s.X+math.abs(a[5])*s.Y+math.abs(a[6])*s.Z,math.abs(a[7])*s.X+math.abs(a[8])*s.Y+math.abs(a[9])*s.Z)
            local low,high=p.Position-e,p.Position+e
            lo=V3.new(math.min(lo.X,low.X),math.min(lo.Y,low.Y),math.min(lo.Z,low.Z));hi=V3.new(math.max(hi.X,high.X),math.max(hi.Y,high.Y),math.max(hi.Z,high.Z))
        end end
        if count==0 then return CF.new(),V3.new(1,1,1) end
        return CF.new((lo+hi)*.5),hi-lo
    end
    function methods:GetPivot() if self.PrimaryPart then return self.PrimaryPart.CFrame end;local cf=self:GetBoundingBox();return cf end
    function methods:PivotTo(target) local delta=target*self:GetPivot():Inverse();for _,p in ipairs(self:GetDescendants()) do if p:IsA("BasePart") then p.CFrame=delta*p.CFrame end end end
    function methods:Play() self.IsPlaying=true end
    function methods:Stop() self.IsPlaying=false end
    function methods:Emit(count) self._props.Emitted=(self._props.Emitted or 0)+count end
    function methods:FireServer(...) table.insert(self._sim.remotes,{Name=self.Name,Args={...}});self.OnServerEvent:Fire(self._sim.player,...) end
    function methods:FireClient(player,...) if player==self._sim.player then self.OnClientEvent:Fire(...) end end
    function methods:FireAllClients(...) self.OnClientEvent:Fire(...) end
    function methods:EquipTool(tool)
        local char=self.Parent;local player=self._sim:playerForCharacter(char)
        for _,o in ipairs(char:GetChildren()) do if o:IsA("Tool") then o.Parent=player.Backpack;o.Unequipped:Fire() end end
        tool.Parent=char;tool.Equipped:Fire()
    end
    function methods:TakeDamage(amount)
        if self.Parent:FindFirstChildOfClass("ForceField") then return end
        self.Health=math.max(0,self.Health-amount);if self.Health<=0 then self.Died:Fire() end
    end
    function methods:GetState() return self._sim.Enum.HumanoidStateType.Running end
    function methods:ViewportPointToRay() return {Origin=self.CFrame.Position,Direction=self.CFrame.LookVector} end
    methods.ScreenPointToRay=methods.ViewportPointToRay

    self.game=self:object("DataModel","game");self.services={}
    function self.game:GetService(name) assert(self._sim.services[name],"Unknown service "..name);return self._sim.services[name] end
    for _,name in ipairs({"StarterPlayer","ServerScriptService","Players","ReplicatedStorage","DataStoreService","MarketplaceService","Debris","TweenService","RunService","Lighting","HttpService","StarterPack","StarterGui","UserInputService","SoundService","GuiService","ContextActionService"}) do self.services[name]=self:object(name,name,self.game) end
    self.workspace=self:object("Workspace","Workspace",self.game)
    self.workspace.CurrentCamera=self:object("Camera","Camera",self.workspace);self.workspace.CurrentCamera.CFrame=CF.new(0,10,20)
    function self.workspace:Raycast(origin,direction,params) table.insert(self._sim.rays,{Origin=origin,Direction=direction,Params=params});return self._sim.rayResult end
    function self.services.Players:GetPlayers() local r={};for _,p in ipairs(self:GetChildren()) do if p:IsA("Player") then table.insert(r,p) end end;return r end
    function self:playerForCharacter(char) for _,p in ipairs(self.services.Players:GetPlayers()) do if p.Character==char then return p end end end
    function self.services.Players:GetPlayerFromCharacter(char) return self._sim:playerForCharacter(char) end
    function self.services.Players:GetPlayerByUserId(id) for _,p in ipairs(self:GetPlayers()) do if p.UserId==id then return p end end end
    self.actions={}
    function self.services.ContextActionService:BindAction(name,fn) self._sim.actions[name]=fn end
    function self.services.RunService:IsStudio() return self._sim.isStudio==true end
    function self.services.RunService:BindToRenderStep(name,_,fn) self._sim.actions[name]=fn end
    function self.services.StarterGui:SetCoreGuiEnabled() end
    function self.services.UserInputService:GetFocusedTextBox() return nil end
    function self.services.UserInputService:IsMouseButtonPressed() return false end
    self.services.UserInputService.KeyboardEnabled=true;self.services.UserInputService.TouchEnabled=false;self.services.UserInputService.GamepadEnabled=false
    function self.services.Debris:AddItem(o,t) self._sim:schedule(t,function() o:Destroy() end) end
    function self.services.TweenService:Create(o,_,properties) return {Play=function() for k,v in pairs(properties) do o[k]=v end end,Cancel=function() end} end
    function self.game:BindToClose(fn) self._sim.closeHandler=fn end
    self.guid=0;function self.services.HttpService:GenerateGUID() self._sim.guid+=1;return 'sim-guid-'..self._sim.guid end
    local store={}
    function store:UpdateAsync(key,callback) local old=copy(self.sim.store[key]);local result=callback(old);if result then self.sim.store[key]=copy(result) end;return result end
    store.sim=self
    function self.services.DataStoreService:GetDataStore() return store end
    function self.services.MarketplaceService:UserOwnsGamePassAsync(id,pass) return self._sim.owned[id] and self._sim.owned[id][pass] or false end
    function self.services.MarketplaceService:GetProductInfoAsync(id) return assert(self._sim.metadata[id],"Missing catalog metadata: "..id) end
    function self.services.MarketplaceService:PromptGamePassPurchase(p,id) table.insert(self._sim.prompts,{Kind='Pass',Player=p,Id=id}) end
    function self.services.MarketplaceService:PromptProductPurchase(p,id) table.insert(self._sim.prompts,{Kind='Product',Player=p,Id=id}) end
    local random={NextNumber=function(_,a,b) return a and (a+(b-a)*.5) or .5 end,NextInteger=function(_,a) return a end}
    local clock=table.clone(os);clock.clock=function() return self.now end;clock.time=function() return 1800000000+math.floor(self.now) end
    self.modules={}
    local generic={new=function(...) return {...} end}
    self.env=setmetatable({game=self.game,workspace=self.workspace,Enum=self.Enum,Vector3=V3,Vector2=V2,CFrame=CF,Color3=Color3,
        UDim={new=udim},UDim2={new=udim2,fromOffset=function(x,y) return udim2(0,x,0,y) end,fromScale=function(x,y) return udim2(x,0,y,0) end},
        Instance={new=function(class) return self:object(class) end},Random={new=function() return random end},RaycastParams=generic,TweenInfo=generic,
        NumberRange=generic,NumberSequence=generic,NumberSequenceKeypoint=generic,ColorSequence=generic,ColorSequenceKeypoint=generic,
        os=clock,task={wait=function(t) return coroutine.yield(t or .03) end,spawn=function(fn,...) self:schedule(0,fn,...) end,delay=function(t,fn,...) self:schedule(t,fn,...) end},
        require=function(module) return assert(self.modules[type(module)=="string" and module or module.Name],"Missing simulated module") end,
        typeof=function(v) local m=type(v)=="table" and getmetatable(v);return m and m.__type or type(v) end,
        warn=function(...) table.insert(self.errors,{...}) end}, {__index=getfenv()})
    return self
end
function Sim:run(source,name) local fn,err=loadstring(source,name);assert(fn,err);setfenv(fn,self.env);return fn() end
function Sim:addPlayer(name,id)
    local p=self:object("Player",name,self.services.Players);p.UserId=id;p.DisplayName=name
    self:object("Backpack","Backpack",p);self:object("PlayerGui","PlayerGui",p)
    if not self.player then self.player=p;self.services.Players.LocalPlayer=p end
    return p
end
function Sim:spawnCharacter(p)
    if p.Character then p.CharacterRemoving:Fire(p.Character);p.Character:Destroy() end
    local char=self:object("Model",p.Name.."Character",self.workspace)
    self:object("Humanoid","Humanoid",char)
    local root=self:object("Part","HumanoidRootPart",char);root.CFrame=CF.new(0,10,0);char.PrimaryPart=root
    local head=self:object("Part","Head",char);head.CFrame=CF.new(0,12,0)
    p.Character=char;p.CharacterAdded:Fire(char);return char
end
return Sim
