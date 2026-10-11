-- "Any": a universal stand-in for every Roblox API the effects touch
local Any = {}
setmetatable(Any, { __index = function() return Any end, __call = function() return Any end, __newindex = function() end,
	__mul = function() return Any end, __add = function() return Any end, __sub = function() return Any end, __div = function() return Any end })
Enum, Instance, Color3, NumberRange, ColorSequence, NumberSequence, NumberSequenceKeypoint, Vector2, RaycastParams, OverlapParams, UDim2, CFrame = Any, Any, Any, Any, Any, Any, Any, Any, Any, Any, Any, Any
Random = { new = function() return { NextNumber = function(_, a, b) if a == nil then return math.random() end return a + (b - a) * math.random() end } end }
PhysicalProperties = { new = function(d, f, e, fw, ew) return { Density = d, Friction = f, Elasticity = e, FrictionWeight = fw, ElasticityWeight = ew } end }
warn = print
local attrs = {}
LOCAL = { Name = "me", GetAttribute = function(_, k) return attrs[k] end, SetAttribute = function(_, k, v) attrs[k] = v end,
	GetAttributeChangedSignal = function() return Any end, CameraMode = 0, CameraMinZoomDistance = 0, CameraMaxZoomDistance = 100 }
LOCAL_ATTRS = attrs
local V = {}
V.__index = function(t, k)
	if k == "Magnitude" then return math.sqrt(t.X*t.X + t.Y*t.Y + t.Z*t.Z) end
	if k == "Unit" then local m = math.sqrt(t.X*t.X + t.Y*t.Y + t.Z*t.Z); return setmetatable({X=t.X/m,Y=t.Y/m,Z=t.Z/m}, V) end
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
V.zero = V.new(0,0,0); V.one = V.new(1,1,1); V.yAxis = V.new(0,1,0); V.xAxis = V.new(1,0,0)
Vector3 = V
CFrame = setmetatable({ lookAt = function(pos, target) return { Position = pos, LookVector = (target - pos).Unit } end }, { __index = function() return Any end })
typeof = function(v) if getmetatable(v) == V then return "Vector3" end return type(v) end
FAKE_PARTS = {}
workspace = setmetatable({
	GetServerTimeNow = function() return SERVER_NOW or 0 end,
	GetPartBoundsInRadius = function(_, c, r)
		local out = {}
		for _, p in FAKE_PARTS do if (p.Position - c).Magnitude <= r then table.insert(out, p) end end
		return out
	end,
	CurrentCamera = Any,
}, { __index = function() return Any end })
game = { GetService = function(_, n)
	if n == "Players" then return { LocalPlayer = LOCAL } end
	return Any
end }

FAKE_T = 0
os = setmetatable({ clock = function() return FAKE_T end }, { __index = os })
local function mc() return (function()
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
		Description = "Small garden shears. Slow and tiny, but free — they trim neatly around trees and decorations. Strike key = SNIP BURST: five spots around your aim are cut at once. They wear out with every cut — repair them. Upgrade them: five tiers, up to the Golden Shears.",
	},
	WeedCutter = {
		Display = "Weed Cutter", Rarity = "Uncommon", Price = 8000, Kind = "Swipe", Icon = "🔪",
		Radius = 5, Arc = 110, Power = 34, Cooldown = 0.3, Reach = 3,
		Description = "A hand cutter for tall grass. Swipe the mouse left and right while holding the button — fast and cheap, great for small patches. Strike key = SLASH WAVE: a long strip of grass in front of you is cut. It wears out — repair it. Five tiers, up to the Master Cutter.",
	},
	Scythe = {
		Display = "Scythe", Rarity = "Rare", Price = 40000, Kind = "Swing", Icon = "🌙",
		Radius = 7.2, Arc = 170, Power = 48, Cooldown = 1, Reach = 0,
		Description = "The classic scythe. One wide, slow swing mows several rows of grass around you. Strike key = HARVEST: a huge cone in front of you is cut down to the ground. It wears out — repair it. Five tiers: the last one is the Golden Scythe.",
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
		Description = "An electric string trimmer. Hold the button and guide it with the mouse — VRRRRR! Strike key = WHIRL: the line shoots out, you spin once and ALL the grass in a wide ring around you is cut (costs battery). Runs on its battery; upgrade it at the shop.",
	},
	PushMower = {
		Display = "Push Mower", Rarity = "Epic", Price = 300000, Kind = "Push", Icon = "🛒",
		Radius = 2.6, Power = 100, Speed = 16,
		Description = "A proper lawn mower. Just walk with W A S D — it rolls in front of you and cuts everything under it, leaving neat stripes. Strike key = OVERDRIVE: a much wider deck and a faster walk for a while. It burns fuel — refuel it with Gasoline or in the shop. Five tiers.",
	},
	RidingMower = {
		Display = "Riding Mower", Rarity = "Mythic", Price = 6500000, Kind = "Ride", Icon = "🚜",
		Radius = 6.4, Power = 100, Speed = 27,
		Description = "Sit down and drive (W A S D). Mows a wide strip and paints perfect stripes. Space = get off. Strike key = NITRO: a burst of speed. It burns fuel — refuel it with Gasoline or in the shop. Five tiers: the last one is the Turbo Mower.",
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
	BladeSpeed = { Display = "Blade Speed", Base = 40000, Growth = 2.2, Max = 5, Per = 1.5, Help = "+1.5 cuts per second · the WHIRL recharges 3 s faster" },
	Range = { Display = "Cutting Range", Base = 40000, Growth = 2.2, Max = 5, Per = 0.5, Help = "+0.5 studs cutting radius · +1.2 studs WHIRL radius" },
	Battery = { Display = "Battery", Base = 25000, Growth = 2.2, Max = 5, Per = 20, Help = "+20 s of battery" },
	Power = { Display = "Cutting Power", Base = 60000, Growth = 2.2, Max = 5, Per = 2.5, Help = "+2.5 grass cut per hit" },
}
T.TrimmerUpgradeOrder = { "BladeSpeed", "Range", "Battery", "Power" }
T.BatteryRecharge = 0.25 -- seconds of battery gained per second while it's off

--[[
	v2.43 THE GRASS TOOLS GROW UP. Shears, Weed Cutter, Scythe, Push Mower and Riding Mower
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
	per second (the order: Shears → Weed Cutter → Scythe → Push Mower → Trimmer → Riding Mower).
	tests/ladder_test.lua checks it; keep it true when you change a number.
]]
local GRASS_TIERS: { [string]: any } = {
	Shears = { Names = { "Grass Shears", "Iron Shears", "Steel Shears", "Pro Shears", "Golden Shears" }, Costs = { 3000, 9000, 25000, 70000 },
		Durability = { 300, 380, 470, 580, 720 }, RepairPer = 4, Grow = { Radius = 1.03, Power = 1.035, Cooldown = 0.985 } },
	WeedCutter = { Names = { "Weed Cutter", "Sharp Cutter", "Steel Cutter", "Power Cutter", "Master Cutter" }, Costs = { 4000, 10000, 22000, 45000 },
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
	local help = "a better " .. string.lower(t.Names[1]) .. ": more power, reach and " .. (if t.Fuel then "fuel" else "durability")
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
	Shears = { Display = "Snip Burst", Icon = "✂️", Cooldown = 24, Per = 2, Spots = 5, Spread = 1.7, Help = "five spots around your aim are cut at once" },
	WeedCutter = { Display = "Slash Wave", Icon = "🌊", Cooldown = 30, Per = 2.5, Length = 18, LengthPer = 1.5, Help = "a long strip in front of you is cut" },
	Scythe = { Display = "Harvest", Icon = "🌾", Cooldown = 40, Per = 3, Range = 15, RangePer = 1.5, Arc = 130, Golden = 0.1, Help = "a huge cone in front of you is cut to the ground" },
	PushMower = { Display = "Overdrive", Icon = "💨", Cooldown = 45, Per = 3, Time = 8, TimePer = 0.5, Deck = 2, Walk = 1.35, Help = "a much wider deck and a faster walk" },
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
		Description = "Not a broom: a rake PULLS. Drag it toward you and the tines drag the leaves along (pushed away it slides over them). Press the strike key to GATHER everything around it into one big pile — huge piles swept into your zone pay a Big Pile bonus. Works in tall grass and pulls stuck leaves out of thick grass. Upgrade it here: wider tines, a bigger and quicker GATHER.",
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
		Description = "Doesn't collect anything — it BLOWS. Hold the button: leaves in front of you fly away from the nozzle. Great for moving a pile toward your zone or out of tall grass. Strike key = JET (the gust carries YOU; it needs a long recharge afterwards). Runs on energy: recharge it for Money in the shop or with a Blower Battery.",
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
		Description = "Sucks up leaves and pays for them at once, as if they reached your zone. Strike key = VORTEX: a whirlwind at your aim pulls every loose leaf around into one pile, then the vacuum swallows it in one gulp. It wears out — repair it for Money or with a Vacuum Battery.",
	},
	-- v2.32: breaks the BLOCKS of your garden (BlockConfig: reach, swings per block).
	-- Kind "Pick": it has its own controller on the client (Pickaxe), not ToolController.
	Pickaxe = {
		Display = "Pickaxe", Rarity = "Common", Price = 2500, Slot = 6, Icon = "⛏", Kind = "Pick",
		Description = "Breaks the blocks of your garden: point at a block and click — or hold. Strike key = SMASH: one heavy blow breaks 3×3 blocks. Every block wears it down — repair it here. Upgrade it: Iron, Gold, Diamond and Rainbow mine faster, reach further and last longer.",
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
		Description = "Fires small air pulses. Click (or hold) to shoot: a pulse hits, the leaves fly away, crash into the ones lying around and bounce off them. Six pulses, then a long reload (strike key = reload now). Stone items and blocks of ice stay where they are; other players get a shove. Runs on energy — recharge it for Money in the shop. Upgrade its power, fire rate, pulse size and energy. FULLY UPGRADED (every upgrade at level 5) the pulses BREAK blocks of ice (3 pulses) and nudge STONE items a little.",
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
	Tier = { Display = "Tier", Max = #T.PickaxeTiers - 1, Costs = {}, Help = "a better pickaxe: faster, further, tougher" },
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
	Force = { Display = "Blow Force", Base = 30000, Growth = 2.1, Max = 5, Per = 3, Help = "+3 studs/s blow speed · faster and higher JET flight" },
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
	Power = { Display = "Pulse Power", Base = 900000, Growth = 2, Max = 5, Per = 4.5, Help = "+4.5 studs/s: items fly further · players are shoved harder" },
	Rate = { Display = "Fire Rate", Base = 900000, Growth = 2, Max = 5, Per = 0.06, Help = "0.06 s faster between pulses · 0.25 s faster reload" },
	Size = { Display = "Pulse Size", Base = 800000, Growth = 2, Max = 5, Per = 0.5, Help = "+0.5 studs wider pulse · +1.5 studs range" },
	Energy = { Display = "Energy", Base = 700000, Growth = 2, Max = 5, Help = "more pulses on one charge (60 → 360)" },
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
		Description = "20 seconds: leaves near you drift to you — you still sweep them up yourself. Only the Mega Magnet collects them for you.",
	},
	GrassKiller = {
		Display = "Grass Killer", Rarity = "Uncommon", Price = 4000, Icon = "🧴", Target = true,
		Radius = 7,
		Description = "Pick a spot: all the grass there vanishes at once. Handy — but it leaves no Grass Clippings.",
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
		Description = "40 seconds: leaves all around you fly to you and are collected the moment they touch you.",
	},
	-- v2.32: a full charge for the Leaf Blower (its energy gauge)
	BlowerBattery = {
		Display = "Blower Battery", Rarity = "Rare", Price = 18000, Icon = "🔌", Needs = "Blower",
		Description = "Fully recharges your Leaf Blower's energy — right where you stand.",
	},
	-- v2.38: the VACUUM's battery — puts its whole capacity back (exactly what the paid
	-- repair does), anywhere. Dearer than the two other batteries; a full repair costs
	-- 💰60 per item of capacity (6,000 at Capacity 100 … 60,000 at 1,000): the shop's
	-- repair is cheaper up to Capacity level 2, the same at level 3 (500 items) and
	-- dearer from level 4 on — there the battery (rare in stock) is the better deal.
	VacuumBattery = {
		Display = "Vacuum Battery", Rarity = "Epic", Price = 95000, Icon = "🔋", Needs = "Vacuum",
		Description = "A heavy-duty power cell: fully restores your Vacuum's worn-out capacity — right where you stand, even when it has broken down.",
	},
	-- v2.43: a full charge for the Leaf Blaster (its energy gauge)
	BlasterBattery = {
		Display = "Blaster Battery", Rarity = "Epic", Price = 120000, Icon = "🔋", Needs = "Blaster",
		Description = "Fully recharges your Leaf Blaster's energy — right where you stand.",
	},
	-- v2.43: fills the fuel tank of the Push Mower AND the Riding Mower
	Gasoline = {
		Display = "Gasoline", Rarity = "Epic", Price = 60000, Icon = "⛽", NeedsMower = true, Fuel = true,
		Description = "A can of gasoline: fills the fuel tank of your Push Mower and your Riding Mower to the top.",
	},
	-- v2.43: repairs ONE of Shears, Weed Cutter, Scythe, Pickaxe — use it, then pick the tool
	-- in the panel (the ones in your hotbar)
	RepairKit = {
		Display = "Repair Kit", Rarity = "Epic", Price = 75000, Icon = "🧰", ToolTarget = true,
		Description = "Use it, then pick one of your Grass Shears, Weed Cutter, Scythe or Pickaxe in the panel: it is repaired completely.",
	},
	-- v2.51: GRASS SALT — pick a grass spot (a lawn cell or the top of an Earth block): grass never
	-- grows there again. Pricey (the dearest of the everyday items after the Big Toy's league):
	-- above the Repair Kit (75,000) and Gasoline (60,000), below the Mega Magnet (250,000).
	-- While it is in the hand every spot without grass glows (GrassFX; GrassService.MakeBare)
	GrassSalt = {
		Display = "Grass Salt", Rarity = "Legendary", Price = 200000, Icon = "🧂", Target = true,
		Radius = 2.5,
		Description = "Pick a grass spot — a lawn cell or the top of an Earth block: the grass there is gone and NEVER grows back. While you hold it, every spot without grass glows.",
	},
	-- v2.32 PET TOYS: use one, pick one of your EQUIPPED pets — for 5 minutes its ability
	-- recharges faster and is stronger by Boost (PetConfig.BoostValue / PetAbilityService.Boost).
	-- PetTarget = the client opens the pet picker; the server gets { Action = "Use", Id, Pet = uid }.
	SmallToy = {
		Display = "Small Toy", Rarity = "Rare", Price = 10000, Icon = "🧸", PetTarget = true,
		Boost = 0.10, Duration = 300,
		Description = "Give it to one of your equipped pets: for 5 minutes its ability recharges 10% faster and is 10% stronger.",
	},
	MediumToy = {
		Display = "Medium Toy", Rarity = "Epic", Price = 40000, Icon = "🧸", PetTarget = true,
		Boost = 0.25, Duration = 300,
		Description = "Give it to one of your equipped pets: for 5 minutes its ability recharges 25% faster and is 25% stronger.",
	},
	BigToy = {
		Display = "Big Toy", Rarity = "Legendary", Price = 150000, Icon = "🧸", PetTarget = true,
		Boost = 0.50, Duration = 300,
		Description = "Give it to one of your equipped pets: for 5 minutes its ability recharges 50% faster and is 50% stronger.",
	},
}
T.ConsumableOrder = { "LeafMagnet", "GrassKiller", "BatteryPack", "TurboFuel", "MegaMagnet", "BlowerBattery", "VacuumBattery", "BlasterBattery", "Gasoline", "RepairKit", "GrassSalt", "SmallToy", "MediumToy", "BigToy" }
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

return T
end)() end
TC_MODULE = mc()
local function mt() return (function()
--[[
	Leaf Rush · ToolController (client, v1.2) — using the tools in your hand

	Grass tools (slot 2), the Leaf Blower (4) and the Vacuum (5). The rake (3) sweeps
	with BroomController; riding mowers are driven by MowerDrive.
	Use = the Sweep binding (left mouse by default; on a phone: touch the ground).

	  ✂️ Shears       click a spot: snip (small, slow; also around trees & decor)
	  🔪 Weed Cutter  hold and swipe the mouse LEFT–RIGHT: every swipe cuts in front
	  🌙 Scythe       click: wind up… and one wide swing all around the front
	  ⚡ Trimmer      hold: cuts under the aim while the battery lasts (VRRRRR)
	  🛒 Push Mower   just walk: the server cuts under it
	  💨 Blower       hold: leaves in front fly away from the nozzle (physics you own)
	  🌀 Vacuum       hold: leaves near the nozzle are sucked up (the server pays)
	  🔫 Blaster      click / hold: one air pulse per shot, six shots, then a reload (v2.42)

	The server decides every cut / payment (ToolService); here: aim, animation, sound
	and effects. The arm swings by setting the shoulder joint's Transform each frame
	(after the default animation), so the motion is smooth and local.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local ToolController = {}
ToolController.__index = ToolController

local player = Players.LocalPlayer

function ToolController.new(deps)
	local self = setmetatable({}, ToolController)
	for k, v in deps do
		self[k] = v -- Config, ToolConfig, Remote, Juice, Controls, GrassFX, MyResources
	end
	self.ray = RaycastParams.new()
	self.ray.FilterType = Enum.RaycastFilterType.Exclude
	self.ray.IgnoreWater = true
	self.ray.RespectCanCollide = false
	if self.Config.Collision.RayGroup then
		self.ray.CollisionGroup = self.Config.Collision.RayGroup
	end
	self.overlap = OverlapParams.new()
	self.overlap.FilterType = Enum.RaycastFilterType.Include
	self.overlap.CollisionGroup = self.Config.Collision.QueryGroup or "Default"
	self.pressing = false
	-- v2.42 the Leaf Blaster: pulses in flight, the items it threw (they bounce off each other
	-- for a moment) — they go on after the tool is put away, so they live here, not in Start
	self.pulses, self.flying, self.flyN, self.flyAcc = {}, {}, 0, 0
	self.bMag, self.bReloadAt, self.bSeq = nil, 0, nil
	self.blastCap = ((self.Config.Resources and self.Config.Resources.MaxSpeed) or 70) * 0.78 -- (stays under the anti-teleport speed)
	RunService.Heartbeat:Connect(function(dt)
		if #self.pulses > 0 or self.flyN > 0 then
			self:_blastWorld(dt)
		end
	end)
	-- v2.43: sitting on the Riding Mower the strike key is its NITRO (the tool controller is
	-- not running then: the mower has its own drive module)
	UserInputService.InputBegan:Connect(function(input, gp)
		if gp or self.active or self.uiOpen then
			return
		end
		if self.Controls.Is("Strike", input) or input.KeyCode == Enum.KeyCode.ButtonX then
			local char = player.Character
			if char and char:GetAttribute("LRRiding") then
				self:_send({ A = "Ability" })
			end
		end
	end)
	UserInputService.InputBegan:Connect(function(input, gp)
		if not self.active or self.uiOpen then
			return
		end
		if input.UserInputType == Enum.UserInputType.Touch then
			if gp then
				return
			end
			self.touchPos = Vector2.new(input.Position.X, input.Position.Y)
			self.touchInput = input
			self:_press(true)
		elseif self.Controls.Is("Sweep", input) and not gp then
			self:_press(true)
		elseif not gp and self.kind == "Blower" and (self.Controls.Is("Strike", input) or input.KeyCode == Enum.KeyCode.ButtonX) then
			self:ToggleJet() -- v2.34: the strike key switches the Leaf Blower BLOW <-> JET
		elseif not gp and self.kind == "Vacuum" and (self.Controls.Is("Strike", input) or input.KeyCode == Enum.KeyCode.ButtonX) then
			self:Vortex() -- v2.38: the strike key plants the Vacuum's VORTEX
		elseif not gp and self.kind == "Trimmer" and (self.Controls.Is("Strike", input) or input.KeyCode == Enum.KeyCode.ButtonX) then
			self:Whirl() -- v2.40: the strike key = the Lawn Trimmer's WHIRL
		elseif not gp and self.kind == "Blaster" and (self.Controls.Is("Strike", input) or input.KeyCode == Enum.KeyCode.ButtonX) then
			self:Reload() -- v2.42: the strike key reloads the Leaf Blaster now
		elseif not gp and (self.kind == "Snip" or self.kind == "Swipe" or self.kind == "Swing" or self.kind == "Push") and (self.Controls.Is("Strike", input) or input.KeyCode == Enum.KeyCode.ButtonX) then
			self:UseAbility() -- v2.43: Snip Burst / Slash Wave / Harvest / Overdrive
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if input == self.touchInput then
			self.touchPos = Vector2.new(input.Position.X, input.Position.Y)
		elseif input.UserInputType == Enum.UserInputType.MouseMovement then
			-- (first person: the mouse is locked, so swipes come from its movement)
			self.mouseDX = (self.mouseDX or 0) + input.Delta.X
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input == self.touchInput then
			self.touchInput = nil
			self:_press(false)
		elseif self.Controls.Is("Sweep", input) then
			self:_press(false)
		end
	end)
	-- others' cuts (a quick green burst where they cut)
	return self
end

-- the aim ray ignores you, every garden's trees / decorations / drops and effects:
-- it always finds the ground (v1.4: aiming at tall grass under a tree canopy works)
function ToolController:_rayIgnore(char)
	local list = { char }
	local root = workspace:FindFirstChild("LeafRush")
	local plots = root and root:FindFirstChild("Plots")
	if plots then
		for _, plot in plots:GetChildren() do
			for _, name in { "Objects", "Resources", "Broom" } do
				local f = plot:FindFirstChild(name)
				if f then
					table.insert(list, f)
				end
			end
		end
	end
	for _, name in { "Mowers", "Pets" } do
		local f = root and root:FindFirstChild(name)
		if f then
			table.insert(list, f)
		end
	end
	for _, name in { "LeafRushFX", "LeafToolArc" } do
		local f = workspace:FindFirstChild(name)
		if f then
			table.insert(list, f)
		end
	end
	return list
end

function ToolController:_def()
	return self.ToolConfig.GrassStats(self.id, self:_up()[self.id]) or self.ToolConfig.Def(self.id) -- (v2.43: with the tier's numbers)
end

-- v2.43: the Scythe's last tier is the Golden Scythe
function ToolController:_isGold()
	return self.id == "Scythe" and self.tool ~= nil and (tonumber(self.tool:GetAttribute("Tier")) or 1) >= 5
end

---------------------------------------------------------------- first person (V, like the broom)
function ToolController:SetMode(mode)
	self.mode = if mode == "FirstPerson" then "FirstPerson" else "Aim"
	self:_applyCamera()
end

function ToolController:_fp()
	return self.mode == "FirstPerson"
end

-- first person while a tool is in hand (and no window is open: a window needs the
-- mouse free). Leaving it: back to the normal camera — but only if no other tool took
-- over in the same frame (switching tools must not pop the camera out and back in)
function ToolController:_applyCamera()
	local want = self.active and self:_fp() and not self.uiOpen and self.hum ~= nil and self.hum.Health > 0
	if want and not self.fpOn then
		self.fpOn = true
		if not self.camSaved then
			self.camSaved = true
			self.prevCamMode = player.CameraMode
			self.prevMinZoom = player.CameraMinZoomDistance
		end
		self.camToken = (self.camToken or 0) + 1
		player.CameraMode = Enum.CameraMode.LockFirstPerson
	elseif not want and self.fpOn then
		self.fpOn = false
		self.camToken = (self.camToken or 0) + 1
		local token = self.camToken
		task.defer(function()
			if self.camToken ~= token or self.fpOn then
				return -- (another tool / the window closed: first person again)
			end
			self.camSaved = false
			player.CameraMode = self.prevCamMode or Enum.CameraMode.Classic
			local old = self.prevMinZoom or 0.5
			if player.CameraMode == Enum.CameraMode.Classic then
				-- step back out to a comfortable third-person distance
				player.CameraMinZoomDistance = math.min(12, player.CameraMaxZoomDistance)
				task.delay(0.15, function()
					if self.camToken == token then
						player.CameraMinZoomDistance = old
					end
				end)
			end
		end)
	end
end

-- a window opened / closed (the bootstrap tells us): free the mouse for it
function ToolController:SetUiOpen(open)
	self.uiOpen = open
	self:_applyCamera()
end

---------------------------------------------------------------- tool effects (made locally on the tool in hand)
local TEX_SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local TEX_SMOKE = "rbxasset://textures/particles/smoke_main.dds"
-- v2.42 the Leaf Blaster: the colour of its pulse / pips by tier (1 Basic … 4 Legendary)
-- (ToolModels.BlasterGlow has the same colours, for the model)
local BLAST_TINT = { Color3.fromRGB(190, 240, 255), Color3.fromRGB(255, 200, 120), Color3.fromRGB(130, 210, 255), Color3.fromRGB(150, 255, 235) }
local BLAST_DARK = Color3.fromRGB(45, 45, 52)

local function emitter(parent, props)
	local e = Instance.new("ParticleEmitter")
	e.Name = "LeafToolFX"
	e.Enabled = false
	e.LightEmission = 0.3
	for k, v in props do
		(e :: any)[k] = v
	end
	e.Parent = parent
	return e
end

-- sets up the glow / particles for the tool in hand; returns { Work = emitters on while
-- working, Burst = emitters for one-off bursts }
function ToolController:_toolFX(tool)
	local fx = { Work = {}, Burst = {}, Made = {} }
	local function part(name)
		local p = tool:FindFirstChild(name, true)
		return if p and p:IsA("BasePart") then p else nil
	end
	local function keep(inst)
		table.insert(fx.Made, inst)
		return inst
	end
	local id = self.id
	if self.kind == "Trimmer" then
		local head = part("Head")
		if head then
			-- chopped grass flying out + a green glow of the line
			table.insert(fx.Work, keep(emitter(head, { Texture = TEX_SPARK, Color = ColorSequence.new(Color3.fromRGB(120, 220, 80), Color3.fromRGB(70, 150, 50)), Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) }), Lifetime = NumberRange.new(0.25, 0.5), Speed = NumberRange.new(8, 14), SpreadAngle = Vector2.new(180, 25), Rate = 70, Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-400, 400), Drag = 3 })))
			local light = keep(Instance.new("PointLight"))
			light.Color = Color3.fromRGB(140, 255, 110)
			light.Range = 6
			light.Brightness = 0
			light.Parent = head
			fx.Light = light
			-- v2.41: the upgraded trimmer (tier 3 Turbo / 4 Legendary) throws glowing sparks
			-- in its line's colour and shines in it
			local tier = math.clamp(math.floor(tonumber(tool:GetAttribute("Tier")) or 1), 1, 4)
			if tier >= 3 then
				local tint = if tier >= 4 then Color3.fromRGB(255, 215, 90) else Color3.fromRGB(110, 220, 255)
				light.Color = tint
				light.Range = 6 + tier
				table.insert(fx.Work, keep(emitter(head, { Texture = TEX_SPARK, Color = ColorSequence.new(Color3.new(1, 1, 1), tint), Size = NumberSequence.new(0.25, 0), Lifetime = NumberRange.new(0.2, 0.4), Speed = NumberRange.new(10, 16), SpreadAngle = Vector2.new(180, 20), Rate = 20 + tier * 8, LightEmission = 1, Drag = 3 })))
			end
		end
	elseif self.kind == "Blower" then
		-- v1.7: the more it's upgraded (tier 1…4), the more it blows: more / bigger air,
		-- then coloured streaks, spinning leaf bits and a glow
		local tier = tool:GetAttribute("Tier") or 1
		self.fxTier = tier
		local k = 1 + (tier - 1) * 0.6
		local tint = ({ Color3.fromRGB(200, 235, 255), Color3.fromRGB(255, 190, 130), Color3.fromRGB(120, 200, 255), Color3.fromRGB(120, 255, 240) })[tier]
		local nose = part("Nose")
		if nose then
			-- a fast stream of air along the tube
			local a = keep(Instance.new("Attachment"))
			a.Parent = nose
			table.insert(fx.Work, keep(emitter(a, { Texture = TEX_SMOKE, Color = ColorSequence.new(Color3.fromRGB(235, 245, 255)), Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) }), Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 2.2 + (tier - 1) * 0.5) }), Lifetime = NumberRange.new(0.35, 0.6 + tier * 0.06), Speed = NumberRange.new(26, 34 + tier * 3), SpreadAngle = Vector2.new(8 + tier * 2, 8 + tier * 2), Rate = 45 * k, EmissionDirection = Enum.NormalId.Front })))
			table.insert(fx.Work, keep(emitter(a, { Texture = TEX_SPARK, Color = ColorSequence.new(tint), Size = NumberSequence.new(0.15 + tier * 0.03, 0), Lifetime = NumberRange.new(0.3, 0.5), Speed = NumberRange.new(30, 40), SpreadAngle = Vector2.new(6, 6), Rate = 30 * k, LightEmission = 0.8, EmissionDirection = Enum.NormalId.Front })))
			if tier >= 2 then
				-- tumbling bits of leaves in the stream
				table.insert(fx.Work, keep(emitter(a, { Texture = TEX_SPARK, Color = ColorSequence.new(Color3.fromRGB(240, 160, 60), Color3.fromRGB(140, 200, 70)), Size = NumberSequence.new(0.3, 0.1), Lifetime = NumberRange.new(0.4, 0.7), Speed = NumberRange.new(18, 26), SpreadAngle = Vector2.new(14, 14), Rate = 10 + tier * 6, Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-500, 500), EmissionDirection = Enum.NormalId.Front })))
			end
			if tier >= 3 then
				-- (v1.10: the round "rings of wind" puffs are gone — just a glow)
				local light = keep(Instance.new("PointLight"))
				light.Color = tint
				light.Range = 5 + tier
				light.Brightness = 0
				light.Parent = nose
				fx.Light = light
			end
			if tier >= 4 then
				-- a glittering trail
				table.insert(fx.Work, keep(emitter(a, { Texture = TEX_SPARK, Color = ColorSequence.new(Color3.fromRGB(255, 230, 120), tint), Size = NumberSequence.new(0.45, 0), Lifetime = NumberRange.new(0.5, 0.9), Speed = NumberRange.new(10, 30), SpreadAngle = Vector2.new(25, 25), Rate = 40, LightEmission = 1, Drag = 2, EmissionDirection = Enum.NormalId.Front })))
			end
		end
		local tur = part("Turbine")
		if tur then
			table.insert(fx.Work, keep(emitter(tur, { Texture = TEX_SPARK, Color = ColorSequence.new(tint), Size = NumberSequence.new(0.2, 0), Lifetime = NumberRange.new(0.2, 0.35), Speed = NumberRange.new(2, 4), SpreadAngle = Vector2.new(180, 180), Rate = 25, LightEmission = 1 })))
		end
	elseif self.kind == "Vacuum" then
		-- v1.7: more, bigger, brighter swirls with each tier; a vortex of sparks at the
		-- nozzle (3), a glowing core that crackles (4)
		local tier = tool:GetAttribute("Tier") or 1
		self.fxTier = tier
		local k = 1 + (tier - 1) * 0.6
		local c1 = ({ Color3.fromRGB(200, 150, 255), Color3.fromRGB(120, 255, 225), Color3.fromRGB(255, 130, 150), Color3.fromRGB(255, 215, 90) })[tier]
		local c2 = ({ Color3.fromRGB(120, 80, 255), Color3.fromRGB(40, 180, 170), Color3.fromRGB(200, 40, 80), Color3.fromRGB(255, 150, 40) })[tier]
		local nose = part("Nose")
		if nose then
			-- a swirl pulled INTO the nozzle
			table.insert(fx.Work, keep(emitter(nose, { Texture = TEX_SPARK, Color = ColorSequence.new(c1, c2), Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 0.35 + tier * 0.05) }), Lifetime = NumberRange.new(0.4, 0.6), Speed = NumberRange.new(-9 - tier, -6), SpreadAngle = Vector2.new(180, 180), Rate = 50 * k, LightEmission = 0.9, Shape = Enum.ParticleEmitterShape.Sphere, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface })))
			if tier >= 2 then
				table.insert(fx.Work, keep(emitter(nose, { Texture = TEX_SMOKE, Color = ColorSequence.new(c1), Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.6), NumberSequenceKeypoint.new(1, 1) }), Size = NumberSequence.new(1.6, 0.2), Lifetime = NumberRange.new(0.35, 0.5), Speed = NumberRange.new(-6, -4), SpreadAngle = Vector2.new(180, 180), Rate = 12 + tier * 5, Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-300, 300), Shape = Enum.ParticleEmitterShape.Sphere, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface })))
			end
			if tier >= 3 then
				table.insert(fx.Work, keep(emitter(nose, { Texture = TEX_SPARK, Color = ColorSequence.new(Color3.new(1, 1, 1), c1), Size = NumberSequence.new(0.25, 0), Lifetime = NumberRange.new(0.25, 0.4), Speed = NumberRange.new(-14, -10), SpreadAngle = Vector2.new(180, 180), Rate = 30 + tier * 5, LightEmission = 1, Shape = Enum.ParticleEmitterShape.Sphere, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface, ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward })))
			end
		end
		local lamp = part("Light")
		if lamp then
			local light = keep(Instance.new("PointLight"))
			light.Color = c1
			light.Range = 7 + (tier - 1) * 2
			light.Brightness = 0
			light.Parent = lamp
			fx.Light = light
		end
		local core = part("Vortex")
		if core then
			table.insert(fx.Work, keep(emitter(core, { Texture = TEX_SPARK, Color = ColorSequence.new(c1, Color3.new(1, 1, 1)), Size = NumberSequence.new(0.3, 0), Lifetime = NumberRange.new(0.3, 0.5), Speed = NumberRange.new(1, 3), SpreadAngle = Vector2.new(180, 180), Rate = 35, LightEmission = 1 })))
		end
	elseif self.kind == "Blaster" then
		-- v2.42: a flash of sparks and a puff of air at the muzzle for every pulse (Burst),
		-- a light that flashes, and the drum's six pips (the magazine, lit by _blastGear)
		local tier = tool:GetAttribute("Tier") or 1
		self.fxTier = tier
		local tint = BLAST_TINT[tier] or BLAST_TINT[1]
		local nose = part("Nose")
		if nose then
			local a = keep(Instance.new("Attachment"))
			a.Parent = nose
			table.insert(fx.Burst, keep(emitter(a, { Texture = TEX_SPARK, Color = ColorSequence.new(Color3.new(1, 1, 1), tint), Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) }), Lifetime = NumberRange.new(0.15, 0.32), Speed = NumberRange.new(14, 26), SpreadAngle = Vector2.new(14, 14), LightEmission = 1, EmissionDirection = Enum.NormalId.Front })))
			table.insert(fx.Burst, keep(emitter(a, { Texture = TEX_SMOKE, Color = ColorSequence.new(Color3.fromRGB(235, 245, 255)), Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) }), Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 2 + tier * 0.4) }), Lifetime = NumberRange.new(0.3, 0.55), Speed = NumberRange.new(5, 10), SpreadAngle = Vector2.new(25, 25), Drag = 3, EmissionDirection = Enum.NormalId.Front })))
			local flash = keep(Instance.new("PointLight"))
			flash.Color = tint
			flash.Range = 9
			flash.Brightness = 0
			flash.Parent = nose
			fx.Flash = flash
		end
		fx.Pips = {}
		for k = 1, 6 do
			fx.Pips[k] = part("Pip" .. k)
		end
	elseif self.kind == "Swing" or self.kind == "Swipe" or self.kind == "Snip" then
		-- a glowing trail along the blade (you see the swing), sparks on every cut
		local blades = {}
		for _, d in tool:GetDescendants() do
			if d:IsA("BasePart") and (d.Name == "Blade" or d.Name == "Tooth") then
				table.insert(blades, d)
			end
		end
		local first, last = blades[1], blades[#blades]
		if first and last then
			local a0, a1 = keep(Instance.new("Attachment")), keep(Instance.new("Attachment"))
			a0.Parent, a1.Parent = first, last
			local gold = id == "Scythe" and (tonumber(tool:GetAttribute("Tier")) or 1) >= 5
			local tr = keep(Instance.new("Trail"))
			tr.Attachment0, tr.Attachment1 = a0, a1
			tr.Lifetime = 0.22
			tr.LightEmission = 0.8
			tr.Color = ColorSequence.new(if gold then Color3.fromRGB(255, 225, 110) else Color3.fromRGB(220, 255, 220))
			tr.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
			tr.FaceCamera = true
			tr.Enabled = false -- (on only while the blade swings: _pose)
			tr.Parent = first
			fx.Trail = tr
			table.insert(fx.Burst, keep(emitter(last, { Texture = TEX_SPARK, Color = ColorSequence.new(if gold then Color3.fromRGB(255, 220, 90) else Color3.fromRGB(230, 255, 230)), Size = NumberSequence.new(0.3, 0), Lifetime = NumberRange.new(0.3, 0.5), Speed = NumberRange.new(4, 9), SpreadAngle = Vector2.new(180, 180), LightEmission = 1 })))
			if gold then
				local light = keep(Instance.new("PointLight"))
				light.Color = Color3.fromRGB(255, 210, 90)
				light.Range = 8
				light.Brightness = 0.5
				light.Parent = last
			end
		end
	end
	-- v2.43: the energy gauge on the model of the Leaf Blower / the Leaf Blaster (five segments)
	if self.kind == "Blower" or self.kind == "Blaster" then
		fx.Segs = {}
		for k = 1, 5 do
			fx.Segs[k] = part("Seg" .. k)
		end
	end
	return fx
end

function ToolController:_fxWork(on)
	local fx = self.fx
	if not fx or fx.WorkOn == on then
		return
	end
	fx.WorkOn = on
	for _, e in fx.Work do
		e.Enabled = on
	end
	if fx.Light then
		fx.Light.Brightness = if on then 0.7 else 0
	end
end

function ToolController:_fxBurst(n)
	for _, e in (self.fx and self.fx.Burst) or {} do
		e:Emit(n or 12)
	end
end

---------------------------------------------------------------- lifecycle
function ToolController:Start(tool)
	self:Stop()
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not hum or not root then
		return
	end
	self.tool, self.id = tool, tool:GetAttribute("LeafTool")
	local def = self:_def()
	if not def or def.Kind == "Ride" or def.Kind == "Pick" then
		-- (v2.32: the Pickaxe has its own controller — the client module Pickaxe)
		self.tool, self.id = nil, nil
		return
	end
	self.active = true
	self.char, self.hum, self.root = char, hum, root
	self.kind = def.Kind or self.id -- "Snip" / … or "Blower" / "Vacuum"
	self.pressing = false
	self.swipeAcc, self.swipeDir, self.lastMouseX = 0, 0, nil
	self.lastUse, self.lastSend = -1e9, -1e9
	self.anim = nil
	self.ray.FilterDescendantsInstances = self:_rayIgnore(char) -- v1.4: the aim goes THROUGH trees / decor to the ground
	-- the shoulder we swing
	local arm = char:FindFirstChild("RightUpperArm")
	self.shoulder = (arm and arm:FindFirstChild("RightShoulder")) or (char:FindFirstChild("Torso") and char.Torso:FindFirstChild("Right Shoulder"))
	local larm = char:FindFirstChild("LeftUpperArm")
	self.lshoulder = (larm and larm:FindFirstChild("LeftShoulder")) or (char:FindFirstChild("Torso") and char.Torso:FindFirstChild("Left Shoulder"))
	self.r15 = arm ~= nil
	-- where the tool is aimed: a flat ring on the ground (v1.4: not for the scythe,
	-- the weed cutter and the blower — they work around / in front of you, a ring
	-- under your feet only got in the way)
	local ring = if self.kind == "Swing" or self.kind == "Swipe" or self.kind == "Blower" or self.kind == "Push" or self.kind == "Blaster" then nil else Instance.new("Part") -- (v2.42: the blaster has none either — its pulse shows where it goes)
	if ring then
		ring.Name = "LeafToolAim"
		ring.Anchored = true
		ring.CanCollide = false
		ring.CanQuery = false
		ring.CanTouch = false
		ring.CastShadow = false
		ring.Shape = Enum.PartType.Cylinder
		ring.Material = Enum.Material.Neon
		ring.Transparency = 0.75
		ring.Color = if self:_isGold() then Color3.fromRGB(255, 210, 80) elseif self.kind == "Blower" then Color3.fromRGB(170, 220, 255) elseif self.kind == "Vacuum" then Color3.fromRGB(190, 140, 255) else Color3.fromRGB(150, 240, 120)
		ring.Parent = workspace
	end
	self.ring = ring
	-- a looping motor sound for the powered tools
	if self.kind == "Trimmer" or self.kind == "Push" or self.kind == "Blower" or self.kind == "Vacuum" then
		local s = Instance.new("Sound")
		s.SoundId = self.Config.FX.ToolSounds.Loop
		s.Looped = true
		s.Volume = 0
		s.PlaybackSpeed = if self.kind == "Trimmer" then 3.2 elseif self.kind == "Push" then 0.7 elseif self.kind == "Blower" then 1.5 else 1
		s.Parent = root
		s:Play()
		self.loop = s
	end
	self.fx = self:_toolFX(tool)
	self.wasReloading = nil -- v2.42
	self:_jetFX() -- v2.34 (the blower remembers its mode)
	self.mouseDX = 0
	self.mode = if player:GetAttribute("Setting_CameraMode") == "FirstPerson" then "FirstPerson" else "Aim"
	self:_applyCamera()
	self.conn = RunService.RenderStepped:Connect(function(dt)
		self:_step(dt)
	end)
	self.animConn = RunService.Stepped:Connect(function()
		self:_pose()
	end)
end

function ToolController:Stop()
	if not self.active then
		return
	end
	self.active = false
	self.pressing = false
	self.buttonPress = false
	self:_jetStop() -- v2.34
	if self.conn then
		self.conn:Disconnect()
		self.conn = nil
	end
	if self.animConn then
		self.animConn:Disconnect()
		self.animConn = nil
	end
	if self.ring then
		self.ring:Destroy()
		self.ring = nil
	end
	if self.loop then
		self.loop:Destroy()
		self.loop = nil
	end
	if self.fx then
		for _, inst in self.fx.Made do
			inst:Destroy()
		end
		self.fx = nil
	end
	self:_applyCamera()
	if self.shoulder and self.lastWritten and self.shoulder.Transform == self.lastWritten then
		self.shoulder.Transform = self.lastBase
	end
	self.lastWritten, self.lastBase, self.anim = nil, nil, nil
	if self.lshoulder and self.lWritten and self.lshoulder.Transform == self.lWritten then
		self.lshoulder.Transform = self.lBase
	end
	self.lWritten, self.lBase = nil, nil
	if self.hum then
		self.hum.AutoRotate = true
	end
	self.tool, self.id = nil, nil
end

---------------------------------------------------------------- input
function ToolController:_press(on)
	if on == self.pressing then
		return
	end
	self.pressing = on
	if on then
		self.lastMouseX = nil
		self.swipeAcc = 0
		if self.kind == "Snip" then
			self:_snip()
		elseif self.kind == "Swing" then
			self:_swing()
		elseif self.kind == "Blaster" then
			self:_blastFire(self:_aim()) -- v2.42: a click is a shot (holding goes on in _step)
		end
	end
	if self.hum then
		-- while working you face your aim (the body turns toward it)
		self.hum.AutoRotate = self:_fp() or not (on and self.kind ~= "Push")
	end
end

-- the point on the ground you aim at (mouse or finger)
function ToolController:_aim()
	local cam = workspace.CurrentCamera
	-- v1.4 touch: the USE button works the tool IN FRONT of you (no finger on the ground)
	if self.buttonPress and not self.touchPos and self.root then
		local look = Vector3.new(self.root.CFrame.LookVector.X, 0, self.root.CFrame.LookVector.Z)
		look = if look.Magnitude > 1e-3 then look.Unit else Vector3.new(0, 0, -1)
		return self.root.Position + look * 4 - Vector3.new(0, 2.9, 0)
	end
	local screen = self.touchPos or UserInputService:GetMouseLocation()
	if self:_fp() and not self.touchPos then
		screen = cam.ViewportSize / 2 -- (first person: the crosshair in the middle)
	end
	local ray = if self.touchPos then cam:ScreenPointToRay(screen.X, screen.Y) else cam:ViewportPointToRay(screen.X, screen.Y)
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 300, self.ray)
	if hit then
		return hit.Position
	end
	local groundY = self.root.Position.Y - 3
	if math.abs(ray.Direction.Y) > 1e-3 then
		local t = (groundY - ray.Origin.Y) / ray.Direction.Y
		if t > 0 then
			return ray.Origin + ray.Direction * t
		end
	end
	return self.root.Position + self.root.CFrame.LookVector * 4 - Vector3.new(0, 3, 0)
end

local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

function ToolController:_face(point)
	if self:_fp() then
		return -- (first person: you already face where the camera looks)
	end
	local d = flat(point - self.root.Position)
	if d.Magnitude > 0.5 then
		local pos = self.root.Position
		self.root.CFrame = CFrame.lookAt(pos, pos + d)
	end
end

function ToolController:_send(req)
	self.Remote:FireServer(req)
end

---------------------------------------------------------------- the tools
function ToolController:_snip()
	local def = self:_def()
	local now = os.clock()
	if now - self.lastUse < def.Cooldown then
		return
	end
	self.lastUse = now
	local aim = self:_clampAim(self:_aim(), def.Reach)
	self:_face(aim)
	self.anim = { Kind = "Snip", T0 = now, Len = 0.22 }
	self:_send({ A = "Cut", Pos = aim, Dir = flat(aim - self.root.Position) })
	self:_cutFX(aim, def.Radius)
end

function ToolController:_swipe(dir)
	local def = self:_def()
	local now = os.clock()
	if now - self.lastUse < def.Cooldown then
		return
	end
	self.lastUse = now
	local look = flat(self.root.CFrame.LookVector).Unit
	self.anim = { Kind = "Swipe", T0 = now, Len = 0.2, Dir = dir }
	local center = self.root.Position + look * def.Reach
	self:_send({ A = "Cut", Pos = center, Dir = look })
	self:_arcFX(self.root.Position, look, def.Reach + def.Radius, def.Arc or 90, Color3.fromRGB(200, 255, 200), 0.22)
	self:_cutFX(center - Vector3.new(0, 2.8, 0), def.Radius * 0.8)
end

function ToolController:_swing()
	local def = self:_def()
	local now = os.clock()
	if (self.anim and self.anim.Kind == "Swing") or now - self.lastUse < def.Cooldown then
		return
	end
	self.lastUse = now
	local aim = self:_aim()
	self:_face(aim)
	self.anim = { Kind = "Swing", T0 = now, Len = 0.75 }
	local look = flat(self.root.CFrame.LookVector).Unit
	-- the wind-up, then the swing (the server cuts when the blade comes round)
	task.delay(0.25, function()
		if not self.active or self.id == nil then
			return
		end
		self:_send({ A = "Cut", Pos = self.root.Position, Dir = look })
		local gold = self:_isGold()
		self:_arcFX(self.root.Position, look, def.Radius, def.Arc or 160, if gold then Color3.fromRGB(255, 220, 90) else Color3.fromRGB(235, 255, 235), 0.4)
		if gold then
			self.Juice.Burst(self.root.Position, Color3.fromRGB(255, 220, 90), 18, 10)
		end
		self.Juice.Sound(self.Config.FX.ToolSounds.Cut, if gold then 1.1 else 0.8, 0.5, "scythe")
		for k = -1, 1 do
			local d = CFrame.Angles(0, k * math.rad(45), 0):VectorToWorldSpace(look)
			self:_cutFX(self.root.Position + d * def.Radius * 0.6 - Vector3.new(0, 2.8, 0), 2)
		end
	end)
end

function ToolController:_clampAim(aim, reach)
	local off = flat(aim - self.root.Position)
	if off.Magnitude > reach then
		off = off.Unit * reach
		local p = self.root.Position + off
		return Vector3.new(p.X, aim.Y, p.Z)
	end
	return aim
end

---------------------------------------------------------------- effects
function ToolController:_cutFX(pos, radius)
	self:_fxBurst(math.clamp(math.floor(radius * 3), 6, 18))
	-- grass bits flying up + a soft ring where it was cut
	self.Juice.Burst(pos + Vector3.new(0, 0.4, 0), Color3.fromRGB(110, 190, 70), math.clamp(math.floor(radius * 4), 6, 22), 8)
	self.Juice.Burst(pos + Vector3.new(0, 0.6, 0), Color3.fromRGB(170, 230, 110), 5, 4)
	self.Juice.Ring(pos + Vector3.new(0, 0.15, 0), Color3.fromRGB(150, 235, 110), radius, 0.3)
	self.Juice.Sound(self.Config.FX.ToolSounds.Cut, 1.9 + math.random() * 0.3, 0.3, "snip")
end

-- a quick fading arc of the blade's path
function ToolController:_arcFX(center, look, radius, arc, color, life)
	local folder = Instance.new("Folder")
	folder.Name = "LeafToolArc"
	folder.Parent = workspace
	local n = math.clamp(math.floor(arc / 15), 4, 12)
	local y = center.Y - 2.6
	local parts = {}
	for k = 0, n - 1 do
		local a = math.rad(-arc / 2 + (k + 0.5) * arc / n)
		local d = CFrame.Angles(0, a, 0):VectorToWorldSpace(look)
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = Enum.Material.Neon
		p.Color = color
		p.Transparency = 0.35
		p.Size = Vector3.new(0.15, 0.25, radius * math.rad(arc / n) * 1.05)
		local at = Vector3.new(center.X, y, center.Z) + d * radius * 0.85
		p.CFrame = CFrame.lookAt(at, at + d:Cross(Vector3.yAxis))
		p.Parent = folder
		table.insert(parts, p)
	end
	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = (os.clock() - t0) / life
		if t >= 1 then
			conn:Disconnect()
			folder:Destroy()
			return
		end
		for _, p in parts do
			p.Transparency = 0.35 + 0.65 * t
		end
	end)
end

---------------------------------------------------------------- per frame
local function myParts(self, center, radius)
	local folders = self.MyResources()
	if not folders then
		return {}
	end
	self.overlap.FilterDescendantsInstances = if typeof(folders) == "Instance" then { folders } else folders
	return workspace:GetPartBoundsInRadius(center, radius, self.overlap)
end

---------------------------------------------------------------- v2.42 the LEAF BLASTER
--[[
	One shot = one AIR PULSE. The server (ToolService.BlastAt) counts the magazine (6
	pulses, then a reload), the energy and the fire rate and shoves other players; here:
	  • the pulse: a glowing ball with ribbons flies from the muzzle to your aim and on
		(B.Speed studs/s, B.Range studs). Every item it touches — the ones this client
		owns (MyResources), like the Leaf Blower's — is knocked away: mostly forward, a
		little to the sides, with a hop and a spin, never faster than the anti-teleport
		limit (Config.Resources.MaxSpeed).
	  • STONE items (attribute Heavy) and items locked in ICE (IceHP) are never touched.
	  • the items it threw are tracked for ~1.3 s ("flying"): they bounce (their elasticity
		is raised for that time) and when one runs into another loose item it shoves it
		away like a billiard ball (equal masses), which then flies and shoves the next …
		(three links at most) — "hit -> fly -> crash -> bounce off".
	  • effects: muzzle flash, sound, a pulse with ribbons and sparks, a ring where it hits,
		a streak + sparks on every struck leaf, sparks where two items crash.
	The magazine as THIS client knows it: BlastState() (the server's numbers, then what
	was fired since). Reload() / BlastState() are also used by the touch button and ToolHud.
]]
local Debris = game:GetService("Debris")
local rng = Random.new()

local function serverNow()
	local ok, t = pcall(function()
		return workspace:GetServerTimeNow()
	end)
	return if ok then t else os.time()
end

-- a part this pulse may move: loose, simulated by me, and not a stone / ice / carried one
local function blastable(part, stone) -- (stone: a fully upgraded blaster may nudge STONE items)
	return part:IsA("BasePart") and not part.Anchored and part.ReceiveAge == 0 and (stone == true or not part:GetAttribute("Heavy")) and part:GetAttribute("IceHP") == nil and not part:GetAttribute("Carried") and not part:GetAttribute("Cocooned")
end

local function clampV(v, cap)
	if v.Magnitude > cap then
		return v.Unit * cap
	end
	return v
end

function ToolController:_blaster()
	return self.ToolConfig.Blaster(self:_up().Blaster or {})
end

-- v2.43: seconds of the cooldown of this tool's strike-key ability, and how long it is
function ToolController:AbilityLeft()
	local name = self.ToolConfig.AbilityAttr[self.id]
	if not name then
		return 0, 0
	end
	local ready = player:GetAttribute(name .. "Ready")
	local total = tonumber(player:GetAttribute(name .. "Cd")) or 30
	if type(ready) ~= "number" then
		return 0, total
	end
	return math.clamp(ready - serverNow(), 0, total), total
end

-- the strike key with Shears / Weed Cutter / Scythe / Push Mower in the hand (the server decides)
function ToolController:UseAbility()
	local ab = self.ToolConfig.Abilities[self.id]
	if not self.active or self.uiOpen or not ab or not self.root then
		return false
	end
	local now = os.clock()
	if now - (self.abSent or 0) < 0.4 then
		return false
	end
	local left = self:AbilityLeft()
	if left > 0 then
		if now - (self.abSaid or 0) > 1.2 then
			self.abSaid = now
			self:_toast(string.format("%s %s recharges — %d s", ab.Icon, ab.Display, math.ceil(left)), 1.5)
		end
		return false
	end
	self.abSent = now
	self:_send({ A = "Ability", Pos = self:_aim() })
	if self.kind == "Snip" or self.kind == "Swipe" or self.kind == "Swing" then
		self.anim = { Kind = "Swing", T0 = now, Len = 0.7 }
	end
	return true
end

-- every frame: the five segments of the gauge on the model light by the energy left
function ToolController:_energyGear()
	local fx = self.fx
	if not fx or not fx.Segs then
		return
	end
	local left, max
	if self.kind == "Blower" then
		left, max = player:GetAttribute("BlowLeft"), player:GetAttribute("BlowMax")
	else
		left, max = player:GetAttribute("BlastLeft"), player:GetAttribute("BlastMax")
	end
	if type(left) ~= "number" or type(max) ~= "number" or max <= 0 then
		return
	end
	local f = math.clamp(left / max, 0, 1)
	local lit = if left <= 0 then 0 else math.clamp(math.ceil(f * 5 - 1e-6), 1, 5)
	local color = if f > 0.4 then Color3.fromRGB(110, 230, 100) elseif f > 0.2 then Color3.fromRGB(250, 190, 60) else Color3.fromRGB(235, 70, 60)
	if lit ~= fx.SegLit or color ~= fx.SegColor then
		fx.SegLit, fx.SegColor = lit, color
		for k, seg in fx.Segs do
			seg.Color = if k <= lit then color else BLAST_DARK
			seg.Material = if k <= lit then Enum.Material.Neon else Enum.Material.SmoothPlastic
		end
	end
end

-- the magazine: (shots left, magazine size, seconds of reload left, the whole reload)
function ToolController:BlastState()
	local B = self:_blaster()
	local seq = player:GetAttribute("BlastSeq")
	if seq ~= self.bSeq then
		self.bSeq = seq -- (the server published: take its numbers)
		local mag, at = player:GetAttribute("BlastMag"), player:GetAttribute("BlastReloadAt")
		self.bMag = if type(mag) == "number" then mag else B.Magazine
		self.bReloadAt = if type(at) == "number" then at else 0
	end
	local now = serverNow()
	if self.bReloadAt > 0 and now >= self.bReloadAt then
		self.bReloadAt = 0 -- (a reload that is over fills the magazine)
		self.bMag = B.Magazine
	end
	self.bMag = math.min(self.bMag or B.Magazine, B.Magazine)
	return self.bMag, B.Magazine, if self.bReloadAt > 0 then self.bReloadAt - now else 0, B.Reload
end

function ToolController:_blastReloadFX(B)
	self.anim = { Kind = "Reload", T0 = os.clock(), Len = math.min(0.7, B.Reload * 0.5) }
	self.Juice.Sound(self.Config.FX.ToolSounds.Cut, 1.9, 0.35, "blastreload")
	if self.root then
		self.Juice.Popup(self.root.Position + Vector3.new(0, 3.2, 0), "RELOAD", Color3.fromRGB(255, 230, 150), 0.8)
	end
end

-- the strike key / the touch button: reload now (not when it's full or already reloading)
function ToolController:Reload()
	if not self.active or self.kind ~= "Blaster" or self.uiOpen then
		return false
	end
	local mag, cap, left = self:BlastState()
	if left > 0 or mag >= cap then
		return false
	end
	local B = self:_blaster()
	self.bReloadAt = serverNow() + B.Reload
	self:_send({ A = "Reload" })
	self:_blastReloadFX(B)
	return true
end

-- every frame while it is in the hand: the drum's pips (one per pulse; a reload fills them
-- one by one), the click when the reload is over, the muzzle light fading
function ToolController:_blastGear(dt)
	local fx = self.fx
	local mag, cap, left, total = self:BlastState()
	local reloading = left > 0
	if self.wasReloading and not reloading and self.root then
		self.Juice.Sound(self.Config.FX.ToolSounds.Cut, 2.4, 0.3, "blastready")
		self:_fxBurst(6)
		self.Juice.Popup(self.root.Position + Vector3.new(0, 3.2, 0), "READY!", Color3.fromRGB(160, 255, 170), 0.7)
	end
	self.wasReloading = reloading
	if not fx then
		return
	end
	if fx.Pips then
		local shown = if reloading then math.floor((1 - left / math.max(total, 0.1)) * cap) else mag
		if shown ~= fx.PipsShown then
			fx.PipsShown = shown
			local tint = BLAST_TINT[self.fxTier or 1] or BLAST_TINT[1]
			for k, pip in fx.Pips do
				local on = k <= shown
				pip.Color = if on then tint else BLAST_DARK
				pip.Material = if on then Enum.Material.Neon else Enum.Material.SmoothPlastic
			end
		end
	end
	if fx.Flash and fx.Flash.Brightness > 0 then
		fx.Flash.Brightness = math.max(0, fx.Flash.Brightness - dt * 20)
	end
end

-- the pulse you see: a glowing core inside a thin air shell, two ribbons (up-down and
-- left-right) behind it, sparks and bits of leaves, a light. -> { folder, core, shell }
local function pulseVisual(origin, dir, size, tint, tier)
	local folder = Instance.new("Folder")
	folder.Name = "LeafToolArc" -- (the aim ray ignores this folder)
	folder.Parent = workspace
	local function ball(name, diameter, color, transparency)
		local b = Instance.new("Part")
		b.Name = name
		b.Shape = Enum.PartType.Ball
		b.Anchored = true
		b.CanCollide = false
		b.CanQuery = false
		b.CanTouch = false
		b.CastShadow = false
		b.Material = Enum.Material.Neon
		b.Color = color
		b.Transparency = transparency
		b.Size = Vector3.one * diameter
		b.CFrame = CFrame.lookAt(origin, origin + dir)
		b.Parent = folder
		return b
	end
	local core = ball("Core", size, tint, 0.3)
	local shell = ball("Shell", size * 2, Color3.new(1, 1, 1), 0.82)
	for _, axis in { Vector3.yAxis, Vector3.xAxis } do
		local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
		a0.Position, a1.Position = axis * size * 0.9, -axis * size * 0.9
		a0.Parent, a1.Parent = core, core
		local tr = Instance.new("Trail")
		tr.Attachment0, tr.Attachment1 = a0, a1
		tr.Lifetime = 0.28
		tr.LightEmission = 0.85
		tr.FaceCamera = false
		tr.Color = ColorSequence.new(tint, Color3.new(1, 1, 1))
		tr.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 1) })
		tr.Parent = core
	end
	local k = 1 + (tier - 1) * 0.5
	local function spark(props)
		local e = emitter(core, props)
		e.Enabled = true
		return e
	end
	spark({ Texture = TEX_SPARK, Color = ColorSequence.new(Color3.new(1, 1, 1), tint), Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) }), Lifetime = NumberRange.new(0.25, 0.45), Speed = NumberRange.new(2, 7), SpreadAngle = Vector2.new(180, 180), Rate = 60 * k, LightEmission = 1, Drag = 2 })
	spark({ Texture = TEX_SPARK, Color = ColorSequence.new(Color3.fromRGB(240, 160, 60), Color3.fromRGB(140, 200, 70)), Size = NumberSequence.new(0.35, 0.1), Lifetime = NumberRange.new(0.4, 0.7), Speed = NumberRange.new(3, 9), SpreadAngle = Vector2.new(180, 180), Rate = 18 * k, Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-500, 500) })
	local light = Instance.new("PointLight")
	light.Color = tint
	light.Range = 8 + tier
	light.Brightness = 1.2
	light.Parent = core
	return { folder = folder, core = core, shell = shell }
end

local function pulsePos(p: any, d: number)
	local t = if p.drop > 0 then math.clamp(d / p.drop, 0, 1) else 1
	return Vector3.new(p.origin.X + p.dir.X * d, p.y0 + (p.y1 - p.y0) * t, p.origin.Z + p.dir.Z * d)
end

function ToolController:_newPulse(origin, dir, size, range, speed, tier, mine, y1, power, drop)
	local p = {
		origin = origin, dir = dir, dist = 0, range = range, size = size, speed = speed, y0 = origin.Y, y1 = y1, drop = drop,
		age = 0, mine = mine, power = power, tint = BLAST_TINT[tier] or BLAST_TINT[1], tier = tier, hit = {}, count = 0, fxN = 0,
	}
	if not self.Juice.EffectsOn or self.Juice.EffectsOn() then
		p.vis = pulseVisual(origin, dir, size, p.tint, tier)
	end
	table.insert(self.pulses, p)
	return p
end

-- another player's pulse (ToolFX "Blast"): only the picture, nothing is moved by it
function ToolController:ShowPulse(origin, dir, size, range, tier)
	if typeof(origin) ~= "Vector3" or typeof(dir) ~= "Vector3" or dir.Magnitude < 0.1 or dir.Magnitude > 2 or #self.pulses >= 30 then
		return
	end
	if self.Juice.EffectsOn and not self.Juice.EffectsOn() then
		return
	end
	local d = flat(dir)
	if d.Magnitude < 1e-3 then
		return
	end
	size = math.clamp(tonumber(size) or 2.2, 1, 8)
	range = math.clamp(tonumber(range) or 34, 8, 80)
	tier = math.clamp(math.floor(tonumber(tier) or 1), 1, 4)
	self:_newPulse(origin, d.Unit, size, range, 85, tier, false, origin.Y - 1.8, 0, 14)
end

-- fire: checks the rate, the magazine and the energy here too (the server decides)
function ToolController:_blastFire(aim)
	if not self.active or self.kind ~= "Blaster" or self.uiOpen or not self.root then
		return false
	end
	local B = self:_blaster()
	local now = os.clock()
	if now - self.lastUse < B.FireEvery then
		return false
	end
	local mag, _cap, reloadLeft = self:BlastState()
	if reloadLeft > 0 then
		if now - (self.blastSaid or 0) > 0.6 then
			self.blastSaid = now
			self.Juice.Sound(self.Config.FX.ToolSounds.Cut, 2.6, 0.25, "blastdry") -- (a dry click)
		end
		return false
	end
	local left = player:GetAttribute("BlastLeft")
	if type(left) == "number" and left <= 0 then
		if now - (self.blastSaid or 0) > 2.5 then
			self.blastSaid = now
			self:_toast("🪫 The Leaf Blaster is out of energy — recharge it in SHOP · TOOLS", 3)
		end
		return false
	end
	if mag <= 0 then
		self:Reload()
		return false
	end
	self.lastUse = now
	local rootPos = self.root.Position
	local nose = self.tool and self.tool:FindFirstChild("Nose", true)
	local muzzle = if nose and nose:IsA("BasePart") then nose.Position else rootPos + flat(self.root.CFrame.LookVector) * 2.4 + Vector3.new(0, 0.2, 0)
	local dir = flat(aim - muzzle)
	local dist = dir.Magnitude
	if dist < 1.5 then
		dir = flat(self.root.CFrame.LookVector)
	end
	dir = if dir.Magnitude > 1e-3 then dir.Unit else Vector3.new(0, 0, -1)
	self:_face(aim)
	-- the magazine (predicted: the server's numbers replace it with its next publish)
	self.bMag = mag - 1
	if self.bMag <= 0 then
		self.bReloadAt = serverNow() + B.Reload
		self:_blastReloadFX(B)
	end
	self:_send({ A = "Blast", Dir = dir })
	local tier = math.clamp(math.floor(tonumber(self.tool and self.tool:GetAttribute("Tier")) or 1), 1, 4)
	local pulse = self:_newPulse(muzzle, dir, B.Size, B.Range, B.Speed, tier, true, math.min(aim.Y + 0.6, muzzle.Y + 3), B.Power, math.clamp(dist, 4, B.Range))
	pulse.stone = B.StoneNudge == true
	-- the muzzle flash, the recoil, the bang
	self:_fxBurst(10 + tier * 2)
	if self.fx and self.fx.Flash then
		self.fx.Flash.Brightness = 3
	end
	self.anim = { Kind = "Recoil", T0 = now, Len = 0.22 }
	self.Juice.Burst(muzzle + dir * 0.6, BLAST_TINT[tier], 6 + tier * 2, 14)
	self.Juice.Sound(self.Config.FX.ToolSounds.Cut, 0.5 + tier * 0.05, 0.7, "blast")
	self.Juice.Sound(self.Config.FX.ToolSounds.Cut, 1.5, 0.3, "blast2")
	self.Juice.Shake(0.07, 0.1)
	return true
end

-- a streak behind a struck leaf + a few sparks (the first dozens of every pulse only)
local function leafFX(part, tint)
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Name, a1.Name = "LeafBlastA", "LeafBlastA"
	a0.Position, a1.Position = Vector3.new(0.3, 0.05, 0), Vector3.new(-0.3, 0.05, 0)
	a0.Parent, a1.Parent = part, part
	local tr = Instance.new("Trail")
	tr.Name = "LeafBlastTrail"
	tr.Attachment0, tr.Attachment1 = a0, a1
	tr.Lifetime = 0.4
	tr.LightEmission = 0.7
	tr.Color = ColorSequence.new(tint, Color3.new(1, 1, 1))
	tr.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	tr.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) })
	tr.Parent = part
	local e = emitter(a0, { Texture = TEX_SPARK, Color = ColorSequence.new(Color3.new(1, 1, 1), tint), Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 0) }), Lifetime = NumberRange.new(0.3, 0.6), Speed = NumberRange.new(3, 8), SpreadAngle = Vector2.new(180, 180), LightEmission = 1, Rate = 0 })
	e:Emit(5)
	Debris:AddItem(a0, 1.2)
	Debris:AddItem(a1, 1.2)
	Debris:AddItem(tr, 1.2)
end

-- an item that was struck (or shoved by another one) bounces for a moment and takes part
-- in the chain of crashes (_flyStep). -> its record, or nil when too many are in the air
function ToolController:_blastBounce(part, depth)
	local f = self.flying[part]
	local now = os.clock()
	if f then
		f.t1 = now + 1.3
		return f
	end
	if self.flyN >= 48 then
		return nil
	end
	local cur = part.CurrentPhysicalProperties
	local mine = PhysicalProperties.new(cur.Density, cur.Friction, 0.82, cur.FrictionWeight, 5) -- (bouncy: its elasticity wins at every touch)
	f = { t1 = now + 1.3, depth = depth, orig = part.CustomPhysicalProperties, pair = {}, last = part.Position }
	part.CustomPhysicalProperties = mine
	self.flying[part] = f
	self.flyN += 1
	return f
end

function ToolController:_flyEnd(part, f)
	self.flying[part] = nil
	self.flyN -= 1
	if part.Parent then
		part.CustomPhysicalProperties = f.orig -- (back to what it was; nil = the material's)
	end
end

-- the pulse knocks an item away
function ToolController:_blastKick(part: BasePart, p: any, pos: Vector3)
	local rel = flat(part.Position - pos)
	local side = rel - p.dir * rel:Dot(p.dir)
	local sideDir = if side.Magnitude > 0.15 then side.Unit else Vector3.new(-p.dir.Z, 0, p.dir.X) * (if rng:NextNumber() < 0.5 then 1 else -1)
	local push = (p.dir * 0.8 + sideDir * 0.4).Unit
	local speed = math.min(p.power, self.blastCap) * (1 - 0.3 * p.dist / p.range) * rng:NextNumber(0.9, 1.1) * (if part:GetAttribute("Heavy") then 0.25 else 1)
	local v = part.AssemblyLinearVelocity
	local nv = Vector3.new(push.X * speed, math.max(v.Y, 13 + p.power * 0.28), push.Z * speed)
	part.AssemblyLinearVelocity = clampV(nv, self.blastCap)
	part.AssemblyAngularVelocity = Vector3.new(rng:NextNumber(-16, 16), rng:NextNumber(-22, 22), rng:NextNumber(-16, 16))
	p.count += 1
	self:_blastBounce(part, 0)
	if p.fxN < 26 then
		p.fxN += 1
		leafFX(part, p.tint)
	end
	if p.count == 1 then
		-- the first thing it hits: a ring on the ground and a thud
		self.Juice.Ring(Vector3.new(part.Position.X, part.Position.Y - 0.2, part.Position.Z), p.tint, p.size * 1.8, 0.3)
		self.Juice.Burst(part.Position, p.tint, 8, 10)
		self.Juice.Sound(self.Config.FX.ToolSounds.Cut, 0.9, 0.35, "blasthit")
	end
end

local function pulseEnd(self: any, p: any, pos: Vector3)
	local vis = p.vis
	if vis then
		for _, d in vis.folder:GetDescendants() do
			if d:IsA("ParticleEmitter") then
				d.Enabled = false
			elseif d:IsA("PointLight") then
				d.Enabled = false
			end
		end
		vis.core.Transparency = 1
		vis.shell.Transparency = 1
		Debris:AddItem(vis.folder, 0.6)
	end
	-- it fizzles out: a ring on the ground where it ends
	self.Juice.Ring(Vector3.new(pos.X, p.y1 - 0.5, pos.Z), p.tint, p.size * 1.4, 0.35)
	self.Juice.Burst(pos, p.tint, 5, 8)
end

-- one frame of a pulse: it flies, the picture follows, my items it touches are knocked
-- away. -> true when it is over
function ToolController:_pulseStep(p: any, dt: number)
	p.age += dt
	local prev = p.dist
	p.dist = math.min(p.dist + p.speed * dt, p.range)
	local pos = pulsePos(p, p.dist)
	local vis = p.vis
	if vis then
		local pulse = 1 + 0.1 * math.sin(p.age * 38)
		vis.core.CFrame = CFrame.lookAt(pos, pos + p.dir)
		vis.core.Size = Vector3.one * p.size * pulse
		vis.shell.CFrame = vis.core.CFrame
		vis.shell.Size = Vector3.one * p.size * 2 * (2 - pulse)
	end
	if p.mine and p.dist > prev then
		-- (the ball sweeps from where it was to where it is: nothing slips through)
		local mid = (pulsePos(p, prev) + pos) / 2
		for _, part in myParts(self, mid, p.size + (p.dist - prev) / 2 + 0.3) do
			if not p.hit[part] and blastable(part, p.stone) then
				p.hit[part] = true
				self:_blastKick(part, p, pos)
			end
		end
	end
	if p.dist >= p.range then
		pulseEnd(self, p, pos)
		return true
	end
	return false
end

-- the items that were thrown: when one runs into another loose item it shoves it away
-- (two equal masses, restitution 0.8: the first slows, the second flies), and that one
-- goes on to shove the next — three links at most. Twelve checks a second.
function ToolController:_flyStep(dt)
	self.flyAcc += dt
	if self.flyAcc < 0.08 then
		return
	end
	self.flyAcc = 0
	local now = os.clock()
	local cap = self.blastCap
	local sparks = 6
	local list = {}
	for part in self.flying do
		table.insert(list, part)
	end
	for _, part in list do
		local f = self.flying[part]
		if f then
			local va = if part.Parent then part.AssemblyLinearVelocity else Vector3.zero
			if not part.Parent or now >= f.t1 or va.Magnitude < 3 then
				self:_flyEnd(part, f)
			else
				-- (it moved from f.last to here since the last check: the whole stretch is
				-- tested, so a fast item can't slip through between two checks)
				local a0, a1 = f.last or part.Position, part.Position
				f.last = a1
				if f.depth < 3 and va.Magnitude > 8 then
					local seg = a1 - a0
					local segLen2 = seg:Dot(seg)
					for _, o in myParts(self, (a0 + a1) / 2, 1.4 + math.sqrt(segLen2) / 2) do
						if o ~= part and (f.pair[o] or 0) < now and blastable(o) and segLen2 > 1e-6 then
							-- where on that stretch do the two touch first (centres 1.1 studs apart)?
							local d0 = a0 - o.Position
							local b = d0:Dot(seg)
							local c = d0:Dot(d0) - 1.21
							local disc = b * b - segLen2 * c
							local t = if c <= 0 then 0 elseif disc >= 0 then (-b - math.sqrt(disc)) / segLen2 else 2
							local n = o.Position - (a0 + seg * math.clamp(t, 0, 1))
							if t <= 1 and n.Magnitude > 0.05 then
								n = n.Unit
								local vo = o.AssemblyLinearVelocity
								local vrel = (part.AssemblyLinearVelocity - vo):Dot(n)
								if vrel > 3 then
									f.pair[o] = now + 0.3
									local j = vrel * 0.9
									part.AssemblyLinearVelocity = clampV(part.AssemblyLinearVelocity - n * j, cap)
									o.AssemblyLinearVelocity = clampV(vo + n * j + Vector3.new(0, 4, 0), cap)
									o.AssemblyAngularVelocity = Vector3.new(rng:NextNumber(-14, 14), rng:NextNumber(-18, 18), rng:NextNumber(-14, 14))
									local f2 = self:_blastBounce(o, f.depth + 1)
									if f2 then
										f2.pair[part] = now + 0.3
									end
									if sparks > 0 then
										sparks -= 1
										self.Juice.Burst((part.Position + o.Position) / 2, Color3.fromRGB(255, 240, 200), 4, 8)
										if sparks == 5 then
											self.Juice.Sound(self.Config.FX.ToolSounds.Cut, 2.1 + rng:NextNumber(0, 0.4), 0.15, "blastbump")
										end
									end
								end
							end
						end
					end
				end
			end
		end
	end
end

function ToolController:_blastWorld(dt)
	local pulses = self.pulses
	for i = #pulses, 1, -1 do
		local ok, done = pcall(self._pulseStep, self, pulses[i], dt)
		if not ok or done then
			if not ok then
				warn("[LeafRush] blaster pulse: " .. tostring(done))
				local vis = pulses[i].vis
				if vis then
					vis.folder:Destroy()
				end
			end
			table.remove(pulses, i)
		end
	end
	if self.flyN > 0 then
		local ok, err = pcall(self._flyStep, self, dt)
		if not ok then
			warn("[LeafRush] blaster crash: " .. tostring(err))
		end
	end
end

function ToolController:_step(dt)
	if not self.root or not self.root.Parent or (self.hum and self.hum.Health <= 0) then
		self:Stop()
		return
	end
	local def = self:_def()
	local aim = self:_aim()
	local rootPos = self.root.Position
	local now = os.clock()
	local ring = self.ring
	local working = self.pressing and not self.uiOpen
	if working and self.kind ~= "Push" then
		self:_face(aim)
	end
	-- the aim ring: where the tool works
	local ringAt, ringR = aim, 1
	if self.kind == "Snip" then
		ringAt, ringR = self:_clampAim(aim, def.Reach), def.Radius
	elseif self.kind == "Swipe" then
		ringAt, ringR = rootPos + flat(self.root.CFrame.LookVector).Unit * def.Reach - Vector3.new(0, 2.9, 0), def.Radius
	elseif self.kind == "Swing" then
		ringAt, ringR = rootPos - Vector3.new(0, 2.9, 0), def.Radius
	elseif self.kind == "Trimmer" then
		local T = self:_trimmer()
		ringAt, ringR = self:_clampAim(aim, T.Reach), T.Radius
	elseif self.kind == "Push" then
		ringAt, ringR = (self.root.CFrame * CFrame.new(0, -2.9, -2.9)).Position, def.Radius
	elseif self.kind == "Blower" then
		ringAt, ringR = self:_clampAim(aim, 6), 1.2
	elseif self.kind == "Vacuum" then
		local V = self:_vacuum()
		ringAt, ringR = self:_clampAim(aim, 5), V.Range
	end
	if ring then
		ring.Size = Vector3.new(0.06, ringR * 2, ringR * 2)
		ring.CFrame = CFrame.new(ringAt.X, ringAt.Y + 0.08, ringAt.Z) * CFrame.Angles(0, 0, math.pi / 2)
		ring.Transparency = if working then 0.55 else 0.8
	end

	-- v1.4 touch: holding USE with the weed cutter swipes by itself, left-right-left…
	if self.kind == "Swipe" and working and self.buttonPress and not self.touchPos then
		if now - self.lastUse >= def.Cooldown then
			self.autoDir = -(self.autoDir or 1)
			self:_swipe(self.autoDir)
		end
	elseif self.kind == "Swipe" and working then
		-- a swipe = the mouse (or finger) moved far enough one way, then turned back
		local x = (self.touchPos or UserInputService:GetMouseLocation()).X
		if self:_fp() and not self.touchPos then
			x = (self.lastMouseX or 0) + (self.mouseDX or 0) -- (locked mouse: its movement)
		end
		self.mouseDX = 0
		if self.lastMouseX then
			local dx = x - self.lastMouseX
			if dx ~= 0 then
				local dir = if dx > 0 then 1 else -1
				if dir ~= self.swipeDir then
					self.swipeDir = dir
					self.swipeAcc = 0
				end
				self.swipeAcc += math.abs(dx)
				if self.swipeAcc >= 45 then
					self.swipeAcc = -1e9 -- (one cut per stroke: turn back for the next)
					self:_swipe(dir)
				end
			end
		end
		self.lastMouseX = x
	end

	local fxOn = false
	local vol = 0
	local jetting = false -- v2.34
	if self.kind == "Trimmer" then
		local bat = player:GetAttribute("Battery") or 0
		if working and bat > 0 then
			vol = 0.45
			local T = self:_trimmer()
			local at = self:_clampAim(aim, T.Reach)
			if now - self.lastSend >= 0.12 then
				self.lastSend = now
				self:_send({ A = "Trim", Pos = at })
				self.Juice.Burst(at + Vector3.new(0, 0.3, 0), Color3.fromRGB(120, 200, 80), 3, 6)
			end
			if not (self.anim and self.anim.Kind == "Whirl") then -- (v2.40: the WHIRL's swing is not cut short)
				self.anim = { Kind = "Buzz", T0 = now, Len = 0.15 }
			end
			fxOn = true
		end
	elseif self.kind == "Push" then
		local v = flat(self.root.AssemblyLinearVelocity).Magnitude
		vol = 0.12 + math.clamp(v / 16, 0, 1) * 0.3
	elseif self.kind == "Blower" and working then
		-- v2.32: it runs on ENERGY (the server counts it: attribute BlowLeft). Empty =
		-- no air, no sound — the line above the hotbar (ToolHud) says how to recharge
		local left = player:GetAttribute("BlowLeft")
		if type(left) ~= "number" or left > 0 then
			vol = 0.45
			fxOn = true
			if self.jet then
				self:_jet(aim, dt) -- v2.34: the gust carries YOU
				jetting = true
			else
				self:_blow(aim, dt)
			end
			self.anim = { Kind = "Hose", T0 = now, Len = 0.18, Amp = 1 } -- v2.37: the arm aims the nozzle and shakes with the motor
		end
	elseif self.kind == "Vacuum" and working then
		local used, cap = player:GetAttribute("VacUsed") or 0, player:GetAttribute("VacCap") or 100
		if used < cap then
			vol = 0.4
			fxOn = true
			self:_suck(aim, dt, now)
			self.anim = { Kind = "Hose", T0 = now, Len = 0.18, Amp = 0.7 } -- v2.37: the arm sweeps the hose over the ground
		end
	elseif self.kind == "Blaster" then
		-- v2.42: holding the button keeps firing (the fire rate is the limit); the magazine
		-- drum, the reload click and the muzzle light are looked after every frame
		if working then
			self:_blastFire(aim)
		end
		self:_blastGear(dt)
	end
	if not jetting and self.jetLV then
		self:_jetStop() -- v2.34: the button was let go / the energy ran out
	end
	if self.kind == "Blower" then
		-- v2.43: the JET has a recharge: when it starts (after the JET was used) the tool is back in BLOW mode
		if self.jet and not working and self:AbilityLeft() > 0 then
			self.jet = false
			self:_jetStop()
			self:_jetFX()
		end
		self:_energyGear()
	elseif self.kind == "Blaster" then
		self:_energyGear()
	end
	self:_fxWork(fxOn)
	if self.loop then
		self.loop.Volume += (vol - self.loop.Volume) * math.min(1, dt * 10)
	end
end

-- the upgrades (decoded once per change of the "Tools" attribute, not every frame)
function ToolController:_up()
	local raw = player:GetAttribute("Tools") or "{}"
	if raw ~= self.upRaw then
		self.upRaw = raw
		local ok, t = pcall(function()
			return game:GetService("HttpService"):JSONDecode(raw)
		end)
		self.upCache = if ok and type(t) == "table" and type(t.Up) == "table" then t.Up else {}
	end
	return self.upCache
end

function ToolController:_trimmer()
	return self.ToolConfig.Trimmer(self:_up().Trimmer or {})
end

function ToolController:_vacuum()
	return self.ToolConfig.Vacuum(self:_up().Vacuum or {})
end

-- the blower: leaves in a cone in front fly away from you (the ones you own)
function ToolController:_blow(aim, dt)
	local B = self.ToolConfig.Blower(self:_up().Blower or {}) -- (v1.2.1: with its upgrades)
	local rootPos = self.root.Position
	local dir = flat(aim - rootPos)
	dir = if dir.Magnitude > 0.5 then dir.Unit else flat(self.root.CFrame.LookVector).Unit
	local cosHalf = math.cos(math.rad(B.Cone))
	local maxV = math.min(B.Force, (self.Config.Resources.MaxSpeed or 70) * 0.6)
	-- v1.4: players in front of the nozzle get blown back (the server decides)
	local now = os.clock()
	if now - (self.lastBlowSend or 0) >= 0.3 then
		self.lastBlowSend = now
		self:_send({ A = "Blow", Dir = dir })
	end
	for _, p in myParts(self, rootPos + dir * B.Range * 0.5, B.Range * 0.55) do
		if p.ReceiveAge == 0 and not p.Anchored and not p:GetAttribute("Heavy") then
			local off = flat(p.Position - rootPos)
			local d = off.Magnitude
			if d > 0.5 and d <= B.Range and off.Unit:Dot(dir) >= cosHalf then
				local fall = 1 - d / B.Range * 0.6
				local want = (off.Unit * 0.35 + dir * 0.65).Unit * maxV * fall
				local v = p.AssemblyLinearVelocity
				local nv = v:Lerp(Vector3.new(want.X, math.max(v.Y, 3 * fall), want.Z), math.min(1, dt * 6))
				p.AssemblyLinearVelocity = nv
			end
		end
	end
	local tier = self.fxTier or 1
	if math.random() < dt * (25 + tier * 8) then
		local nose = rootPos + dir * 3 - Vector3.new(0, 2, 0)
		self.Juice.Burst(nose, Color3.fromRGB(220, 240, 255), 2 + tier, 16 + tier * 2)
	end
	-- (v1.10: no more ring gusts on the ground at high tiers)
end

--[[
	v2.34 the blower's JET mode. The strike key (Q by default; on phones the round
	button next to USE) switches BLOW <-> JET. In JET mode the gust is turned round: it
	blows backwards over YOU and carries you away from the spot you aim at —
	  aim far ahead  -> you slide / glide backwards, away from it
	  aim at your feet -> straight up
	so you steer with the aim (walking input nudges it a little). Nothing else is blown.
	The character is ours (client-owned physics), so the push is applied here, like
	Knockback: a horizontal LinearVelocity in Plane mode (the Humanoid can't cancel it)
	+ the vertical speed set directly. Limits (ToolConfig.Helpers.Blower Jet…): speed
	under the server's movement guard, a ceiling above the ground, no thrust without
	energy (the server drains it exactly as when blowing).
]]
function ToolController:ToggleJet()
	if not self.active or self.kind ~= "Blower" or self.uiOpen then
		return false
	end
	if not self.jet then
		local left = self:AbilityLeft() -- v2.43: the JET has a long recharge after it was used
		if left > 0 then
			self:_toast(string.format("🚀 The JET is recharging — %d s", math.ceil(left)), 2)
			return false
		end
	end
	self.jet = not self.jet
	self:_jetStop()
	self:_jetFX()
	if self.Hud and self.Hud.Toast then
		pcall(self.Hud.Toast, self.Hud, if self.jet then "🚀 Leaf Blower: JET mode — the gust carries YOU. Aim at the ground to fly up!" else "💨 Leaf Blower: BLOW mode — leaves fly away from the nozzle", 3)
	end
	if self.Juice and self.root then
		pcall(self.Juice.Ring, self.root.Position - Vector3.new(0, 2.6, 0), if self.jet then Color3.fromRGB(120, 190, 255) else Color3.fromRGB(220, 240, 255), 3, 0.3)
	end
	return true
end

-- the air stream of the tool in hand follows the mode (out of the nozzle / backwards)
function ToolController:_jetFX()
	local fx = self.fx
	if not fx or self.kind ~= "Blower" then
		return
	end
	local jet = self.jet == true
	for _, e in fx.Work do
		if typeof(e) == "Instance" and e:IsA("ParticleEmitter") and e.Parent and e.Parent:IsA("Attachment") then
			e.EmissionDirection = if jet then Enum.NormalId.Back else Enum.NormalId.Front
		end
	end
	if self.loop then
		self.loop.PlaybackSpeed = if jet then 1.9 else 1.5
	end
end

function ToolController:_jetStop()
	local lv = self.jetLV
	self.jetLV, self.jetV = nil, nil
	if lv then
		pcall(function()
			lv:Destroy()
		end)
	end
end

function ToolController:_jet(aim, dt)
	local root, hum = self.root, self.hum
	if not root or not hum then
		return
	end
	dt = math.clamp(dt, 0, 0.1)
	local D = (self.ToolConfig.Helpers and self.ToolConfig.Helpers.Blower) or {}
	local B = self.ToolConfig.Blower(self:_up().Blower or {})
	local rootPos = root.Position
	-- where the gust (and you) go: away from the aim
	local to = aim - rootPos
	local stream
	if to.Magnitude > 0.5 then
		stream = -to.Unit
	else
		local look = flat(root.CFrame.LookVector)
		stream = if look.Magnitude > 1e-3 then -look.Unit else Vector3.new(0, 1, 0)
	end
	if stream.X ~= stream.X or stream.Y ~= stream.Y or stream.Z ~= stream.Z then
		return
	end
	local now = os.clock()
	if now - (self.lastBlowSend or 0) >= 0.3 then
		self.lastBlowSend = now
		self:_send({ A = "Blow", Dir = stream, Jet = true }) -- (the server drains the energy)
	end
	-- horizontal: a speed that builds up toward "away from the aim" (+ a little steering)
	-- v2.35: the flight grows with the Blow Force upgrade (k = 0 … 1 over its levels)
	local maxSpeed = D.JetMaxSpeed or 33
	local fu = self.ToolConfig.BlowerUpgrades and self.ToolConfig.BlowerUpgrades.Force
	local span = fu and (fu.Max or 5) * (fu.Per or 3) or 15
	local k = math.clamp((B.Force - (D.Force or 22)) / math.max(span, 1), 0, 1)
	local speed = math.min(maxSpeed, (D.JetSpeed or 16) + ((D.JetSpeedMax or maxSpeed) - (D.JetSpeed or 16)) * k)
	local move = flat(hum.MoveDirection)
	local wantH = flat(stream) * speed + move * (D.JetSteer or 7)
	local want = Vector2.new(wantH.X, wantH.Z)
	if want.Magnitude > maxSpeed then
		want = want.Unit * maxSpeed
	end
	local lv = self.jetLV
	if not lv or lv.Parent ~= root then
		self:_jetStop()
		local att = root:FindFirstChild("RootAttachment") or root:FindFirstChildOfClass("Attachment")
		if not att then
			att = Instance.new("Attachment")
			att.Parent = root
		end
		lv = Instance.new("LinearVelocity")
		lv.Name = "LeafRushJet"
		lv.Attachment0 = att
		lv.RelativeTo = Enum.ActuatorRelativeTo.World
		lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
		lv.PrimaryTangentAxis = Vector3.xAxis
		lv.SecondaryTangentAxis = Vector3.zAxis
		lv.ForceLimitMode = Enum.ForceLimitMode.Magnitude
		lv.MaxForce = root.AssemblyMass * 900
		local v0 = root.AssemblyLinearVelocity
		local start = Vector2.new(v0.X, v0.Z)
		if start.Magnitude > maxSpeed then
			start = start.Unit * maxSpeed
		end
		self.jetV = start
		lv.PlaneVelocity = start
		lv.Parent = root
		self.jetLV = lv
	end
	local cur = self.jetV or Vector2.zero
	local diff = want - cur
	local step = (D.JetAccel or 75) * dt
	cur = if diff.Magnitude <= step then want else cur + diff.Unit * step
	self.jetV = cur
	lv.PlaneVelocity = cur
	-- vertical: lift when the gust points up (you aim down), up to a ceiling
	local up = math.max(stream.Y, 0)
	if up > 0.05 then
		local maxH = (D.JetMinHeight or 12) + ((D.JetMaxHeight or 40) - (D.JetMinHeight or 12)) * k
		local hit = workspace:Raycast(rootPos, Vector3.new(0, -(maxH + 30), 0), self.ray)
		local height = if hit then rootPos.Y - hit.Position.Y - 3 else math.huge
		local room = math.clamp((maxH - height) / 8, 0, 1)
		if room > 0 then
			local v = root.AssemblyLinearVelocity
			local cap = ((D.JetLiftMin or 16) + ((D.JetLift or 32) - (D.JetLiftMin or 16)) * k) * up
			local vy = v.Y
			if vy < cap then
				vy = math.min(vy + workspace.Gravity * (D.JetLiftG or 1.9) * up * room * dt, cap)
			end
			local grounded = hum.FloorMaterial ~= Enum.Material.Air
			if grounded and up > 0.5 then
				-- take off: a small hop, and tell the Humanoid it is in the air
				vy = math.max(vy, 14 * room)
				if now - (self.jetHop or 0) > 0.25 then
					self.jetHop = now
					pcall(function()
						hum:ChangeState(Enum.HumanoidStateType.Freefall)
					end)
				end
			end
			if vy ~= v.Y then
				root.AssemblyLinearVelocity = Vector3.new(v.X, vy, v.Z)
			end
		end
	end
	-- the gust behind you
	local tier = self.fxTier or 1
	if math.random() < dt * (25 + tier * 8) then
		self.Juice.Burst(rootPos + stream * 3 - Vector3.new(0, 1, 0), Color3.fromRGB(220, 240, 255), 2 + tier, 16 + tier * 2)
	end
end

--[[
	v2.38 the vacuum's VORTEX. The strike key (Q by default; on phones the round button
	next to USE) plants a whirlwind at the spot you aim at (at most Cast studs away): for
	a few seconds it pulls every loose leaf around into one spiral pile, then the vacuum
	swallows the whole pile in one gulp. The server decides everything (ToolService.Vortex:
	cooldown, broken vacuum, the gulp); here: the aim, the request, the feedback.
	  VortexLeft() -> seconds until it is ready again, the whole cooldown
]]
function ToolController:VortexLeft()
	local ready = player:GetAttribute("VortexReady")
	local total = tonumber(player:GetAttribute("VortexCd")) or 45
	if type(ready) ~= "number" then
		return 0, total
	end
	local okT, t = pcall(function()
		return workspace:GetServerTimeNow()
	end)
	if not okT then
		return 0, total
	end
	return math.clamp(ready - t, 0, total), total
end

function ToolController:_toast(text, seconds)
	if self.Hud and self.Hud.Toast then
		pcall(self.Hud.Toast, self.Hud, text, seconds or 2.5)
	end
end

-- fromButton = the touch button: the vortex goes in front of you (no finger on the ground)
function ToolController:Vortex(fromButton)
	if not self.active or self.kind ~= "Vacuum" or self.uiOpen or not self.root then
		return false
	end
	local now = os.clock()
	local used, cap = player:GetAttribute("VacUsed") or 0, player:GetAttribute("VacCap") or 100
	if used >= cap then
		if now - (self.vortexSaid or 0) > 2 then
			self.vortexSaid = now
			self:_toast("💥 Your vacuum is broken — repair it in SHOP · TOOLS or use a Vacuum Battery", 3)
		end
		return false
	end
	local left = self:VortexLeft()
	if left > 0 then
		-- still recharging: say so (not on every key press)
		if now - (self.vortexSaid or 0) > 1.2 then
			self.vortexSaid = now
			self:_toast(string.format("🌪 The Vortex is recharging — %d s", math.ceil(left)), 1.5)
			if self.Juice and self.Config.FX and self.Config.FX.UiSoundId then
				pcall(self.Juice.Sound, self.Config.FX.UiSoundId, 0.7, 0.25, "vortexno")
			end
		end
		return false
	end
	if now - (self.vortexSent or 0) < 1 then
		return false
	end
	self.vortexSent = now
	local V = self.ToolConfig.Vortex(self:_up().Vacuum or {})
	local at
	if fromButton and not self.touchPos then
		local look = flat(self.root.CFrame.LookVector)
		look = if look.Magnitude > 1e-3 then look.Unit else Vector3.new(0, 0, -1)
		at = self.root.Position + look * math.min(9, V.Cast) - Vector3.new(0, 2.9, 0)
	else
		at = self:_clampAim(self:_aim(), V.Cast)
	end
	if at.X ~= at.X or at.Y ~= at.Y or at.Z ~= at.Z then
		return false
	end
	self:_face(at)
	self:_send({ A = "Vortex", Pos = at })
	self.anim = { Kind = "Hose", T0 = now, Len = 0.6, Amp = 2.2 } -- (the arm throws the hose forward)
	if self.Juice then
		pcall(self.Juice.Ring, at + Vector3.new(0, 0.15, 0), Color3.fromRGB(190, 140, 255), V.Radius, 0.45)
	end
	if not self.vortexHinted then
		self.vortexHinted = true
		self:_toast("🌪 VORTEX! It pulls the leaves around into one pile — then your vacuum swallows it in one gulp", 4)
	end
	return true
end

--[[
	v2.40 the Lawn Trimmer's WHIRL. The strike key (Q by default; on phones the round
	button next to USE): the line shoots out to its full length, you spin once and ALL
	the grass of your garden in a wide ring around you is cut at once. The server decides
	everything (ToolService.Whirl: the cooldown, the battery it costs, the cut itself —
	through the normal grass-cutting path); here: the request, the arm, the feedback.
	The spin and the glowing line are drawn for everybody by the client module WhirlFX
	when the server says the whirl really happened.
	  WhirlLeft() -> seconds until it is ready again, the whole cooldown
]]
function ToolController:WhirlLeft()
	local ready = player:GetAttribute("WhirlReady")
	local total = tonumber(player:GetAttribute("WhirlCd")) or 30
	if type(ready) ~= "number" then
		return 0, total
	end
	local okT, t = pcall(function()
		return workspace:GetServerTimeNow()
	end)
	if not okT then
		return 0, total
	end
	return math.clamp(ready - t, 0, total), total
end

function ToolController:Whirl(_fromButton)
	if not self.active or self.kind ~= "Trimmer" or self.uiOpen or not self.root or not self.ToolConfig.Whirl then
		return false
	end
	local now = os.clock()
	local W = self.ToolConfig.Whirl(self:_up().Trimmer or {})
	local left = self:WhirlLeft()
	if left > 0 then
		-- still recharging: say so (not on every key press)
		if now - (self.whirlSaid or 0) > 1.2 then
			self.whirlSaid = now
			self:_toast(string.format("🌀 The Whirl is recharging — %d s", math.ceil(left)), 1.5)
			if self.Juice and self.Config.FX and self.Config.FX.UiSoundId then
				pcall(self.Juice.Sound, self.Config.FX.UiSoundId, 0.7, 0.25, "whirlno")
			end
		end
		return false
	end
	local bat = tonumber(player:GetAttribute("Battery")) or 0
	if bat < W.Battery then
		if now - (self.whirlSaid or 0) > 2 then
			self.whirlSaid = now
			self:_toast(string.format("🔋 The WHIRL needs %d s of battery — let the trimmer recharge or use a Battery Pack", W.Battery), 3)
		end
		return false
	end
	if now - (self.whirlSent or 0) < 1 then
		return false
	end
	self.whirlSent = now
	self:_send({ A = "Whirl" })
	self.anim = { Kind = "Whirl", T0 = now, Len = (W.Time or 0.6) + 0.15 } -- (the arm holds the trimmer out while you turn)
	if not self.whirlHinted then
		self.whirlHinted = true
		self:_toast("🌀 WHIRL! One spin cuts all the grass in a wide ring around you — it costs battery", 4)
	end
	return true
end

-- the vacuum: pull leaves to the nozzle (looks), the server takes and pays
function ToolController:_suck(aim, dt, now)
	local V = self:_vacuum()
	local at = self:_clampAim(aim, 5)
	if now - self.lastSend >= 0.2 then
		self.lastSend = now
		self:_send({ A = "Vac", Pos = at })
	end
	for _, p in myParts(self, at, V.Range + 2) do
		if p.ReceiveAge == 0 and not p.Anchored and not p:GetAttribute("Heavy") then
			local to = at + Vector3.new(0, 0.6, 0) - p.Position
			if to.Magnitude > 0.3 then
				p.AssemblyLinearVelocity = p.AssemblyLinearVelocity:Lerp(to.Unit * 18, math.min(1, dt * 8))
			end
		end
	end
	local tier = self.fxTier or 1
	if math.random() < dt * (20 + tier * 8) then
		local col = ({ Color3.fromRGB(200, 170, 255), Color3.fromRGB(120, 255, 225), Color3.fromRGB(255, 130, 150), Color3.fromRGB(255, 215, 90) })[tier]
		self.Juice.Burst(at + Vector3.new(math.random() * 2 - 1, 0.4, math.random() * 2 - 1), col, 2 + tier, 3 + tier)
	end
	if tier >= 3 and math.random() < dt * tier * 2 then
		self.Juice.Ring(at + Vector3.new(0, 0.1, 0), ({ nil, nil, Color3.fromRGB(255, 130, 150), Color3.fromRGB(255, 215, 90) })[tier], V.Range * 0.8, 0.3)
	end
end

---------------------------------------------------------------- the arm
function ToolController:_pose()
	-- the blade's glowing trail only while it swings
	local tr = self.fx and self.fx.Trail
	if tr then
		local a = self.anim
		tr.Enabled = a ~= nil and (a.Kind == "Swing" or a.Kind == "Swipe" or a.Kind == "Snip")
	end
	local m = self.shoulder
	if not m or not self.active then
		return
	end
	if self.kind == "Push" then
		self:_pushPose()
		return
	end
	-- the pose the animation gave the shoulder this frame. If no animation wrote it
	-- since our last frame, it still holds OUR value: use the base we built on then
	-- (so the swing never adds up frame after frame)
	local cur = m.Transform
	local base = if self.lastWritten and cur == self.lastWritten then self.lastBase else cur
	local a = self.anim
	if not a or (os.clock() - a.T0) / a.Len >= 1 then
		self.anim = nil
		if self.lastWritten then
			if cur == self.lastWritten then
				m.Transform = self.lastBase -- back to the animation's pose, no snap
			end
			self.lastWritten, self.lastBase = nil, nil
		end
		return
	end
	local t = (os.clock() - a.T0) / a.Len
	local cf
	if a.Kind == "Snip" then
		cf = CFrame.Angles(-math.sin(t * math.pi) * 0.6, 0, 0)
	elseif a.Kind == "Swipe" then
		local s = (t * 2 - 1) * (a.Dir or 1)
		cf = CFrame.Angles(-0.3, 0, s * 0.9)
	elseif a.Kind == "Swing" then
		if t < 0.33 then
			local w = t / 0.33
			cf = CFrame.Angles(0.5 * w, 0, 1.2 * w) -- wind up: back and out
		else
			local w = (t - 0.33) / 0.67
			local e = 1 - (1 - w) ^ 2
			cf = CFrame.Angles(0.5 - 0.9 * e, 0, 1.2 - 2.6 * e) -- the big sweep across
		end
	elseif a.Kind == "Buzz" then
		cf = CFrame.Angles(math.sin(os.clock() * 60) * 0.03, math.sin(os.clock() * 7) * 0.2, 0)
	elseif a.Kind == "Whirl" then
		-- v2.40 the WHIRL: the arm swings the trimmer out to the side and holds it there
		-- while the body turns (WhirlFX), then comes back — it ends where it began
		local k = math.sin(math.clamp(t, 0, 1) * math.pi)
		cf = CFrame.Angles(-0.3 * k + math.sin(os.clock() * 60) * 0.03 * k, 0, 1.05 * k)
	elseif a.Kind == "Recoil" then
		-- v2.42 a pulse leaves the Leaf Blaster: the arm kicks and settles
		cf = CFrame.Angles(-0.38 * (1 - t) ^ 2, 0, 0.06 * (1 - t))
	elseif a.Kind == "Reload" then
		-- v2.42 reloading: the arm pumps the drum twice
		local k = math.sin(math.clamp(t, 0, 1) * math.pi)
		cf = CFrame.Angles(-0.2 * k + math.sin(t * math.pi * 4) * 0.12 * k, 0, 0.35 * k)
	elseif a.Kind == "Hose" then
		-- v2.37 the blower / the vacuum at work: a small motor shake + a slow sweep
		-- (it fades out over the last frames, so the arm never snaps back)
		local k = (a.Amp or 1) * math.clamp((1 - t) * 4, 0, 1)
		cf = CFrame.Angles(math.sin(os.clock() * 48) * 0.025 * k, math.sin(os.clock() * 3.4) * 0.16 * k, 0)
	end
	if cf then
		m.Transform = base * cf
		self.lastBase, self.lastWritten = base, m.Transform
	end
end

-- v1.4 the push mower: both hands forward on its bar (the mower itself is fixed to
-- the body by the server, so it rolls smoothly while you walk)
function ToolController:_pushPose()
	-- v1.4: the arms are HELD still on the bar (the walk / run animation doesn't swing
	-- them): the joint gets exactly this pose every frame, not "animation × pose"
	local function hold(joint, key, cf)
		if not joint then
			return
		end
		local cur = joint.Transform
		local base = if self[key .. "Written"] and cur == self[key .. "Written"] then self[key .. "Base"] else cur
		joint.Transform = cf
		self[key .. "Base"], self[key .. "Written"] = base, joint.Transform
	end
	local walk = 0
	if self.r15 then
		hold(self.shoulder, "last", CFrame.Angles(math.rad(62) + walk, 0, 0))
		hold(self.lshoulder, "l", CFrame.Angles(math.rad(62) - walk, 0, 0))
	else
		hold(self.shoulder, "last", CFrame.Angles(0, 0, math.rad(62) + walk))
		hold(self.lshoulder, "l", CFrame.Angles(0, 0, -math.rad(62) + walk))
	end
end

return ToolController
end)() end
CTL_MODULE = mt()
local TC = TC_MODULE
local Controller = CTL_MODULE
local V = Vector3
SERVER_NOW = 1000
local sent, jsound = {}, 0
local deps = {
	Config = { Resources = { MaxSpeed = 70 }, Collision = { QueryGroup = "q" }, FX = { ToolSounds = { Cut = "c", Loop = "l" } } },
	ToolConfig = TC,
	Remote = { FireServer = function(_, req) table.insert(sent, req) end },
	Juice = setmetatable({ EffectsOn = function() return false end, Sound = function() jsound += 1 end }, { __index = function() return function() end end }),
	Controls = { Is = function() return false end, KeyName = function() return "Q" end },
	MyResources = function() return { {} } end,
}
local ctl = Controller.new(deps)
local function part(x, z, extra)
	local p = { Position = V.new(x, 0.3, z), Anchored = false, ReceiveAge = 0, Parent = true, AssemblyLinearVelocity = V.zero, AssemblyAngularVelocity = V.zero,
		CurrentPhysicalProperties = { Density = 0.25, Friction = 0.55, Elasticity = 0.05, FrictionWeight = 1, ElasticityWeight = 1 }, CustomPhysicalProperties = nil,
		attrs = extra or {}, IsA = function() return true end }
	function p:GetAttribute(k) return self.attrs[k] end
	table.insert(FAKE_PARTS, p)
	return p
end
local B = ctl.ToolConfig.Blaster({})
ctl.root = { Position = V.new(0, 3, 0), CFrame = { LookVector = V.new(0, 0, -1) } }
ctl.active, ctl.kind = true, "Blaster"
-- a field of leaves in front + a stone, an ice block, an anchored (stuck) one, one owned by another client, and one behind
local leaves = {}
for i = -2, 2 do for j = 1, 6 do table.insert(leaves, part(i * 1.2, -8 - j * 1.5)) end end
local stone, ice, stuck, foreign, behind = part(0, -9, { Heavy = true }), part(1, -9.5, { IceHP = 3 }), part(-1, -9.5), part(2, -9), part(0, 6)
stuck.Anchored = true; foreign.ReceiveAge = 0.3
local p = ctl:_newPulse(V.new(0, 3, -2), V.new(0, 0, -1), B.Size, B.Range, B.Speed, 1, true, 0.9, B.Power, 20)
local frames = 0
while #ctl.pulses > 0 and frames < 600 do ctl:_blastWorld(1 / 60); frames += 1 end
print(("pulse lived %d frames (%.2f s), range %.0f studs at %.0f studs/s"):format(frames, frames / 60, B.Range, B.Speed))
local moved, maxv, minvy = 0, 0, 1e9
for _, l in leaves do
	local v = l.AssemblyLinearVelocity
	if v.Magnitude > 0.1 then moved += 1; maxv = math.max(maxv, v.Magnitude); minvy = math.min(minvy, v.Y) end
end
print("leaves moved:", moved, "of", #leaves, " max speed", string.format("%.1f", maxv), "(anti-teleport limit 70)  min hop", string.format("%.1f", minvy))
print("stone moved?", stone.AssemblyLinearVelocity.Magnitude > 0, " ice moved?", ice.AssemblyLinearVelocity.Magnitude > 0, " anchored moved?", stuck.AssemblyLinearVelocity.Magnitude > 0, " foreign-owned moved?", foreign.AssemblyLinearVelocity.Magnitude > 0, " behind moved?", behind.AssemblyLinearVelocity.Magnitude > 0)
print("bouncy set on", ctl.flyN, "items; elasticity of a hit leaf:", leaves[10].CustomPhysicalProperties and leaves[10].CustomPhysicalProperties.Elasticity)

-- ---------------- stone: untouched by an ordinary pulse, nudged (a quarter speed) by a fully upgraded one
for i = #FAKE_PARTS, 1, -1 do FAKE_PARTS[i] = nil end
ctl.flying, ctl.flyN, ctl.pulses = {}, 0, {}
local st1, st2, leaf = part(0, -8, { Heavy = true }), part(0.5, -8, { Heavy = true }), part(-0.5, -8)
local p1 = ctl:_newPulse(V.new(0, 3, -2), V.new(0, 0, -1), B.Size, B.Range, B.Speed, 1, true, 0.9, B.Power, 20)
for _ = 1, 40 do ctl:_blastWorld(1 / 60) end
print("ordinary pulse: stone moved?", st1.AssemblyLinearVelocity.Magnitude > 0, "leaf moved?", leaf.AssemblyLinearVelocity.Magnitude > 0)
st1.AssemblyLinearVelocity, leaf.AssemblyLinearVelocity = V.zero, V.zero
ctl.flying, ctl.flyN, ctl.pulses = {}, 0, {}
local p2 = ctl:_newPulse(V.new(0, 3, -2), V.new(0, 0, -1), B.Size, B.Range, B.Speed, 1, true, 0.9, B.Power, 20)
p2.stone = true
for _ = 1, 40 do ctl:_blastWorld(1 / 60) end
local sv, lv = flatSpeed and 0 or 0, 0
print("maxed pulse: stone moved?", st1.AssemblyLinearVelocity.Magnitude > 0, string.format("stone %.1f vs leaf %.1f horizontal", math.sqrt(st1.AssemblyLinearVelocity.X ^ 2 + st1.AssemblyLinearVelocity.Z ^ 2), math.sqrt(leaf.AssemblyLinearVelocity.X ^ 2 + leaf.AssemblyLinearVelocity.Z ^ 2)))
-- ---------------- chain scenario
for i = #FAKE_PARTS, 1, -1 do FAKE_PARTS[i] = nil end
ctl.flying, ctl.flyN, ctl.pulses = {}, 0, {}
local A = part(1.5, -10)     -- inside the pulse (radius 2.2)
local Bp = part(3.0, -12.0)  -- outside it, but where A flies
local C = part(4.2, -14.0)   -- the next link
local far = part(-8, -10)    -- nowhere near
local pp = ctl:_newPulse(V.new(0, 3, -2), V.new(0, 0, -1), B.Size, B.Range, B.Speed, 1, true, 0.9, B.Power, 20)
local function step(dt)
	FAKE_T += dt
	for _, l in FAKE_PARTS do
		if l.Parent and not l.Anchored then
			local v = l.AssemblyLinearVelocity
			v = V.new(v.X * (1 - 0.6 * dt), v.Y - 196 * dt, v.Z * (1 - 0.6 * dt))
			local pos = l.Position + v * dt
			if pos.Y < 0.3 then
				local e = if l.CustomPhysicalProperties then l.CustomPhysicalProperties.Elasticity else 0.05
				pos = V.new(pos.X, 0.3, pos.Z)
				v = V.new(v.X * 0.97, math.abs(v.Y) * e, v.Z * 0.97)
				if v.Y < 1.5 then v = V.new(v.X, 0, v.Z) end
			end
			l.Position, l.AssemblyLinearVelocity = pos, v
		end
	end
	ctl:_blastWorld(dt)
end
for _ = 1, 40 do step(1 / 60) end
local function speed(p) return string.format("%.1f", p.AssemblyLinearVelocity.Magnitude) end
print("A (hit by pulse)", speed(A), " B (outside the pulse)", speed(Bp), " C (next link)", speed(C), " far", speed(far))
print("bump sounds:", jsound, " flying tracked:", ctl.flyN, " B depth:", ctl.flying[Bp] and ctl.flying[Bp].depth, " C depth:", ctl.flying[C] and ctl.flying[C].depth)
-- the physics is put back after ~1.3 s
for _ = 1, 150 do step(1 / 60) end
print("after 2.5 s: tracked", ctl.flyN, " A props back to nil:", A.CustomPhysicalProperties == nil, " B:", Bp.CustomPhysicalProperties == nil, " C:", C.CustomPhysicalProperties == nil)
-- a leaf collected (removed) mid-flight must not error
local D = part(0.2, -9); local pp2 = ctl:_newPulse(V.new(0, 3, -2), V.new(0, 0, -1), B.Size, B.Range, B.Speed, 1, true, 0.9, B.Power, 20)
for _ = 1, 10 do step(1 / 60) end
D.Parent = nil
for _ = 1, 40 do step(1 / 60) end
print("collected mid-flight handled; tracked:", ctl.flyN)
-- the magazine as the client sees it
LOCAL_ATTRS.BlastSeq = 1; LOCAL_ATTRS.BlastMag = 6; LOCAL_ATTRS.BlastReloadAt = 0; LOCAL_ATTRS.BlastLeft = 60; LOCAL_ATTRS.BlastMax = 60
ctl.lastUse = -1e9
ctl.tool = nil
local function st() local m, c, l, t = ctl:BlastState(); return ("%d/%d reload %.1f"):format(m, c, l) end
print("state:", st())
local fired = 0
for i = 1, 8 do
	ctl.lastUse = -1e9
	local ok = ctl:_blastFire(V.new(0, 0, -20))
	if ok then fired += 1 end
	print(i, "fired:", ok, st())
end
print("shots really fired:", fired, " sent to the server:", #sent, " first request:", sent[1] and sent[1].A, sent[1] and ("%.2f"):format(sent[1].Dir.Z))
SERVER_NOW += 3
print("3 s later:", st())
print("manual reload while full:", ctl:Reload())
