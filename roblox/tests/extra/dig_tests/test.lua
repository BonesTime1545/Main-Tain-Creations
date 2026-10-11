local RS={WaitForChild=function(self,n) return SHARED end}
game={GetService=function(_,n) return RS end}
local LR=Instance.new("Folder"); LR.Name="LeafRush"
local MAP=Instance.new("Folder"); MAP.Name="Map"; MAP.Parent=LR
local GI=Instance.new("Folder"); GI.Name="GardenIslands"; GI.Parent=MAP
workspace={FindFirstChild=function(_,n) if n=="LeafRush" then return LR end end, GetServerTimeNow=function() return 0 end}
local BlockService=require({__mod="BlockService"})
local BC=require({__mod="BlockConfig"})
local BM=require({__mod="BlockMath"})
local PM=require({__mod="PlotMath"})
local floor=Instance.new("Part"); floor.Name="Floor"; floor.Size=Vector3.new(20,1,20); floor.Color=Color3.fromRGB(96,150,62)
local model=Instance.new("Folder")
floor.Parent=model; floor.CFrame=(ROTPLOT or CFrame.new(100,0.04,100))*CFrame.new(0,-0.5,0)
local plot={Index=1,Size=20,CFrame=ROTPLOT or CFrame.new(100,0.04,100),Floor=floor,Model=model,Objects={}}
local data={Plot={Blocks={},Objects={},Expansion=0},Tools={Owned={Pickaxe=true}}}
local rootPos=plot.CFrame.P+Vector3.new(0,3,0)
local root={Position=rootPos,Name="HumanoidRootPart"}
local hum={Health=100}
local player={UserId=1,Character={FindFirstChild=function(_,n) return root end,FindFirstChildOfClass=function() return hum end}}
player.SetAttribute=function(self,k,v) end player.GetAttribute=function() return nil end
plot.Owner=player
local fired={}
local ctx={
 Config={Plot={CellSize=5,Sizes={[0]=20,25,30,40,50,75,100},MaxExpansion=6},Collision={Floor="LR_Floor"}},
 PlayerDataService={Get=function() return data end},
 PlotSystem={Get=function() return plot end,All=function() return {plot} end,RepositionObject=function() end},
 PlotMath=PM,
 Players={GetPlayers=function() return {} end},
 Net={BlockFX={FireAllClients=function(_,...) table.insert(fired,{...}) end}},
}
BlockService.Init(ctx)
BlockService.Start=BlockService.Start

function dump(label)
	local counts={}
	for _,p in ALL_PARTS do
		if p.Parent then
			counts[p.Name]=(counts[p.Name] or 0)+1
		end
	end
	local s={}
	for k,v in counts do table.insert(s,k.."="..v) end
	table.sort(s)
	print(label, table.concat(s," "))
end
function solidAt(wx,wy,wz) -- does any collidable brick contain this world point
	local lp=Vector3.new(wx,wy,wz)
	for _,p in ALL_PARTS do
		if p.Parent and p.CanCollide then
			local d=p.CFrame:PointToObjectSpace(lp)
			if math.abs(d.X)<=p.Size.X/2 and math.abs(d.Y)<=p.Size.Y/2 and math.abs(d.Z)<=p.Size.Z/2 then return p.Name end
		end
	end
	return nil
end

BS=BlockService

ISLAND_PARENT=GI
