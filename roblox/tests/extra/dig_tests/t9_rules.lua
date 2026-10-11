-- ROUND 6 "rules": unlimited height, water anywhere (also in the pit), tree support. Pure modules only.
local fails = 0
local function eq(a, b, label)
	if a ~= b then
		fails += 1
		print("FAIL", label, "got", tostring(a), "expected", tostring(b))
	end
end
local BC = require({ __mod = "BlockConfig" })
local BM = require({ __mod = "BlockMath" })
local WF = require({ __mod = "WaterFlow" })
local OLD = require({ __mod = "OldWaterFlow" })
local PM = require({ __mod = "PlotMath" })
local TP = require({ __mod = "TreePlacement" })

---------------------------------------------------------------- 1. height
eq(BC.MaxLevels, 256, "ceiling")
do
	local b = {}
	for l = 1, 200 do
		local ok, why, put = BM.CheckChange(b, {}, 2, 2, l, "D", 20, 5)
		eq(ok, true, "stack level " .. l .. " " .. tostring(why))
		BM.Set(b, 2, 2, put and l or l, "D")
	end
	eq(#b["2,2"], 200, "200 high column")
	eq(BM.TopLevel(b), 200, "TopLevel")
	eq((BM.CheckChange(b, {}, 2, 2, 202, "D", 20, 5)), false, "floating at 202 refused (no support)")
	eq((BM.CheckChange(b, {}, 2, 2, 201, "R", 20, 5)), true, "201 ok")
	for l = 201, 256 do
		BM.Set(b, 2, 2, l, "R")
	end
	eq(#b["2,2"], 256, "256 high")
	local ok, why = BM.CheckChange(b, {}, 2, 2, 257, "D", 20, 5)
	eq(ok, false, "257 refused")
	eq(why, "Blocks stack only 256 high", "message")
	-- encode: run-length packing keeps the tall column short, round-trips
	local text = BM.Encode(b)
	eq(text, "2,2:D200R56", "RLE text " .. text)
	local d = BM.Decode(text)
	eq(d["2,2"], b["2,2"], "RLE decode")
	for l = 1, 258 do
		eq(BM.Get(d, 2, 2, l), BM.Get(b, 2, 2, l), "decoded level " .. l)
	end
	-- mixed
	local m = { ["0,0"] = "DDDSSSSW-DDDD", ["1,0"] = "W", ["3,3"] = "D-D-D" }
	BM.Set(m, 3, 3, -2, nil)
	local t2 = BM.Encode(m)
	local d2 = BM.Decode(t2)
	for _, k in { "0,0", "1,0", "3,3" } do
		eq(d2[k], BM.CleanColumn(m[k]), "mixed " .. k .. " via " .. t2)
	end
	-- hostile text can't blow up
	local h = BM.Decode("0,0:D99999999")
	eq(#h["0,0"], 256, "count capped")
	eq(BM.Decode("0,0:D8;1,1:-5D2")["1,1"], "-----DD", "gap run")
	-- sanitize cuts to the ceiling and keeps 256
	local long = string.rep("D", 400)
	local sn = BM.Sanitize({ ["0,0"] = long }, 4)
	eq(#sn["0,0"], 256, "sanitize cut")
	-- colour variants up to the top
	local v = {}
	for l = 1, 256 do
		BM.Set(v, 0, 0, l, "D", 3)
	end
	eq(BM.GetVariant(v, 0, 0, 256), 3, "variant at 256")
	local vd = BM.Decode(BM.Encode(v))
	eq(BM.GetVariant(vd, 0, 0, 256), 3, "variant at 256 round trip")
	eq(BM.GetVariant(vd, 0, 0, 1), 3, "variant at 1 round trip")
	-- Lv range (the HEIGHT bar) follows
	eq(BM.CleanLv(300), 256, "Lv ceiling")
	eq(BM.CleanLv(100.3), 100.5, "Lv half grid")
	eq(BM.CleanLv(-9), -5, "Lv bottom")
	eq(BM.AimLevel(500, 1), 125, "aim top at 500 studs")
end

---------------------------------------------------------------- 2. water in the pit (data + rules)
do
	local size, cell = 20, 5
	local b = {}
	BM.Set(b, 1, 1, 0, nil)
	BM.Set(b, 1, 1, -1, nil)
	local ok = BM.CheckChange(b, {}, 1, 1, 0, "W", size, cell)
	eq(ok, true, "water into a dug slot of the pit")
	BM.Set(b, 1, 1, -1, "W")
	eq(BM.Get(b, 1, 1, -1), "W", "pit water stored")
	eq(b.Pit["1,1"], "-W", "pit string " .. tostring(b.Pit["1,1"]))
	eq(BM.TopH(b, 1, 1), -2, "water is no ground: TopH goes through it to the earth (-2)")
	local d = BM.Decode(BM.Encode(b))
	eq(BM.Get(d, 1, 1, -1), "W", "pit water round trip")
	local sn = BM.Sanitize(b, 4)
	eq(BM.Get(sn, 1, 1, -1), "W", "pit water survives Sanitize")
	eq(BM.Count(b) >= 1, true, "counted")
	eq((BM.CheckChange(b, {}, 1, 1, -1, nil, size, cell)), true, "scoop it up")
	eq((BM.CheckChange(b, {}, 2, 2, 0, "W", size, cell)), false, "undug earth: not empty")
	-- no placement rules for water above the floor
	local e = {}
	eq((BM.CheckChange(e, {}, 1, 1, 7, "W", size, cell)), true, "water floating in the air")
	eq((BM.CheckChange(e, {}, 2, 3, 1, "W", size, cell)), true, "water at the entrance")
	eq((BM.CheckChange(e, {}, 2, 3, 1, "D", size, cell)), false, "earth at the entrance still refused")
	eq((BM.CheckChange(e, {}, 1, 1, 7, "D", size, cell)), false, "earth floating still refused")
	-- inside a thing's slot: water is fine, a block is not
	local objs = { a = { Type = "CollectionZone", X = 0, Z = 0, Rot = 0, SizeX = 10, SizeZ = 10, Lv = 0 } }
	local zx, zz = PM.CellOf(0, 0, size, cell)
	eq((BM.CheckChange(e, objs, zx, zz, 1, "W", size, cell)), true, "water inside a zone's slot")
	eq((BM.CheckChange(e, objs, zx, zz, 1, "D", size, cell)), false, "earth inside a zone's slot")
	-- 1 water in the pit counts as a pit (BlockService.PitMode: next(blocks.Pit))
	eq(next(b.Pit) ~= nil, true, "pit exists")
end

---------------------------------------------------------------- 3. WaterFlow: same as before without a pit
local function sameSet(a, b)
	for k, v in a do
		if b[k] ~= v then
			return false, k
		end
	end
	for k, v in b do
		if a[k] ~= v then
			return false, k
		end
	end
	return true
end
do
	math.randomseed(7)
	local codes = { "D", "S", "R", "L", "W", "d", "s", "-", "-", "-" }
	local bad = 0
	for trial = 1, 300 do
		local n = math.random(3, 7)
		local blocks = {}
		for cx = 0, n - 1 do
			for cz = 0, n - 1 do
				if math.random() < 0.55 then
					local len = math.random(1, 6)
					local t = {}
					for i = 1, len do
						t[i] = codes[math.random(#codes)]
					end
					local col = BM.CleanColumn(table.concat(t))
					if col then
						blocks[BM.Key(cx, cz)] = col
					end
				end
			end
		end
		local a, b = OLD.Compute(blocks, n), WF.Compute(blocks, n)
		local ok1, k1 = sameSet(a.Amt, b.Amt)
		local ok2 = sameSet(a.Fall, b.Fall)
		local ok3 = sameSet(a.Full, b.Full)
		eq(a.Count, b.Count, "count " .. trial)
		if not (ok1 and ok2 and ok3) then
			bad += 1
			fails += 1
			print("FAIL compute differs", trial, k1)
		end
		-- Surface: old vs new at random points
		for _ = 1, 40 do
			local cx, cz = math.random(0, n - 1), math.random(0, n - 1)
			local y = math.random() * 24 - 1
			local t1, b1 = OLD.Surface(a, cx, cz, y, 0.3)
			local t2, b2 = WF.Surface(b, cx, cz, y, 0.3)
			if t1 ~= t2 or b1 ~= b2 then
				fails += 1
				print("FAIL surface differs", trial, cx, cz, y, t1, b1, t2, b2)
				break
			end
		end
	end
	print("compared 300 random gardens against the old WaterFlow, differing:", bad)
end

---------------------------------------------------------------- 4. WaterFlow in the pit
do
	local n = 5
	-- a 1-cell shaft dug 3 deep (levels 0, -1, -2), a source above it on level 1
	local b = {}
	BM.Set(b, 2, 2, 0, nil)
	BM.Set(b, 2, 2, -1, nil)
	BM.Set(b, 2, 2, -2, nil)
	BM.Set(b, 2, 2, 1, "W")
	local w = WF.Compute(b, n)
	eq(w.Fall[WF.Index(n, 2, 2, 0)], true, "falls into the shaft (0)")
	eq(w.Fall[WF.Index(n, 2, 2, -1)], true, "falls (-1)")
	eq(w.Fall[WF.Index(n, 2, 2, -2)], true, "falls to the bottom of the hole (-2)")
	eq(w.Amt[WF.Index(n, 2, 2, -3)], nil, "…but not into the earth below")
	eq(w.Amt[WF.Index(n, 1, 2, 1)] ~= nil, true, "level 1 still runs on the earth next to it")
	eq(w.Amt[WF.Index(n, 1, 2, 0)], nil, "no water in the earth beside the shaft")
	eq(w.Lo, -2, "Lo")
	eq(w.Hi, 1, "Hi")
	-- index maths of negative levels
	for level = -4, 5 do
		for cz = 0, n - 1 do
			for cx = 0, n - 1 do
				local gx, gz, gl = WF.Cell(n, WF.Index(n, cx, cz, level))
				if gx ~= cx or gz ~= cz or gl ~= level then
					fails += 1
					print("FAIL index", cx, cz, level, gx, gz, gl)
				end
			end
		end
	end
	-- a cavity 3x3 at levels -1, -2 dug out (level 0 stays earth: a cave), two sources make a lake, the rest fills
	local c = {}
	for cx = 1, 3 do
		for cz = 1, 3 do
			BM.Set(c, cx, cz, 0, nil)
			BM.Set(c, cx, cz, -1, nil)
		end
	end
	BM.Set(c, 1, 2, -1, "W")
	BM.Set(c, 3, 2, -1, "W")
	local wc = WF.Compute(c, n)
	eq(wc.Full[WF.Index(n, 2, 2, -1)], true, "lake between two sources in the pit")
	eq(wc.Full[WF.Index(n, 0, 2, -1)], nil, "not into the earth wall")
	eq(wc.Full[WF.Index(n, 2, 2, 0)], nil, "not up through…")
	-- (level 0 above the water is open here: the lake resting on the bed rises into dug cells with 2 full neighbours)
	-- standing water in the pit is something you swim in
	local top, bottom = WF.Surface(wc, 2, 2, -5, 0)
	eq(top ~= nil, true, "Surface finds the pit water")
	if top then
		eq(bottom, -8, "bottom of the pit water")
	end
	-- water lands on the bed of a hole and runs sideways in the hole
	local d = {}
	for cx = 0, 3 do
		BM.Set(d, cx, 0, 0, nil)
		BM.Set(d, cx, 0, -1, nil)
		BM.Set(d, cx, 0, -2, nil)
		BM.Set(d, cx, 0, -3, nil)
		BM.Set(d, cx, 0, -4, nil)
	end
	BM.Set(d, 0, 0, 1, "W")
	local wd = WF.Compute(d, n)
	eq(wd.Fall[WF.Index(n, 0, 0, -4)], true, "falls all the way to the bed (-4)")
	eq(wd.Amt[WF.Index(n, 1, 0, -4)] ~= nil, true, "runs along the bed")
	eq(wd.Amt[WF.Index(n, 0, 1, -3)], nil, "not into the earth wall beside the shaft")
	-- a source in the pit under a source: Sunk works for negative indexes
	local s = {}
	BM.Set(s, 0, 0, 0, nil)
	BM.Set(s, 0, 0, -1, "d")
	local ws = WF.Compute(s, n)
	eq(ws.Half[WF.Index(n, 0, 0, -1)], true, "a slab in the pit is a half cell")
end

---------------------------------------------------------------- 5. WaterFlow on a tall tower is bounded
do
	local n = 4
	local b = {}
	for l = 1, 200 do
		BM.Set(b, 1, 1, l, "D")
	end
	BM.Set(b, 1, 1, 201, "W")
	local t0 = os.clock()
	local w = WF.Compute(b, n)
	eq(w.Hi, 201, "Hi on the tower")
	-- the water runs on the roof (level 201), falls down the sides to the floor
	eq(w.Fall[WF.Index(n, 2, 1, 200)], true, "falls off the tower")
	eq(w.Fall[WF.Index(n, 2, 1, 1)], true, "all the way down")
	eq(w.Count < 2000, true, "count bounded " .. w.Count)
	local top = WF.Surface(w, 1, 1, 201 * 4 - 3, 0.3)
	eq(top ~= nil, true, "swim on the roof")
	print("tower compute+surface seconds", os.clock() - t0)
end

---------------------------------------------------------------- 6. trees need blocks under the WHOLE foot
do
	local size, cell = 40, 5 -- 8 x 8 cells
	TREEDEFS.Big = { Cells = { X = 4, Y = 4 } }
	TREEDEFS.Small = { Cells = { X = 2, Y = 2 } }
	TREEDEFS.Lily = { Cells = { X = 2, Y = 2 }, Ground = "Water" }
	local P = { CellSize = 5, EdgeMargin = 0, KeepOut = 0, DecorSnap = 0.5, DecorRotationStep = 15 }
	local function tree(kind, x, z, lv)
		return { Type = "Tree", TreeType = kind, Level = 1, X = x, Z = z, Rot = 0, Lv = lv }
	end
	local a, b2, c, d = PM.CellSpan(tree("Big", 0, 0), size, cell)
	eq((b2 - a + 1) * (d - c + 1), 16, "a 4x4 tree covers 16 cells")
	-- bare floor: the earth under the floor supports it at level 0
	eq((TP.Check(tree("Big", 0, 0, 0), {}, nil, size, P, {})), true, "on the bare floor")
	local blocks = {}
	BM.Set(blocks, 3, 3, 1, "D") -- one block under one of its cells
	local ok, why = TP.Check(tree("Big", 0, 0, 1), {}, nil, size, P, blocks)
	eq(ok, false, "4x4 tree on ONE block")
	eq(why, "Needs blocks under the whole tree", "message")
	-- auto level (no Lv given) picks the block and fails the same way
	eq((TP.Check(tree("Big", 0, 0, nil), {}, nil, size, P, blocks)), false, "auto level on one block")
	-- all 16 cells
	for cx = a, b2 do
		for cz = c, d do
			BM.Set(blocks, cx, cz, 1, "D")
		end
	end
	eq((TP.Check(tree("Big", 0, 0, 1), {}, nil, size, P, blocks)), true, "on 16 blocks")
	eq((TP.Check(tree("Big", 0, 0, nil), {}, nil, size, P, blocks)), true, "auto level on 16 blocks")
	-- one cell is a slab / a stack / missing
	local m = table.clone(blocks)
	m["3,3"] = nil
	m = BM.Decode(BM.Encode(blocks))
	BM.Set(m, a, c, 1, "d")
	eq((TP.Check(tree("Big", 0, 0, 1), {}, nil, size, P, m)), false, "a slab in one cell is not a full block")
	BM.Set(m, a, c, 1, "D")
	BM.Set(m, a, c, 2, "D")
	eq((TP.Check(tree("Big", 0, 0, 1), {}, nil, size, P, m)), false, "a block on top of the foot: inside a block (FootFree)")
	-- a tree on a higher stack (3 high) needs 16 columns of 3
	local tall = {}
	for cx = a, b2 do
		for cz = c, d do
			for l = 1, 3 do
				BM.Set(tall, cx, cz, l, if l == 2 then "S" else "R")
			end
		end
	end
	eq((TP.Check(tree("Big", 0, 0, 3), {}, nil, size, P, tall)), true, "on 16 columns of 3 (any type)")
	BM.Set(tall, a, c, 3, nil)
	eq((TP.Check(tree("Big", 0, 0, 3), {}, nil, size, P, tall)), false, "one column only 2 high")
	-- slabs on all cells: a tree can stand at 0.5
	local sl = {}
	for cx = a, b2 do
		for cz = c, d do
			BM.Set(sl, cx, cz, 1, "r")
		end
	end
	eq((TP.Check(tree("Big", 0, 0, 0.5), {}, nil, size, P, sl)), true, "on 16 slabs (lv 0.5)")
	-- in the pit
	local pit = {}
	for cx = a, b2 do
		for cz = c, d do
			BM.Set(pit, cx, cz, 0, nil)
		end
	end
	eq((TP.Check(tree("Big", 0, 0, -1), {}, nil, size, P, pit)), true, "in the pit on the earth of slot -1")
	eq((TP.Check(tree("Big", 0, 0, 0), {}, nil, size, P, pit)), false, "the floor is dug out: nothing under it")
	BM.Set(pit, a, c, -1, nil)
	eq((TP.Check(tree("Big", 0, 0, -1), {}, nil, size, P, pit)), false, "one cell dug deeper")
	for cx = a, b2 do
		for cz = c, d do
			BM.Set(pit, cx, cz, -1, nil)
			BM.Set(pit, cx, cz, -2, nil)
			BM.Set(pit, cx, cz, -3, nil)
			BM.Set(pit, cx, cz, -4, nil)
		end
	end
	eq((TP.Check(tree("Big", 0, 0, -5), {}, nil, size, P, pit)), true, "on the bed of the pit")
	-- water plants float; others don't care about the type
	eq((TP.Check(tree("Lily", 0, 0, 3), {}, nil, size, P, {})), true, "a water plant is not asked")
	eq((TP.Check(tree("Small", 0, 0, 2), {}, nil, size, P, {})), false, "a small tree in the air")
	-- cosmetics / zones / buildings stay unrestricted
	eq((TP.Check({ Type = "CollectionZone", X = 0, Z = 0, Rot = 0, SizeX = 10, SizeZ = 10, Lv = 4 }, {}, nil, size, P, {})), true, "zone floating")
	-- an existing tree whose blocks are broken: GroundCheck (what TreeSystem asks) still says fine
	local rec = tree("Big", 0, 0, 1)
	eq((BM.GroundCheck(rec, {}, size, cell)), true, "existing tree floating is not blocked")
	eq((BM.TreeSupport(rec, {}, size, cell)), false, "…but placing it there is")
	-- blocks under an existing tree can still be broken
	eq((BM.CheckChange(blocks, { t = rec }, 3, 3, 1, nil, size, cell)), true, "breaking under a tree is allowed")
end

print(fails == 0 and "RULES OK" or ("FAILURES " .. fails))
