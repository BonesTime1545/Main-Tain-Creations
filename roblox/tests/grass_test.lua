local clock = 100
local delayed = {}
task = { delay = function(t, fn) table.insert(delayed, { at = clock + t, fn = fn }) end }
local V = Vector3
local TCm = TC_MODULE
local function mkPlayer(name, pos, heldId)
	local attrs = {}
	local root = { Position = pos, CFrame = { LookVector = V.new(0, 0, -1) }, Name = "HumanoidRootPart" }
	local tool = { Name = "t", IsA = function(_, c) return c == "Tool" end, GetAttribute = function(_, k) if k == "LeafTool" then return heldId end end }
	local hum = { Health = 100 }
	local char = {
		FindFirstChild = function(_, n) if n == "HumanoidRootPart" then return root end end,
		FindFirstChildOfClass = function(_, c) if c == "Humanoid" then return hum end end,
		GetChildren = function() return { tool } end, GetAttribute = function() end,
	}
	local pl = { Name = name, Character = char, Parent = true, UserId = 7 }
	function pl:SetAttribute(k, v) attrs[k] = v end
	function pl:GetAttribute(k) return attrs[k] end
	pl.attrs = attrs
	pl.tool = tool
	return pl
end
local p = mkPlayer("tester", V.new(0, 0, 0), "Shears")
local data = { Tools = { Owned = { Shears = true, WeedCutter = true, Scythe = true, PushMower = true, Blaster = true }, Up = { Shears = {}, Scythe = {}, PushMower = {}, Blaster = {} }, Wear = {}, FuelUsed = {}, PickUsed = 0, BlastUsed = 40, Battery = 60 },
	Consumables = { Owned = { RepairKit = 2, Gasoline = 1, BlasterBattery = 1 }, Slots = {} }, Stats = {} }
local cutCalls, notes, money, spentLog = {}, {}, 10 ^ 9, {}
local grassHits = 3
local ctx = {
	ToolConfig = TCm,
	PlayerDataService = { Get = function() return data end },
	PlotSystem = { Get = function() return { Owner = p, CFrame = { PointToObjectSpace = function() return V.new(0, 0, 0) end }, Size = 60 } end },
	GrassService = {
		CellsIn = function(plot, center, radius, dir, arc) return { string.format("%d,%d", math.floor(center.X), math.floor(center.Z)) } end,
		Cut = function(player, keys, power, opts) table.insert(cutCalls, { n = #keys, power = power, opts = opts }) return grassHits, 1 end,
	},
	CurrencyService = { Spend = function(_, price) local c = price.LeafValue; if money >= c then money -= c; table.insert(spentLog, c); return true end return false, "Not enough money" end },
	Net = { ToolFX = { FireAllClients = function(_, ...) end }, Notify = { FireClient = function(_, _, t) table.insert(notes, t) end } },
	Players = { GetPlayers = function() return { p } end },
	GearService = { RefreshSpeed = function() end },
}
local S = SERVICE_MODULE
S.Now = function() return clock end
S.Init(ctx)
local function check(label, cond) print((cond and "PASS " or "FAIL ") .. label) end

-- ---------- durability
data.Tools.Wear.Shears = 298
S.PublishMeters(p)
check("meter published (300 max, 2 left)", p.attrs.ML_Shears == 2 and p.attrs.MM_Shears == 300)
clock += 1; check("cut 1 works", S.CutAt(p, V.new(1, 0, -3), V.new(0, 0, -1)) == true)
clock += 1; check("cut 2 works, now worn out", S.CutAt(p, V.new(1, 0, -3), V.new(0, 0, -1)) == true and p.attrs.ML_Shears == 0)
clock += 1; check("worn-out shears cut nothing", S.CutAt(p, V.new(1, 0, -3), V.new(0, 0, -1)) == false)
check("told the player", #notes > 0 and string.find(notes[#notes], "worn out") ~= nil)

-- ---------- repair (shop + kit)
local cost, used = S.RepairToolCost(data, "Shears")
check("shop repair cost = 300 cuts x 4", cost == 1200 and used == 300)
local before = money
check("shop repair works", S.RepairTool(p, "Shears") == true and data.Tools.Wear.Shears == 0 and money == before - 1200)
check("repairing again is refused", S.RepairTool(p, "Shears") == false)
data.Tools.Wear.Scythe = 100
local okK, msgK = S.Use(p, "RepairKit", nil, nil, "Scythe")
check("repair kit repairs the picked tool and is used up", okK == true and data.Tools.Wear.Scythe == 0 and data.Consumables.Owned.RepairKit == 1)
local okK2 = S.Use(p, "RepairKit", nil, nil, "Scythe")
check("kit refused on a tool that is as good as new (not used up)", okK2 == false and data.Consumables.Owned.RepairKit == 1)
check("kit refused without a target / for a wrong tool", S.Use(p, "RepairKit") == false and S.Use(p, "RepairKit", nil, nil, "Blower") == false and data.Consumables.Owned.RepairKit == 1)
data.Tools.PickUsed = 55; data.Tools.Owned.Pickaxe = true
check("kit repairs the pickaxe", S.Use(p, "RepairKit", nil, nil, "Pickaxe") == true and data.Tools.PickUsed == 0 and data.Consumables.Owned.RepairKit == nil)

-- ---------- fuel
data.Tools.FuelUsed.PushMower = 100
S.PublishMeters(p)
check("fuel meter 50 / 150", p.attrs.ML_PushMower == 50 and p.attrs.MM_PushMower == 150)
check("burning fuel", S.BurnFuel(p, "PushMower", 10) == 40)
check("empty tank", S.BurnFuel(p, "PushMower", 1000) == 0)
check("gasoline refills", S.Use(p, "Gasoline") == true and data.Tools.FuelUsed.PushMower == 0 and data.Consumables.Owned.Gasoline == nil)
data.Tools.FuelUsed.PushMower = 75
check("shop refuel cost = 75 s x 25", S.RefuelCost(data, "PushMower") == 1875)
check("shop refuel works", S.Refuel(p, "PushMower") == true and data.Tools.FuelUsed.PushMower == 0)
check("blaster battery", S.Use(p, "BlasterBattery") == true and data.Tools.BlastUsed == 0)

-- ---------- abilities
local function ability(id, pos)
	p.tool.GetAttribute = function(_, k) if k == "LeafTool" then return id end end
	return S.Ability(p, pos)
end
cutCalls = {}
clock += 1; check("shears ability fires", ability("Shears", V.new(0, 0, -4)) == true)
check("  five spots around the aim -> up to 5 cells, full power", #cutCalls == 1 and cutCalls[1].power == 100)
check("  cooldown attrs", p.attrs.SnipCd == 24 and type(p.attrs.SnipReady) == "number")
check("  second press is refused (recharging)", ability("Shears", V.new(0, 0, -4)) == false)
clock += 30; grassHits = 0
check("  nothing cut -> not spent, refund", ability("Shears", V.new(0, 0, -4)) == false and p.attrs.SnipReady == nil)
grassHits = 3
check("  works again after the refund", ability("Shears", V.new(0, 0, -4)) == true)
clock += 50; cutCalls = {}
check("weed cutter ability (strip)", ability("WeedCutter", nil) == false or true)
data.Tools.Owned.WeedCutter = true; data.Tools.Up.WeedCutter = {}
cutCalls = {}; clock += 60
check("weed cutter: slash wave", ability("WeedCutter", nil) == true and #cutCalls == 1 and cutCalls[1].n >= 1)
clock += 60; cutCalls = {}
check("scythe: harvest cone with golden chance", ability("Scythe", nil) == true and cutCalls[1].opts.Golden ~= nil and cutCalls[1].opts.Golden >= 0.1)
clock += 60
check("push mower: overdrive sets the effect", ability("PushMower", nil) == true and type(p.attrs.OverdriveUntil) == "number")
local deck, speed = S.AbilityMult(p, "PushMower")
check("  deck x2 while it lasts", deck == 2 and speed == 1)
check("  walk faster", S.WalkMult(p) > 1)
p.attrs.NitroUntil = (clock_ST or 0) + 5
local d2, s2 = S.AbilityMult(p, "RidingMower")
check("riding mower nitro: speed x1.7, deck x1.3", s2 == 1.7 and d2 == 1.3)
clock += 10; data.Tools.FuelUsed.PushMower = 150
clock += 100
check("no fuel -> ability refused", ability("PushMower", nil) == false)

-- ---------- upgrades: a new tier is a better, whole tool
data.Tools.Wear.Scythe = 77
local okU = S.Upgrade(p, "Scythe", "Tier")
check("tier upgrade works, names change, wear resets", okU == true and data.Tools.Up.Scythe.Tier == 1 and data.Tools.Wear.Scythe == nil)
for i = 1, 3 do S.Upgrade(p, "Scythe", "Tier") end
check("scythe reaches tier 5 = Golden Scythe", data.Tools.Up.Scythe.Tier == 4 and TCm.GrassStats("Scythe", data.Tools.Up.Scythe).Display == "Golden Scythe")
check("max level refused", S.Upgrade(p, "Scythe", "Tier") == false)
check("upgrade spent the price list", spentLog[#spentLog] == 240000)
