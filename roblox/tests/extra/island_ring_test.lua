local BlockMath = {}
function BlockMath.RingRects(hx, hz, poly, step)
	local n = #poly
	local pzmin, pzmax = math.huge, -math.huge
	for _, q in poly do
		pzmin, pzmax = math.min(pzmin, q[2]), math.max(pzmax, q[2])
	end
	local function at(z)
		z = math.clamp(z, pzmin + 1e-6, pzmax - 1e-6)
		local lo, hi = math.huge, -math.huge
		for i = 1, n do
			local a, b = poly[i], poly[i % n + 1]
			local z1, z2 = a[2], b[2]
			if z1 ~= z2 and ((z1 <= z and z <= z2) or (z2 <= z and z <= z1)) then
				local x = a[1] + (z - z1) * (b[1] - a[1]) / (z2 - z1)
				lo, hi = math.min(lo, x), math.max(hi, x)
			end
		end
		return lo, hi
	end
	local zs = { -hz }
	local function add(z)
		if z > zs[#zs] + 1e-4 and z < hz - 1e-4 then
			table.insert(zs, z)
		end
	end
	if pzmax < -hz or pzmin > hz then
		return false, { { -hx, hx, -hz, hz } }
	end
	add(pzmin)
	local z = pzmin + step
	while z < math.min(pzmax, hz) do
		add(z)
		z += step
	end
	add(pzmax)
	table.insert(zs, hz)
	local touched = false
	local rows = {} -- { z0, z1, segs = { {x0, x1} } }
	for i = 1, #zs - 1 do
		local a, b = zs[i], zs[i + 1]
		local mid = (a + b) / 2
		local segs
		if mid < pzmin or mid > pzmax then
			segs = { { -hx, hx } }
		else
			local lmin, lmax, rmin, rmax = math.huge, -math.huge, math.huge, -math.huge
			local function sample(zz)
				local lo, hi = at(zz)
				lmin, lmax = math.min(lmin, lo), math.max(lmax, lo)
				rmin, rmax = math.min(rmin, hi), math.max(rmax, hi)
			end
			sample(a)
			sample(b)
			for _, q in poly do
				if q[2] > a and q[2] < b then
					sample(q[2])
				end
			end
			if rmax > -hx and lmin < hx then
				touched = true
			end
			local left = if lmax > -hx + 0.05 then { -hx, math.min(lmax, hx) } else nil
			local right = if rmin < hx - 0.05 then { math.max(rmin, -hx), hx } else nil
			if left and right and left[2] >= right[1] then
				segs = { { -hx, hx } }
			else
				segs = {}
				if left then
					table.insert(segs, left)
				end
				if right then
					table.insert(segs, right)
				end
			end
		end
		local last = rows[#rows]
		local same = last and #last.segs == #segs
		if same then
			for k, sg in segs do
				if math.abs(sg[1] - last.segs[k][1]) > 0.02 or math.abs(sg[2] - last.segs[k][2]) > 0.02 then
					same = false
					break
				end
			end
		end
		if same then
			last.z1 = b
		else
			table.insert(rows, { z0 = a, z1 = b, segs = segs })
		end
	end
	local out = {}
	for _, r in rows do
		for _, sg in r.segs do
			if sg[2] - sg[1] > 0.05 and r.z1 - r.z0 > 0.05 then
				table.insert(out, { sg[1], sg[2], r.z0, r.z1 })
			end
		end
	end
	return touched, out
end
local function inPoly(poly, x, z)
	local sign
	for i = 1, #poly do
		local a, b = poly[i], poly[i % #poly + 1]
		local c = (b[1]-a[1])*(z-a[2]) - (b[2]-a[2])*(x-a[1])
		if c ~= 0 then
			local sg = c > 0
			if sign == nil then sign = sg elseif sign ~= sg then return false end
		end
	end
	return true
end
local function rot(a, h)
	local c, s = math.cos(a), math.sin(a)
	local out = {}
	for _, q in { {-h,-h},{h,-h},{h,h},{-h,h} } do
		table.insert(out, { q[1]*c - q[2]*s + 7, q[1]*s + q[2]*c - 3 })
	end
	return out
end
local bad, tot = 0, 0
for _, ang in { 0, math.rad(60), math.rad(-120), math.rad(45), math.rad(30) } do
	for _, box in { {8,8}, {2,8}, {6,2}, {8,8} } do
		local poly = rot(ang, 50)
		local hx, hz = box[1], box[2]
		for off = -60, 60, 20 do
			local pp = {}
			for _, q in poly do table.insert(pp, { q[1] - off, q[2] + off*0.5 }) end
			local touched, rects = BlockMath.RingRects(hx, hz, pp, 1)
			for i = 1, 4000 do
				local x, z = (math.random()*2-1)*hx, (math.random()*2-1)*hz
				local inside = inPoly(pp, x, z)
				local cov = false
				for _, r in rects do if x>=r[1] and x<=r[2] and z>=r[3] and z<=r[4] then cov = true end end
				tot += 1
				-- outside the polygon must be covered; deep inside (>1.8 studs) must not
				if not inside and not cov then bad += 1 end
				if inside and cov then
					-- allowed only within the strip overlap: check distance to edge
					local dmin = math.huge
					for k = 1, 4 do
						local a, b = pp[k], pp[k%4+1]
						local dx, dz = b[1]-a[1], b[2]-a[2]
						local d = math.abs(dx*(z-a[2]) - dz*(x-a[1])) / math.sqrt(dx*dx+dz*dz)
						dmin = math.min(dmin, d)
					end
					if dmin > 1.8 then bad += 1 end
				end
			end
			if not touched then
				for i = 1, 200 do
					local x, z = (math.random()*2-1)*hx, (math.random()*2-1)*hz
					if inPoly(pp, x, z) then bad += 1 end
				end
			end
		end
	end
end
print("samples", tot, "bad", bad, "rects example", #select(2, BlockMath.RingRects(8, 8, rot(math.rad(60), 50), 1)))
