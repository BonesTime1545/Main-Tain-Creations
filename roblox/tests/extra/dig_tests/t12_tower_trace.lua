-- BlockFX.Trace with a pit
local U=setmetatable({}, {__index=function(t,k) return function(self,...) return t end end, __call=function(t,...) return t end})
local RSx={WaitForChild=function() return SHARED end}
local svc=setmetatable({},{__index=function(t,k) if k=="LocalPlayer" then return {UserId=1} end if k=="ReplicatedStorage" then return RSx end return U end})
Random={new=function() return U end}
NumberSequence=U NumberSequenceKeypoint=U NumberRange=U ColorSequence=U TweenInfo=U UDim2=U Vector2=U
local gs=game
game={GetService=function(_,n) return svc[n] end}
local BFX_ENV
local ok,BlockFX=pcall(function() return require({__mod="BlockFX"}) end)
print("load BlockFX",ok, ok and "" or BlockFX)
local BM=require({__mod="BlockMath"})
local model=Instance.new("Folder")
local fl=Instance.new("Part"); fl.Name="Floor"; fl.Size=Vector3.new(20,1,20); fl.CFrame=CFrame.new(0,-0.5,0); fl.Parent=model
local blocks={}
BM.Set(blocks,1,1,0,nil); BM.Set(blocks,1,1,-1,nil)
BM.Set(blocks,2,2,1,"D")
model:SetAttribute("Blocks",BM.Encode(blocks))
local function T(label,o,d,br)
	local hit,prev=BlockFX.Trace(model,o,d,br)
	if hit then print(label,"hit",hit.Cx,hit.Cz,hit.Level,hit.Code,"prev",prev and prev.Cx,prev and prev.Cz,prev and prev.Level) else print(label,"nil", prev and ("prev "..prev.Cx..","..prev.Cz..","..prev.Level) or "") end
end
T("down into hole",Vector3.new(-2.5,30,-2.5),Vector3.new(0,-1,0),false)
local fails=0
local function eq(a,b,l) if a~=b then fails+=1 print("FAIL",l,"got",tostring(a),"expected",tostring(b)) end end
local tower={}
for l=1,60 do BM.Set(tower,2,2,l,"D") end
model:SetAttribute("Blocks",BM.Encode(tower))
local h,p=BlockFX.Trace(model,Vector3.new(2.5,400,2.5),Vector3.new(0,-1,0),false)
eq(h and h.Level,60,"down onto the top of the tower") eq(p and p.Level,61,"place above the top")
h,p=BlockFX.Trace(model,Vector3.new(-30,25*4-2,2.5),Vector3.new(1,0,0),false)
eq(h and h.Level,25,"side hit at level 25") eq(p and p.Cx,1,"in front of it") eq(p and p.Level,25,"same level")
h,p=BlockFX.Trace(model,Vector3.new(-2.5,400,-2.5),Vector3.new(0,-1,0),false)
eq(h and h.Level,0,"empty column: the earth under the floor") eq(p and p.Level,1,"place on the floor")
h,p=BlockFX.Trace(model,Vector3.new(2.5,1000,2.5),Vector3.new(0.3,0.2,0),false)
eq(h,nil,"into the sky: nothing")
h,p=BlockFX.Trace(model,Vector3.new(-30,100,2.5),Vector3.new(1,-0.2,0),false)
eq(h~=nil,true,"slanted from far above hits the tower side")
print(fails==0 and "TRACE OK" or "FAILURES "..fails)
