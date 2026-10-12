-- v3.1 (round 14b): sand / stone trees need that block under their WHOLE foot (BlockMath.TreeSupport,
-- what TreePlacement.Check asks on the server and in the preview). Run with dig_tests/gen_rules.py.
local fails = 0
local function eq(a, b, msg) if a ~= b then fails += 1; print("FAIL", msg, tostring(a), tostring(b)) end end
local BM = require(SHARED:WaitForChild("BlockMath"))
local PM = require(SHARED:WaitForChild("PlotMath"))
local TP = require(SHARED:WaitForChild("TreePlacement"))
local size, cell = 40, 5
TREEDEFS.Palm = { Cells = { X = 2, Y = 2 }, Ground = "Sand" }
TREEDEFS.Pine = { Cells = { X = 2, Y = 2 }, Ground = "Stone" }
TREEDEFS.Plain = { Cells = { X = 2, Y = 2 } }
local P = { CellSize = 5, EdgeMargin = 0, KeepOut = 0, DecorSnap = 0.5, DecorRotationStep = 15 }
local function tree(kind, lv) return { Type = "Tree", TreeType = kind, Level = 1, X = 0, Z = 0, Rot = 0, Lv = lv } end
local a, b, c, d = PM.CellSpan(tree("Palm"), size, cell)
local function fill(code)
	local bl = {}
	for cx = a, b do for cz = c, d do BM.Set(bl, cx, cz, 1, code) end end
	return bl
end
local ok, why = TP.Check(tree("Palm", 0), {}, nil, size, P, {})
eq(ok, false, "sand tree on the bare earth floor") eq(why, "Grows only on SAND", "sand message")
eq((TP.Check(tree("Palm", 1), {}, nil, size, P, fill("S"))), true, "sand tree on 4 sand blocks")
eq((TP.Check(tree("Palm", 0.5), {}, nil, size, P, fill("s"))), true, "sand tree on 4 sand slabs")
local mixed = fill("S"); BM.Set(mixed, a, c, 1, "D")
ok, why = TP.Check(tree("Palm", 1), {}, nil, size, P, mixed)
eq(ok, false, "one earth cell under a sand tree") eq(why, "Grows only on SAND", "message")
ok, why = TP.Check(tree("Pine", 1), {}, nil, size, P, fill("S"))
eq(ok, false, "stone tree on sand") eq(why, "Grows only on STONE", "stone message")
eq((TP.Check(tree("Pine", 1), {}, nil, size, P, fill("R"))), true, "stone tree on stone")
eq((TP.Check(tree("Plain", 1), {}, nil, size, P, fill("S"))), true, "an ordinary tree on sand")
eq((TP.Check(tree("Plain", 0), {}, nil, size, P, {})), true, "an ordinary tree on the floor")
print(fails == 0 and "GROUND OK" or ("FAILURES " .. fails))
if fails > 0 then error("ground test failed") end
