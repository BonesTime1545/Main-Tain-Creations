-- usage: luau grass_tops_test.lua <path to GrassService.lua>
game = { GetService = function() return {} end }
Random = { new = function() return { NextNumber = function(_, a, b) return a and (a + math.random() * (b - a)) or math.random() end, NextInteger = function(_, a, b) return math.random(a, b) end } end }
Color3 = { fromRGB = function() return {} end, new = function() return {} end }
local S = (function()
--MODULE--
end)()
local BC = { Height = 4, SlabHeight = 2, MaxLevels = 256, MinLevel = -4 }
function BC.IsSolid(c) return c == "D" or c == "S" or c == "R" or c == "L" or c == "d" or c == "s" or c == "r" or c == "l" end
S.Init({ BlockConfig = BC, ToolConfig = {}, Config = { Plot = { CellSize = 5 } } })
local plot = { Size = 100 } -- 20 x 20
local function mk(blocks) return { Plot = { Blocks = blocks, Bare = {} }, Grass = { Size = 100, Cells = {}, Tops = {} } } end
local fails = 0
local function check(l, c) print((c and "PASS " or "FAIL ") .. l); if not c then fails += 1 end end
local function keys(spots) local t = {} for _, s in spots do t[s.Key] = s end return t end

-- spots
local d = mk({ ["3,3"] = "D", ["5,5"] = "-D", ["7,7"] = "---D", ["9,9"] = "DD", ["11,11"] = "S", ["12,12"] = "-S-D", Pit = { ["14,14"] = "D", ["15,15"] = "-" } })
local sp = keys(S.TopSpots(d, plot))
check("single block on the floor", sp["3,3,1"] ~= nil)
check("floating block over air (level 2)", sp["5,5,2"] ~= nil)
check("tower with holes below (level 4)", sp["7,7,4"] ~= nil)
check("lower of two blocks has no top, upper has", sp["9,9,1"] == nil and sp["9,9,2"] ~= nil)
check("sand has none", sp["11,11,1"] == nil and sp["12,12,2"] == nil)
check("floating D above sand (level 4)", sp["12,12,4"] ~= nil)
check("block in a pit cell (level 0)", sp["14,14,0"] ~= nil and sp["14,14,0"].Y == 0)

-- growth: a lone block among many other tops must get grass in a few steps
local g = { Tall = 30, Thick = 70, Growth = { 9, 15 }, NewGrowth = { 14, 20 }, Spread = 0.7, NewPatches = { 1, 3 } }
local isl = { Max = 0.5, Infect = 0 }
local blocks = { ["5,5"] = "-D", ["3,3"] = "D", Pit = { ["14,14"] = "D" } }
for x = 8, 18 do for z = 0, 3 do blocks[x .. "," .. z] = "D" end end -- a big field of tops
local d2 = mk(blocks)
local N = 0 for _ in S.TopSpots(d2, plot) do N += 1 end
local steps = 0
local function lone() return (d2.Grass.Tops["5,5,2"] or 0) > 0 and (d2.Grass.Tops["3,3,1"] or 0) > 0 and (d2.Grass.Tops["14,14,0"] or 0) > 0 end
while not lone() and steps < 200 do S.GrowTops(d2, plot, Random.new(), g, isl, 1); steps += 1 end
print("spots", N, "steps until all three lone spots have grass:", steps)
check("lone/floating/pit spots grow within ~20 steps", lone() and steps <= 20)
-- Salt keeps a spot bare
local d3 = mk({ ["3,3"] = "D" }); d3.Plot.Bare["3,3"] = string.rep("0", 6) .. "1"
for _ = 1, 30 do S.GrowTops(d3, plot, Random.new(), g, isl, 1) end
check("Grass Salt spot stays bare", (d3.Grass.Tops["3,3,1"] or 0) == 0)
-- covered block (block above) removed from tops
local d4 = mk({ ["3,3"] = "DD" })
for _ = 1, 30 do S.GrowTops(d4, plot, Random.new(), g, isl, 1) end
check("covered block holds no grass", d4.Grass.Tops["3,3,1"] == nil and (d4.Grass.Tops["3,3,2"] or 0) > 0)
print(fails == 0 and "ALL PASS" or ("FAILS " .. fails))
