-- BlockService: a tall tower, water in the pit, water floating (server side, stubs)
ctx.IslandService = { Tier = function() return 9 end, Can = function() return true end }
local fails = 0
local function eq(a, b, label) if a ~= b then fails += 1 print("FAIL", label, "got", tostring(a), "expected", tostring(b)) end end
local function now() RUN_DELAYED() end
-- a 60-high tower in cell (0,0)
for l = 1, 60 do
	local ok, why = BS.Place(player, 0, 0, l, if l % 2 == 0 then "R" else "D")
	if not ok then eq(why, nil, "place level " .. l) break end
end
now()
eq(#data.Plot.Blocks["0,0"], 60, "60 blocks in the data")
eq(BS.Place(player, 0, 0, 257, "D"), false, "257 refused")
local enc = plot.Model:GetAttribute("Blocks")
print("published attribute:", enc)
local bricks = 0
for _, p in ALL_PARTS do if p.Parent and (p.Name == "Dirt" or p.Name == "DirtTop" or p.Name == "Stone") then bricks += 1 end end
eq(bricks >= 60, true, "a brick per level (" .. bricks .. ")")
-- top-level brick at y = 59*4 .. 60*4 above the plot (0.04 + ...)
eq(solidAt(100 - 7.5, 0.04 + 59 * 4 + 2, 100 - 7.5) ~= nil, true, "collision at level 60")
eq(solidAt(100 - 7.5, 0.04 + 60 * 4 + 2, 100 - 7.5), nil, "nothing at level 61")
-- the other services
local x0, z0 = -7.5, -7.5
eq(BS.TopYBelow(plot, x0, z0, 600), 240, "TopYBelow from high above = the top of the tower")
eq(BS.TopYBelow(plot, x0, z0, 50), 48, "TopYBelow in the middle")
eq(BS.CeilY(plot, x0, z0, 10), 12, "CeilY under a block of the tower")
eq(BS.CeilY(plot, x0, z0, 300), nil, "CeilY above the tower: free sky")
-- break the top block, the layer is cleared
data.Plot.Blocks["0,0"] = string.sub(data.Plot.Blocks["0,0"], 1, 59)
BS.Refresh(player) now()
eq(solidAt(100 - 7.5, 0.04 + 59 * 4 + 2, 100 - 7.5), nil, "top gone after refresh")
-- the pit: dig (1,1) two deep, put water into the deepest slot
BM = require({ __mod = "BlockMath" })
local bl = data.Plot.Blocks
BM.Set(bl, 1, 1, 0, nil) BM.Set(bl, 1, 1, -1, nil)
BS.Refresh(player) now()
local ok, why = BS.Place(player, 1, 1, -1, "W")
eq(ok, true, "water into the pit via the server: " .. tostring(why))
eq(BM.Get(data.Plot.Blocks, 1, 1, -1), "W", "stored")
now()
local w = BS.Water(plot)
eq(w ~= nil, true, "water exists")
local x, z = -10 + 1.5 * 5, -10 + 1.5 * 5
local wpos = plot.CFrame.P + Vector3.new(x, -3, z)
eq(BS.InWater(wpos), true, "swimming in the pit water")
local out = BS.InWater(plot.CFrame.P + Vector3.new(x, 8, z))
eq(out, false, "not swimming above the hole")
eq(plot.Model:GetAttribute("Blocks") ~= nil and string.find(plot.Model:GetAttribute("Blocks"), "|1,1:-W", 1, true) ~= nil, true, "pit water in the attribute")
-- the client decodes it to the same
local d = BM.Decode(plot.Model:GetAttribute("Blocks"))
eq(BM.Get(d, 1, 1, -1), "W", "client side decode")
-- water floating in the air, no support
eq((BS.Place(player, 3, 0, 9, "W")), true, "floating water")
eq((BS.Place(player, 3, 2, 1, "D")), true, "earth on the floor")
-- undo of the pit water is possible
local okU = BS.UndoPlace(player, { Cx = 1, Cz = 1, Level = -1, Code = "W", Prev = nil, PrevVar = 0 })
eq(okU, true, "undo pit water")
eq(BM.Get(data.Plot.Blocks, 1, 1, -1), nil, "…gone")
print(fails == 0 and "SERVICE OK" or ("FAILURES " .. fails))
