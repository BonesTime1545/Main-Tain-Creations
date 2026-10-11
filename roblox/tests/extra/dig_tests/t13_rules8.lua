-- ROUND 8 rules: (A) no height ceiling (server + client Trace with the live water-entry path), (B) tree / zone supports can't be broken
local fails = 0
local function eq(a, b, label) if a ~= b then fails += 1 print("FAIL", label, "got", tostring(a), "expected", tostring(b)) end end
Vector2 = { new = function(x, y) return { X = x, Y = y } end }
ctx.IslandService = { Tier = function() return 9 end, Can = function() return true end }
UNDO = {}
ctx.BuildService = { PushUndo = function(_, op) table.insert(UNDO, op) end, InYard = function() return true end }
ctx.ToolConfig = { SmashCells = function(cx, cz, level, axis, n, maxL)
	local out = {}
	for a = -1, 1 do for b = -1, 1 do
		local x, z, l = cx, cz, level
		if axis == "X" then z, l = cz + a, level + b elseif axis == "Z" then x, l = cx + a, level + b else x, z = cx + a, cz + b end
		if x >= 0 and z >= 0 and x < n and z < n and l >= -4 and l <= maxL then table.insert(out, { x, z, l }) end
	end end
	return out end }
local blocks = data.Plot.Blocks
local O = data.Plot.Objects

---------------------------------------------------------------- A1: BlockMath.CheckChange / BlockService.Place stack 256 high
for l = 1, 256 do
	local ok, why = BM.CheckChange(blocks, O, 0, 0, l, "D", 20, 5)
	if not ok then eq(why, nil, "CheckChange place level " .. l) break end
	BM.Set(blocks, 0, 0, l, "D")
end
eq(#blocks["0,0"], 256, "256 blocks stacked through CheckChange")
eq((BM.CheckChange(blocks, O, 0, 0, 257, "D", 20, 5)), false, "257 is the engine-safe ceiling")
local enc = BM.Encode(blocks)
eq(#enc < 100, true, "run-length encoded 256-high column is short: " .. #enc)
eq(#BM.Decode(enc)["0,0"], 256, "decode keeps 256")
blocks["0,0"] = nil
for l = 1, 120 do
	local ok, why = BS.Place(player, 1, 1, l, if l % 3 == 0 then "R" else "D")
	if not ok then eq(why, nil, "BlockService.Place level " .. l) break end
end
RUN_DELAYED()
eq(#data.Plot.Blocks["1,1"], 120, "120 blocks via BlockService.Place")
eq(BM.TopLevel(data.Plot.Blocks), 120, "TopLevel")
data.Plot.Blocks["1,1"] = nil
BS.Refresh(player) RUN_DELAYED()

---------------------------------------------------------------- A2: client: BlockFX with the live refresh path (the stale-top bug)
local HB
local svc = {
	RunService = { Heartbeat = { Connect = function(_, fn) HB = fn return {} end }, Stepped = { Connect = function() return {} end } },
	Players = { LocalPlayer = { UserId = 1 } },
	ReplicatedStorage = { WaitForChild = function() return SHARED end },
}
local anyU = setmetatable({}, { __index = function(t, k) return function(self, ...) return t end end, __call = function(t, ...) return t end })
Random = { new = function() return anyU end }
NumberSequence, NumberSequenceKeypoint, NumberRange, ColorSequence, TweenInfo, UDim2 = anyU, anyU, anyU, anyU, anyU, anyU
game = { GetService = function(_, n) return svc[n] or anyU end }
local W = Instance.new("Folder")
local LRf = Instance.new("Folder") LRf.Name = "LeafRush" LRf.Parent = W
local Plots = Instance.new("Folder") Plots.Name = "Plots" Plots.Parent = LRf
workspace = { _kids = W._kids, FindFirstChild = function(_, n) if n == "LeafRush" then return LRf end end, CurrentCamera = nil, GetServerTimeNow = function() return 0 end }
task.spawn = function() end
local okL, BlockFX = pcall(function() return require({ __mod = "BlockFX" }) end)
eq(okL, true, "BlockFX loads: " .. tostring(BlockFX))
local cmodel = Instance.new("Folder") cmodel.Name = "Plot1" cmodel.Parent = Plots
local cfloor = Instance.new("Part") cfloor.Name = "Floor" cfloor.Size = Vector3.new(20, 1, 20) cfloor.CFrame = CFrame.new(0, -0.5, 0) cfloor.Parent = cmodel
local objs = Instance.new("Folder") objs.Name = "Objects" objs.Parent = cmodel
cmodel:SetAttribute("OwnerUserId", 1)
cmodel.GetAttributeChangedSignal = function() return { Connect = function() return { Disconnect = function() end } end } end
BlockFX.Start({ Plot = { CellSize = 5 } }, {})
local tower = {}
local function setTower(h)
	tower = {}
	for l = 1, h do BM.Set(tower, 2, 2, l, "D") end
	cmodel:SetAttribute("Blocks", BM.Encode(tower))
	HB(0.4)
end
setTower(3)
BlockFX.Blocks(cmodel) -- (the first call caches the highest level: 3)
for _, h in { 8, 12, 13, 30, 61, 200 } do
	setTower(h)
	local hit, prev = BlockFX.Trace(cmodel, Vector3.new(2.5, 4 * 256 + 50, 2.5), Vector3.new(0, -1, 0), false)
	eq(hit and hit.Level, h, "Trace down onto a tower of " .. h)
	eq(prev and prev.Level, h + 1, "…the cell to place into is above it (" .. h .. ")")
end

---------------------------------------------------------------- B: protected supports
for k in pairs(blocks) do blocks[k] = nil end
local function brk(cx, cz, l) return BM.CheckChange(blocks, O, cx, cz, l, nil, 20, 5) end
-- tree 2x2 at cells 0..1 x 0..1 on the floor (Lv 0), zone 2x2 at cells 2..3 x 2..3 (Lv 0)
O.t1 = { Type = "Tree", TreeType = "Oak", Level = 1, X = -5, Z = -5, Rot = 0, Lv = 0 }
O.z1 = { Type = "CollectionZone", X = 5, Z = 5, Rot = 0, SizeX = 10, SizeZ = 10, Lv = 0 }
local ok, why = brk(0, 0, 0)
eq(ok, false, "the earth under the tree (slot 0) can't be dug") eq(why, "A tree stands on this block", "tree reason")
eq((brk(1, 1, 0)), false, "…every cell of its footprint")
eq((brk(2, 2, 0)), false, "the earth under the zone can't be dug") eq(select(2, brk(3, 3, 0)), "The Collection Zone stands on this block", "zone reason")
eq((brk(2, 0, 0)), true, "a cell beside is free")
eq((brk(0, 0, -1)), true, "deeper under the tree is free")
-- a tower under a tree at Lv 3
for l = 1, 3 do for cx = 0, 1 do for cz = 0, 1 do BM.Set(blocks, cx, cz, l, "D") end end end
O.t1.Lv = 3
eq((brk(0, 1, 3)), false, "top block under a tree at Lv 3 is protected")
eq((brk(0, 1, 2)), true, "the block under the support is free (breaking it makes the tree float)")
eq((BM.CheckChange(blocks, O, 0, 1, 4, "D", 20, 5)), false, "…and a block INTO the tree's body is still refused")
eq(select(2, BM.CheckChange(blocks, O, 0, 1, 5, "D", 20, 5)), "A block has to touch the ground or another block", "a block higher above is not refused by the tree")
eq((brk(2, 0, 0)), true, "beside is free")
-- slab: a tree standing on a slab
BM.Set(blocks, 0, 0, 3, nil) BM.Set(blocks, 0, 0, 3, "d")
BM.Set(blocks, 0, 1, 3, "d") BM.Set(blocks, 1, 0, 3, "d") BM.Set(blocks, 1, 1, 3, "d")
O.t1.Lv = 2.5
eq((brk(0, 0, 3)), false, "the slab under a tree at Lv 2.5 is protected")
eq((brk(0, 0, 2)), true, "the full block under the slab is free")
-- moved away: protection ends, no stored flags
O.t1.X, O.t1.Z, O.t1.Lv = 5, -5, 0 -- cells 2..3 x 0..1
eq((brk(0, 0, 3)), true, "tree moved away: free") eq((brk(2, 0, 0)), false, "…its new support is protected")
O.t1 = nil
eq((brk(2, 0, 0)), true, "tree removed: free")
-- other objects are NOT protected
O.d1 = { Type = "Decor", DecorType = "X", X = -5, Z = -5, Rot = 0, Lv = 0 }
eq((brk(0, 0, 0)), true, "a decoration's support is breakable")
O.d1 = nil
-- water plant floats: nothing protected
-- the server paths
UNDO = {}
for k in pairs(blocks) do blocks[k] = nil end
data.Plot.Blocks = blocks
O.t2 = { Type = "Tree", TreeType = "Oak", Level = 1, X = -5, Z = -5, Rot = 0, Lv = 1 }
O.z1.Lv = 0
for cx = 0, 1 do for cz = 0, 1 do BM.Set(blocks, cx, cz, 1, "D") end end
BM.Set(blocks, 2, 0, 1, "D") BM.Set(blocks, 2, 1, 1, "D")
BS.Refresh(player) RUN_DELAYED()
root.Position = plot.CFrame.P + Vector3.new(-7.5, 3, -2.5)
FAKE += 100
HIT(player, 0, 0, 1, 12)
RUN_DELAYED()
eq(BM.Get(data.Plot.Blocks, 0, 0, 1), "D", "Hit: the block under the tree stays")
HIT(player, 2, 0, 1, 12) RUN_DELAYED()
eq(BM.Get(data.Plot.Blocks, 2, 0, 1), nil, "Hit: a free block beside breaks")
-- smash 3x3 over the top face of (1,1) at slot 1: the tree's cells stay, (2,x) goes
BM.Set(data.Plot.Blocks, 2, 0, 1, "D")
FAKE += 1000
BS.Smash(player, 1, 1, 1, "Y") RUN_DELAYED()
eq(BM.Get(data.Plot.Blocks, 0, 0, 1), "D", "Smash: tree support stays") eq(BM.Get(data.Plot.Blocks, 1, 1, 1), "D", "Smash: the aimed support stays")
eq(BM.Get(data.Plot.Blocks, 2, 0, 1), nil, "Smash: a free neighbour breaks")
-- undo of a block put under the tree is refused as well
local okP = BS.Place(player, 3, 0, 1, "D") RUN_DELAYED()
eq(okP, true, "place a block")
-- the client preview (BlockFX.Protected) agrees
for k in pairs(tower) do tower[k] = nil end
local ct = {}
for cx = 0, 1 do for cz = 0, 1 do BM.Set(ct, cx, cz, 1, "D") end end
cmodel:SetAttribute("Blocks", BM.Encode(ct)) HB(0.4)
local tm = Instance.new("Folder") tm.Parent = objs
for k, v in { Type = "Tree", TreeType = "Oak", X = -5, Z = -5, Rot = 0, Lv = 1 } do tm:SetAttribute(k, v) end
eq(BlockFX.Protected(cmodel, 0, 0, 1), "A tree stands on this block", "client: protected shows a reason")
eq(BlockFX.Protected(cmodel, 0, 0, 2), nil, "client: nothing above")
eq(BlockFX.Protected(cmodel, 3, 3, 1), nil, "client: beside")
print(fails == 0 and "RULES8 OK" or ("FAILURES " .. fails))
