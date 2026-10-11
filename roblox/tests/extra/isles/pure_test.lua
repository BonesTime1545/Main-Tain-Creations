local P = require("./pure")
-- cellRects: L shape
local set = {}
for i = 0, 2 do for j = 0, 1 do set[P.cellKey(i, j)] = true end end
set[P.cellKey(0, 2)] = true
local has = function(i, j) return set[P.cellKey(i, j)] == true end
local r = P.cellRects(has, 0, 0, 3, 3)
local area = 0
for _, x in r do area += (x.i1 - x.i0 + 1) * (x.j1 - x.j0 + 1) end
assert(area == 7, "area " .. area)
assert(#r == 2, "rects " .. #r)
-- hole in the middle
set[P.cellKey(1, 0)] = nil
local r2 = P.cellRects(has, 0, 0, 3, 3)
local a2 = 0 for _, x in r2 do a2 += (x.i1 - x.i0 + 1) * (x.j1 - x.j0 + 1) end
assert(a2 == 6)
-- pruneSpurs: a 3x3 block with a one-cell tip
local k = {}
for i = 0, 2 do for j = 0, 2 do k[P.cellKey(i, j)] = true end end
k[P.cellKey(3, 1)] = true
local n = P.pruneSpurs(k)
assert(n == 1 and not k[P.cellKey(3, 1)] and k[P.cellKey(2, 1)], "spur " .. n)
-- bridgeExtension: island starts 5 studs beyond the tip
local cov = function(w, u) return u >= 5 end
assert(P.bridgeExtension(cov, { -4.5, 0, 4.5 }, 2.5, 20, 0.5) == 8)
-- already 2.8 under the deck
assert(P.bridgeExtension(function(w, u) return u >= -2.8 end, { 0 }, 2.5, 20, 0.5) == 0)
-- jagged: corner lateral starts later
local jag = function(w, u) return u >= (if w > 3 then 7 else 5) end
assert(P.bridgeExtension(jag, { -4.5, 0, 4.5 }, 2.5, 20, 0.5) == 10)
-- no ground
assert(P.bridgeExtension(function() return false end, { 0 }, 2.5, 20, 0.5) == nil)
print("ISLES PURE OK")
