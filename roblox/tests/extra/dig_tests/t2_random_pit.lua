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
for step=1,300 do
	local cx,cz,lv=rnd(n),rnd(n),rnd(10)-4
	root.Position=Vector3.new(100,(lv-1)*4+8,100) -- near enough
	local blocks=data.Plot.Blocks
	if rnd(5)<2 and BM.Get(blocks,cx,cz,lv) then
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
