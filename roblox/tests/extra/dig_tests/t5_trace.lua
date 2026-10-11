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
T("down onto neighbour",Vector3.new(2.5,30,-2.5),Vector3.new(0,-1,0),false)
T("down onto block L1",Vector3.new(2.5,30,2.5),Vector3.new(0,-1,0),false)
T("up from pit",Vector3.new(-2.5,-6,-2.5),Vector3.new(0,1,0),false)
T("horizontal in hole +x",Vector3.new(-2.5,-2,-2.5),Vector3.new(1,0,0),false)
T("diagonal from above into hole",Vector3.new(-12,20,-2.5),Vector3.new(1,-1.2,0),false)
T("from outside grid below",Vector3.new(-2.5,-30,-2.5),Vector3.new(0,1,0),false)
T("from far side above breaking",Vector3.new(-30,10,-2.5),Vector3.new(1,-0.2,0),true)
