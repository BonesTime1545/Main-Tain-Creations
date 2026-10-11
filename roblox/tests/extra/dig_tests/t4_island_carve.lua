-- real island 1 + carve
local function mkIsland()
	local model=Instance.new("Folder"); model.Name="GardenIsland1"
	local groups={}
	for _,r in ISLAND do
		local g=r[1]
		if g=="Grass" or g=="Underside" or g=="Details" then
			local f=groups[g]
			if not f then f=Instance.new("Folder"); f.Name=g; f.Parent=model; groups[g]=f end
			local p=Instance.new("Part"); p.Name=g=="Underside" and "Dirt" or g
			p.Size=Vector3.new(r[5],r[6],r[7]); p.CFrame=CFrame.new(r[2],r[3],r[4])
			p.Color=Color3.fromRGB(100,100,100); p.Material=Enum.Material.Plastic; p.Anchored=true
			p.Parent=f; p._isl=g
		end
	end
	return model
end
mkIsland().Parent=ISLAND_PARENT
local model=ISLAND_PARENT:FindFirstChild("GardenIsland1")

-- sample island
local pts={}
for x=147,287,3 do for z=55,195,3 do pts[#pts+1]={x+0.5,z+0.5} end end
local function snap(tag)
	local r={}
	for i,p in pts do
		r[i]={solidAt(p[1],-1,p[2]) ~= nil, solidAt(p[1],-9,p[2]) ~= nil, solidAt(p[1],-15,p[2])~=nil, solidAt(p[1],-19,p[2])~=nil}
	end
	return r
end
local before=snap()
BlockService.Refresh(player); RUN_DELAYED()
local mid=snap()
HIT(player,1,1,0,3); RUN_DELAYED()
local after=snap()
print("floor hidden",floor.Transparency)
local half=10
local function inGarden(p) local lp=plot.CFrame:PointToObjectSpace(Vector3.new(p[1],0,p[2])) return math.abs(lp.X)<=half and math.abs(lp.Z)<=half, lp end
local lost,gained={0,0,0,0},{0,0,0,0}
local ex={}
for i,p in pts do
	local ing=inGarden(p)
	for k=1,4 do
		if before[i][k] and not after[i][k] and not ing then lost[k]+=1 if #ex<10 then table.insert(ex,string.format("lost level%d at %.1f,%.1f",k,p[1],p[2])) end end
		if after[i][k] and not before[i][k] and not ing then gained[k]+=1 end
	end
end
print("outside garden: lost",table.concat(lost,","),"gained",table.concat(gained,","))
for _,e in ex do print(e) end
dump("end")
