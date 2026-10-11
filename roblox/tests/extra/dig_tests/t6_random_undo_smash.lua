for cx=0,3 do for cz=0,3 do if cx~=3 or cz~=3 then BM.Set(data.Plot.Blocks,cx,cz,1,"D") BM.Set(data.Plot.Blocks,cx,cz,2,"R") end end end
UNDO={}
ctx.BuildService={PushUndo=function(_,op) table.insert(UNDO,op) end, InYard=function() return true end}
ctx.ToolConfig={SmashCells=function(cx,cz,level,axis,n,maxL)
	local out={}
	for ring=0,2 do for a=-1,1 do for b=-1,1 do if math.abs(a)+math.abs(b)==ring then
		local x,z,l=cx,cz,level
		if axis=="X" then z,l=cz+a,level+b elseif axis=="Z" then x,l=cx+a,level+b else x,z=cx+a,cz+b end
		if x>=0 and z>=0 and x<n and z<n and l>=-4 and l<=maxL then table.insert(out,{x,z,l}) end
	end end end end
	return out end}
BlockService.Refresh(player)
RUN_DELAYED()
local rng=Random and nil
local seed=12345
local function rnd(n) seed=(seed*1103515245+12345)%2147483648 return (seed//65536)%n end
local n=4
local codes={"D","S","R","L","d","s","r","l"}
local bad=0 WHY={}
local function expectedSolid(blocks,cx,cz,lv)
	local c=BM.Get(blocks,cx,cz,lv)
	return c~=nil and BC.IsSolid(c), c
end
local function check(step)
	local blocks=data.Plot.Blocks
	for cx=0,n-1 do for cz=0,n-1 do for lv=-4,5 do
		local sol,c=expectedSolid(blocks,cx,cz,lv)
		local wx=100-10+(cx+0.5)*5; local wz=100-10+(cz+0.5)*5
		local y0=(lv-1)*4
		local probeY=y0+ (BC.IsHalf(c) and 1 or 2)
		local hit=solidAt(wx,probeY,wz)
		if sol then
			-- exposed? replicate cull rule
			local pit = blocks.Pit and next(blocks.Pit)~=nil
			if lv<=0 and not pit then
			else
			local up=BM.Get(blocks,cx,cz,lv+1)
			local show=true
			if lv<=0 then
				show = BC.IsHalf(c) or not (up and BC.IsSolid(up) and not BC.IsHalf(up))
				if not show then
					for _,d in {{1,0},{-1,0},{0,1},{0,-1}} do
						local x,z=cx+d[1],cz+d[2]
						if x>=0 and z>=0 and x<n and z<n then
							local o=BM.Get(blocks,x,z,lv)
							if not (o and BC.IsSolid(o) and not BC.IsHalf(o)) then show=true break end
						end
					end
				end
			end
			if show and not hit then bad+=1 print("step",step,"MISSING collision at",cx,cz,lv,c) end
			end
		else
			if hit and lv>0 or (hit and lv<=0 and hit~="Floor") then bad+=1 print("step",step,"STALE collision at",cx,cz,lv,"part",hit) end
		end
	end end end
end
for step=1,600 do
	local cx,cz,lv=rnd(n),rnd(n),rnd(10)-4
	root.Position=Vector3.new(100,(lv-1)*4+8,100) -- near enough
	local blocks=data.Plot.Blocks
	local r=rnd(10)
	if r==0 and #UNDO>0 then
		local op=table.remove(UNDO)
		local ok,why=BlockService.UndoPlace(player,op)
		WHY["undo:"..tostring(why)]=(WHY["undo:"..tostring(why)] or 0)+1
	elseif r==1 and BM.Get(blocks,cx,cz,lv) then
		FAKE+=100
		BlockService.Smash(player,cx,cz,lv,({"X","Y","Z"})[rnd(3)+1])
		WHY.smash=(WHY.smash or 0)+1
	elseif r<5 and BM.Get(blocks,cx,cz,lv) then
		FAKE+=10
		HIT(player,cx,cz,lv,6)
	else
		local ok,why=BlockService.Place(player,cx,cz,lv,codes[rnd(#codes)+1]) WHY[tostring(why)]=(WHY[tostring(why)] or 0)+1
	end
	RUN_DELAYED()
	check(step)
	if bad>10 then break end
end
print("bad",bad) for k,v in WHY do print(v,k) end
dump("end")
