local clock = 100
task = { delay = function() end }
local V = Vector3
local CFm = { __mul = function(a) return a end }
local function cf(pos) return setmetatable({ Position = pos, LookVector = V.new(0, 0, -1) }, CFm) end
local attrs = {}
local root = { Position = V.new(0, 3, 0), Name = "HumanoidRootPart" }
root.CFrame = cf(root.Position)
local tool = { Name = "t", IsA = function(_, c) return c == "Tool" end, GetAttribute = function(_, k) if k == "LeafTool" then return "PushMower" end end }
local char = { FindFirstChild = function(_, n) if n == "HumanoidRootPart" then return root end end, FindFirstChildOfClass = function() return { Health = 100 } end, GetChildren = function() return { tool } end, GetAttribute = function() end }
local p = { Name = "m", Character = char, Parent = true, UserId = 9, SetAttribute = function(_, k, v) attrs[k] = v end, GetAttribute = function(_, k) return attrs[k] end }
local data = { Tools = { Owned = { PushMower = true }, Up = { PushMower = {} }, Wear = {}, FuelUsed = {}, Battery = 60 }, Consumables = { Owned = {}, Slots = {} }, Stats = {} }
local cuts, notes = 0, {}
local ctx = { ToolConfig = TC_MODULE, PlayerDataService = { Get = function() return data end },
	PlotSystem = { Get = function() return { CFrame = {}, Size = 60 } end },
	GrassService = { CellsIn = function() return { "1,1" } end, Cut = function() cuts += 1 return 2 end },
	Net = { Notify = { FireClient = function(_, _, t) table.insert(notes, t) end } }, Players = { GetPlayers = function() return { p } end } }
local S = SERVICE_MODULE
S.Now = function() return clock end
S.Init(ctx)
local function check(l, c) print((c and "PASS " or "FAIL ") .. l) end
S.PublishBlast(p, true) -- (creates the per-player state, as the server loop does)
-- first call remembers the position, the next ones cut
local results = {}
for i = 1, 5 do
	root.Position = V.new(i * 2.5, 3, 0); root.CFrame = cf(root.Position)
	clock += 0.2
	local ok, r = pcall(S.MowStep, p, 0.2)
	table.insert(results, tostring(ok) .. ":" .. tostring(r))
end
print(table.concat(results, " "))
check("push mower cuts while walking", cuts >= 3)
check("it burns fuel", (data.Tools.FuelUsed.PushMower or 0) > 0.5)
-- a sprinting player (about 30 studs/s) still mows
local cutsBefore = cuts
for i = 1, 4 do
	root.Position = V.new(20 + i * 6, 3, 0); root.CFrame = cf(root.Position)
	clock += 0.2
	S.MowStep(p, 0.2)
end
check("push mower still cuts at a sprint (30 studs/s)", cuts - cutsBefore >= 3)
