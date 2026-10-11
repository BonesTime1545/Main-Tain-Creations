-- ground (round 6): real island 1 (rotated plot), the whole 20x20 yard dug to the bottom.
-- NODEEP=1 simulates the old (shallow) islands to show what the test catches.
local function mkIsland()
	local model=Instance.new("Folder"); model.Name="GardenIsland1"
	local groups={}
	for _,r in ISLAND do
		local g=r[1]
		if g=="Grass" or g=="Underside" or g=="Details" then
			local f=groups[g]
			if not f then f=Instance.new("Folder"); f.Name=g; f.Parent=model; groups[g]=f end
			local p=Instance.new("Part"); p.Name=g=="Underside" and (r[3]-r[6]/2 > -6.5 and "Dirt" or "Rock") or g
			p.Size=Vector3.new(r[5],r[6],r[7]); p.CFrame=CFrame.new(r[2],r[3],r[4])
			p.Color=Color3.fromRGB(100,100,100); p.Material=Enum.Material.Plastic; p.Anchored=true
			p.Parent=f
		end
	end
	return model
end
local model=mkIsland(); model.Parent=ISLAND_PARENT
if NODEEP then model:SetAttribute("LRDeep",true) end
local nUnder=0 for _,p in model:GetDescendants() do if p.Name=="Rock" or p.Name=="Dirt" then nUnder+=1 end end

local SZ=SIZE or 20
local EXP=({[20]=0,[25]=1,[30]=2,[40]=3,[50]=4,[75]=5,[100]=6})[SZ]
data.Plot.Expansion=EXP; plot.Size=SZ
plot.CFrame=CFrame.new(217,0.04,125)*CFrame.Angles(0,math.rad(ROTDEG or -120),0)*CFrame.new(0,0,50-SZ/2)
BlockService.Refresh(player); RUN_DELAYED()
local n=SZ//5
local function dig(cx,cz) for level=0,-4,-1 do root.Position=plot.CFrame:PointToWorldSpace(Vector3.new(-SZ/2+2.5+cx*5,level*4+2,-SZ/2+2.5+cz*5)) HIT(player,cx,cz,level,4) RUN_DELAYED() end end
if SZ==20 then for cx=0,n-1 do for cz=0,n-1 do dig(cx,cz) end end
else for _,c in {{0,0},{n-1,0},{0,n-1},{n-1,n-1},{n//2,0},{n//2,n-1},{0,n//2},{n-1,n//2}} do dig(c[1],c[2]) end end
RUN_DELAYED()
-- the pit exists: is every cell dug?
local blocks=data.Plot.Blocks
local solidCells=0
for cx=0,n-1 do for cz=0,n-1 do for level=-4,0 do if BC.IsSolid(BM.Get(blocks,cx,cz,level)) then solidCells+=1 end end end end
print("cells still solid in the yard", solidCells)
dump("dug")
local deepest=0 for _,p in ALL_PARTS do if p.Parent and p.CFrame then local b=p.CFrame.Y-p.Size.Y/2 if b<deepest then deepest=b end end end
print("island bottom y", deepest, "parts under (before/after count equal)", nUnder)

local half=SZ/2
local function world(lx,ly,lz) local w=plot.CFrame:PointToWorldSpace(Vector3.new(lx,0,lz)) return w.X, plot.CFrame.Y+ly, w.Z end
-- points on rings OUTSIDE the yard footprint: distance d from its edge (measured in the plot frame)
local gaps, gapsBelow, wrongName, tot = 0, 0, 0, 0
local ex={}
for _,d in {0.3,0.8,1.5,2.5} do
	for t=-half-d,half+d,SZ>20 and 3.1 or 0.7 do
		for _,pt in {{t,half+d},{t,-half-d},{half+d,t},{-half-d,t}} do
			for _,ly in {-1,-5,-9,-13,-17,-19.5,-20.5,-21.5,-23,-26} do
				local x,y,z=world(pt[1],ly,pt[2])
				local who=solidAt(x,y,z)
				tot+=1
				if not who and ly<-21 then gapsBelow+=1
				elseif not who then gaps+=1 if #ex<400 then table.insert(ex,string.format("gap d=%.1f y=%.1f local %.1f,%.1f",d,ly,pt[1],pt[2])) end
				elseif d<=2.5 and ly>-20.9 and ly<-0.5 and who~="DirtWall" and who~="DirtBed" then wrongName+=1 if #ex<400 then table.insert(ex,string.format("%s d=%.1f y=%.1f",who,d,ly)) end end
			end
		end
	end
end
print("outside samples",tot,"see-through (wall zone y>-21)",gaps,"below the bed",gapsBelow)
for _,e in ex do print(e) end
-- inside: bed holds, air above it
local badBed=0
for x=-half+0.5,half-0.5,SZ>20 and 5 or 1 do for z=-half+0.5,half-0.5,SZ>20 and 5 or 1 do
	local cx,cz=math.floor((x+half)/5),math.floor((z+half)/5)
	if not BC.IsSolid(BM.Get(blocks,cx,cz,-4)) then
	local wx,wy,wz=world(x,-20.3,z)
	if solidAt(wx,wy,wz)~="DirtBed" then badBed+=1 end
	local ax,ay,az=world(x,-18,z)
	if solidAt(ax,ay,az) then badBed+=1000 end
	end
end end
print("bed errors", badBed)
-- a thing at the lowest level stands exactly on the bed
local rec={Type="Decor",DecorType="x",X=0,Z=0,Rot=0}
print("TopY of a dug column", BM.TopY(blocks,0,0), "(bed top = -20)")
