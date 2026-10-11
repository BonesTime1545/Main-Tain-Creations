-- coroutine-based task
local cos={}
task.spawn=function(fn,...) local co=coroutine.create(fn) table.insert(cos,co) coroutine.resume(co,...) end
task.wait=function(t) coroutine.yield() return t end
local function STEP(n) for i=1,n do FAKE+=0.5 for _,co in cos do if coroutine.status(co)=="suspended" then coroutine.resume(co) end end end end
player.Character.PivotTo=nil
local charObj
charObj={FindFirstChild=function(_,n) return root end,FindFirstChildOfClass=function() return hum end,GetAttribute=function() return nil end,PivotTo=function(self,cf) root.Position=cf.Position end}
player.Character=charObj
root.CFrame=CFrame.new(0,0,0); root.AssemblyLinearVelocity=Vector3.zero
ctx.PlotSystem.SpawnCFrame=function(pl) return pl.CFrame*CFrame.new(0,3.5,30) end
ctx.Net.BlockRequest={} ctx.Net.BlockHit={OnServerEvent={Connect=function() end}} ctx.Net.Notify={FireClient=function(_,p,t) print("NOTIFY",t) end}
ctx.Players.PlayerRemoving={Connect=function() end}
ctx.Players.GetPlayers=function() return {player} end
BlockService.Start()
for cx=0,3 do for cz=0,3 do BM.Set(data.Plot.Blocks,cx,cz,1,"D") end end
BM.Set(data.Plot.Blocks,1,1,2,"R")
BlockService.Refresh(player); RUN_DELAYED()
-- 1. noclip
local base=plot.CFrame.P
root.Position=base+Vector3.new(-2.5,5.5,-2.5)
STEP(1) print("after 1 check",root.Position.Y-base.Y)
STEP(1) print("after 2 checks (expect ~ 8+3.4):",root.Position.Y-base.Y, root.Position.X-base.X)
-- standing on top of the stone is fine
root.Position=base+Vector3.new(-2.5,8+3,-2.5); STEP(4) print("on top stays", root.Position.Y-base.Y)
-- 2. heal
local n0=0 for _,p in ALL_PARTS do if p.Parent and p.Name=="Dirt" then n0+=1 end end
for _,p in ALL_PARTS do if p.Parent and p.Name=="Dirt" then p:Destroy() break end end
STEP(8); RUN_DELAYED(); STEP(1)
local n1=0 for _,p in ALL_PARTS do if p.Parent and p.Name=="Dirt" then n1+=1 end end
print("dirt bricks before/after heal",n0,n1)
-- 3. pit idle
root.Position=base+Vector3.new(0,20,0)
for _,l in {1,0,-1,-2,-3} do BM.Set(data.Plot.Blocks,1,1,l,nil) end
-- hole through the block at level 1/2: simplest: break via data then rebuild
data.Plot.Blocks["1,1"]=nil
BlockService.Refresh(player); RUN_DELAYED()
root.Position=base+Vector3.new(-2.5,-11,-2.5)
STEP(3) print("in pit, y=",root.Position.Y-base.Y)
STEP(195) print("after 97 s idle y=",root.Position.Y-base.Y, "z",root.Position.Z-base.Z)
-- 4. atomic rebuild: break the colour then place
local function count() local c=0 for _,p in ALL_PARTS do if p.Parent and (p.Name=="Dirt" or p.Name=="DirtTop") then c+=1 end end return c end
local before=count()
root.Position=base+Vector3.new(0,10,0)
local savedColor=BC.Types.D.Color
BC.Types.D.Color="oops"
BlockService.Place(player,0,0,1,"S") -- S tier ignored
BlockService.Place(player,3,3,2,"D")
RUN_DELAYED()
print("bricks before / after failed rebuild",before,count())
BC.Types.D.Color=savedColor
