-- minimal Roblox stubs so the game's modules load in plain Luau
local V = {}
V.__index = function(t, k)
	if k == "Magnitude" then return math.sqrt(t.X*t.X + t.Y*t.Y + t.Z*t.Z) end
	if k == "Unit" then local m = math.sqrt(t.X*t.X + t.Y*t.Y + t.Z*t.Z); return setmetatable({X=t.X/m,Y=t.Y/m,Z=t.Z/m}, V) end
	if k == "Cross" then return function(a, b) return V.new(a.Y*b.Z-a.Z*b.Y, a.Z*b.X-a.X*b.Z, a.X*b.Y-a.Y*b.X) end end
	if k == "Dot" then return function(a, b) return a.X*b.X + a.Y*b.Y + a.Z*b.Z end end
	return rawget(V, k)
end
V.__add = function(a, b) return setmetatable({X=a.X+b.X,Y=a.Y+b.Y,Z=a.Z+b.Z}, V) end
V.__sub = function(a, b) return setmetatable({X=a.X-b.X,Y=a.Y-b.Y,Z=a.Z-b.Z}, V) end
V.__mul = function(a, b)
	if type(a) == "number" then a, b = b, a end
	if type(b) == "number" then return setmetatable({X=a.X*b,Y=a.Y*b,Z=a.Z*b}, V) end
	return setmetatable({X=a.X*b.X,Y=a.Y*b.Y,Z=a.Z*b.Z}, V)
end
V.__div = function(a, b) return setmetatable({X=a.X/b,Y=a.Y/b,Z=a.Z/b}, V) end
V.__unm = function(a) return setmetatable({X=-a.X,Y=-a.Y,Z=-a.Z}, V) end
function V.new(x, y, z) return setmetatable({X=x or 0,Y=y or 0,Z=z or 0}, V) end
V.zero = V.new(0,0,0); V.yAxis = V.new(0,1,0); V.xAxis = V.new(1,0,0); V.one = V.new(1,1,1)
Vector3 = V
local Cf = {}
Cf.__index = Cf
function Cf.new(...) return setmetatable({LookVector = V.new(0,0,-1)}, Cf) end
function Cf.Angles() return setmetatable({}, Cf) end
Cf.__mul = function(a, b) return a end
typeof = function(v) if getmetatable(v) == V then return "Vector3" end return type(v) end

local Cf = {}
Cf.__index = Cf
function Cf.new() return setmetatable({}, Cf) end
function Cf.Angles() return setmetatable({}, Cf) end
Cf.__mul = function(a) return a end
CFrame = Cf
local function ToolConfigModule()
--[[
	Leaf Rush · ToolConfig (shared, v1.2) — the lawn and every tool besides the broom

	THE LAWN (GrassService): your yard is a grid of 5×5-stud cells. While you play,
	every few minutes a few cells grow a bit (Grass.TickEvery). Growth 0…100:
	    0–29  Normal grass     the broom works normally
	   30–69  Tall grass       broom −15 %
	   70–99  Thick grass      broom −40 %, some leaves get STUCK in it
	     100  OVERGROWN        the broom barely moves anything, everything lying there
	                           is stuck — cut it first
	It grows slowly, only while you are online, only after your first coins, and never
	covers more than MaxShare of the lawn, so it's a small chore, never a wall.
	Collection Zones never grow grass. Cells under trees / decorations grow slower;
	v1.4: every grass tool cuts there too (a tree in tall grass never blocks a cut).

	HOTBAR (bottom of the screen):
	  1 broom · 2 grass tool (the one you picked) · 3 rake · 4 leaf blower · 5 vacuum
	  6 7 8 one-use items (you choose which three in Inventory · TOOLS)

	Everything is bought with Money in SHOP · TOOLS (and with Robux, RobuxConfig).
]]

local T = {}

---------------------------------------------------------------- the lawn
T.Grass = {
	TickEvery = 150, -- seconds between growth steps (online only)
	StartAfterEarned = 300, -- no grass before you earned your first 💰300 (new players)
	NewPatches = { 1, 3 }, -- new spots per step (more on a big lawn, see GrassService)
	NewGrowth = { 14, 20 }, -- a new spot starts with this much
	Growth = { 9, 15 }, -- an existing spot grows by this much per step
	Spread = 0.7, -- chance a new spot starts next to existing grass (patches, not dots)
	MaxShare = 0.4, -- at most this share of the lawn above Normal
	ObjectCellMult = 0.5, -- cells under a tree / decoration grow at half speed
	Tall = 30,
	Thick = 70,
	Over = 100,
	-- broom / rake strength by level (Normal, Tall, Thick, Overgrown)
	BroomMult = { 1, 0.85, 0.6, 0.15 },
	RakeMult = { 1, 1, 0.95, 0.5 },
	StuckChance = { 0, 0, 0.35, 1 }, -- a resource lying there gets stuck
	-- cutting: every 10 growth removed (above 10) = 1 Grass Clippings
	ClipPer = 10,
	ClipFloor = 10,
	StripeTime = 600, -- mower stripes stay this long (seconds)
	RakeFreeTime = 20, -- a raked-free resource can't get stuck again for this long
}

--[[
	v2.43 THE LAWN GETS HARDER WITH EVERY ISLAND (the tiers of IslandConfig; grass starts on
	island 2). Each row is what you get from that island on:
	  Tick     × the time between two growth steps (smaller = it grows more often)
	  Max      the share of the lawn that may be above Normal grass (the lawn gets busier)
	  Infect   chance, per growth step, that every Thick / Overgrown spot SPREADS to a bare
			   neighbour (up to 4 new spots per step) — an untended patch becomes a field
	  Slow     how much grass slows YOU down while you walk in it: { Tall, Thick, Overgrown }
	The WEATHER helps too: WeatherConfig Mods.GrassMult (Rain / Spring / Storm … grow it
	faster: the tick is shorter by that factor and every step adds more).
]]
T.Grass.Islands = {
	{ Tier = 2, Tick = 1, Max = 0.4, Infect = 0, Slow = { 0, 0, 0 } },
	{ Tier = 3, Tick = 0.85, Max = 0.45, Infect = 0, Slow = { 0, 0.1, 0.25 } },
	{ Tier = 4, Tick = 0.75, Max = 0.5, Infect = 0.08, Slow = { 0.05, 0.15, 0.3 } },
	{ Tier = 5, Tick = 0.65, Max = 0.55, Infect = 0.12, Slow = { 0.08, 0.2, 0.38 } },
	{ Tier = 7, Tick = 0.55, Max = 0.6, Infect = 0.16, Slow = { 0.1, 0.26, 0.45 } },
	{ Tier = 9, Tick = 0.45, Max = 0.65, Infect = 0.2, Slow = { 0.13, 0.31, 0.5 } },
	{ Tier = 11, Tick = 0.4, Max = 0.7, Infect = 0.25, Slow = { 0.15, 0.35, 0.55 } },
}
function T.GrassIsland(tier)
	local out = T.Grass.Islands[1]
	for _, row in T.Grass.Islands do
		if (tonumber(tier) or 1) >= row.Tier then
			out = row
		end
	end
	return out
end

function T.Level(g)
	g = g or 0
	if g >= T.Grass.Over then
		return 4
	elseif g >= T.Grass.Thick then
		return 3
	elseif g >= T.Grass.Tall then
		return 2
	end
	return 1
end
T.LevelNames = { "Normal grass", "Tall grass", "Thick grass", "Overgrown" }

---------------------------------------------------------------- grass tools (hotbar slot 2)
-- Kind: "Snip" (click: one small spot) · "Swipe" (swipe the mouse left-right) ·
--       "Swing" (click: a wide arc around you) · "Trimmer" (hold: cuts under the aim) ·
--       "Push" (walk with it) · "Ride" (sit on it and drive, WASD)
T.GrassTools = {
	Shears = {
		Display = "Grass Shears", Rarity = "Common", Price = 0, Kind = "Snip", Icon = "✂️",
		Radius = 2.4, Power = 24, Cooldown = 0.5, Reach = 8, CutsObjects = true,
		Description = "Free shears. Snip Burst cuts five spots at once.",
	},
	WeedCutter = {
		Display = "Grass Cutter", Rarity = "Uncommon", Price = 8000, Kind = "Swipe", Icon = "🔪",
		Radius = 5, Arc = 110, Power = 34, Cooldown = 0.3, Reach = 3,
		Description = "Swipe to cut grass fast. Slash Wave cuts a long strip.",
	},
	Scythe = {
		Display = "Scythe", Rarity = "Rare", Price = 40000, Kind = "Swing", Icon = "🌙",
		Radius = 7.2, Arc = 170, Power = 48, Cooldown = 1, Reach = 0,
		Description = "One wide swing mows rows. Harvest cuts a huge cone.",
	},
	Trimmer = {
		Display = "Lawn Trimmer", Rarity = "Legendary", Price = 1400000, Kind = "Trimmer", Icon = "⚡",
		Radius = 6.2, Power = 14, Rate = 8, Reach = 10, Battery = 60,
		-- v2.40 WHIRL (the strike key / the touch button): the line shoots out to its full
		-- length and you spin once — ALL the grass in a wide ring around you is cut at once
		-- (the server cuts it through GrassService.Cut, so clippings, quests, the lawn
		-- stats and the Mushroom Stump count as always) and the loose leaves around hop
		-- up in the draught. It costs a chunk of battery. Numbers with upgrades: T.Whirl.
		WhirlRadius = 12, WhirlRadiusPer = 1.2, -- studs · + per Cutting Range level (12 -> 18)
		WhirlCooldown = 24, WhirlCooldownPer = 3, -- seconds · − per Blade Speed level (24 -> 9)
		WhirlBattery = 12, -- seconds of battery one whirl costs
		WhirlPower = 100, -- grass cut in every spot of the ring (100 = down to the ground)
		WhirlTime = 0.6, -- seconds the spin takes
		WhirlHop = 9, -- studs/s the loose leaves in the ring hop up with
		Description = "Hold to cut under your aim. Whirl clears a ring.",
	},
	PushMower = {
		Display = "Push Mower", Rarity = "Epic", Price = 300000, Kind = "Push", Icon = "🛒",
		Radius = 2.6, Power = 100, Speed = 16,
		Description = "Walk to mow stripes. Overdrive widens the deck.",
	},
	RidingMower = {
		Display = "Riding Mower", Rarity = "Mythic", Price = 6500000, Kind = "Ride", Icon = "🚜",
		Radius = 6.4, Power = 100, Speed = 27,
		Description = "Drive to mow a wide strip. Nitro is a speed burst.",
	},
}
-- v1.4 the Push Mower is not held in the hand: it is fixed to your body (so it never
-- shakes with the walk animation) and rolls in front of you while you WALK (W A S D).
-- PushOffset = where its bar is, from the HumanoidRootPart; PushDeck = the deck (the
-- part that cuts) from the bar — the same numbers the model is built with.
T.PushOffset = CFrame.new(0, 0.2, -1.2)
T.PushDeck = CFrame.new(0, -2.55, -2.9)
T.GrassOrder = { "Shears", "WeedCutter", "Scythe", "PushMower", "Trimmer", "RidingMower" } -- (v2.43: the Golden Scythe and the Turbo Mower are the last tiers now)
T.StarterGrassTool = "Shears"

-- Lawn Trimmer upgrades (level 0…5): cost = Base × Growth^level (v1.2.1 balance)
T.TrimmerUpgrades = {
	BladeSpeed = { Display = "Blade Speed", Base = 40000, Growth = 2.2, Max = 5, Per = 1.5, Help = "+1.5 cuts/s · Whirl 3 s faster" },
	Range = { Display = "Cutting Range", Base = 40000, Growth = 2.2, Max = 5, Per = 0.5, Help = "+0.5 studs radius · Whirl +1.2" },
	Battery = { Display = "Battery", Base = 25000, Growth = 2.2, Max = 5, Per = 20, Help = "+20 s of battery" },
	Power = { Display = "Cutting Power", Base = 60000, Growth = 2.2, Max = 5, Per = 2.5, Help = "+2.5 grass cut per hit" },
}
T.TrimmerUpgradeOrder = { "BladeSpeed", "Range", "Battery", "Power" }
T.BatteryRecharge = 0.25 -- seconds of battery gained per second while it's off

--[[
	v2.43 THE GRASS TOOLS GROW UP. Shears, Grass Cutter, Scythe, Push Mower and Riding Mower
	have five TIERS (the upgrade "Tier", saved as data.Tools.Up.<Tool>.Tier = 0 … 4, like the
	pickaxe): every tier has its own NAME and LOOK, a bit more reach / power / speed and more
	DURABILITY (the hand tools: cuts before it is worn out; it is repaired for Money in the
	shop or with a Repair Kit) or a bigger FUEL tank (the mowers: seconds of running; Gasoline
	or the shop fills it). The last tier of the Scythe IS the old Golden Scythe, the last tier
	of the Riding Mower IS the old Turbo Mower. The Lawn Trimmer keeps its four stat upgrades;
	its name follows its look (Pro / Turbo / Legendary).
	Every tool has an ABILITY on the strike key (Q) with its own cooldown (T.Abilities); the
	Trimmer's is its Whirl.

	THE LADDER. The tools are meant to be replaced one by one, so each one is clearly better
	than the one before: the BASE of every tool clears more grass per second than the FULLY
	UPGRADED tool before it (by at least 25 %) — T.MowRate says how much grass a tool clears
	per second (the order: Shears → Grass Cutter → Scythe → Push Mower → Trimmer → Riding Mower).
	tests/ladder_test.lua checks it; keep it true when you change a number.
]]
local GRASS_TIERS: { [string]: any } = {
	Shears = { Names = { "Grass Shears", "Iron Shears", "Steel Shears", "Pro Shears", "Golden Shears" }, Costs = { 3000, 9000, 25000, 70000 },
		Durability = { 300, 380, 470, 580, 720 }, RepairPer = 4, Grow = { Radius = 1.03, Power = 1.035, Cooldown = 0.985 } },
	WeedCutter = { Names = { "Grass Cutter", "Sharp Cutter", "Steel Cutter", "Power Cutter", "Master Cutter" }, Costs = { 4000, 10000, 22000, 45000 },
		Durability = { 400, 500, 620, 760, 940 }, RepairPer = 6, Grow = { Radius = 1.03, Power = 1.035, Cooldown = 0.985 } },
	Scythe = { Names = { "Scythe", "Iron Scythe", "Steel Scythe", "Moon Scythe", "Golden Scythe" }, Costs = { 20000, 48000, 110000, 240000 },
		Durability = { 250, 320, 400, 500, 640 }, RepairPer = 20, Grow = { Radius = 1.03, Power = 1.035, Cooldown = 0.985 } },
	PushMower = { Names = { "Push Mower", "Sport Mower", "Power Mower", "Pro Mower", "Master Mower" }, Costs = { 150000, 360000, 800000, 1600000 },
		Fuel = { 150, 190, 235, 285, 345 }, Grow = { Radius = 1.035, Power = 1, Cooldown = 1 } },
	RidingMower = { Names = { "Riding Mower", "Garden Tractor", "Pro Tractor", "Racing Tractor", "Turbo Mower" }, Costs = { 3200000, 7800000, 16000000, 32000000 },
		Fuel = { 200, 255, 320, 395, 480 }, Grow = { Radius = 1.035, Power = 1, Cooldown = 1, Speed = 1.03 } },
}
T.GrassTiers = GRASS_TIERS
T.TrimmerNames = { "Lawn Trimmer", "Pro Trimmer", "Turbo Trimmer", "Legendary Trimmer" }
local GRASS_UP: { [string]: any } = {}
for id, t: any in T.GrassTiers do
	local help = "a better " .. string.lower(t.Names[1])
	GRASS_UP[id] = { Tier = { Display = "Tier", Max = #t.Names - 1, Costs = t.Costs, Help = help } }
end
T.GrassUpgrades = GRASS_UP
-- money to put one point of durability / one second of fuel back (the shop); the one-use
-- items that do it for free (Repair Kit, Gasoline, the batteries) always cost MORE than a
-- full shop refill of the item they belong to (T.CheckItemPrices)
T.FuelPer = { PushMower = 25, RidingMower = 80 } -- Money per second of fuel
T.WearLow = 0.2 -- the gauge warns below this share of the durability / fuel

-- the strike-key abilities (the Trimmer's WHIRL and the Vacuum's VORTEX are in their tools)
-- Cooldown seconds at tier 1, minus Per for every tier above (the server's clock)
T.Abilities = {
	Shears = { Display = "Snip Burst", Icon = "✂️", Cooldown = 24, Per = 2, Spots = 5, Spread = 1.7, Help = "five spots cut at once" },
	WeedCutter = { Display = "Slash Wave", Icon = "🌊", Cooldown = 30, Per = 2.5, Length = 18, LengthPer = 1.5, Help = "cuts a long strip ahead" },
	Scythe = { Display = "Harvest", Icon = "🌾", Cooldown = 40, Per = 3, Range = 15, RangePer = 1.5, Arc = 130, Golden = 0.1, Help = "cuts a huge cone" },
	PushMower = { Display = "Overdrive", Icon = "💨", Cooldown = 45, Per = 3, Time = 8, TimePer = 0.5, Deck = 2, Walk = 1.35, Help = "wider deck, faster walk" },
	RidingMower = { Display = "Nitro", Icon = "🔥", Cooldown = 50, Per = 4, Time = 7, TimePer = 0.5, Deck = 1.3, Boost = 1.7, Help = "a burst of speed" },
}

-- the player attributes of each ability's cooldown: <Name>Ready (server time it is ready again)
-- and <Name>Cd (its length) — the hotbar draws them as a separate bar under the tool, ToolHud /
-- the touch button read them too
T.AbilityAttr = { Shears = "Snip", WeedCutter = "Slash", Scythe = "Harvest", PushMower = "Overdrive", RidingMower = "Nitro", Trimmer = "Whirl", Vacuum = "Vortex", Pickaxe = "Smash", Blower = "Jet" }

-- which tier (1 … 5) a tool has by its upgrade levels (data.Tools.Up[tool])
function T.GrassTierOf(id, levels)
	local t = T.GrassTiers[id]
	if not t then
		return 1
	end
	local lv = type(levels) == "table" and tonumber(levels.Tier) or 0
	if lv ~= lv then
		lv = 0
	end
	return math.clamp(1 + math.floor(lv), 1, #t.Names)
end

local function round(v, d)
	local m = 10 ^ (d or 0)
	return math.floor(v * m + 0.5) / m
end

-- a grass tool WITH its tier: a copy of its table with the tier's name, Radius, Power,
-- Cooldown, Speed, Durability / Fuel, Tier, Ability cooldown (and the Golden Scythe's chance)
function T.GrassStats(id, levels)
	local base = T.GrassTools[id]
	if not base then
		return nil
	end
	local out: any = {}
	for k, v in base do
		out[k] = v
	end
	local tiers = T.GrassTiers[id]
	if tiers then
		local t = T.GrassTierOf(id, levels) - 1
		local g = tiers.Grow
		out.Tier = t + 1
		out.Display = tiers.Names[t + 1]
		out.Radius = round(base.Radius * g.Radius ^ t, 2)
		out.Power = math.min(100, round(base.Power * g.Power ^ t, 1))
		if base.Cooldown then
			out.Cooldown = round(base.Cooldown * g.Cooldown ^ t, 3)
		end
		if base.Speed then
			out.Speed = round(base.Speed * (g.Speed or 1) ^ t, 2)
		end
		out.Durability = tiers.Durability and tiers.Durability[t + 1]
		out.Fuel = tiers.Fuel and tiers.Fuel[t + 1]
		local ab = T.Abilities[id]
		if ab then
			out.AbCooldown = math.max(8, ab.Cooldown - t * ab.Per)
		end
		if id == "Scythe" and t == #tiers.Names - 1 then
			out.GoldenChance = 0.04 -- the last tier = the Golden Scythe: shining Golden Grass
		end
	elseif id == "Trimmer" then
		local tier = T.HelperTier("Trimmer", levels)
		out.Tier = tier
		out.Display = T.TrimmerNames[tier] or base.Display
	end
	return out
end

-- how much grass a tool clears per second in normal use (area × share cut ÷ time): the
-- number the ladder above is built on. Hand tools: the action's area ÷ the slower of its
-- cooldown and a realistic click / swipe / swing rate; mowers: deck width × walking speed;
-- trimmer: the strip its radius sweeps at 9 studs/s + the whirl's ring ÷ its cooldown
local FLOOR = { Snip = 0.3, Swipe = 0.45, Swing = 1 }
function T.MowRate(id, levels)
	local d: any = T.GrassStats(id, levels)
	local pe = math.min(d.Power, 100) / 100
	if d.Kind == "Snip" or d.Kind == "Swipe" or d.Kind == "Swing" then
		local area = math.pi * d.Radius ^ 2 * (if d.Arc then d.Arc / 360 else 1)
		return area * pe / math.max(d.Cooldown, FLOOR[d.Kind])
	elseif d.Kind == "Push" or d.Kind == "Ride" then
		return 2 * d.Radius * d.Speed * pe
	elseif d.Kind == "Trimmer" then
		local tr, wh = T.Trimmer(levels), T.Whirl(levels)
		return 2 * tr.Radius * 9 * math.min(tr.Power * tr.Rate, 100) / 100 + math.pi * wh.Radius ^ 2 / wh.Cooldown
	end
	return 0
end

-- the levels of a tool with every upgrade at its top
function T.TopLevels(tool)
	local out = {}
	for stat, u in T.UpgradesOf(tool) or {} do
		out[stat] = u.Max
	end
	return out
end

-- money for a full repair / refuel by how much is missing
function T.WearRepairCost(id, tier, used)
	local t = T.GrassTiers[id]
	if not t or not t.RepairPer then
		return 0
	end
	local cap = t.Durability[math.clamp(tier, 1, #t.Durability)]
	return math.ceil(math.clamp(used, 0, cap) * t.RepairPer)
end
function T.FuelCost(id, secondsMissing)
	return math.ceil(math.max(0, secondsMissing) * (T.FuelPer[id] or 0))
end

---------------------------------------------------------------- helper tools (slots 3, 4, 5)
T.Helpers = {
	Rake = {
		Display = "Rake", Rarity = "Rare", Price = 25000, Slot = 3, Icon = "🧤",
		-- v1.2.1: NOT a broom. It PULLS: drag it toward you and the tines drag every
		-- leaf along; pushed away the tines slide over them. Q = GATHER: everything
		-- around the head is raked into one tight pile (Big Pile bonus in your zone).
		-- Works in tall grass and pulls stuck leaves out of thick grass.
		Stats = { Power = 6, SweepSize = 62, Speed = 14, Control = 80, Luck = 0, Durability = 35 },
		LoosenRadius = 3.2, -- frees stuck leaves in thick grass it passes over
		GatherRadius = 8, -- Q: rakes everything this close into one pile
		GatherCooldown = 4,
		-- (v2.40: these are the numbers WITHOUT upgrades — T.RakeUpgrades / T.Rake(levels))
		Description = "Pulls leaves toward you. Gather makes one big pile.",
	},
	Blower = {
		Display = "Leaf Blower", Rarity = "Epic", Price = 90000, Slot = 4, Icon = "💨",
		Range = 13, Cone = 28, Force = 22, -- (v1.4: a bit stronger from the start)
		PlayerPush = 26, PlayerLift = 9, PlayerEvery = 0.35, -- v1.4: it pushes players in front of it
		Energy = 30, -- v2.32: seconds of blowing on a full charge (upgrade "Energy": up to 180 s)
		-- v2.34 JET mode (the strike key / the touch button switches BLOW <-> JET): the gust
		-- is turned round and carries YOU away from where you aim (aim at the ground = up).
		-- Speeds in studs/s — JetMaxSpeed stays well under the movement guard's 45 studs/s
		-- (Config.Movement), so the server never pulls a flying player back.
		-- v2.35: everything grows with the Blow Force upgrade: Lvl 0 -> max level
		JetSpeed = 16, JetSpeedMax = 33, JetMaxSpeed = 33, -- horizontal speed 16 -> 33
		JetAccel = 75, JetSteer = 7, -- how fast it picks up speed · how much walking input steers
		JetLiftMin = 16, JetLift = 32, JetLiftG = 1.9, JetMinHeight = 12, JetMaxHeight = 40, -- climb 16 -> 32 · ceiling 12 -> 40 -- climb speed · lift (× gravity) · ceiling above the ground
		JetCooldown = 20, -- v2.43: seconds before the JET (strike key) can be started again after it was used (+ per level below)
		JetCooldownPer = -1, -- (−1 s per Blow Force level: 20 -> 15 s — never short)
		Description = "Blows leaves away from you. Jet carries you.",
	},
	Vacuum = {
		Display = "Vacuum", Rarity = "Legendary", Price = 450000, Slot = 5, Icon = "🌀",
		-- v1.2.1: a helper for the last leaves, not a broom replacement: short reach,
		-- slow, wears out fast (a broom sweeps whole piles at once)
		Range = 3.5, Rate = 1.5, Capacity = 100,
		-- v2.38 VORTEX (the strike key / the touch button): a whirlwind is planted at the
		-- aim point for VortexTime seconds. It pulls every loose item within its radius
		-- into one tight spiral pile (the owner's client moves its own parts — WorldFX
		-- "Push", Mode "Swirl"), then the vacuum swallows the pile in ONE gulp: everything
		-- within VortexGulp studs of the centre is paid exactly like normal vacuuming
		-- (and wears the vacuum by one per item). Numbers with upgrades: T.Vortex.
		VortexRadius = 12, VortexRadiusPer = 1.2, -- studs · + per Suction Power level (12 -> 18)
		VortexTime = 3, -- seconds the whirlwind turns before the gulp
		VortexCooldown = 45, VortexCooldownPer = 4, -- seconds · − per Suction Speed level (45 -> 25)
		VortexCast = 18, -- how far from you it can be planted
		VortexGulp = 5.5, -- what lies this close to its centre at the end is swallowed
		VortexSpeed = 11, -- studs/s the items are pulled with
		VortexMax = 150, -- items in one gulp at most (and never more than the capacity left)
		Description = "Sucks up leaves and pays at once. Vortex pulls a pile.",
	},
	-- v2.32: breaks the BLOCKS of your garden (BlockConfig: reach, swings per block).
	-- Kind "Pick": it has its own controller on the client (Pickaxe), not ToolController.
	Pickaxe = {
		Display = "Pickaxe", Rarity = "Common", Price = 2500, Slot = 6, Icon = "⛏", Kind = "Pick",
		Description = "Breaks blocks. Smash breaks 3×3 at once.",
	},
	-- v2.42 the LEAF BLASTER (hotbar: after the pickaxe). Fires small AIR PULSES: every pulse
	-- hits (items fly away) -> the flying items crash into the ones lying around and bounce
	-- off them. Magazine of 6 pulses, then it RELOADS. It never moves STONE items (mutation
	-- Stone) or items locked in ICE (Deep Freeze), and it shoves other players (no damage).
	-- Upgrades (T.BlasterUpgrades): Power, Fire Rate, Pulse Size, Energy. Numbers with
	-- upgrades: T.Blaster(levels). Its energy = pulses on one charge (data.Tools.BlastUsed).
	Blaster = {
		Display = "Leaf Blaster", Rarity = "Mythic", Price = 8000000, Slot = 7, Icon = "🔫", Kind = "Blaster",
		Magazine = 6, -- pulses before the reload
		Power = 24, -- studs/s the first items hit fly away with (+4.5 per Pulse Power level)
		FireEvery = 0.55, -- seconds between two pulses (−0.06 per Fire Rate level)
		Reload = 3.6, -- seconds of reloading after the last pulse (−0.25 per Fire Rate level: 3.6 -> 2.35)
		Size = 2.2, -- studs: radius of a pulse (+0.5 per Pulse Size level)
		Range = 34, -- studs a pulse flies (+1.5 per Pulse Size level)
		PulseSpeed = 85, -- studs/s the pulse itself flies
		PlayerPush = 30, PlayerLift = 10, -- the shove other players get (+12 % per Pulse Power level)
		Energy = 60, -- pulses on a full charge (upgrade "Energy": up to 360)
		Description = "Shoots air pulses that knock leaves away.",
	},
}

--[[
	v2.38 the PICKAXE's TIERS, DURABILITY and SMASH
	One Pickaxe tool, upgraded in SHOP · TOOLS (the upgrade "Tier" of T.PickaxeUpgrades,
	saved as data.Tools.Up.Pickaxe.Tier = 0 … 4): Stone -> Iron -> Gold -> Diamond -> Rainbow.
	  Hits        swings per block by its code (D earth, S sand, L wood, R stone, W water);
	              a block kind that is not listed takes ceil(its own Hits × HitMult)
	  HitEvery    seconds per swing · Reach  studs from you to the block
	  Durability  blocks it breaks before it is BROKEN (data.Tools.PickUsed counts them;
	              water is scooped up for free). A broken pickaxe mines nothing until it
	              is repaired: RepairPer Money for every point that is missing.
	  Smash       seconds the SMASH (strike key: 3×3 blocks in one blow) recharges
	(No "Price" / "Rarity" in these tables on purpose: StockConfig would sell them as tools.)
]]
T.PickaxeTiers = {
	-- v2.44: weak pickaxes take MANY swings (Hits per block code: D earth, S sand, L wood, R stone, W water);
	-- the Rainbow pickaxe breaks every block with the first swing
	{ Id = "Stone", Name = "Stone", Hits = { D = 4, S = 4, L = 6, R = 10, W = 1 }, HitMult = 1, HitEvery = 0.34, Reach = 14, Durability = 150, Smash = 90, RepairPer = 10 },
	{ Id = "Iron", Name = "Iron", Cost = 40000, Hits = { D = 3, S = 3, L = 4, R = 7, W = 1 }, HitMult = 0.8, HitEvery = 0.32, Reach = 15, Durability = 350, Smash = 75, RepairPer = 14 },
	{ Id = "Gold", Name = "Gold", Cost = 250000, Hits = { D = 2, S = 2, L = 3, R = 4, W = 1 }, HitMult = 0.6, HitEvery = 0.3, Reach = 16, Durability = 700, Smash = 60, RepairPer = 18 },
	{ Id = "Diamond", Name = "Diamond", Cost = 1200000, Hits = { D = 1, S = 1, L = 2, R = 2, W = 1 }, HitMult = 0.4, HitEvery = 0.27, Reach = 18, Durability = 1200, Smash = 45, RepairPer = 24 },
	{ Id = "Rainbow", Name = "Rainbow", Cost = 6000000, Hits = { D = 1, S = 1, L = 1, R = 1, W = 1 }, HitMult = 0.2, HitEvery = 0.24, Reach = 20, Durability = 2000, Smash = 30, RepairPer = 30 },
}
for i, t in T.PickaxeTiers do
	t.Index = i
end
T.PickaxeUpgrades = {
	Tier = { Display = "Tier", Max = #T.PickaxeTiers - 1, Costs = {}, Help = "a better pickaxe" },
}
for i = 2, #T.PickaxeTiers do
	T.PickaxeUpgrades.Tier.Costs[i - 1] = T.PickaxeTiers[i].Cost
end
T.PickaxeUpgradeOrder = { "Tier" }
T.PickaxeLow = 0.15 -- the gauge warns below this share of the durability (or below 10 blocks)

-- the tier 1 … 5 of a pickaxe by its upgrade levels (data.Tools.Up.Pickaxe)
function T.PickaxeTier(levels)
	local lv = type(levels) == "table" and tonumber(levels.Tier) or 0
	if lv ~= lv then
		lv = 0
	end
	return math.clamp(1 + math.floor(lv), 1, #T.PickaxeTiers)
end

-- the pickaxe with its upgrades: the tier's table (Index, Name, HitEvery, Reach, Durability, Smash …)
function T.Pickaxe(levels)
	return T.PickaxeTiers[T.PickaxeTier(levels)]
end

-- swings a block of this code takes with a pickaxe of this tier (baseHits = BlockConfig's Hits)
function T.PickaxeHits(tier, code, baseHits)
	local t = T.PickaxeTiers[math.clamp(math.floor(tonumber(tier) or 1), 1, #T.PickaxeTiers)]
	baseHits = math.max(1, math.floor(tonumber(baseHits) or 1))
	local h = t.Hits and t.Hits[code]
	if not h then
		h = math.ceil(baseHits * (t.HitMult or 1) - 1e-6)
	end
	return math.clamp(h, 1, math.max(baseHits, h)) -- (v2.44: a weak pickaxe may need MORE swings than the block's base number)
end

-- Money to repair a pickaxe of this tier that has broken `used` blocks since its last repair
function T.PickaxeRepairCost(tier, used)
	local t = T.PickaxeTiers[math.clamp(math.floor(tonumber(tier) or 1), 1, #T.PickaxeTiers)]
	used = math.clamp(math.floor(tonumber(used) or 0), 0, t.Durability)
	return math.ceil(used * t.RepairPer)
end

--[[
	SMASH: which cells one heavy blow breaks. (cx, cz, level) = the block you point at,
	axis = the axis the FACE you point at looks along:
	  "Y"  its top (or bottom): you look down at the ground -> the 3×3 SLAB of that level
	  "X"  a side facing east / west  -> the 3×3 WALL in front of you (cz−1…cz+1 × 3 levels)
	  "Z"  a side facing north / south -> the 3×3 WALL in front of you (cx−1…cx+1 × 3 levels)
	So it always breaks the square you see around the block, never the blocks behind it.
	-> { { cx, cz, level } … } inside the garden (n × n cells, maxLevels high), the
	   targeted block first, then the ones next to it, the corners last.
]]
function T.SmashCells(cx, cz, level, axis, n, maxLevels)
	local out = {}
	for ring = 0, 2 do
		for a = -1, 1 do
			for b = -1, 1 do
				if math.abs(a) + math.abs(b) == ring then
					local x, z, l = cx, cz, level
					if axis == "X" then
						z, l = cz + a, level + b
					elseif axis == "Z" then
						x, l = cx + a, level + b
					else
						x, z = cx + a, cz + b
					end
					if x >= 0 and z >= 0 and x < n and z < n and l >= -4 and l <= maxLevels then
						table.insert(out, { x, z, l })
					end
				end
			end
		end
	end
	return out
end

-- the axis a direction looks along most ("X" / "Y" / "Z"): the face of a block you see
-- from that direction (used when nothing better is known)
function T.SmashAxis(dx, dy, dz)
	dx, dy, dz = math.abs(tonumber(dx) or 0), math.abs(tonumber(dy) or 0), math.abs(tonumber(dz) or 0)
	if dy >= dx and dy >= dz then
		return "Y"
	elseif dx >= dz then
		return "X"
	end
	return "Z"
end
T.HelperOrder = { "Rake", "Blower", "Vacuum", "Pickaxe", "Blaster" }

--[[
	v2.40 RAKE upgrades (level 0…5, saved as data.Tools.Up.Rake). The rake sweeps with the
	broom's physics (BroomTypes.Physics: head width = 2.2 + SweepSize × 0.05 studs), so:
	  Width   +8 Sweep Size per level = the head is 0.4 studs wider (5.3 -> 7.3 studs);
	          the strip in which it frees leaves stuck in thick grass grows with it
	          (LoosenRadius 3.2 -> 4.7). The collider on the server, the client's sweep
	          and the model in the hand all use T.Rake(levels).Stats.
	  Gather  the strike key's GATHER reaches further: 8 -> 14 studs (more leaves in one pile)
	  Quick   the GATHER recharges faster: 4 -> 1.5 s
]]
T.RakeUpgrades = {
	Width = { Display = "Tine Width", Base = 10000, Growth = 2.1, Max = 5, Per = 8, PerLoosen = 0.3, Help = "+0.4 studs wider head" },
	Gather = { Display = "Gather Radius", Base = 8000, Growth = 2.1, Max = 5, Per = 1.2, Help = "+1.2 studs GATHER radius" },
	Quick = { Display = "Quick Gather", Base = 12000, Growth = 2.1, Max = 5, Per = 0.5, Help = "GATHER recharges 0.5 s faster" },
}
T.RakeUpgradeOrder = { "Width", "Gather", "Quick" }

-- Vacuum upgrades (level 0…5)
T.VacuumUpgrades = {
	Power = { Display = "Suction Power", Base = 150000, Growth = 2.2, Max = 5, Per = 0.6, Help = "+0.6 studs reach" },
	Speed = { Display = "Suction Speed", Base = 200000, Growth = 2.2, Max = 5, Per = 0.6, Help = "+0.6 items per second" },
	Capacity = { Display = "Capacity", Base = 250000, Growth = 2, Max = 5, Help = "items before it breaks" },
}

-- v1.2.1 Leaf Blower upgrades (level 0…5)
T.BlowerUpgrades = {
	Force = { Display = "Blow Force", Base = 30000, Growth = 2.1, Max = 5, Per = 3, Help = "+3 studs/s blow speed" },
	Range = { Display = "Blow Range", Base = 30000, Growth = 2.1, Max = 5, Per = 1.5, Help = "+1.5 studs reach" },
	Cone = { Display = "Nozzle Width", Base = 20000, Growth = 2.1, Max = 5, Per = 4, Help = "+4° wider stream" },
	-- v2.32: how long it blows on one charge (T.BlowerEnergy: 30 → 60 → 90 → 120 → 150 → 180 s)
	Energy = { Display = "Energy", Base = 25000, Growth = 2.1, Max = 5, Help = "+30 s of blowing" },
}
T.BlowerUpgradeOrder = { "Force", "Range", "Cone", "Energy" }
-- v2.32 the Leaf Blower's ENERGY: seconds of blowing by its "Energy" level. It is used
-- up only while it really blows (the server counts), never comes back by itself and is
-- refilled like the vacuum is repaired — for Money in the shop (by how empty it is) —
-- or at once with a Blower Battery (one-use item).
T.BlowerEnergy = { [0] = 30, 60, 90, 120, 150, 180 }
T.BlowerRechargePerSecond = 50 -- Money per second of energy put back
T.BlowerLow = 0.2 -- the gauge warns below this share (or below 6 s)
T.VacuumUpgradeOrder = { "Power", "Speed", "Capacity" }
T.VacuumCapacity = { [0] = 100, 200, 350, 500, 750, 1000 }
T.VacuumRepairPerItem = 60 -- Money per item of capacity

--[[
	v2.42 the LEAF BLASTER's upgrades (level 0…5, saved as data.Tools.Up.Blaster)
	  Power   +4.5 studs/s: the items it hits fly faster and further, players are shoved harder
	  Rate    0.06 s less between two pulses · 0.2 s less to reload (0.55 -> 0.25 s · 2.4 -> 1.4 s)
	  Size    +0.5 studs wider pulse (hits more items at once) · +1.5 studs range
	  Energy  pulses on one charge: 60 -> 100 -> 150 -> 210 -> 280 -> 360. Used up one per pulse,
			  never comes back by itself: put back for Money in the shop (by how empty it is).
	The look follows the sum of Power + Rate + Size (the blower's tiers, T.HelperTier).
]]
T.BlasterUpgrades = {
	Power = { Display = "Pulse Power", Base = 900000, Growth = 2, Max = 5, Per = 4.5, Help = "+4.5 studs/s pulse speed" },
	Rate = { Display = "Fire Rate", Base = 900000, Growth = 2, Max = 5, Per = 0.06, Help = "0.06 s faster shots" },
	Size = { Display = "Pulse Size", Base = 800000, Growth = 2, Max = 5, Per = 0.5, Help = "+0.5 studs wider pulse" },
	Energy = { Display = "Energy", Base = 700000, Growth = 2, Max = 5, Help = "more pulses per charge" },
}
T.BlasterUpgradeOrder = { "Power", "Rate", "Size", "Energy" }
T.BlasterEnergy = { [0] = 60, 100, 150, 210, 280, 360 }
T.BlasterRechargePerShot = 120 -- Money per pulse of energy put back (a full charge of the best blaster: 43,200)
T.BlasterLow = 0.2 -- the gauge warns below this share (or below 6 pulses)

---------------------------------------------------------------- one-use items (slots 6, 7, 8)
T.Consumables = {
	LeafMagnet = {
		Display = "Leaf Magnet", Rarity = "Rare", Price = 9000, Icon = "🧲",
		Duration = 20, Radius = 12, Pull = 8, -- (v2.43: no Pickup: only the Mega Magnet collects by itself)
		-- v1.7: it really pulls now (the old drift was eaten by ground friction), and
		-- whatever reaches you is picked up at once, as if it reached your Collect zone
		Description = "20 s: leaves near you drift to you.",
	},
	GrassKiller = {
		Display = "Grass Killer", Rarity = "Uncommon", Price = 4000, Icon = "🧴", Target = true,
		Radius = 7,
		Description = "Removes all grass on a spot. No clippings.",
	},
	BatteryPack = {
		Display = "Battery Pack", Rarity = "Uncommon", Price = 12000, Icon = "🔋", Needs = "Trimmer",
		Description = "Fully recharges your Lawn Trimmer.",
	},
	TurboFuel = {
		Display = "Turbo Fuel", Rarity = "Epic", Price = 20000, Icon = "⛽", NeedsMower = true,
		Duration = 45, SpeedMult = 1.5,
		Description = "45 seconds: +50% lawn mower speed.",
	},
	MegaMagnet = {
		Display = "Mega Magnet", Rarity = "Legendary", Price = 250000, Icon = "🌟",
		Duration = 40, Radius = 18, Pull = 14, Pickup = 5,
		-- v1.7: lasts twice as long as the Leaf Magnet (it was shorter: 12 s)
		Description = "40 s: leaves fly to you and are collected.",
	},
	-- v2.32: a full charge for the Leaf Blower (its energy gauge)
	BlowerBattery = {
		Display = "Blower Battery", Rarity = "Rare", Price = 18000, Icon = "🔌", Needs = "Blower",
		Description = "Fully recharges your Leaf Blower.",
	},
	-- v2.38: the VACUUM's battery — puts its whole capacity back (exactly what the paid
	-- repair does), anywhere. Dearer than the two other batteries; a full repair costs
	-- 💰60 per item of capacity (6,000 at Capacity 100 … 60,000 at 1,000): the shop's
	-- repair is cheaper up to Capacity level 2, the same at level 3 (500 items) and
	-- dearer from level 4 on — there the battery (rare in stock) is the better deal.
	VacuumBattery = {
		Display = "Vacuum Battery", Rarity = "Epic", Price = 95000, Icon = "🔋", Needs = "Vacuum",
		Description = "Fully restores your Vacuum's capacity.",
	},
	-- v2.43: a full charge for the Leaf Blaster (its energy gauge)
	BlasterBattery = {
		Display = "Blaster Battery", Rarity = "Epic", Price = 120000, Icon = "🔋", Needs = "Blaster",
		Description = "Fully recharges your Leaf Blaster.",
	},
	-- v2.43: fills the fuel tank of the Push Mower AND the Riding Mower
	Gasoline = {
		Display = "Gasoline", Rarity = "Epic", Price = 60000, Icon = "⛽", NeedsMower = true, Fuel = true,
		Description = "Fills the fuel tank of both mowers.",
	},
	-- v2.43: repairs ONE of Shears, Grass Cutter, Scythe, Pickaxe — use it, then pick the tool
	-- in the panel (the ones in your hotbar)
	RepairKit = {
		Display = "Repair Kit", Rarity = "Epic", Price = 75000, Icon = "🧰", ToolTarget = true,
		Description = "Repairs one tool fully.",
	},
	-- v2.51: GRASS SALT — pick a grass spot (a lawn cell or the top of an Earth block): grass never
	-- grows there again. Pricey (the dearest of the everyday items after the Big Toy's league):
	-- above the Repair Kit (75,000) and Gasoline (60,000), below the Mega Magnet (250,000).
	-- While it is in the hand every spot without grass glows (GrassFX; GrassService.MakeBare)
	GrassSalt = {
		Display = "Grass Salt", Rarity = "Legendary", Price = 200000, Icon = "🧂", Target = true,
		Radius = 2.5,
		Description = "Grass on one spot never grows back.",
	},
	-- v2.32 PET TOYS: use one, pick one of your EQUIPPED pets — for 5 minutes its ability
	-- recharges faster and is stronger by Boost (PetConfig.BoostValue / PetAbilityService.Boost).
	-- PetTarget = the client opens the pet picker; the server gets { Action = "Use", Id, Pet = uid }.
	SmallToy = {
		Display = "Small Toy", Rarity = "Rare", Price = 10000, Icon = "🧸", PetTarget = true,
		Boost = 0.10, Duration = 300,
		Description = "5 min: pet ability 10% faster and stronger.",
	},
	MediumToy = {
		Display = "Medium Toy", Rarity = "Epic", Price = 40000, Icon = "🧸", PetTarget = true,
		Boost = 0.25, Duration = 300,
		Description = "5 min: pet ability 25% faster and stronger.",
	},
	BigToy = {
		Display = "Big Toy", Rarity = "Legendary", Price = 150000, Icon = "🧸", PetTarget = true,
		Boost = 0.50, Duration = 300,
		Description = "5 min: pet ability 50% faster and stronger.",
	},
}
-- (round 15, harvest) the Cow's MILK BOTTLE: NEVER sold (NotSold: no shop, no stock, no auto-buy, no Money purchase).
-- A Cow drops bottles in your garden; walk over one to pick it up. Use it on one EQUIPPED pet (the toy picker, or
-- 🥛 GIVE MILK in the pet panel): +Boost ability power and speed for Duration — a second bottle only refreshes the
-- time (never stacks). It adds to a toy's boost (PetAbilityService.EffBoost).
T.Consumables.MilkBottle = {
	Display = "Milk Bottle", Rarity = "Epic", Price = 50000, Icon = "🥛", PetTarget = true, Milk = true, NotSold = true,
	Boost = 0.15, Duration = 300,
	Description = "5 min: a pet's ability works 15% better.",
}
T.ConsumableOrder = { "LeafMagnet", "GrassKiller", "BatteryPack", "TurboFuel", "MegaMagnet", "BlowerBattery", "VacuumBattery", "BlasterBattery", "Gasoline", "RepairKit", "GrassSalt", "SmallToy", "MediumToy", "BigToy" }
table.insert(T.ConsumableOrder, "MilkBottle") -- (round 15: the inventory / trades list it; shops skip NotSold)
T.RepairTargets = { Shears = true, WeedCutter = true, Scythe = true, Pickaxe = true } -- (what a Repair Kit mends)
T.ConsumableSlots = 3
T.MaxStack = math.huge -- (v2.37: no limit on one-use items — nothing refuses by it any more)

---------------------------------------------------------------- helpers
function T.Def(id)
	return T.GrassTools[id] or T.Helpers[id] or T.Consumables[id]
end

function T.KindOf(id)
	if T.GrassTools[id] then
		return "Grass"
	elseif T.Helpers[id] then
		return "Helper"
	elseif T.Consumables[id] then
		return "Consumable"
	end
	return nil
end

-- v2.43: the one-use items that refill something must cost MORE than the shop's full refill
-- of the best version of that thing (it is a convenience: use it anywhere, at once).
-- -> list of problems (empty = fine); tests/ladder_test.lua runs it
function T.CheckItemPrices()
	local bad = {}
	local function need(item, cost, what)
		if T.Consumables[item].Price <= cost then
			table.insert(bad, string.format("%s (%d) must cost more than %s (%d)", item, T.Consumables[item].Price, what, cost))
		end
	end
	need("BlowerBattery", T.RechargeCost(T.BlowerEnergy[5]), "a full Blower recharge")
	need("BlasterBattery", T.BlasterRechargeCost(T.BlasterEnergy[5]), "a full Blaster recharge")
	need("VacuumBattery", T.RepairCost(T.VacuumCapacity[5]), "a full Vacuum repair")
	need("Gasoline", math.max(T.FuelCost("PushMower", T.GrassTiers.PushMower.Fuel[5]), T.FuelCost("RidingMower", T.GrassTiers.RidingMower.Fuel[5])), "a full refuel")
	local worst = 0
	for id, t: any in T.GrassTiers do
		if t.Durability then
			worst = math.max(worst, T.WearRepairCost(id, 5, t.Durability[5]))
		end
	end
	worst = math.max(worst, T.PickaxeRepairCost(5, T.PickaxeTiers[5].Durability))
	need("RepairKit", worst, "the dearest full repair")
	-- (the Trimmer's battery recharges for free, so its Battery Pack only has to be a small buy)
	return bad
end

function T.UpgradeCost(tool, stat, level)
	local ups = T.UpgradesOf(tool)
	local u = ups and ups[stat]
	if not u or level >= u.Max then
		return nil
	end
	if u.Costs then
		return u.Costs[level + 1] -- v2.38: a price list (the pickaxe's tiers)
	end
	return math.floor(u.Base * (u.Growth or 2) ^ level)
end

-- the trimmer with its upgrades: radius, power per hit, hits per second, battery seconds
function T.Trimmer(levels)
	levels = levels or {}
	local d, U = T.GrassTools.Trimmer, T.TrimmerUpgrades
	return {
		Radius = d.Radius + (levels.Range or 0) * U.Range.Per,
		Power = d.Power + (levels.Power or 0) * U.Power.Per,
		Rate = d.Rate + (levels.BladeSpeed or 0) * U.BladeSpeed.Per,
		Battery = d.Battery + (levels.Battery or 0) * U.Battery.Per,
		Reach = d.Reach,
	}
end

-- the vacuum with its upgrades: reach, items per second, capacity
function T.Vacuum(levels)
	levels = levels or {}
	local d, U = T.Helpers.Vacuum, T.VacuumUpgrades
	return {
		Range = d.Range + (levels.Power or 0) * U.Power.Per,
		Rate = d.Rate + (levels.Speed or 0) * U.Speed.Per,
		Capacity = T.VacuumCapacity[math.clamp(levels.Capacity or 0, 0, 5)],
	}
end

-- v2.40 the trimmer's WHIRL with its upgrades: Cutting Range = a wider ring,
-- Blade Speed = a shorter recharge
function T.Whirl(levels)
	levels = if type(levels) == "table" then levels else {}
	local d = T.GrassTools.Trimmer
	local function lv(stat)
		local v = tonumber(levels[stat]) or 0
		if v ~= v then
			v = 0
		end
		return math.clamp(math.floor(v), 0, 5)
	end
	return {
		Radius = d.WhirlRadius + lv("Range") * d.WhirlRadiusPer,
		Cooldown = math.max(8, d.WhirlCooldown - lv("BladeSpeed") * d.WhirlCooldownPer),
		Battery = d.WhirlBattery,
		Power = d.WhirlPower,
		Time = d.WhirlTime,
		Hop = d.WhirlHop,
	}
end

-- v2.40 the rake with its upgrades: Stats (the broom stats it sweeps with — a table of
-- its own, never the config's), Width (studs, what BroomTypes.Physics makes of the
-- Sweep Size), LoosenRadius, GatherRadius, GatherCooldown
function T.Rake(levels)
	levels = if type(levels) == "table" then levels else {}
	local d, U = T.Helpers.Rake, T.RakeUpgrades
	local function lv(stat)
		local v = tonumber(levels[stat]) or 0
		if v ~= v then
			v = 0
		end
		return math.clamp(math.floor(v), 0, U[stat].Max)
	end
	local stats = {}
	for k, v in d.Stats do
		stats[k] = v
	end
	stats.SweepSize = d.Stats.SweepSize + lv("Width") * U.Width.Per
	return {
		Stats = stats,
		SweepSize = stats.SweepSize,
		Width = 2.2 + stats.SweepSize * 0.05, -- (= BroomTypes.Physics(stats).Width)
		LoosenRadius = d.LoosenRadius + lv("Width") * U.Width.PerLoosen,
		GatherRadius = d.GatherRadius + lv("Gather") * U.Gather.Per,
		GatherCooldown = math.max(1, d.GatherCooldown - lv("Quick") * U.Quick.Per),
	}
end

-- v2.38 the vacuum's VORTEX with its upgrades: Suction Power = a wider whirlwind,
-- Suction Speed = a shorter recharge
function T.Vortex(levels)
	levels = levels or {}
	local d = T.Helpers.Vacuum
	local power = math.clamp(math.floor(tonumber(levels.Power) or 0), 0, 5)
	local speed = math.clamp(math.floor(tonumber(levels.Speed) or 0), 0, 5)
	return {
		Radius = d.VortexRadius + power * d.VortexRadiusPer,
		Time = d.VortexTime,
		Cooldown = math.max(10, d.VortexCooldown - speed * d.VortexCooldownPer),
		Cast = d.VortexCast,
		Gulp = d.VortexGulp,
		Speed = d.VortexSpeed,
		Max = d.VortexMax,
	}
end

-- the leaf blower with its upgrades: reach, stream half-angle, blow speed
function T.Blower(levels)
	levels = levels or {}
	local d, U = T.Helpers.Blower, T.BlowerUpgrades
	return {
		JetCooldown = math.max(10, d.JetCooldown + (tonumber(levels.Force) or 0) * d.JetCooldownPer),
		Range = d.Range + (levels.Range or 0) * U.Range.Per,
		Cone = d.Cone + (levels.Cone or 0) * U.Cone.Per,
		Force = d.Force + (levels.Force or 0) * U.Force.Per,
		Energy = T.BlowerEnergy[math.clamp(math.floor(tonumber(levels.Energy) or 0), 0, 5)] or d.Energy, -- v2.32: seconds of blowing
	}
end

-- v2.42 the leaf blaster with its upgrades: magazine, pulse speed (items), fire rate, reload,
-- pulse radius / range, the shove players get, energy (pulses on a full charge)
function T.Blaster(levels)
	levels = if type(levels) == "table" then levels else {}
	local d, U = T.Helpers.Blaster, T.BlasterUpgrades
	local function lv(stat)
		local v = tonumber(levels[stat]) or 0
		if v ~= v then
			v = 0
		end
		return math.clamp(math.floor(v), 0, U[stat].Max)
	end
	return {
		Magazine = d.Magazine,
		-- every upgrade at its top: the pulses break ice (IceDamage per pulse; a block has 3 hit points)
		-- and nudge stone items a little (a quarter of a leaf's speed)
		Maxed = lv("Power") >= 5 and lv("Rate") >= 5 and lv("Size") >= 5 and lv("Energy") >= 5,
		IceDamage = if lv("Power") >= 5 and lv("Rate") >= 5 and lv("Size") >= 5 and lv("Energy") >= 5 then 1 else nil,
		StoneNudge = lv("Power") >= 5 and lv("Rate") >= 5 and lv("Size") >= 5 and lv("Energy") >= 5,
		Power = d.Power + lv("Power") * U.Power.Per,
		FireEvery = math.max(0.2, d.FireEvery - lv("Rate") * U.Rate.Per),
		Reload = math.max(2, d.Reload - lv("Rate") * 0.25),
		Size = d.Size + lv("Size") * U.Size.Per,
		Range = d.Range + lv("Size") * 1.5,
		Speed = d.PulseSpeed,
		PlayerPush = d.PlayerPush * (1 + lv("Power") * 0.12),
		PlayerLift = d.PlayerLift,
		Energy = T.BlasterEnergy[lv("Energy")] or d.Energy,
	}
end

-- v2.42: Money to put `shots` pulses of energy back into the Leaf Blaster
function T.BlasterRechargeCost(shots)
	return math.ceil(math.max(0, shots) * T.BlasterRechargePerShot)
end

-- v2.32: Money to put `seconds` of energy back into the Leaf Blower
function T.RechargeCost(seconds)
	return math.ceil(math.max(0, seconds) * T.BlowerRechargePerSecond)
end

-- the upgrade table of a tool (nil = it has none)
-- v1.7: how upgraded the Leaf Blower / Vacuum looks: tier 1 … 4 by the SUM of its
-- upgrade levels (0-3 → 1 Basic, 4-7 → 2 Pro, 8-11 → 3 Turbo, 12-15 → 4 Legendary).
-- The model changes with the tier and it blows / sucks with more and more effects.
T.TierNames = { "Basic", "Pro", "Turbo", "Legendary" }
T.TierStep = 4
-- v2.41: the RAKE and the LAWN TRIMMER change their look with their upgrades too.
--   Rake     3 upgrades × 5 levels = 0…15, the same steps as the blower / vacuum:
--            0-3 Basic · 4-7 Pro · 8-11 Turbo · 12-15 Legendary
--   Trimmer  4 upgrades × 5 levels = 0…20, so its step is 5:
--            0-4 Basic · 5-9 Pro · 10-14 Turbo · 15-20 Legendary
-- (only the levels of their own upgrade tables count, each clamped to 0…Max — an old
-- save gets its tier from the levels it already has)
T.TierSteps = { Trimmer = 5 }
function T.HelperTier(tool, levels)
	if T.GrassTiers[tool] then
		return T.GrassTierOf(tool, levels) -- v2.43: 1 … 5 (the grass tools' own tiers)
	end
	if tool == "Pickaxe" then
		return T.PickaxeTier(levels) -- v2.38: 1 Stone … 5 Rainbow
	end
	if tool == "Rake" or tool == "Trimmer" then
		local ups = if tool == "Rake" then T.RakeUpgrades else T.TrimmerUpgrades
		local sum = 0
		if type(levels) == "table" then
			for stat, u in ups do
				local v = tonumber(levels[stat]) or 0
				if v ~= v then
					v = 0
				end
				sum += math.clamp(math.floor(v), 0, u.Max)
			end
		end
		return math.clamp(1 + math.floor(sum / (T.TierSteps[tool] or T.TierStep)), 1, #T.TierNames)
	end
	if tool ~= "Blower" and tool ~= "Vacuum" and tool ~= "Blaster" then
		return 1
	end
	local sum = 0
	for k, v in levels or {} do
		if k ~= "Energy" then -- (v2.32: the blower's Energy level doesn't change its look — the tiers stay where they were)
			sum += tonumber(v) or 0
		end
	end
	return math.clamp(1 + math.floor(sum / T.TierStep), 1, #T.TierNames)
end
-- tier from the published "Tools" attribute ({ Up = { Blower = {…} } }, already decoded)
function T.TierFromState(tool, state)
	local up = type(state) == "table" and type(state.Up) == "table" and state.Up[tool] or nil
	return T.HelperTier(tool, up)
end

-- v2.41: the tools whose look follows T.TierNames (for the UI: "Rake · Pro")
T.TieredLook = { Blower = true, Vacuum = true, Rake = true, Trimmer = true, Blaster = true, Shears = true, WeedCutter = true, Scythe = true, PushMower = true, RidingMower = true }

-- v2.38: what a tier of a tool is called ("Pro" … for the blower / vacuum, "Iron" … for the pickaxe)
function T.TierName(tool, tier)
	if T.GrassTiers[tool] then
		return T.GrassTiers[tool].Names[tier] or "" -- v2.43
	end
	if tool == "Trimmer" then
		return T.TrimmerNames[tier] or ""
	end
	if tool == "Pickaxe" then
		local t = T.PickaxeTiers[tier]
		return t and t.Name or ""
	end
	return T.TierNames[tier] or ""
end

function T.UpgradesOf(tool)
	return if T.GrassUpgrades[tool] then T.GrassUpgrades[tool] elseif tool == "Trimmer" then T.TrimmerUpgrades elseif tool == "Vacuum" then T.VacuumUpgrades elseif tool == "Blower" then T.BlowerUpgrades elseif tool == "Pickaxe" then T.PickaxeUpgrades elseif tool == "Rake" then T.RakeUpgrades elseif tool == "Blaster" then T.BlasterUpgrades else nil -- (v2.40: the rake · v2.42: the blaster)
end
function T.UpgradeOrderOf(tool)
	return if T.GrassUpgrades[tool] then { "Tier" } elseif tool == "Trimmer" then T.TrimmerUpgradeOrder elseif tool == "Vacuum" then T.VacuumUpgradeOrder elseif tool == "Blower" then T.BlowerUpgradeOrder elseif tool == "Pickaxe" then T.PickaxeUpgradeOrder elseif tool == "Rake" then T.RakeUpgradeOrder elseif tool == "Blaster" then T.BlasterUpgradeOrder else nil
end

function T.RepairCost(capacity)
	return math.floor(capacity * T.VacuumRepairPerItem)
end

-- (inv, round 13) the numbers a tool / item works with, for the Inventory:
-- { { Icon, Label, Value (string), Unit? } … }. `state` = the decoded "Tools" attribute
-- ({ Up = { [tool] = levels } }) -> the numbers of the CURRENT tier / upgrades, through the
-- same functions the game plays with (GrassStats, Trimmer, Whirl, Rake, Blower, Vacuum,
-- Vortex, Pickaxe, Blaster)
local function statNum(v, d)
	v = tonumber(v) or 0
	d = d or 2
	local m = 10 ^ d
	local r = math.floor(v * m + 0.5) / m
	if r == math.floor(r) then
		return tostring(math.floor(r))
	end
	local str = string.format("%." .. tostring(d) .. "f", r)
	str = string.gsub(str, "0+$", "")
	return (string.gsub(str, "%.$", ""))
end
T.StatNumber = statNum
function T.StatLines(id, state)
	local out = {}
	local function add(icon, label, value, unit)
		if value ~= nil then
			table.insert(out, { Icon = icon, Label = label, Value = if type(value) == "number" then statNum(value) else tostring(value), Unit = unit })
		end
	end
	local up = type(state) == "table" and type(state.Up) == "table" and state.Up[id] or nil
	up = if type(up) == "table" then up else {}
	if T.GrassTools[id] then
		if id == "Trimmer" then
			local tr, wh = T.Trimmer(up), T.Whirl(up)
			add("🏅", "Tier", T.TierName("Trimmer", T.HelperTier("Trimmer", up)))
			add("📏", "Cutting radius", tr.Radius, "studs")
			add("💪", "Cutting power", tr.Power)
			add("⚡", "Cuts per second", tr.Rate)
			add("🔋", "Battery", tr.Battery, "sec")
			add("🌀", "Whirl radius", wh.Radius, "studs")
			add("⏱", "Whirl recharge", wh.Cooldown, "sec")
		else
			local d: any = T.GrassStats(id, up)
			if d.Tier and T.GrassTiers[id] then
				add("🏅", "Tier", tostring(d.Display) .. " (" .. tostring(d.Tier) .. "/" .. tostring(#T.GrassTiers[id].Names) .. ")")
			end
			add("📏", "Cutting radius", d.Radius, "studs")
			add("💪", "Cutting power", d.Power)
			add("⏱", "Cut every", d.Cooldown, "sec")
			add("🏃", "Speed", d.Speed, "studs/s")
			add("🛠", "Durability", d.Durability, "uses")
			add("⛽", "Fuel", d.Fuel, "sec")
			add("✨", "Ability recharge", d.AbCooldown, "sec")
			if d.GoldenChance then
				add("🌟", "Golden Grass chance", statNum(d.GoldenChance * 100) .. "%")
			end
		end
		local okR, rate = pcall(T.MowRate, id, up)
		if okR and type(rate) == "number" and rate > 0 then
			add("🌿", "Mows", statNum(rate, 1), "studs²/s")
		end
	elseif id == "Rake" then
		local r = T.Rake(up)
		add("🏅", "Tier", T.TierName("Rake", T.HelperTier("Rake", up)))
		add("📏", "Head width", r.Width, "studs")
		add("🌾", "Loosens leaves within", r.LoosenRadius, "studs")
		add("🧲", "Gather radius", r.GatherRadius, "studs")
		add("⏱", "Gather recharge", r.GatherCooldown, "sec")
		add("💪", "Power", r.Stats.Power)
		add("🎯", "Control", r.Stats.Control)
	elseif id == "Blower" then
		local b = T.Blower(up)
		add("🏅", "Tier", T.TierName("Blower", T.HelperTier("Blower", up)))
		add("📏", "Reach", b.Range, "studs")
		add("📐", "Stream width", statNum(b.Cone) .. "°")
		add("💨", "Blow force", b.Force, "studs/s")
		add("🔋", "Energy", b.Energy, "sec")
		add("🚀", "Jet recharge", b.JetCooldown, "sec")
	elseif id == "Vacuum" then
		local v, vo = T.Vacuum(up), T.Vortex(up)
		add("🏅", "Tier", T.TierName("Vacuum", T.HelperTier("Vacuum", up)))
		add("📏", "Reach", v.Range, "studs")
		add("🌀", "Suction", v.Rate, "items/s")
		add("📦", "Capacity", v.Capacity, "items")
		add("🌪", "Vortex radius", vo.Radius, "studs")
		add("⏱", "Vortex recharge", vo.Cooldown, "sec")
	elseif id == "Pickaxe" then
		local p: any = T.Pickaxe(up)
		add("🏅", "Tier", tostring(p.Name) .. " (" .. tostring(p.Index or T.PickaxeTier(up)) .. "/" .. tostring(#T.PickaxeTiers) .. ")")
		add("⛏", "Swing every", p.HitEvery, "sec")
		add("📏", "Reach", p.Reach, "studs")
		add("🪨", "Swings per stone block", p.Hits and p.Hits.R)
		add("🛠", "Durability", p.Durability, "blocks")
		add("💥", "Smash recharge", p.Smash, "sec")
	elseif id == "Blaster" then
		local b = T.Blaster(up)
		add("🏅", "Tier", T.TierName("Blaster", T.HelperTier("Blaster", up)))
		add("🔫", "Magazine", b.Magazine, "pulses")
		add("💪", "Pulse power", b.Power, "studs/s")
		add("⏱", "Fire every", b.FireEvery, "sec")
		add("🔄", "Reload", b.Reload, "sec")
		add("📏", "Pulse size", b.Size, "studs")
		add("🎯", "Range", b.Range, "studs")
		add("🔋", "Energy", b.Energy, "pulses")
	elseif T.Consumables[id] then
		local c: any = T.Consumables[id]
		add("⏳", "Lasts", c.Duration, "sec")
		add("📏", "Radius", c.Radius, "studs")
		add("🧲", "Pull", c.Pull, "studs/s")
		add("✋", "Collects within", c.Pickup, "studs")
		if c.SpeedMult then
			add("🏃", "Mower speed", "+" .. statNum((c.SpeedMult - 1) * 100) .. "%")
		end
		if c.Boost then
			add("🧸", "Pet ability boost", "+" .. statNum(c.Boost * 100) .. "%")
		end
		if c.Needs then
			local nd = T.Def(c.Needs)
			add("🔌", "For", nd and nd.Display or c.Needs)
		elseif c.NeedsMower then
			add("🔌", "For", T.GrassTools.PushMower.Display .. " · " .. T.GrassTools.RidingMower.Display)
		elseif c.ToolTarget then
			local names = {}
			for _, tid in { "Shears", "WeedCutter", "Scythe", "Pickaxe" } do
				local td = T.RepairTargets[tid] and T.Def(tid)
				if td then
					table.insert(names, td.Display)
				end
			end
			add("🔌", "For", table.concat(names, " · "))
		end
	end
	return out
end

--[[
	(round 15) 🐕 GOLDEN RETRIEVER (Home Egg): the tool IN YOUR HAND works better — every stat +X %
	(PetPowers.ToolMult; the server publishes it as the player attribute ToolBoost with 3 decimals, so the client
	uses the very same number). Both sides call these on the stat tables they already work with:
	  T.Boosted(t, mult)     a tool's table (GrassStats, Trimmer, Whirl, Vacuum, Vortex, Blower, Blaster, a pickaxe
							 tier): a COPY in which every effect number is × mult (radius, reach, power, rate,
							 force, range, cone, speed, size, arc …) and every waiting time is ÷ mult (cooldowns,
							 reload, the time between shots / swings). What the tool HOLDS (durability, fuel,
							 battery, energy, capacity, magazine — gauges counted in the save) and prices / tiers /
							 ids stay as they are. A Power that is a share of the grass cut never passes 100.
	  T.BoostStats(s, mult)  the six broom stats (the broom, the rake): every number × mult, 2 decimals.
	mult = 1 gives back the very same table (no copy).
]]
T.BoostFaster = { Cooldown = true, AbCooldown = true, FireEvery = true, Reload = true, GatherCooldown = true, JetCooldown = true, HitEvery = true, Smash = true }
T.BoostKeep = { Tier = true, Index = true, Durability = true, Fuel = true, Energy = true, Battery = true, Capacity = true, Magazine = true, Price = true, Cost = true, RepairPer = true, HitMult = true, Time = true, Max = true, Slot = true }
function T.Boosted(t, mult)
	mult = tonumber(mult) or 1
	if type(t) ~= "table" or mult == 1 or mult ~= mult or mult <= 0 or mult == math.huge then
		return t
	end
	local out: any = {}
	for k, v in t do
		if type(v) == "number" and not T.BoostKeep[k] then
			if T.BoostFaster[k] then
				v = v / mult
			else
				local nv = v * mult
				if k == "Power" and v <= 100 then
					nv = math.min(nv, 100)
				elseif k == "Arc" then
					nv = math.min(nv, 360)
				end
				v = nv
			end
		end
		out[k] = v
	end
	return out
end
function T.BoostStats(stats, mult)
	mult = tonumber(mult) or 1
	if type(stats) ~= "table" or mult == 1 or mult ~= mult or mult <= 0 or mult == math.huge then
		return stats
	end
	local out: any = {}
	for k, v in stats do
		out[k] = if type(v) == "number" then math.floor(v * mult * 100 + 0.5) / 100 else v
	end
	return out
end

-- (round 16 wind) the Leaf Blower's numbers with the Wind Egg pets: `wind` = the Wyvern (× Range, Cone, Force and
-- Energy, ÷ JetCooldown), `reach` = the Wind Squirrel (× Range). The server publishes both as the player attributes
-- WindBoost / WindReach (3 decimals), so the client uses the very same numbers. 1 / 1 gives back the same table.
function T.WindBlower(t, wind, reach)
	wind, reach = tonumber(wind) or 1, tonumber(reach) or 1
	if type(t) ~= "table" or (wind == 1 and reach == 1) or wind ~= wind or reach ~= reach or wind <= 0 or reach <= 0 then
		return t
	end
	local out = table.clone(t)
	if type(out.Range) == "number" then
		out.Range = out.Range * wind * reach
	end
	if type(out.Cone) == "number" then
		out.Cone = math.min(out.Cone * wind, 80)
	end
	if type(out.Force) == "number" then
		out.Force = out.Force * wind
	end
	if type(out.Energy) == "number" then
		out.Energy = math.floor(out.Energy * wind + 0.5)
	end
	if type(out.JetCooldown) == "number" then
		out.JetCooldown = out.JetCooldown / wind
	end
	return out
end

return T

end
T = ToolConfigModule()
local order = { "Shears", "WeedCutter", "Scythe", "PushMower", "Trimmer", "RidingMower" }
local prev, fails = nil, 0
print("tool            base rate   max rate   base / previous max")
for _, id in order do
	local base = T.MowRate(id, {})
	local top = T.MowRate(id, T.TopLevels(id))
	local ratio = if prev then base / prev else 0
	local ok = not prev or ratio >= 1.25
	if not ok then fails += 1 end
	print(string.format("%-14s %8.1f %10.1f %14s %s", id, base, top, prev and string.format("%.2f", ratio) or "-", ok and "" or "  <-- TOO CLOSE"))
	prev = top
end
print("names: " .. table.concat(T.GrassTiers.Scythe.Names, " > ") .. " | " .. table.concat(T.GrassTiers.RidingMower.Names, " > "))
for _, id in order do
	local d = T.GrassStats(id, { Tier = 4 })
	local d0 = T.GrassStats(id, {})
	print(string.format("%-12s tier5 '%s' R %.2f P %.0f cd %s speed %s dur %s fuel %s ab %s", id, tostring(d.Display), d.Radius, d.Power, tostring(d.Cooldown), tostring(d.Speed), tostring(d.Durability), tostring(d.Fuel), tostring(d.AbCooldown)))
end
print("GoldenScythe/TurboMower still sold?", T.GrassTools.GoldenScythe, T.GrassTools.TurboMower, " in order:", table.find(T.GrassOrder, "GoldenScythe"))
print("price problems:", #T.CheckItemPrices())
for _, m in T.CheckItemPrices() do print("  " .. m); fails += 1 end
for _, id in order do local d = T.GrassTools[id]; print(string.format("%-12s %-10s %9d", id, d.Rarity, d.Price)) end
print("blaster", T.Helpers.Blaster.Rarity, T.Helpers.Blaster.Price, "upgrades:", T.UpgradeCost("Blaster","Power",0), T.UpgradeCost("Blaster","Power",4))
local BM = T.Blower({ Force = 5, Range = 5, Cone = 5, Energy = 5 })
print("blower: no ice / stone power, jet cd", BM.Maxed, BM.IceDamage, BM.StoneNudge, BM.JetCooldown, T.Blower({}).JetCooldown)
if BM.Maxed or BM.IceDamage or BM.StoneNudge then fails += 1 end
local top = T.Blaster({ Power = 5, Rate = 5, Size = 5, Energy = 5 })
local almost = T.Blaster({ Power = 5, Rate = 5, Size = 5, Energy = 4 })
print("blaster maxed:", top.Maxed, top.IceDamage, top.StoneNudge, " | one short:", almost.Maxed, almost.IceDamage, almost.StoneNudge)
print("blaster reload s:", T.Blaster({}).Reload, "->", top.Reload)
if not (top.Maxed and top.IceDamage == 1 and top.StoneNudge) or almost.Maxed or almost.IceDamage or almost.StoneNudge or top.Reload < 2 then fails += 1 end
print("leaf magnet collects by itself?", T.Consumables.LeafMagnet.Pickup, " mega magnet:", T.Consumables.MegaMagnet.Pickup)
if T.Consumables.LeafMagnet.Pickup ~= nil or not T.Consumables.MegaMagnet.Pickup then fails += 1 end
print(fails == 0 and "LADDER OK" or ("FAILURES: " .. fails))
for tier = 1, 11 do
	local r = T.GrassIsland(tier)
	print(string.format("island %2d  tick x%.2f  max %.2f  infect %.2f  slow tall %.2f thick %.2f over %.2f", tier, r.Tick, r.Max, r.Infect, r.Slow[1], r.Slow[2], r.Slow[3]))
end
-- the real growth interval: base 150 s x tick / weather
for _, w in { { "Clear", 1 }, { "Rain", 1.7 }, { "Storm", 2 }, { "Paradise", 2.4 } } do
	print(string.format("island 5 in %-8s: a growth step every %.0f s", w[1], T.Grass.TickEvery * T.GrassIsland(5).Tick / w[2]))
end
local f = T.Features
