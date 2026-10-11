FAKE=0
-- stubs for a headless run of BlockService
local function mkvec(x,y,z) return setmetatable({X=x,Y=y,Z=z}, V3) end
V3 = {}
V3.__index = function(t,k)
	if k=="Magnitude" then return math.sqrt(t.X*t.X+t.Y*t.Y+t.Z*t.Z) end
	if k=="Unit" then local m=math.sqrt(t.X*t.X+t.Y*t.Y+t.Z*t.Z) return mkvec(t.X/m,t.Y/m,t.Z/m) end
	return rawget(V3,k)
end
V3.__add=function(a,b) return mkvec(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
V3.__sub=function(a,b) return mkvec(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
V3.__mul=function(a,b) if type(a)=="number" then a,b=b,a end if type(b)=="number" then return mkvec(a.X*b,a.Y*b,a.Z*b) end return mkvec(a.X*b.X,a.Y*b.Y,a.Z*b.Z) end
V3.__div=function(a,b) return mkvec(a.X/b,a.Y/b,a.Z/b) end
V3.__unm=function(a) return mkvec(-a.X,-a.Y,-a.Z) end
V3.__eq=function(a,b) return a.X==b.X and a.Y==b.Y and a.Z==b.Z end
function V3.new(x,y,z) return mkvec(x or 0,y or 0,z or 0) end
V3.zero=mkvec(0,0,0)
Vector3=V3
-- CFrame with yaw rotation
local CF={}
local function rot(yaw,v) local c,s=math.cos(yaw),math.sin(yaw) return mkvec(v.X*c+v.Z*s, v.Y, -v.X*s+v.Z*c) end
CF.__index=function(t,k) if k=="X" then return t.P.X elseif k=="Y" then return t.P.Y elseif k=="Z" then return t.P.Z elseif k=="Position" then return t.P elseif k=="Rotation" then return setmetatable({P=mkvec(0,0,0),yaw=t.yaw},CF) elseif k=="UpVector" then return mkvec(0,1,0) end return rawget(CF,k) end
CF.__add=function(a,b) return setmetatable({P=a.P+b,yaw=a.yaw},CF) end
function CF.new(x,y,z) if type(x)=="table" then return setmetatable({P=x,yaw=0},CF) end return setmetatable({P=mkvec(x or 0,y or 0,z or 0),yaw=0},CF) end
function CF.Angles(rx,ry,rz) return setmetatable({P=mkvec(0,0,0),yaw=ry or 0},CF) end
CF.__mul=function(a,b) if getmetatable(b)==CF then return setmetatable({P=a.P+rot(a.yaw,b.P),yaw=a.yaw+b.yaw},CF) else return a.P+rot(a.yaw,b) end end
function CF.PointToObjectSpace(a,v) return rot(-a.yaw,v-a.P) end
function CF.PointToWorldSpace(a,v) return a.P+rot(a.yaw,v) end
function CF:VectorToObjectSpace(v) return rot(-self.yaw,v) end
CFrame=CF
local C3={}
C3.__index=function(t,k) if k=="R" then return t.r end return rawget(C3,k) end
function C3.fromRGB(r,g,b) return setmetatable({r=r/255,g=g/255,b=b/255},C3) end
function C3.new(r,g,b) return setmetatable({r=r,g=g,b=b},C3) end
function C3:ToHex() return string.format("%02x%02x%02x", self.r*255, self.g*255, self.b*255) end
function C3:Lerp(o,a) return setmetatable({r=self.r+(o.r-self.r)*a,g=self.g+(o.g-self.g)*a,b=self.b+(o.b-self.b)*a},C3) end
Color3=C3
local function enum(name) return setmetatable({},{__index=function(t,k) local v=setmetatable({Name=k,Value=#name+#k},{__tostring=function() return name.."."..k end}); rawset(t,k,v); return v end}) end
Enum=setmetatable({},{__index=function(t,k) local e=enum(k); rawset(t,k,e); return e end})
ALL_PARTS={}
local Inst={}
Inst.__index=function(t,k)
	if k=="Parent" then return rawget(t,"_parent") end
	local m=rawget(Inst,k) if m then return m end
	return rawget(t,"_p")[k]
end
Inst.__newindex=function(t,k,v)
	if k=="Parent" then
		local old=rawget(t,"_parent")
		if old then old._kids[t]=nil end
		rawset(t,"_parent",v)
		if v then v._kids[t]=true end
		return
	end
	rawget(t,"_p")[k]=v
end
function Inst:Clone() local c=Instance.new(self._p.ClassName) for k,v in pairs(self._p) do c._p[k]=v end for k,v in pairs(self._attr) do c._attr[k]=v end return c end
function Inst:Destroy() self.Parent=nil; self._destroyed=true end
function Inst:ClearAllChildren() for k in pairs(self._kids) do k.Parent=nil end end
function Inst:GetChildren() local o={} for k in pairs(self._kids) do table.insert(o,k) end return o end
function Inst:IsA(c) return c==self.ClassName or c=="BasePart" and self.ClassName=="Part" end
function Inst:SetAttribute(k,v) self._attr[k]=v end
function Inst:GetAttribute(k) return self._attr[k] end
function Inst:FindFirstChild(n) for k in pairs(self._kids) do if k.Name==n then return k end end end
function Inst:GetDescendants() local o={} local function go(x) for k in pairs(x._kids) do table.insert(o,k) go(k) end end go(self) return o end
Instance={new=function(cls)
	local t=setmetatable({_p={ClassName=cls,Name=cls,Transparency=0,CanCollide=true,CanQuery=true,Anchored=false},_kids={},_attr={}},Inst)
	if cls=="Part" then table.insert(ALL_PARTS,t) end
	return t
end}
local clock=0
local delayed={}
task={delay=function(t,fn) table.insert(delayed,{at=clock+t,fn=fn}) end}
function RUN_DELAYED() while #delayed>0 do table.sort(delayed,function(a,b) return a.at<b.at end) local d=table.remove(delayed,1) clock=math.max(clock,d.at) d.fn() end end
warn=function(...) print("WARN",...) end

OSC=setmetatable({},{__index=function(_,k) if k=="clock" then return function() return FAKE end end return os[k] end}) os=OSC
function HIT(player,cx,cz,l,n) for i=1,(n or 1) do FAKE+=1 BS.Hit(player,cx,cz,l) end end
typeof=function(v) if getmetatable(v)==V3 then return "Vector3" end return type(v) end
