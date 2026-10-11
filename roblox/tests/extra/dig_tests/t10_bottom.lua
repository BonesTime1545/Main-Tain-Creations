-- bottom layer = a solid floor for everything (pure rules + the Editor's bed aim)
local U=setmetatable({}, {__index=function(t,k) return function(self,...) return t end end, __call=function(t,...) return t end})
local RSx={WaitForChild=function() return SHARED end}
local svc=setmetatable({},{__index=function(t,k) if k=="LocalPlayer" then return {UserId=1} end if k=="ReplicatedStorage" then return RSx end return U end})
Random={new=function() return U end}
NumberSequence=U NumberSequenceKeypoint=U NumberRange=U ColorSequence=U TweenInfo=U UDim2=U Vector2=U
game={GetService=function(_,n) return svc[n] end}
local BlockFX=require({__mod="BlockFX"})
local BM=require({__mod="BlockMath"})
local BC=require({__mod="BlockConfig"})
local fails=0
local function check(label,cond) if not cond then fails+=1 print("FAIL",label) else print("ok",label) end end
local model=Instance.new("Folder")
local fl=Instance.new("Part"); fl.Name="Floor"; fl.Size=Vector3.new(20,1,20); fl.CFrame=CFrame.new(0,-0.5,0); fl.Parent=model
local blocks={}
for lv=0,-4,-1 do BM.Set(blocks,1,1,lv,nil) end   -- a column dug to the very bottom
model:SetAttribute("Blocks",BM.Encode(blocks))
local hit,prev=BlockFX.Trace(model,Vector3.new(-2.5,30,-2.5),Vector3.new(0,-1,0),false)
check("ray down an open column: no block hit", hit==nil)
check("... and the place is the lowest slot", prev and prev.Level==BC.MinLevel)
local lv,pt=BM.BedAim(prev,Vector3.new(-2.5,30,-2.5),Vector3.new(0.1,-1,0).Unit)
check("BedAim -> level -Below", lv==-BC.Below)
check("BedAim point on the bed plane y=-20", pt and math.abs(pt.Y+20)<1e-6)
check("BedAim: not for a ray going up", BM.BedAim(prev,Vector3.new(0,0,0),Vector3.new(0,1,0))==nil)
check("BedAim: not for another slot", BM.BedAim({Level=-3},Vector3.new(0,30,0),Vector3.new(0,-1,0))==nil)
-- standing on the bed
check("TopH of the dug column = -Below", (BM.TopH(blocks,1,1))==-BC.Below)
check("TopY = -20 (the bed's top)", BM.TopY(blocks,1,1)==-20)
check("CleanLv keeps -5", BM.CleanLv(-5)==-5 and BM.CleanLv(-9)==-5)
local zone={Type="CollectionZone",X=-2.5,Z=-2.5,Rot=0,SizeX=5,SizeZ=5,Lv=-5}
local ok,why=BM.BodyCheck(zone,blocks,20,5,-5)
check("a 5x5 thing stands on the bed (cell 1,1 dug)", ok)
local ok2=BM.BodyCheck({Type="CollectionZone",X=2.5,Z=2.5,Rot=0,SizeX=5,SizeZ=5},blocks,20,5,-5)
check("... but not inside untouched earth next to it", ok2==false)
check("auto level of a thing in the hole is the bed", BM.AutoLevel(zone,blocks,20,5)==-5)
-- blocks in the lowest slot
local okB,r1=BM.CheckChange(blocks,{},1,1,BC.MinLevel,"S",20,5)
check("a block can be placed in the lowest slot (bed supports it)", okB)
local okC=BM.CheckChange(blocks,{},1,1,BC.MinLevel-1,"S",20,5)
check("nothing below the bed", okC==false)
check("Supported at the lowest slot", BM.Supported(blocks,1,1,BC.MinLevel,4))
check("the bed itself can't be broken", BM.CheckChange(blocks,{},1,1,BC.MinLevel-1,nil,20,5)==false)
-- deepen / outward pure geometry
local d=BM.IslandDeepen()
check("island deepen covers the bed + 6 studs", -10-d <= -(BC.Below*BC.Height+1)-6 and d%4==0)
local dy,dh=BM.DeepenBox(-10,d,-10) check("wide layer grows", dy==-d/2 and dh==d)
dy,dh=BM.DeepenBox(-14,d,-10) check("layer below moves", dy==-d and dh==0)
dy,dh=BM.DeepenBox(-6,d,-10) check("layer above stays", dy==0 and dh==0)
-- outward rings never reach into the polygon, leave at most ~1 stud of gap
local function inPoly(poly,x,z) local c=false local n=#poly for i=1,n do local a,b=poly[i],poly[i%n+1] if (a[2]>z)~=(b[2]>z) and x<(b[1]-a[1])*(z-a[2])/(b[2]-a[2])+a[1] then c=not c end end return c end
local function dist(poly,x,z) local m=1e9 for i=1,#poly do local a,b=poly[i],poly[i%#poly+1] local dx,dz=b[1]-a[1],b[2]-a[2] local t=math.clamp(((x-a[1])*dx+(z-a[2])*dz)/(dx*dx+dz*dz),0,1) m=math.min(m,math.sqrt((x-a[1]-t*dx)^2+(z-a[2]-t*dz)^2)) end return m end
local intr,gapMax,samples=0,0,0
math.randomseed(7)
for _,ang in {0,30,45,60,-120,10,89} do for _,h in {10,25,50} do
	local c,s=math.cos(math.rad(ang)),math.sin(math.rad(ang))
	local poly={} for _,q in {{-h,-h},{h,-h},{h,h},{-h,h}} do table.insert(poly,{q[1]*c-q[2]*s+3,q[1]*s+q[2]*c-2}) end
	local touched,rects=BM.RingRects(16,16,poly,1,true)
	for i=1,3000 do
		local x,z=(math.random()*2-1)*16,(math.random()*2-1)*16
		local cov=false for _,r in rects do if x>=r[1] and x<=r[2] and z>=r[3] and z<=r[4] then cov=true end end
		local inside=inPoly(poly,x,z)
		samples+=1
		if cov and inside then intr+=1 end
		if not cov and not inside then gapMax=math.max(gapMax,dist(poly,x,z)) end
	end
end end
print("outward samples",samples,"inside-covered",intr,"max uncovered distance from the polygon",gapMax)
check("outward rings never reach into the polygon", intr==0)
check("the uncovered sliver is thinner than the 3-stud wall", gapMax<=1.5)
print(fails==0 and "ALL OK" or ("FAILURES "..fails))
