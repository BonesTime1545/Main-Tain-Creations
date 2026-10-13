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
		Display = "Grass Cutter", Rarity = "Uncommon", Price = 8000, Kind = "Swipe", Icon = "🔪",
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
	-- v2.43: repairs ONE of Shears, Grass Cutter, Scythe, Pickaxe — use it, then pick the tool
	-- in the panel (the ones in your hotbar)
	RepairKit = {
		Display = "Repair Kit", Rarity = "Epic", Price = 75000, Icon = "🧰", ToolTarget = true,
		Description = "Use it, then pick one of your Grass Shears, Grass Cutter, Scythe or Pickaxe in the panel: it is repaired completely.",
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
-- (round 15, harvest) the Cow's MILK BOTTLE: NEVER sold (NotSold: no shop, no stock, no auto-buy, no Money purchase).
-- A Cow drops bottles in your garden; walk over one to pick it up. Use it on one EQUIPPED pet (the toy picker, or
-- 🥛 GIVE MILK in the pet panel): +Boost ability power and speed for Duration — a second bottle only refreshes the
-- time (never stacks). It adds to a toy's boost (PetAbilityService.EffBoost).
T.Consumables.MilkBottle = {
	Display = "Milk Bottle", Rarity = "Epic", Price = 50000, Icon = "🥛", PetTarget = true, Milk = true, NotSold = true,
	Boost = 0.15, Duration = 300,
	Description = "Fresh milk from your Cow. Give it to one of your equipped pets: for 5 minutes its ability works 15% better. Another bottle only starts the 5 minutes again.",
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
end)() end
TC_MODULE = mc()
game = { GetService = function() return { Heartbeat = { Connect = function() end }, JSONEncode = function() return "{}" end } end }
workspace = { GetServerTimeNow = function() return clock_ST or 0 end }
local function ms() return (function()
--[[
	Leaf Rush · ToolService (v1.2) — every tool besides the broom, one-use items

	Owns data.Tools / data.Consumables (DataSchema v12) and the Tools in your backpack:
	  slot 2  the grass tool you picked (Shears … Turbo Mower)
	  slot 3  Rake · slot 4 Leaf Blower · slot 5 Vacuum (when owned)
	  (slot 1 = the broom: BroomSystem; slots 6-8 = one-use items: no Tool, used here)

	RemoteFunction ToolRequest (buying & settings):
	  { Action = "Buy", Id }                 a grass tool / Rake / Blower / Vacuum (Money)
	  { Action = "Equip", Id }               which owned grass tool sits in slot 2
	  { Action = "Upgrade", Tool, Stat }     Trimmer / Vacuum upgrades
	  { Action = "Repair" }                  fix the vacuum (Money, by how worn it is)
	  { Action = "Recharge" }                v2.32: refill the Leaf Blower's energy (Money, by how empty)
	  { Action = "RechargeBlast" }           v2.42: refill the Leaf Blaster's energy (Money, by how empty)
	  { Action = "RepairTool", Id }          v2.43: repair Shears / Grass Cutter / Scythe (Money, by how worn)
	  { Action = "Refuel", Id }              v2.43: fill the tank of the Push / Riding Mower (Money, by how empty)
	  { Action = "BuyItem", Id, Count }      one-use items (1…10)
	  { Action = "Slot", Id, On }            show a one-use item in the hotbar (max 3)
	  { Action = "Use", Id, Pos? }           use one (Grass Killer: Pos = where; v2.32 pet toys: Pet = uid)
	RemoteEvent ToolAction (while working, rate-limited):
	  { A = "Cut", Pos, Dir }  Shears / Grass Cutter / Scythe (cooldown per tool)
	  { A = "Trim", Pos }      the trimmer is running at Pos (uses battery)
	  { A = "Rake", Pos }      the rake passes here (pulls stuck leaves out)
	  { A = "Vac", Pos }       the vacuum sucks at Pos
	  { A = "Vortex", Pos }    v2.38: the vacuum's VORTEX (strike key) is planted at Pos
  { A = "Whirl" }          v2.40: the trimmer's WHIRL (strike key): all the grass in a ring around you
	  { A = "Ability", Pos }   v2.43: the strike key with a grass tool in the hand / on the mower
	  { A = "Blast", Dir }     v2.42: the Leaf Blaster fires one air pulse along Dir (magazine of 6)
	  { A = "Reload" }         v2.42: reload the Leaf Blaster now
	  { A = "Off" }            get off the riding mower
	Every action is checked here: the tool must be IN YOUR HAND, the spot near you
	and in your own garden, cooldowns / battery / capacity on the server's clock.
	Mowers cut on the server from where the mower really is (no client message).
]]

local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local ToolService = {}

local ctx
local st = {} -- [player] = { LastCut, LastTrim, LastRake, LastVac, VacBudget, Mower, MowerT, MowerPos, EmptyWarned, BatPub }
-- (review v2.38) the VORTEX cooldown by UserId: st[player] is forgotten when the player
-- leaves, so leaving and joining this server again would have recharged it at once
local vortexReady = {} -- [userId] = ToolService.Now() it is ready again
local whirlReady = {} -- v2.40: the same for the trimmer's WHIRL

ToolService.Now = os.clock

function ToolService.Init(context)
	ctx = context
end

local function TC()
	return ctx.ToolConfig
end
-- (round 15) 🐕 the Golden Retriever: the held tool's stat table, boosted (ToolConfig.Boosted; the client does the same)
local function toolMult(player)
	return if ctx.PetPowers and ctx.PetPowers.ToolMult then ctx.PetPowers.ToolMult(player) else 1
end
local function HB(player, t)
	if t and TC().Boosted then
		return TC().Boosted(t, toolMult(player))
	end
	return t
end

-- (round 16 wind) the Wind Egg pets on the Leaf Blower (ToolConfig.WindBlower)
local function WB(player, t)
	local PP = ctx.PetPowers
	if t and TC().WindBlower and PP and PP.WindMult then
		return TC().WindBlower(t, PP.WindMult(player), if PP.WindReach then PP.WindReach(player) else 1)
	end
	return t
end

local function S(player)
	local s = st[player]
	if not s then
		s = { LastCut = -1e9, LastTrim = -1e9, LastRake = -1e9, LastVac = -1e9, VacBudget = 0 }
		st[player] = s
	end
	return s
end

local function notify(player, text)
	if ctx.Net and ctx.Net.Notify then
		ctx.Net.Notify:FireClient(player, text)
	end
end

local function serverTime()
	local ok, t = pcall(function()
		return workspace:GetServerTimeNow()
	end)
	return if ok then t else os.time()
end

---------------------------------------------------------------- state -> client
function ToolService.Publish(player)
	local data = ctx.PlayerDataService.Get(player)
	if not data then
		return
	end
	local T = data.Tools
	-- v1.4: a used-up item leaves the hotbar (0 magnets = no magnet slot)
	local slots = data.Consumables.Slots
	for i = #slots, 1, -1 do
		if (data.Consumables.Owned[slots[i]] or 0) <= 0 then
			table.remove(slots, i)
		end
	end
	local owned = {}
	for id in T.Owned do
		table.insert(owned, id)
	end
	table.sort(owned)
	local vac = TC().Vacuum(T.Up.Vacuum)
	local pack = {
		Owned = owned,
		Grass = T.Grass,
		Up = T.Up,
		Items = data.Consumables.Owned,
		Slots = data.Consumables.Slots,
	}
	player:SetAttribute("Tools", HttpService:JSONEncode(pack))
	ToolService.PublishHotbar(player)
	player:SetAttribute("VacUsed", T.VacUsed)
	player:SetAttribute("VacCap", vac.Capacity)
	-- v2.38: the pickaxe's durability gauge (PickUsed = blocks broken since its last repair)
	local pick = TC().Pickaxe(T.Up.Pickaxe)
	T.PickUsed = math.clamp(math.floor(tonumber(T.PickUsed) or 0), 0, pick.Durability)
	player:SetAttribute("PickUsed", T.PickUsed)
	player:SetAttribute("PickCap", pick.Durability)
	-- v2.40: the rake with its upgrades, for the client's sweep (BroomController) and the
	-- rake other players see (RemoteBrooms): its Sweep Size, the GATHER's radius / recharge
	if TC().Rake then
		local rake = TC().Rake(T.Up.Rake)
		player:SetAttribute("RakeSweep", rake.SweepSize)
		player:SetAttribute("RakeGather", rake.GatherRadius)
		player:SetAttribute("RakeGatherCd", rake.GatherCooldown)
		-- v2.41: its look (1 Basic … 4 Legendary) — the rake is drawn by the clients
		-- (BroomController for its owner, RemoteBrooms for everybody else)
		player:SetAttribute("RakeTier", TC().HelperTier("Rake", T.Up.Rake))
	end
	ToolService.PublishBattery(player, true)
	ToolService.PublishBlow(player, true) -- v2.32
	ToolService.PublishBlast(player, true) -- v2.42
	ToolService.PublishMeters(player) -- v2.43
end

-- v2.40: the broom stats the player's rake sweeps with (its Tine Width upgrade)
function ToolService.RakeStats(player)
	local data = ctx.PlayerDataService.Get(player)
	local up = data and data.Tools and type(data.Tools.Up) == "table" and data.Tools.Up.Rake or nil
	if TC().Rake then
		return (TC().BoostStats or function(x) return x end)(TC().Rake(up).Stats, toolMult(player))
	end
	return TC().Helpers.Rake.Stats
end

-- v2.32 the Leaf Blower's energy gauge: attributes BlowLeft / BlowMax (seconds)
function ToolService.PublishBlow(player, force)
	local data = ctx.PlayerDataService.Get(player)
	if not data then
		return
	end
	local s = S(player)
	local max = WB(player, TC().Blower(data.Tools.Up.Blower or {})).Energy
	data.Tools.BlowUsed = math.clamp(tonumber(data.Tools.BlowUsed) or 0, 0, max)
	local v = math.floor((max - data.Tools.BlowUsed) * 10 + 0.5) / 10
	if force or not s.BlowPub or math.abs(s.BlowPub - v) >= 0.5 or (v <= 0) ~= (s.BlowPub <= 0) then
		s.BlowPub = v
		player:SetAttribute("BlowLeft", v)
		player:SetAttribute("BlowMax", max)
	end
end

function ToolService.PublishBattery(player, force)
	local data = ctx.PlayerDataService.Get(player)
	if not data then
		return
	end
	local s = S(player)
	local max = TC().Trimmer(data.Tools.Up.Trimmer).Battery
	data.Tools.Battery = math.clamp(data.Tools.Battery, 0, max)
	local v = math.floor(data.Tools.Battery * 10 + 0.5) / 10
	if force or not s.BatPub or math.abs(s.BatPub - v) >= 0.5 or (v <= 0) ~= (s.BatPub <= 0) or v == max then
		s.BatPub = v
		player:SetAttribute("Battery", v)
		player:SetAttribute("BatteryMax", max)
	end
end

---------------------------------------------------------------- tools in the backpack
-- the id of the tool in your hand (nil = none / the broom)
function ToolService.Held(player)
	local char = player.Character
	if not char then
		return nil
	end
	for _, t in char:GetChildren() do
		if t:IsA("Tool") then
			local id = t:GetAttribute("LeafTool")
			if id then
				return id, t
			end
		end
	end
	return nil
end

local function weldModel(tool, model, handle)
	handle.Name = "Handle"
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			if p ~= handle then
				local w = Instance.new("WeldConstraint")
				w.Part0 = handle
				w.Part1 = p
				w.Parent = p
			end
			p.Anchored = false
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = p == handle
			p.Massless = true
		end
	end
	for _, c in model:GetChildren() do
		c.Parent = tool
	end
	model:Destroy()
end

local function buildTool(player, id, slot)
	local data0 = ctx.PlayerDataService.Get(player)
	local def = TC().GrassStats(id, data0 and data0.Tools.Up[id]) or TC().Def(id) -- (v2.43: a grass tool has its tier's name)
	local tool = Instance.new("Tool")
	tool.Name = def.Display
	tool.ToolTip = def.Display
	tool.CanBeDropped = false
	tool:SetAttribute("LeafTool", id)
	tool:SetAttribute("ToolSlot", slot)
	if id == "Rake" then
		-- the rake sweeps with the broom's collider (BroomSystem) and BroomModel's look
		tool:SetAttribute("Implement", "Rake")
		local phys = ctx.BroomTypes.Physics(ToolService.RakeStats(player), "Rake") -- (v2.40: a wider head with Tine Width)
		-- v2.41: the rake looks cooler with its upgrades (tier 1 … 4, like the blower / vacuum)
		local rakeData = ctx.PlayerDataService.Get(player)
		local rakeUp = rakeData and rakeData.Tools and type(rakeData.Tools.Up) == "table" and rakeData.Tools.Up.Rake or nil
		local rakeTier = TC().HelperTier("Rake", rakeUp)
		if rakeTier > 1 then
			tool:SetAttribute("Tier", rakeTier)
			tool.ToolTip = def.Display .. " · " .. TC().TierName("Rake", rakeTier)
		end
		local model, rig = ctx.BroomModel.Build(true, "Rake", phys.HeadScale, rakeTier)
		local handle = rig.handle
		for _, p in rig.parts do
			if p ~= handle then
				local w = Instance.new("WeldConstraint")
				w.Part0 = handle
				w.Part1 = p
				w.Parent = p
			end
			p.Anchored = false
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = p == handle
			p.Massless = p ~= handle
			p.Parent = tool
		end
		handle.Name = "Handle"
		model:Destroy()
		tool.Grip = CFrame.new(handle.Size.X * 0.5 - 0.8, 0, 0) * CFrame.Angles(0, math.rad(90), 0)
		tool.Equipped:Connect(function()
			player:SetAttribute("Implement", "Rake")
			ctx.BroomSystem.Activate(player, "Rake")
		end)
		tool.Unequipped:Connect(function()
			player:SetAttribute("Implement", nil)
			ctx.BroomSystem.Park(player)
		end)
		return tool
	end
	if def.Tier then
		tool:SetAttribute("Tier", def.Tier) -- (v2.43: the hotbar / the client look at it)
	end
	if def.Kind == "Push" then
		-- v1.4: nothing in the hand — the mower rolls in front of you, fixed to your
		-- body (not the hand, so it never shakes with the walk animation). You just
		-- WALK (W A S D) and it cuts what it rolls over.
		tool.RequiresHandle = false
		tool.Equipped:Connect(function()
			ToolService.AttachPush(player, id)
		end)
		tool.Unequipped:Connect(function()
			ToolService.DetachPush(player)
		end)
		return tool
	end
	if def.Kind == "Ride" then
		-- nothing in the hand: taking it out puts the mower under you
		tool.RequiresHandle = false
		tool.Equipped:Connect(function()
			ToolService.Mount(player, id)
		end)
		tool.Unequipped:Connect(function()
			ToolService.Dismount(player)
		end)
		return tool
	end
	-- v1.7: the blower / vacuum look more and more powerful with their upgrades
	local data = ctx.PlayerDataService.Get(player)
	local tier = TC().HelperTier(id, data and data.Tools.Up[id])
	if tier > 1 then
		tool:SetAttribute("Tier", tier)
		if not TC().GrassTiers[id] then
			tool.ToolTip = def.Display .. " · " .. TC().TierName(id, tier) -- (v2.38: the pickaxe's tiers have their own names)
		end
	end
	local model, handle = ctx.ToolModels.Build(id, nil, tier, data and data.Tools.Up[id]) -- (v2.43: + the levels: the maxed stats show on the model)
	weldModel(tool, model, handle)
	tool.Grip = CFrame.new()
	return tool
end

-- v1.4 the push mower: a model welded to the HumanoidRootPart at ToolConfig.PushOffset
function ToolService.AttachPush(player, id)
	ToolService.DetachPush(player)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil
	end
	local dataP = ctx.PlayerDataService.Get(player)
	local model, pivot = ctx.ToolModels.Build(id, nil, TC().HelperTier(id, dataP and dataP.Tools.Up[id]))
	pivot.Name = "MowerPivot"
	local offset = TC().PushOffset
	model:PivotTo(root.CFrame * offset)
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			if p ~= pivot then
				local w = Instance.new("WeldConstraint")
				w.Part0 = pivot
				w.Part1 = p
				w.Parent = p
			end
			p.Anchored = false
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.Massless = true
		end
	end
	local weld = Instance.new("Weld")
	weld.Name = "MowerWeld"
	weld.Part0 = root
	weld.Part1 = pivot
	weld.C0 = offset
	weld.Parent = pivot
	model.Name = "LeafPushMower"
	model:SetAttribute("LeafMower", id)
	model.Parent = char
	return model
end

function ToolService.DetachPush(player)
	local char = player.Character
	local m = char and char:FindFirstChild("LeafPushMower")
	if m then
		m:Destroy()
	end
end

-- (re)build the Tools for slots 2-5; what was in your hand stays in your hand
function ToolService.GiveTools(player)
	local data = ctx.PlayerDataService.Get(player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not data or not backpack then
		return
	end
	local heldId, heldTool = ToolService.Held(player)
	-- riding the mower that stays in slot 2: keep that tool (rebuilding it would
	-- make a new mower under you)
	local s = st[player]
	local keep = if s and s.Mower and heldId == s.MowerId then heldTool else nil
	for _, container in { backpack, player.Character } do
		if container then
			for _, t in container:GetChildren() do
				if t:IsA("Tool") and t:GetAttribute("LeafTool") and t ~= keep then
					t:Destroy()
				end
			end
		end
	end
	local want = {}
	for _, gid in TC().GrassOrder do
		-- v2.43: EVERY grass tool you own is made (the hotbar decides which ones you carry)
		if data.Tools.Owned[gid] and not (keep and gid == heldId) then
			table.insert(want, { gid, 2 })
		end
	end
	for _, id in TC().HelperOrder do
		if data.Tools.Owned[id] then
			table.insert(want, { id, TC().Helpers[id].Slot })
		end
	end
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	for _, w in want do
		local tool = buildTool(player, w[1], w[2])
		if w[1] == heldId and hum and hum.Health > 0 then
			tool.Parent = player.Character
		else
			tool.Parent = backpack
		end
	end
end

---------------------------------------------------------------- buying
local function spend(player, money)
	return ctx.CurrencyService.Spend(player, { LeafValue = money })
end

function ToolService.Buy(player, id)
	local data = ctx.PlayerDataService.Get(player)
	local kind = type(id) == "string" and TC().KindOf(id)
	if not data or (kind ~= "Grass" and kind ~= "Helper") then
		return false, "Unknown tool"
	end
	if ctx.IslandService then
		local can, why = ctx.IslandService.Can(player, "Tools")
		if not can then
			return false, why
		end
	end
	if data.Tools.Owned[id] then
		return false, "You already own it"
	end
	if id == "Pickaxe" and ctx.IslandService then
		local canP, whyP = ctx.IslandService.Can(player, "Pickaxe") -- v2.43: with the blocks (island 3)
		if not canP then
			return false, whyP
		end
	end
	local def = TC().Def(id)
	-- v2.32: tools come with the shop's deliveries (StockService: a restock every 5 minutes)
	if ctx.StockService then
		local inStock, whyStock = ctx.StockService.Check(player, "Tools", id, 1)
		if not inStock then
			return false, whyStock
		end
	end
	if (def.Price or 0) > 0 then
		local ok, why = spend(player, def.Price)
		if not ok then
			return false, why
		end
	end
	if ctx.StockService then
		ctx.StockService.Take(player, "Tools", id, 1)
	end
	data.Tools.Owned[id] = true
	if kind == "Grass" then
		data.Tools.Grass = id -- a new grass tool goes straight into slot 2
	end
	if id == "Trimmer" then
		data.Tools.Battery = TC().Trimmer(data.Tools.Up.Trimmer).Battery
	end
	ToolService.GiveTools(player)
	ToolService.Publish(player)
	return true, "✅ " .. def.Display .. " bought!"
end

function ToolService.Equip(player, id)
	local data = ctx.PlayerDataService.Get(player)
	if not data or type(id) ~= "string" or not TC().GrassTools[id] or not data.Tools.Owned[id] then
		return false, "You don't own it"
	end
	if data.Tools.Grass ~= id then
		ToolService.Dismount(player)
		data.Tools.Grass = id
		ToolService.GiveTools(player)
		ToolService.Publish(player)
	end
	return true, TC().GrassTools[id].Display .. " is in slot 2"
end

function ToolService.UpgradeCost(data, tool, stat)
	if type(tool) ~= "string" or type(stat) ~= "string" or not data.Tools.Owned[tool] then
		return nil
	end
	local ups = TC().UpgradesOf(tool)
	if not ups or not ups[stat] then
		return nil
	end
	local lv = data.Tools.Up[tool] and data.Tools.Up[tool][stat] or 0
	return TC().UpgradeCost(tool, stat, lv), lv
end

function ToolService.Upgrade(player, tool, stat)
	local data = ctx.PlayerDataService.Get(player)
	if not data or not TC().UpgradesOf(tool) then
		return false, "Unknown upgrade"
	end
	if ctx.IslandService then
		local can, why = ctx.IslandService.Can(player, "Tools")
		if not can then
			return false, why
		end
	end
	if not data.Tools.Owned[tool] then
		return false, "Buy the " .. TC().Def(tool).Display .. " first"
	end
	local cost, lv = ToolService.UpgradeCost(data, tool, stat)
	if not cost then
		return false, "Max level"
	end
	local ok, why = spend(player, cost)
	if not ok then
		return false, why
	end
	data.Tools.Up[tool] = data.Tools.Up[tool] or {}
	local tier0 = TC().HelperTier(tool, data.Tools.Up[tool])
	data.Tools.Up[tool][stat] = lv + 1
	if tool == "Pickaxe" then
		data.Tools.PickUsed = 0 -- v2.38: a new head — the better pickaxe comes whole
	elseif TC().GrassTiers[tool] then
		data.Tools.Wear[tool] = nil -- v2.43: a better tool comes whole (and with a full tank)
		data.Tools.FuelUsed[tool] = nil
	end
	ToolService.Publish(player)
	if tool == "Rake" and stat == "Width" then
		-- v2.40: a wider head — rebuild the rake (model + the sweeping collider; it stays
		-- in your hand if you held it)
		pcall(ToolService.GiveTools, player)
	end
	local U = TC().UpgradesOf(tool)
	local tier1 = TC().HelperTier(tool, data.Tools.Up[tool])
	if tier1 ~= tier0 then
		-- v1.7: a new look — rebuild the tool (it stays in your hand if you held it)
		-- (v2.41: the rake and the trimmer have tiers too; the rake's Tine Width has
		-- rebuilt it just above already)
		if not (tool == "Rake" and stat == "Width") then
			pcall(ToolService.GiveTools, player)
		end
		if tool == "Pickaxe" then
			return true, "⛏ ✨ " .. TC().TierName(tool, tier1) .. " Pickaxe!" -- v2.38
		end
		if TC().GrassTiers[tool] then
			return true, "⬆ ✨ " .. TC().TierName(tool, tier1) .. "!" -- v2.43
		end
		return true, "⬆ " .. U[stat].Display .. " → Lvl " .. (lv + 1) .. " · ✨ " .. TC().Def(tool).Display .. ": " .. TC().TierName(tool, tier1) .. "!"
	end
	return true, "⬆ " .. U[stat].Display .. " → Lvl " .. (lv + 1)
end

function ToolService.RepairCost(data)
	local cap = TC().Vacuum(data.Tools.Up.Vacuum).Capacity
	local used = math.min(data.Tools.VacUsed, cap)
	return math.ceil(TC().RepairCost(cap) * used / cap)
end

function ToolService.Repair(player)
	local data = ctx.PlayerDataService.Get(player)
	if not data or not data.Tools.Owned.Vacuum then
		return false, "You have no vacuum"
	end
	if data.Tools.VacUsed <= 0 then
		return false, "It's as good as new"
	end
	local ok, why = spend(player, ToolService.RepairCost(data))
	if not ok then
		return false, why
	end
	data.Tools.VacUsed = 0
	ToolService.Publish(player)
	return true, "🔧 Vacuum repaired!"
end

-- v2.32 the Leaf Blower's energy is put back like the vacuum is repaired: for Money,
-- by how much is missing (ToolConfig.BlowerRechargePerSecond) — or with a Blower Battery
function ToolService.RechargeCost(data, player) -- (round 16: + player = the wind pets' energy bonus)
	local max = WB(player, TC().Blower(data.Tools.Up.Blower or {})).Energy
	local used = math.clamp(tonumber(data.Tools.BlowUsed) or 0, 0, max)
	return TC().RechargeCost(used), used
end

function ToolService.Recharge(player)
	local data = ctx.PlayerDataService.Get(player)
	if not data or not data.Tools.Owned.Blower then
		return false, "You have no leaf blower"
	end
	local cost, used = ToolService.RechargeCost(data, player)
	if used < 0.5 then
		return false, "It's fully charged"
	end
	local ok, why = spend(player, cost)
	if not ok then
		return false, why
	end
	data.Tools.BlowUsed = 0
	S(player).BlowWarned = nil
	ToolService.Publish(player)
	return true, "🔋 Leaf Blower recharged!"
end

---------------------------------------------------------------- v2.43 wear, fuel, repair
--[[
	Shears / Grass Cutter / Scythe wear out: every cut uses one point of their DURABILITY
	(data.Tools.Wear[id] = cuts since the last repair; the tier says how many they stand —
	ToolConfig.GrassTiers). A worn-out tool cuts nothing until it is repaired: SHOP · TOOLS
	(Money by how worn) or a Repair Kit. The Push / Riding Mower burn FUEL while they cut
	(data.Tools.FuelUsed[id] seconds; the tier says the size of the tank); empty = they cut
	nothing (the Riding Mower stops too). SHOP (Money) or Gasoline refills.
	For the hotbar every one of them publishes the attributes ML_<id> (what is left) and
	MM_<id> (the most it holds): the green bar in the slot.
]]
local METER_IDS = { "Shears", "WeedCutter", "Scythe", "PushMower", "RidingMower" }

-- (left, max) of a grass tool's durability or fuel; nil when it has neither
function ToolService.MeterState(data, id)
	local d = data and TC().GrassStats(id, data.Tools.Up[id])
	if not d then
		return nil
	end
	if d.Durability then
		local used = math.clamp(math.floor(tonumber(data.Tools.Wear[id]) or 0), 0, d.Durability)
		return d.Durability - used, d.Durability
	elseif d.Fuel then
		local used = math.clamp(tonumber(data.Tools.FuelUsed[id]) or 0, 0, d.Fuel)
		return d.Fuel - used, d.Fuel
	end
	return nil
end

function ToolService.PublishMeters(player)
	local data = ctx.PlayerDataService.Get(player)
	if not data then
		return
	end
	for _, id in METER_IDS do
		local left, max
		if data.Tools.Owned[id] then
			left, max = ToolService.MeterState(data, id)
		end
		player:SetAttribute("ML_" .. id, if left then math.floor(left * 10 + 0.5) / 10 else nil)
		player:SetAttribute("MM_" .. id, max)
	end
end

-- n cuts were made with a hand tool
function ToolService.Wear(player, id, n)
	local data = ctx.PlayerDataService.Get(player)
	local left, max = ToolService.MeterState(data, id)
	if not left or not max then
		return left
	end
	local used = max - left + n
	data.Tools.Wear[id] = math.min(max, used)
	local nl = max - data.Tools.Wear[id]
	player:SetAttribute("ML_" .. id, nl)
	if nl <= 0 then
		notify(player, "💥 " .. TC().GrassStats(id, data.Tools.Up[id]).Display .. " is worn out — repair it in SHOP · TOOLS or with a Repair Kit")
	end
	return nl
end

-- dt seconds of running: fuel used (-> fuel left)
function ToolService.BurnFuel(player, id, dt)
	local data = ctx.PlayerDataService.Get(player)
	local left, max = ToolService.MeterState(data, id)
	if not left or not max then
		return 1
	end
	local used = math.min(max, max - left + dt)
	data.Tools.FuelUsed[id] = used
	local nl = max - used
	local s = S(player)
	if s.FuelPub == nil or math.abs(s.FuelPub - nl) >= 1 or nl <= 0 then
		s.FuelPub = nl
		player:SetAttribute("ML_" .. id, math.floor(nl * 10 + 0.5) / 10)
	end
	return nl
end

function ToolService.RepairToolCost(data, id)
	local d = TC().GrassStats(id, data.Tools.Up[id])
	local used = math.clamp(math.floor(tonumber(data.Tools.Wear[id]) or 0), 0, d and d.Durability or 0)
	return TC().WearRepairCost(id, d and d.Tier or 1, used), used
end

function ToolService.RepairTool(player, id)
	local data = ctx.PlayerDataService.Get(player)
	local tiers = type(id) == "string" and TC().GrassTiers[id]
	if not data or not tiers or not tiers.Durability or not data.Tools.Owned[id] then
		return false, "You can't repair that"
	end
	local cost, used = ToolService.RepairToolCost(data, id)
	if used <= 0 then
		return false, "It's as good as new"
	end
	local ok, why = spend(player, cost)
	if not ok then
		return false, why
	end
	data.Tools.Wear[id] = 0
	ToolService.PublishMeters(player)
	return true, "🔧 " .. TC().GrassStats(id, data.Tools.Up[id]).Display .. " repaired!"
end

function ToolService.RefuelCost(data, id)
	local left, max = ToolService.MeterState(data, id)
	if not left or not TC().FuelPer[id] then
		return 0, 0
	end
	return TC().FuelCost(id, max - left), max - left
end

function ToolService.Refuel(player, id)
	local data = ctx.PlayerDataService.Get(player)
	if not data or type(id) ~= "string" or not TC().FuelPer[id] or not data.Tools.Owned[id] then
		return false, "Nothing to refuel"
	end
	local cost, missing = ToolService.RefuelCost(data, id)
	if missing < 1 then
		return false, "The tank is full"
	end
	local ok, why = spend(player, cost)
	if not ok then
		return false, why
	end
	data.Tools.FuelUsed[id] = 0
	S(player).FuelPub = nil
	ToolService.PublishMeters(player)
	return true, "⛽ " .. TC().GrassStats(id, data.Tools.Up[id]).Display .. " refuelled!"
end

---------------------------------------------------------------- v2.43 the abilities of the grass tools
--[[
	{ A = "Ability", Pos } — the strike key (Q) with Shears, Grass Cutter, Scythe or the Push
	Mower in the hand, or sitting on the Riding Mower. Every tool has its OWN ability
	(ToolConfig.Abilities); the cooldown runs on the server's clock and is published as the
	player attributes <Name>Ready (server time it is ready again) and <Name>Cd (its length)
	— the hotbar draws it as a separate bar under the tool, like the broom's strike:
	  Shears        Snip Burst  five spots around the aim are cut at once
	  Grass Cutter   Slash Wave  a long strip in front of you is cut
	  Scythe        Harvest     a huge cone in front of you is cut to the ground
	  Push Mower    Overdrive   a much wider deck and a faster walk for a while
	  Riding Mower  Nitro       a burst of speed (and a bit wider deck)
	Nothing is spent when nothing was cut (or the tool is worn out / has no fuel).
]]
local function flatV(v)
	return Vector3.new(v.X, 0, v.Z)
end
local AB_NAME = { Shears = "Snip", WeedCutter = "Slash", Scythe = "Harvest", PushMower = "Overdrive", RidingMower = "Nitro", Blower = "Jet" }
ToolService.AbilityNames = AB_NAME
local abilityReady = {} -- [userId][toolId] = ToolService.Now() it is ready again (outlives a rejoin)

local function abilityGate(player, id, cd)
	local name = AB_NAME[id]
	local per = abilityReady[player.UserId]
	if not per then
		per = {}
		abilityReady[player.UserId] = per
	end
	local now = ToolService.Now()
	if now < (per[id] or -1e9) then
		if player:GetAttribute(name .. "Ready") == nil then
			player:SetAttribute(name .. "Cd", cd)
			player:SetAttribute(name .. "Ready", serverTime() + (per[id] - now))
		end
		return false, per[id] - now
	end
	per[id] = now + cd
	player:SetAttribute(name .. "Cd", cd)
	player:SetAttribute(name .. "Ready", serverTime() + cd)
	return true
end

local function abilityRefund(player, id)
	local per = abilityReady[player.UserId]
	if per then
		per[id] = nil
	end
	player:SetAttribute(AB_NAME[id] .. "Ready", nil)
	player:SetAttribute(AB_NAME[id] .. "Cd", nil)
end

-- the seconds left of the Overdrive / Nitro (the effect)
local function activeFor(player, attr)
	return math.max(0, (player:GetAttribute(attr) or 0) - serverTime())
end

local function mergeKeys(into, keys)
	for _, k in keys do
		into[k] = true
	end
end

function ToolService.Ability(player, pos)
	local s = S(player)
	local data = ctx.PlayerDataService.Get(player)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local plot = ctx.PlotSystem.Get(player)
	if not data or not root then
		return false
	end
	local id = if s.Mower and s.MowerId then s.MowerId else ToolService.Held(player)
	local ab = id and TC().Abilities[id]
	local def = ab and HB(player, TC().GrassStats(id, data.Tools.Up[id]))
	if not def then
		return false
	end
	if def.Durability or def.Fuel then
		local left = ToolService.MeterState(data, id)
		if not left or left <= 0 then
			notify(player, if def.Fuel then "⛽ Out of fuel — fill the tank with Gasoline or in SHOP · TOOLS" else "💥 It is worn out — repair it first")
			return false
		end
	end
	local ok, left = abilityGate(player, id, def.AbCooldown)
	if not ok then
		notify(player, string.format("%s %s recharges: %d s", ab.Icon, ab.Display, math.ceil(left)))
		return false
	end
	local t = (def.Tier or 1) - 1
	local look = flatV(root.CFrame.LookVector)
	look = if look.Magnitude > 1e-3 then look.Unit else Vector3.new(0, 0, -1)
	local set = {}
	local fxPos, fxSize, fxTime = root.Position, def.Radius, 0
	if id == "Shears" or id == "WeedCutter" or id == "Scythe" then
		if not plot then
			abilityRefund(player, id)
			return false
		end
		if id == "Shears" then
			-- five spots: the aim and four around it
			local at = if typeof(pos) == "Vector3" and flatV(pos - root.Position).Magnitude <= def.Reach + 6 then pos else root.Position + look * 4
			local d = ab.Spread * def.Radius
			for _, off in { Vector3.zero, Vector3.new(d, 0, 0), Vector3.new(-d, 0, 0), Vector3.new(0, 0, d), Vector3.new(0, 0, -d) } do
				mergeKeys(set, ctx.GrassService.CellsIn(plot, at + off, def.Radius * 1.05))
			end
			fxPos, fxSize = at, d + def.Radius
		elseif id == "WeedCutter" then
			local len = ab.Length + t * ab.LengthPer
			for dist = 2, len, 2.5 do
				mergeKeys(set, ctx.GrassService.CellsIn(plot, root.Position + look * dist, def.Radius * 0.7))
			end
			fxPos, fxSize = root.Position + look * (len / 2), len
		else
			local range = ab.Range + t * ab.RangePer
			mergeKeys(set, ctx.GrassService.CellsIn(plot, root.Position, range, look, ab.Arc))
			fxPos, fxSize = root.Position + look * (range / 2), range
		end
		local keys = {}
		for k in set do
			table.insert(keys, k)
		end
		local n = ctx.GrassService.Cut(player, keys, 100, { Objects = id == "Shears", Golden = if id == "Scythe" then ab.Golden + (def.GoldenChance or 0) else nil })
		if (n or 0) <= 0 then
			abilityRefund(player, id) -- (nothing was cut: nothing is spent)
			notify(player, "🌿 There is no grass there")
			return false
		end
		ToolService.Wear(player, id, 3)
	elseif id == "PushMower" then
		local time = ab.Time + t * ab.TimePer
		fxTime = time
		player:SetAttribute("OverdriveUntil", serverTime() + time)
		if ctx.GearService then
			ctx.GearService.RefreshSpeed(player)
			task.delay(time + 0.2, function()
				if player.Parent and ctx.GearService then
					ctx.GearService.RefreshSpeed(player)
				end
			end)
		end
		fxSize = def.Radius * ab.Deck
	elseif id == "RidingMower" then
		local time = ab.Time + t * ab.TimePer
		fxTime = time
		player:SetAttribute("NitroUntil", serverTime() + time)
		fxSize = def.Radius * ab.Deck
	end
	if ctx.Net.ToolFX then
		ctx.Net.ToolFX:FireAllClients("Ability", player.UserId, id, fxPos, Vector3.new(fxSize, look.X, look.Z), fxTime)
	end
	return true
end

-- the Overdrive / Nitro right now: (deck multiplier, speed multiplier)
function ToolService.AbilityMult(player, id)
	local ab = TC().Abilities[id]
	if id == "PushMower" and activeFor(player, "OverdriveUntil") > 0 then
		return ab.Deck, 1
	elseif id == "RidingMower" and activeFor(player, "NitroUntil") > 0 then
		return ab.Deck, ab.Boost
	end
	return 1, 1
end

-- walking speed factor of the Push Mower's Overdrive (GearService.SpeedFor)
function ToolService.WalkMult(player)
	if activeFor(player, "OverdriveUntil") > 0 then
		return TC().Abilities.PushMower.Walk
	end
	return 1
end

---------------------------------------------------------------- v2.42 the LEAF BLASTER
--[[
	Server side of the Leaf Blaster (hotbar tool "Blaster", ToolConfig.Helpers.Blaster):
	  • ENERGY = pulses on a full charge (T.Blaster(levels).Energy). data.Tools.BlastUsed
	    counts the pulses fired since the last recharge. It never comes back by itself:
	    SHOP · TOOLS puts it back for Money (RechargeBlast, by how empty it is).
	    Published for the gauges as the attributes BlastLeft / BlastMax.
	  • MAGAZINE = 6 pulses, then a RELOAD of B.Reload seconds (the strike key reloads
	    early). The server's clock decides; it publishes BlastMag, BlastReloadAt (server
	    time it is ready, 0 = not reloading) and BlastSeq (changes with every publish, so
	    the client knows when to take the server's numbers).
	  • PLAYERS: a pulse flies B.Speed studs/s along Dir for B.Range studs. When it reaches
	    a player (within B.Size + a little) they get a shove, exactly like a broom strike
	    or the Leaf Blower (Net.Knockback, no damage, the victim's own client moves them).
	  • ITEMS (leaves …) lie in a garden whose OWNER'S client simulates them, so the owner's
	    client moves them (ToolController, as with the Leaf Blower). Stone items and items
	    locked in ice are never moved. Everybody sees the pulse (ToolFX "Blast").
]]
function ToolService.PublishBlast(player, force)
	local data = ctx.PlayerDataService.Get(player)
	if not data then
		return
	end
	local s = S(player)
	local max = TC().Blaster(data.Tools.Up.Blaster or {}).Energy
	data.Tools.BlastUsed = math.clamp(math.floor(tonumber(data.Tools.BlastUsed) or 0), 0, max)
	local v = max - data.Tools.BlastUsed
	if force or s.BlastPub ~= v or s.BlastPubMax ~= max then
		s.BlastPub, s.BlastPubMax = v, max
		player:SetAttribute("BlastLeft", v)
		player:SetAttribute("BlastMax", max)
	end
end

-- the magazine / reload state to the client
local function publishMag(player, s)
	s.BlastSeq = (s.BlastSeq or 0) + 1
	player:SetAttribute("BlastMag", s.BlastMag or 0)
	player:SetAttribute("BlastReloadAt", s.BlastReloadST or 0)
	player:SetAttribute("BlastSeq", s.BlastSeq)
end

-- a reload whose time is up fills the magazine (checked whenever it is needed)
local function blastRefill(s, B, now)
	if s.BlastReload and now >= s.BlastReload then
		s.BlastReload, s.BlastReloadST = nil, nil
		s.BlastMag = B.Magazine
	end
	s.BlastMag = math.min(s.BlastMag or B.Magazine, B.Magazine)
end

local function startReload(player, s, B, now)
	s.BlastReload = now + B.Reload
	s.BlastReloadST = serverTime() + B.Reload
	publishMag(player, s)
end

function ToolService.RechargeBlastCost(data)
	local max = TC().Blaster(data.Tools.Up.Blaster or {}).Energy
	local used = math.clamp(math.floor(tonumber(data.Tools.BlastUsed) or 0), 0, max)
	return TC().BlasterRechargeCost(used), used
end

function ToolService.RechargeBlast(player)
	local data = ctx.PlayerDataService.Get(player)
	if not data or not data.Tools.Owned.Blaster then
		return false, "You have no leaf blaster"
	end
	local cost, used = ToolService.RechargeBlastCost(data)
	if used < 1 then
		return false, "It's fully charged"
	end
	local ok, why = spend(player, cost)
	if not ok then
		return false, why
	end
	data.Tools.BlastUsed = 0
	S(player).BlastWarned = nil
	ToolService.Publish(player)
	return true, "🔋 Leaf Blaster recharged!"
end

---------------------------------------------------------------- v2.38 the PICKAXE's durability
--[[
	data.Tools.PickUsed = blocks the pickaxe broke since its last repair; its tier
	(ToolConfig.PickaxeTiers, data.Tools.Up.Pickaxe.Tier) says how many it stands.
	BlockService asks PickState before a swing and calls PickWear for every block that
	broke. At 0 the pickaxe is BROKEN: nothing is mined until it is repaired — for Money
	in SHOP · TOOLS (by how much is missing, like the vacuum) or with Robux ("PickRepair").
	Upgrading to the next tier brings a whole pickaxe.
]]
-- the tier's table, blocks left before it breaks, blocks used
function ToolService.PickState(data)
	local T = data and data.Tools
	if type(T) ~= "table" or type(T.Up) ~= "table" then
		return TC().PickaxeTiers[1], 0, 0
	end
	local pick = TC().Pickaxe(T.Up.Pickaxe)
	local used = math.clamp(math.floor(tonumber(T.PickUsed) or 0), 0, pick.Durability)
	return pick, pick.Durability - used, used
end

-- n blocks were broken: wear it (-> blocks left)
function ToolService.PickWear(player, n)
	local data = ctx.PlayerDataService.Get(player)
	n = math.floor(tonumber(n) or 0)
	if not data or n <= 0 then
		return 0
	end
	local pick, left, used = ToolService.PickState(data)
	if left <= 0 then
		return 0
	end
	used = math.min(pick.Durability, used + n)
	data.Tools.PickUsed = used
	player:SetAttribute("PickUsed", used)
	player:SetAttribute("PickCap", pick.Durability)
	if used >= pick.Durability then
		notify(player, "💥 Your pickaxe broke — repair it in SHOP · TOOLS")
	end
	return pick.Durability - used
end

function ToolService.PickRepairCost(data)
	local pick, _, used = ToolService.PickState(data)
	return TC().PickaxeRepairCost(pick.Index, used), used
end

function ToolService.PickRepair(player)
	local data = ctx.PlayerDataService.Get(player)
	if not data or not data.Tools.Owned.Pickaxe then
		return false, "You have no pickaxe"
	end
	local cost, used = ToolService.PickRepairCost(data)
	if used <= 0 then
		return false, "It's as good as new"
	end
	local ok, why = spend(player, cost)
	if not ok then
		return false, why
	end
	data.Tools.PickUsed = 0
	ToolService.Publish(player)
	return true, "🔧 Pickaxe repaired!"
end

function ToolService.BuyItem(player, id, count)
	local data = ctx.PlayerDataService.Get(player)
	local def = type(id) == "string" and TC().Consumables[id]
	count = math.floor(tonumber(count) or 1)
	if not data or not def then
		return false, "Unknown item"
	end
	if count < 1 or count > 10 then
		return false, "Bad amount"
	end
	if def.NotSold then
		return false, "This item is not sold" -- (round 15: the Milk Bottle comes from a Cow only)
	end
	if ctx.IslandService then
		local can, why = ctx.IslandService.Can(player, "Items")
		if not can then
			return false, why
		end
	end
	local have = data.Consumables.Owned[id] or 0
	-- (v2.37: no limit on how many you carry)
	-- v2.32: one-use items come with the shop's deliveries (StockService)
	if ctx.StockService then
		local inStock, whyStock = ctx.StockService.Check(player, "Consumables", id, count)
		if not inStock then
			return false, whyStock
		end
	end
	local ok, why = spend(player, def.Price * count)
	if not ok then
		return false, why
	end
	if ctx.StockService then
		ctx.StockService.Take(player, "Consumables", id, count)
	end
	data.Consumables.Owned[id] = have + count
	local slots = data.Consumables.Slots
	if not table.find(slots, id) and #slots < TC().ConsumableSlots then
		table.insert(slots, id) -- (a free hotbar slot takes it at once)
	end
	ToolService.Publish(player)
	return true, "✅ " .. def.Display .. " ×" .. count
end

-- v1.7: a one-use item given as a reward (the wheel's Mega Magnet): free, into a
-- free hotbar slot when there is one. Returns how many were given.
function ToolService.GiveItem(player, id, count)
	local data = ctx.PlayerDataService.Get(player)
	local def = type(id) == "string" and TC().Consumables[id]
	if not data or not def then
		return 0
	end
	local have = data.Consumables.Owned[id] or 0
	count = math.floor(tonumber(count) or 1) -- (v2.37: no stack limit)
	if count ~= count or count <= 0 or count == math.huge then
		return 0
	end
	data.Consumables.Owned[id] = have + count
	local slots = data.Consumables.Slots
	if not table.find(slots, id) and #slots < TC().ConsumableSlots then
		table.insert(slots, id)
	end
	ToolService.Publish(player)
	return count
end

function ToolService.SetSlot(player, id, on)
	local data = ctx.PlayerDataService.Get(player)
	if not data or type(id) ~= "string" or not TC().Consumables[id] then
		return false, "Unknown item"
	end
	local slots = data.Consumables.Slots
	local i = table.find(slots, id)
	if on then
		if (data.Consumables.Owned[id] or 0) <= 0 then
			return false, "You have no " .. TC().Consumables[id].Display .. " — buy some in SHOP · TOOLS"
		end
		if not i then
			if #slots >= TC().ConsumableSlots then
				return false, "The hotbar holds " .. TC().ConsumableSlots .. " items — take one out first"
			end
			table.insert(slots, id)
		end
	elseif i then
		table.remove(slots, i)
	end
	ToolService.Publish(player)
	return true
end

---------------------------------------------------------------- v2.12 the HOTBAR
--[[
	The quick bar holds up to 10 things of ANY kind, in the order the player chose:
	  { K = "Broom", Id = broom id }      { K = "Tool", Id = grass tool / Rake / Blower / Vacuum }
	  { K = "Item", Id = one-use item }    { K = "Stored", Id = object id in the inventory }
	  { K = "Egg", Id = egg id }           { K = "Pet", Id = pet uid }
	The list is only a layout: owning / using things is checked where it always was.
	An empty saved list = the client shows its default (broom, tools, items).
	{ Action = "Hotbar", List = { … } }
]]
ToolService.HotbarMax = 10
local HOTBAR_KINDS = { Broom = true, Tool = true, Item = true, Stored = true, Egg = true, Pet = true, Box = true } -- (v2.39: { K = "Box", Id = cosmetic box id })

function ToolService.PublishHotbar(player)
	local data = ctx.PlayerDataService.Get(player)
	if not data then
		return
	end
	pcall(function()
		player:SetAttribute("Hotbar", HttpService:JSONEncode(if type(data.Hotbar) == "table" then data.Hotbar else {}))
		player:SetAttribute("HotbarSet", data.HotbarSet == true)
	end)
end

function ToolService.SetHotbar(player, list)
	local data = ctx.PlayerDataService.Get(player)
	if not data or type(list) ~= "table" then
		return false, "Bad request"
	end
	local out, seen = {}, {}
	for i = 1, math.min(#list, ToolService.HotbarMax) do
		local e = list[i]
		if type(e) == "table" and type(e.K) == "string" and HOTBAR_KINDS[e.K] and type(e.Id) == "string" and #e.Id > 0 and #e.Id <= 40 then
			local key = e.K .. ":" .. e.Id
			if not seen[key] then
				seen[key] = true
				table.insert(out, { K = e.K, Id = e.Id })
			end
		end
	end
	data.Hotbar = out
	data.HotbarSet = true -- (the player arranged it: no default any more)
	ToolService.PublishHotbar(player)
	player:SetAttribute("HotbarSet", true)
	return true
end

---------------------------------------------------------------- v2.37 the thing IN THE HAND
--[[
	What a player holds that is NOT a Roblox Tool (an egg, a cosmetic box, a sapling /
	tree, a building, a cosmetic, a one-use item, a pet) is shown to everybody by the
	client module HandItem. The client only says WHICH thing ({ A = "Hold", K, Id } on
	ToolAction; K = nil puts it away); the server checks that the player owns it and
	writes the look itself into the player attribute "Held":
	   I|<item>   E|<egg>   B|<box>   T|<tree>|<level>   D|<decor>   Z   P|<pet>|<variant>|<level>
	{ A = "Act", K = kind, Pos?, S? } = "I just did this" (planted, set an egg down, used
	a magnet …): relayed to every client on ToolFX ("Act", userId, kind, pos, text) —
	only a picture, nothing is decided by it.
]]
local HAND_ACTS = { Plant = true, SetEgg = true, SetBox = true, SetDecor = true, Magnet = true, Spray = true, Plug = true, Toy = true, Give = true, PutPet = true, PickUp = true }

function ToolService.HoldItem(player, kind, id)
	local data = ctx.PlayerDataService.Get(player)
	if not data then
		return
	end
	-- (review: the client sends at most one every 0.25 s — 8 a second is not the game's client)
	local s = S(player)
	local t = os.clock()
	if t - (s.HoldT or -1e9) > 1 then
		s.HoldT, s.HoldN = t, 0
	end
	s.HoldN = (s.HoldN or 0) + 1
	if s.HoldN > 8 then
		return
	end
	local look = nil
	if type(kind) == "string" and type(id) == "string" and #id > 0 and #id <= 40 then
		pcall(function()
			if kind == "Item" then
				if TC().Consumables[id] and (tonumber(data.Consumables.Owned[id]) or 0) >= 1 then
					look = "I|" .. id
				end
			elseif kind == "Egg" then
				if ctx.PetConfig.Eggs[id] and (tonumber(data.Eggs.Owned[id]) or 0) >= 1 then
					look = "E|" .. id
				end
			elseif kind == "Box" then
				local b = data.Boxes
				if type(b) == "table" and type(b.Owned) == "table" and (tonumber(b.Owned[id]) or 0) >= 1 then
					look = "B|" .. id
				end
			elseif kind == "Stored" then
				local rec = data.Plot.Stored[id]
				if type(rec) == "table" then
					if rec.Type == "Tree" and type(rec.TreeType) == "string" then
						look = "T|" .. rec.TreeType .. "|" .. tostring(math.max(math.floor(tonumber(rec.Level) or 1), 0))
					elseif rec.Type == "Decor" and type(rec.DecorType) == "string" then
						look = "D|" .. rec.DecorType
					else
						look = "Z"
					end
				end
			elseif kind == "Pet" then
				local p = data.Pets.Owned[id]
				if type(p) == "table" and type(p.Id) == "string" then
					look = "P|" .. p.Id .. "|" .. tostring(p.Variant or "Normal") .. "|" .. tostring(p.Level or 1)
				end
			end
		end)
	end
	if look ~= nil and #look > 80 then
		look = nil
	end
	player:SetAttribute("Held", look)
end

function ToolService.HandAct(player, kind, pos, text)
	if type(kind) ~= "string" or not HAND_ACTS[kind] then
		return
	end
	local s = S(player)
	local now = os.clock()
	if now - (s.LastAct or -1e9) < 0.15 then
		return
	end
	s.LastAct = now
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	if typeof(pos) == "Vector3" then
		local m = (pos - root.Position).Magnitude
		if not (m == m and m <= 250) then
			pos = nil
		end
	else
		pos = nil
	end
	if type(text) ~= "string" or #text > 40 then
		text = nil
	end
	if ctx.Net.ToolFX then
		ctx.Net.ToolFX:FireAllClients("Act", player.UserId, kind, pos, text)
	end
end

---------------------------------------------------------------- one-use items
local function ownsMower(data)
	return data.Tools.Owned.PushMower or data.Tools.Owned.RidingMower
end

function ToolService.Use(player, id, pos, pet, toolId)
	local data = ctx.PlayerDataService.Get(player)
	local def = type(id) == "string" and TC().Consumables[id]
	if not data or not def then
		return false, "Unknown item"
	end
	if (data.Consumables.Owned[id] or 0) < 1 then
		return false, "You have no " .. def.Display
	end
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then
		return false, "Not now"
	end
	local msg
	if id == "LeafMagnet" or id == "MegaMagnet" then
		player:SetAttribute("MagnetUntil", serverTime() + def.Duration)
		player:SetAttribute("MagnetKind", id)
		msg = "🧲 " .. def.Display .. " for " .. def.Duration .. " s!"
	elseif id == "GrassKiller" then
		if typeof(pos) ~= "Vector3" or (pos - root.Position).Magnitude > 80 then
			return false, "Pick a spot near you"
		end
		local plot = ctx.PlotSystem.Get(player)
		if not plot or not ctx.GrassService.CellAt(plot, pos) then
			return false, "Pick a spot in your garden"
		end
		if ctx.GrassService.Clear(player, pos, def.Radius) == 0 then
			return false, "No grass to kill there"
		end
		msg = "🧴 The grass there is gone!"
	elseif id == "GrassSalt" then
		-- v2.51: this grass spot never grows grass again (a lawn cell or the top of an Earth block)
		if typeof(pos) ~= "Vector3" or (pos - root.Position).Magnitude > 80 then
			return false, "Pick a spot near you"
		end
		local okS, whyS = ctx.GrassService.MakeBare(player, pos)
		if not okS then
			return false, whyS
		end
		msg = whyS
	elseif id == "BatteryPack" then
		if not data.Tools.Owned.Trimmer then
			return false, "You need a Lawn Trimmer"
		end
		local max = TC().Trimmer(data.Tools.Up.Trimmer).Battery
		if data.Tools.Battery >= max then
			return false, "The battery is already full"
		end
		data.Tools.Battery = max
		ToolService.PublishBattery(player, true)
		msg = "🔋 Trimmer battery full!"
	elseif id == "TurboFuel" then
		if not ownsMower(data) then
			return false, "You need a lawn mower"
		end
		player:SetAttribute("TurboUntil", serverTime() + def.Duration)
		msg = "⛽ Turbo! +50% mower speed for " .. def.Duration .. " s"
	elseif id == "BlowerBattery" then
		-- v2.32: a full charge for the Leaf Blower
		if not data.Tools.Owned.Blower then
			return false, "You need a Leaf Blower"
		end
		if (tonumber(data.Tools.BlowUsed) or 0) < 0.5 then
			return false, "The Leaf Blower is already fully charged"
		end
		data.Tools.BlowUsed = 0
		S(player).BlowWarned = nil
		msg = "🔋 Leaf Blower fully charged!"
	elseif id == "BlasterBattery" then
		-- v2.43: a full charge for the Leaf Blaster
		if not data.Tools.Owned.Blaster then
			return false, "You need a Leaf Blaster"
		end
		if (tonumber(data.Tools.BlastUsed) or 0) < 1 then
			return false, "The Leaf Blaster is already fully charged"
		end
		data.Tools.BlastUsed = 0
		S(player).BlastWarned = nil
		msg = "🔋 Leaf Blaster fully charged!"
	elseif id == "Gasoline" then
		-- v2.43: the tanks of both mowers to the top
		if not ownsMower(data) then
			return false, "You need a lawn mower"
		end
		local any = false
		for _, m in { "PushMower", "RidingMower" } do
			if data.Tools.Owned[m] and (tonumber(data.Tools.FuelUsed[m]) or 0) >= 1 then
				data.Tools.FuelUsed[m] = 0
				any = true
			end
		end
		if not any then
			return false, "The tanks are already full"
		end
		S(player).FuelPub = nil
		msg = "⛽ The tank is full!"
	elseif id == "RepairKit" then
		-- v2.43: ONE of Shears / Grass Cutter / Scythe / Pickaxe (toolId = the one picked in the panel)
		if type(toolId) ~= "string" or not TC().RepairTargets[toolId] or not data.Tools.Owned[toolId] then
			return false, "Pick a tool to repair"
		end
		if toolId == "Pickaxe" then
			if (tonumber(data.Tools.PickUsed) or 0) <= 0 then
				return false, "The Pickaxe is as good as new"
			end
			data.Tools.PickUsed = 0
			msg = "🔧 Pickaxe repaired!"
		else
			if (tonumber(data.Tools.Wear[toolId]) or 0) <= 0 then
				return false, "It's as good as new"
			end
			data.Tools.Wear[toolId] = 0
			msg = "🔧 " .. TC().GrassStats(toolId, data.Tools.Up[toolId]).Display .. " repaired!"
		end
	elseif id == "VacuumBattery" then
		-- v2.38: the whole capacity back — exactly what ToolService.Repair does (it is
		-- not used up when there is no vacuum or nothing is worn)
		if not data.Tools.Owned.Vacuum then
			return false, "You need a Vacuum"
		end
		if (tonumber(data.Tools.VacUsed) or 0) <= 0 then
			return false, "The Vacuum is already as good as new"
		end
		data.Tools.VacUsed = 0
		msg = "🔋 Vacuum fully restored!"
	elseif def.Milk then
		-- (round 15) the Cow's Milk Bottle: +Boost for Duration to one EQUIPPED pet (refreshed, never stacked)
		local PA = ctx.PetAbilityService
		if not PA or not PA.Milk then
			return false, "Not now"
		end
		local okM, textM = PA.Milk(player, pet, def.Boost, def.Duration)
		if not okM then
			return false, textM
		end
		msg = textM
	elseif def.PetTarget then
		-- v2.32 a pet toy: `pet` = the uid of one of your EQUIPPED pets (the client's picker)
		local PA = ctx.PetAbilityService
		if not PA or not PA.Boost then
			return false, "Not now"
		end
		local okB, text = PA.Boost(player, pet, def.Boost, def.Duration, id)
		if not okB then
			return false, text
		end
		msg = text
	else
		return false, "Unknown item"
	end
	data.Consumables.Owned[id] -= 1
	if data.Consumables.Owned[id] <= 0 then
		data.Consumables.Owned[id] = nil
	end
	data.Stats.ItemsUsed = (data.Stats.ItemsUsed or 0) + 1
	if ctx.QuestService then
		ctx.QuestService.Track(player, "ItemsUsed", 1) -- round 13
	end
	ToolService.Publish(player)
	return true, msg
end

---------------------------------------------------------------- working
local function rootOf(player)
	local char = player.Character
	return char and char:FindFirstChild("HumanoidRootPart")
end

local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

-- Shears / Grass Cutter / Scythe
function ToolService.CutAt(player, pos, dir)
	local id = ToolService.Held(player)
	local dataC = ctx.PlayerDataService.Get(player)
	local def = id and dataC and HB(player, TC().GrassStats(id, dataC.Tools.Up[id]))
	if not def or (def.Kind ~= "Snip" and def.Kind ~= "Swipe" and def.Kind ~= "Swing") then
		return false
	end
	-- v2.43: a worn-out tool cuts nothing
	local wearLeft = ToolService.MeterState(dataC, id)
	if wearLeft and wearLeft <= 0 then
		local sw = S(player)
		if ToolService.Now() - (sw.WornSaid or -1e9) > 4 then
			sw.WornSaid = ToolService.Now()
			notify(player, "💥 " .. def.Display .. " is worn out — repair it in SHOP · TOOLS or with a Repair Kit")
		end
		return false
	end
	local root = rootOf(player)
	local plot = ctx.PlotSystem.Get(player)
	if not root or not plot or typeof(pos) ~= "Vector3" then
		return false
	end
	local s = S(player)
	local now = ToolService.Now()
	if now - s.LastCut < def.Cooldown * 0.8 then
		return false
	end
	local d = if typeof(dir) == "Vector3" and flat(dir).Magnitude > 1e-3 then flat(dir).Unit else flat(root.CFrame.LookVector).Unit
	local center
	if def.Kind == "Snip" then
		if flat(pos - root.Position).Magnitude > def.Reach + 2 then
			return false
		end
		center = pos
	elseif def.Kind == "Swipe" then
		center = root.Position + d * def.Reach
	else
		center = root.Position
	end
	s.LastCut = now
	local keys = ctx.GrassService.CellsIn(plot, center, def.Radius, if def.Arc then d else nil, def.Arc)
	local n, clips = ctx.GrassService.Cut(player, keys, def.Power, { Objects = def.CutsObjects, Golden = def.GoldenChance })
	ToolService.Wear(player, id, 1) -- v2.43
	if ctx.Net.ToolFX then
		ctx.Net.ToolFX:FireAllClients("Cut", player.UserId, id, center, d)
	end
	return true, n, clips
end

-- the trimmer runs at `pos` (called ~8×/s while the button is held)
function ToolService.Trim(player, pos)
	local id = ToolService.Held(player)
	local data = ctx.PlayerDataService.Get(player)
	local root = rootOf(player)
	local plot = ctx.PlotSystem.Get(player)
	if id ~= "Trimmer" or not data or not root or not plot or typeof(pos) ~= "Vector3" then
		return false
	end
	local tr = HB(player, TC().Trimmer(data.Tools.Up.Trimmer))
	if flat(pos - root.Position).Magnitude > tr.Reach + 2 then
		return false
	end
	local s = S(player)
	local now = ToolService.Now()
	local dt = math.clamp(now - s.LastTrim, 0, 0.2)
	s.LastTrim = now
	if data.Tools.Battery <= 0 then
		if not s.EmptyWarned then
			s.EmptyWarned = true
			notify(player, "🔋 The trimmer's battery is empty — it recharges slowly, or use a Battery Pack")
		end
		return false
	end
	s.EmptyWarned = false
	data.Tools.Battery = math.max(0, data.Tools.Battery - dt)
	ToolService.PublishBattery(player)
	if dt <= 0 then
		return true, 0
	end
	local keys = ctx.GrassService.CellsIn(plot, pos, tr.Radius)
	local n = ctx.GrassService.Cut(player, keys, tr.Power * tr.Rate * dt)
	return true, n
end

---------------------------------------------------------------- v2.40 the trimmer's WHIRL
--[[
	{ A = "Whirl" } — the strike key with the Lawn Trimmer in the hand. The line shoots
	out to its full length, the player spins once and ALL the grass of their garden
	within ToolConfig.Whirl(…).Radius studs of them is cut down at once — through the
	normal GrassService.Cut (clippings fall, the "cut grass" quest, the lawn stats and
	the Mushroom Stump count exactly as with any grass tool).
	  • costs Whirl.Battery seconds of the trimmer's battery (it must have that much)
	  • recharges Whirl.Cooldown seconds on the server's clock (attribute "WhirlReady" =
	    server time it is ready again, "WhirlCd" = its length, for the HUD / the button)
	  • nothing is spent when there is no grass in reach (or you are not at your garden)
	  • everybody sees it: ToolFX ("Whirl", userId, "Trimmer", centre, Vector3(radius,
	    seconds, spots cut)) — the client module WhirlFX spins the character and draws
	    the line; the owner's loose leaves in the ring hop up (WorldFX "Push", Mode "Up")
	-> true, spots cut, clippings   |   false, why
]]
function ToolService.Whirl(player)
	local data = ctx.PlayerDataService.Get(player)
	local root = rootOf(player)
	local plot = ctx.PlotSystem.Get(player)
	if ToolService.Held(player) ~= "Trimmer" or not data or not root or not plot or not TC().Whirl then
		return false
	end
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then
		return false
	end
	local s = S(player)
	local now = ToolService.Now()
	local W = HB(player, TC().Whirl(data.Tools.Up.Trimmer))
	if not s.WhirlReady and whirlReady[player.UserId] then
		s.WhirlReady = whirlReady[player.UserId] -- (the cooldown outlives a rejoin, like the vortex's)
	end
	if now < (s.WhirlReady or -1e9) then
		if player:GetAttribute("WhirlReady") == nil then
			-- (after a rejoin the client's gauge doesn't know about it yet)
			player:SetAttribute("WhirlCd", W.Cooldown)
			player:SetAttribute("WhirlReady", serverTime() + (s.WhirlReady - now))
		end
		return false, "cooldown"
	end
	local function say(text)
		if now - (s.WhirlWarned or -1e9) > 2.5 then
			s.WhirlWarned = now
			notify(player, text)
		end
	end
	if (tonumber(data.Tools.Battery) or 0) < W.Battery then
		say("🔋 The WHIRL needs " .. W.Battery .. " s of battery — let the trimmer recharge or use a Battery Pack")
		return false, "battery"
	end
	local center = root.Position
	local keys = ctx.GrassService.CellsIn(plot, center, W.Radius)
	local grassy = 0
	for _, k in keys do
		if ctx.GrassService.Get(player, k) > 0 then
			grassy += 1
		end
	end
	if grassy == 0 then
		say("🌀 No grass around you to whirl — stand in the grass of your garden")
		return false, "nothing"
	end
	s.WhirlReady = now + W.Cooldown
	whirlReady[player.UserId] = s.WhirlReady
	data.Tools.Battery = math.max(0, data.Tools.Battery - W.Battery)
	s.LastTrim = now -- (the battery doesn't recharge in the same second)
	ToolService.PublishBattery(player, true)
	player:SetAttribute("WhirlCd", W.Cooldown)
	player:SetAttribute("WhirlReady", serverTime() + W.Cooldown)
	local n, clips = ctx.GrassService.Cut(player, keys, W.Power)
	if ctx.Net.ToolFX then
		ctx.Net.ToolFX:FireAllClients("Whirl", player.UserId, "Trimmer", center, Vector3.new(W.Radius, W.Time, n))
	end
	if ctx.Net.WorldFX then
		-- the draught of the line: the owner's loose leaves in the ring hop up where they lie
		-- (their own client moves them — nothing is scattered, a pile stays a pile)
		pcall(function()
			ctx.Net.WorldFX:FireClient(player, "Push", center - Vector3.new(0, 2.5, 0), nil, { Radius = W.Radius, Mode = "Up", Speed = W.Hop })
		end)
	end
	return true, n, clips
end

-- v1.4 the Leaf Blower pushes PLAYERS standing in front of its nozzle (no damage;
-- the victim's own client applies the shove, like a broom strike). Rate-limited, the
-- server uses its own positions and the blower's range / cone (+ upgrades).
local blowImmune = setmetatable({}, { __mode = "k" }) -- [victim] = time
function ToolService.BlowAt(player, dir, jet)
	if ToolService.Held(player) ~= "Blower" or typeof(dir) ~= "Vector3" or dir ~= dir then
		return 0
	end
	local root = rootOf(player)
	local data = ctx.PlayerDataService.Get(player)
	local s = S(player)
	local now = ToolService.Now()
	local def = TC().Helpers.Blower
	if not root or not data or now - (s.LastBlow or -1e9) < (def.PlayerEvery or 0.35) * 0.8 then
		return 0
	end
	if jet == true and now < (s.JetReady or -1e9) then
		return 0, "jetcd" -- v2.43: the JET is still recharging
	end
	local gap = now - (s.LastBlow or -1e9)
	s.LastBlow = now
	-- v2.32 ENERGY: every second of blowing uses a second of it (the client reports
	-- about 3×/s while it blows; the time between two reports is what was used — a
	-- first report after a pause counts as one report's worth). Empty = it stops.
	local B = WB(player, HB(player, TC().Blower(data.Tools.Up.Blower or {})))
	local used = tonumber(data.Tools.BlowUsed) or 0
	if used >= B.Energy then
		if not s.BlowWarned then
			s.BlowWarned = true
			notify(player, "🪫 The Leaf Blower is out of energy — recharge it in SHOP · TOOLS or use a Blower Battery")
		end
		ToolService.PublishBlow(player)
		return 0, "empty"
	end
	data.Tools.BlowUsed = math.min(B.Energy, used + (if gap > 0.6 then 0.3 else gap))
	ToolService.PublishBlow(player)
	if data.Tools.BlowUsed >= B.Energy and not s.BlowWarned then
		s.BlowWarned = true
		notify(player, "🪫 The Leaf Blower is out of energy — recharge it in SHOP · TOOLS or use a Blower Battery")
	end
	if jet == true then
		-- v2.34 JET mode: the gust is turned round and carries the PLAYER (their own
		-- client moves the character — characters are owned by their players; its speed
		-- is capped under the movement guard's limit, ToolConfig Jet…). The server keeps
		-- draining the same energy (above) and shows the stream to everybody else.
		-- Nothing is blown in this mode: no leaves, no players, no ice.
		s.JetLast = now -- v2.43: when it stops (ToolService.Start), the recharge begins
		local m = dir.Magnitude
		if m == m and m > 1e-3 and m < 1e3 and ctx.Net.ToolFX then
			ctx.Net.ToolFX:FireAllClients("Jet", player.UserId, "Blower", root.Position, dir.Unit)
		end
		return 0, "jet"
	end
	local look = flat(root.CFrame.LookVector)
	local d = flat(dir)
	if d.Magnitude < 1e-3 then
		return 0
	end
	d = d.Unit
	if look.Magnitude > 1e-3 and d:Dot(look.Unit) < math.cos(math.rad(75)) then
		d = look.Unit -- (the client's aim may turn it only so far from where you face)
	end
	-- (round 16 wind) the Wind Squirrel works while you blow: where and how far
	if ctx.PetPowers and ctx.PetPowers.OnBlow then
		pcall(ctx.PetPowers.OnBlow, player, root.Position, d, B.Range)
	end
	local cosHalf = math.cos(math.rad(B.Cone + 10))
	local n = 0
	for _, other in ctx.Players:GetPlayers() do
		if other ~= player and (blowImmune[other] or 0) <= now then
			local oroot = rootOf(other)
			local hum = other.Character and other.Character:FindFirstChildOfClass("Humanoid")
			if oroot and hum and hum.Health > 0 then
				local off = flat(oroot.Position - root.Position)
				local dist = off.Magnitude
				if dist > 0.5 and dist <= B.Range + 1.5 and math.abs(oroot.Position.Y - root.Position.Y) < 6 and off.Unit:Dot(d) >= cosHalf then
					local fall = 1 - dist / (B.Range + 1.5) * 0.5
					local push = (off.Unit * 0.4 + d * 0.6).Unit * (def.PlayerPush or 26) * fall * (B.Force / def.Force) ^ 0.5
					local dv = Vector3.new(push.X, def.PlayerLift or 9, push.Z)
					blowImmune[other] = now + (def.PlayerEvery or 0.35)
					if ctx.SecurityService then
						ctx.SecurityService.Grace(other, 1.2)
					end
					if ctx.Net.Knockback then
						ctx.Net.Knockback:FireClient(other, dv, player.UserId)
					end
					n += 1
				end
			end
		end
	end
	-- v1.9: the air stream slowly MELTS frozen items' ice blocks in front of you
	local plot = ctx.PlotSystem.Get(player)
	local RS = ctx.ResourceService
	if plot and RS and RS.HitIce then
		local melt = (ctx.MutationTypes and ctx.MutationTypes.Config and ctx.MutationTypes.Config.Defs.Frozen.Ability.MeltPerBlow) or 0.35
		for part in RS.AliveIn(plot) do
			if RS.IsIced(part) then
				local off = flat(part.Position - root.Position)
				local dist = off.Magnitude
				if dist <= B.Range + 1.5 and (dist < 1.5 or off.Unit:Dot(d) >= cosHalf) then
					local broke = RS.HitIce(part, melt)
					if ctx.MutationService then
						ctx.MutationService.FX(if broke then "IceMelt" else "IceDrip", part.Position, Color3.fromRGB(150, 210, 255))
					end
				end
			end
		end
	end
	return n
end

-- v2.42 the strike key / the RELOAD button: start the reload before the magazine is empty
function ToolService.BlastReload(player)
	if ToolService.Held(player) ~= "Blaster" then
		return false
	end
	local data = ctx.PlayerDataService.Get(player)
	if not data then
		return false
	end
	local s = S(player)
	local now = ToolService.Now()
	local B = HB(player, TC().Blaster(data.Tools.Up.Blaster))
	blastRefill(s, B, now)
	if s.BlastReload or s.BlastMag >= B.Magazine then
		return false -- (already reloading / already full)
	end
	startReload(player, s, B, now)
	return true
end

local blastImmune = setmetatable({}, { __mode = "k" }) -- [victim] = time
-- one pulse: checks the tool in the hand, the rate, the magazine and the energy on the
-- server's clock, then shoves the players the pulse reaches. -> players shoved, reason?
function ToolService.BlastAt(player, dir)
	if ToolService.Held(player) ~= "Blaster" or typeof(dir) ~= "Vector3" or dir ~= dir then
		return 0
	end
	local root = rootOf(player)
	local data = ctx.PlayerDataService.Get(player)
	if not root or not data then
		return 0
	end
	local s = S(player)
	local now = ToolService.Now()
	local B = HB(player, TC().Blaster(data.Tools.Up.Blaster))
	blastRefill(s, B, now)
	if s.BlastReload then
		return 0, "reload"
	end
	if now - (s.LastBlast or -1e9) < B.FireEvery * 0.8 then
		return 0
	end
	local used = math.floor(tonumber(data.Tools.BlastUsed) or 0)
	if used >= B.Energy then
		if not s.BlastWarned then
			s.BlastWarned = true
			notify(player, "🪫 The Leaf Blaster is out of energy — recharge it in SHOP · TOOLS")
		end
		ToolService.PublishBlast(player)
		return 0, "empty"
	end
	local look = flat(root.CFrame.LookVector)
	local d = flat(dir)
	if d.Magnitude < 1e-3 then
		return 0
	end
	d = d.Unit
	if look.Magnitude > 1e-3 and d:Dot(look.Unit) < math.cos(math.rad(75)) then
		d = look.Unit -- (the client's aim may turn it only so far from where you face)
	end
	s.LastBlast = now
	data.Tools.BlastUsed = used + 1
	s.BlastMag -= 1
	ToolService.PublishBlast(player)
	if data.Tools.BlastUsed >= B.Energy and not s.BlastWarned then
		s.BlastWarned = true
		notify(player, "🪫 The Leaf Blaster is out of energy — recharge it in SHOP · TOOLS")
	end
	if s.BlastMag <= 0 then
		startReload(player, s, B, now) -- (the sixth pulse: it reloads)
	else
		publishMag(player, s)
	end
	local origin = root.Position
	local tier = TC().HelperTier("Blaster", data.Tools.Up.Blaster)
	if ctx.Net.ToolFX then
		ctx.Net.ToolFX:FireAllClients("Blast", player.UserId, "Blaster", origin + d * 2.4, d, Vector3.new(B.Size, B.Range, tier))
	end
	-- v2.43: a FULLY upgraded blaster: its pulses BREAK blocks of ice in their way and the stone
	-- items of the garden are loose for a moment (ResourceService.CanPushHeavy: the client nudges them)
	if B.Maxed then
		local token = (s.HeavyToken or 0) + 1
		s.HeavyToken = token
		player:SetAttribute("BlowHeavy", true)
		task.delay(3, function()
			if s.HeavyToken == token and player.Parent then
				player:SetAttribute("BlowHeavy", nil)
			end
		end)
		local plot = ctx.PlotSystem.Get(player)
		local RS = ctx.ResourceService
		if plot and RS and RS.HitIce and RS.AliveIn then
			for part in RS.AliveIn(plot) do
				if RS.IsIced(part) then
					local off = flat(part.Position - origin)
					local along = off:Dot(d)
					if along > 0.3 and along <= B.Range + 1.5 and (off - d * along).Magnitude <= B.Size + 1.5 then
						task.delay(along / B.Speed, function()
							if part.Parent and RS.IsIced(part) then
								local broke = RS.HitIce(part, B.IceDamage)
								if ctx.MutationService then
									ctx.MutationService.FX(if broke then "IceMelt" else "IceDrip", part.Position, Color3.fromRGB(150, 210, 255))
								end
							end
						end)
					end
				end
			end
		end
	end
	-- the players the pulse reaches (each one when the pulse gets there)
	local n = 0
	for _, other in ctx.Players:GetPlayers() do
		local oroot = if other ~= player then rootOf(other) else nil
		local hum = oroot and other.Character and other.Character:FindFirstChildOfClass("Humanoid")
		if oroot and hum and hum.Health > 0 then
			local off = flat(oroot.Position - origin)
			local along = off:Dot(d)
			if along > 0.3 and along <= B.Range + 1.5 and (off - d * along).Magnitude <= B.Size + 2.4 and math.abs(oroot.Position.Y - origin.Y) < 7 then
				n += 1
				task.delay(along / B.Speed, function()
					-- (when the pulse arrives: is the player still in its way?)
					local r2 = other.Parent and rootOf(other)
					local h2 = r2 and other.Character and other.Character:FindFirstChildOfClass("Humanoid")
					if not r2 or not h2 or h2.Health <= 0 or (blastImmune[other] or 0) > ToolService.Now() then
						return
					end
					local center = origin + d * along
					local rel = flat(r2.Position - center)
					if rel.Magnitude > B.Size + 2.4 or math.abs(r2.Position.Y - origin.Y) >= 7 then
						return
					end
					local fall = 1 - along / (B.Range + 1.5) * 0.4
					local side = if rel.Magnitude > 0.2 then rel.Unit else d
					local push = (d * 0.85 + side * 0.15).Unit * B.PlayerPush * fall
					blastImmune[other] = ToolService.Now() + 0.25
					if ctx.SecurityService then
						ctx.SecurityService.Grace(other, 1.2)
					end
					if ctx.Net.Knockback then
						ctx.Net.Knockback:FireClient(other, Vector3.new(push.X, B.PlayerLift, push.Z), player.UserId)
					end
				end)
			end
		end
	end
	return n
end

function ToolService.RakeAt(player, pos)
	if ToolService.Held(player) ~= "Rake" or typeof(pos) ~= "Vector3" then
		return 0
	end
	local root = rootOf(player)
	local s = S(player)
	local now = ToolService.Now()
	if not root or flat(pos - root.Position).Magnitude > 14 or now - s.LastRake < 0.2 then
		return 0
	end
	s.LastRake = now
	-- (v2.40: the strip grows with the Tine Width upgrade)
	local data = ctx.PlayerDataService.Get(player)
	local radius = if TC().Rake and data then TC().Rake(data.Tools.Up.Rake).LoosenRadius * toolMult(player) else TC().Helpers.Rake.LoosenRadius
	return ctx.GrassService.Loosen(player, pos, radius)
end

-- the vacuum at `pos`: sucks up to its rate × time, pays like the zone
function ToolService.Vacuum(player, pos, now)
	local data = ctx.PlayerDataService.Get(player)
	local root = rootOf(player)
	if ToolService.Held(player) ~= "Vacuum" or not data or not root or typeof(pos) ~= "Vector3" then
		return 0
	end
	local vac = HB(player, TC().Vacuum(data.Tools.Up.Vacuum))
	if data.Tools.VacUsed >= vac.Capacity then
		return 0, "broken"
	end
	if flat(pos - root.Position).Magnitude > vac.Range + 8 then
		return 0
	end
	local s = S(player)
	now = now or ToolService.Now()
	local idle = now - s.LastVac > 1
	local dt = math.clamp(now - s.LastVac, 0, 0.3)
	s.LastVac = now
	s.VacBudget = math.min(s.VacBudget + vac.Rate * dt, math.max(vac.Rate, 1))
	if idle then
		s.VacBudget = math.max(s.VacBudget, 1) -- (switching it on grabs the first leaf at once)
	end
	local take = math.min(math.floor(s.VacBudget), vac.Capacity - data.Tools.VacUsed)
	if take <= 0 then
		return 0
	end
	-- candidates: your yard and your wild groves
	local RS = ctx.ResourceService
	local plot = ctx.PlotSystem.Get(player)
	local groups = {}
	if plot then
		table.insert(groups, plot)
	end
	local all = ctx.WildService and ctx.WildService.All and ctx.WildService.All()
	for _, field in (all and all[player]) or {} do
		table.insert(groups, field)
	end
	local cands = {}
	for _, g in groups do
		for part in RS.AliveIn(g) do
			local off = part.Position - pos
			local d = flat(off).Magnitude
			-- near the nozzle AND near you (the aim point can't stretch the reach)
			if d <= vac.Range and math.abs(off.Y) < 5 and flat(part.Position - root.Position).Magnitude <= vac.Range + 3 and not part:GetAttribute("Heavy") and not part:GetAttribute("Carried") then
				-- overgrown grass holds on to what's in it
				local blocked = RS.IsStuck(part) and g == plot and ctx.GrassService.LevelAt(player, part.Position) >= 4
				if not blocked then
					table.insert(cands, { part = part, d = d, g = g })
				end
			end
		end
	end
	if #cands == 0 then
		return 0
	end
	table.sort(cands, function(a, b)
		return a.d < b.d
	end)
	local byGroup = {}
	for i = 1, math.min(take, #cands) do
		local c = cands[i]
		byGroup[c.g] = byGroup[c.g] or {}
		table.insert(byGroup[c.g], c.part)
	end
	local got = 0
	for g, list in byGroup do
		for _, part in list do
			if RS.IsStuck(part) then
				RS.SetStuck(part, false)
			end
		end
		got += ctx.CollectionSystem.Credit(player, g, list, pos)
	end
	s.VacBudget -= got
	data.Tools.VacUsed += got
	data.Stats.VacuumItems = (data.Stats.VacuumItems or 0) + got
	player:SetAttribute("VacUsed", data.Tools.VacUsed)
	if data.Tools.VacUsed >= vac.Capacity then
		notify(player, "💥 Your vacuum is full and broke down — repair it in SHOP · TOOLS")
	end
	return got
end

---------------------------------------------------------------- v2.38 the vacuum's VORTEX
--[[
	{ A = "Vortex", Pos } — the strike key with the Vacuum in the hand. A whirlwind is
	planted at Pos (near you) for ToolConfig.Vortex(…).Time seconds:
	  • everybody sees it (ToolFX "Vortex", userId, "Vacuum", pos, Vector3(radius, time, tier))
	  • the items are the owner's physics, so the owner's client pulls them: the server
	    repeats WorldFX "Push" { Mode = "Swirl", Radius, Speed, Left } to that player
	    4-5 times a second while it turns
	  • at the end the server looks where the items REALLY are: everything of your yard /
	    your wild groves within Gulp studs of the centre is swallowed in one gulp through
	    the vacuum's normal path (CollectionSystem.Credit: value, combo, pets, quests) and
	    wears the vacuum by one per item — never more than the capacity that is left.
	    Heavy, carried and iced items and what overgrown grass holds stay, as always.
	Checked here: the Vacuum is in your hand (also at the gulp), it is not broken, the
	spot is near you, the cooldown runs on the server's clock (attribute "VortexReady"
	= server time it is ready again, "VortexCd" = its length, for the HUD).
]]
function ToolService.Vortex(player, pos)
	local data = ctx.PlayerDataService.Get(player)
	local root = rootOf(player)
	if ToolService.Held(player) ~= "Vacuum" or not data or not root or typeof(pos) ~= "Vector3" then
		return false
	end
	if pos.X ~= pos.X or pos.Y ~= pos.Y or pos.Z ~= pos.Z then
		return false
	end
	local s = S(player)
	local now = ToolService.Now()
	if s.Vortex then
		return false, "busy"
	end
	local vac = HB(player, TC().Vacuum(data.Tools.Up.Vacuum))
	if data.Tools.VacUsed >= vac.Capacity then
		if now - (s.VortexWarned or -1e9) > 3 then
			s.VortexWarned = now
			notify(player, "💥 Your vacuum is broken — repair it in SHOP · TOOLS or use a Vacuum Battery")
		end
		return false, "broken"
	end
	if not s.VortexReady and vortexReady[player.UserId] then
		s.VortexReady = vortexReady[player.UserId] -- (review: the cooldown outlives a rejoin)
	end
	if now < (s.VortexReady or -1e9) then
		if player:GetAttribute("VortexReady") == nil then
			-- (after a rejoin the client's gauge doesn't know about it yet)
			player:SetAttribute("VortexCd", HB(player, TC().Vortex(data.Tools.Up.Vacuum)).Cooldown)
			player:SetAttribute("VortexReady", serverTime() + (s.VortexReady - now))
		end
		return false, "cooldown"
	end
	local V = HB(player, TC().Vortex(data.Tools.Up.Vacuum))
	if flat(pos - root.Position).Magnitude > V.Cast + 4 or math.abs(pos.Y - root.Position.Y) > 30 then
		return false, "far"
	end
	s.VortexReady = now + V.Cooldown
	vortexReady[player.UserId] = s.VortexReady
	s.Vortex ={ Pos = pos, End = now + V.Time, V = V }
	player:SetAttribute("VortexCd", V.Cooldown)
	player:SetAttribute("VortexReady", serverTime() + V.Cooldown)
	-- leaves stuck in thick grass come loose so the whirl can move them (like the magnets)
	if ctx.GrassService and ctx.GrassService.Loosen then
		pcall(ctx.GrassService.Loosen, player, pos, V.Radius)
	end
	if ctx.Net.ToolFX then
		local tier = TC().HelperTier("Vacuum", data.Tools.Up.Vacuum)
		ctx.Net.ToolFX:FireAllClients("Vortex", player.UserId, "Vacuum", pos, Vector3.new(V.Radius, V.Time, tier))
	end
	ToolService.VortexStep(player)
	return true
end

-- ~5×/s while a vortex turns: keep the owner's client pulling; when its time is up — the gulp
function ToolService.VortexStep(player)
	local s = st[player]
	local v = s and s.Vortex
	if not v then
		return 0
	end
	local now = ToolService.Now()
	if now < v.End then
		if ctx.Net and ctx.Net.WorldFX then
			pcall(function()
				ctx.Net.WorldFX:FireClient(player, "Push", v.Pos, nil, { Radius = v.V.Radius, Mode = "Swirl", Speed = v.V.Speed, Left = v.End - now })
			end)
		end
		return 0
	end
	s.Vortex = nil
	local data = ctx.PlayerDataService.Get(player)
	local got = 0
	if data and ToolService.Held(player) == "Vacuum" then
		local vac = HB(player, TC().Vacuum(data.Tools.Up.Vacuum))
		local room = math.min(vac.Capacity - data.Tools.VacUsed, v.V.Max)
		if room > 0 then
			local RS = ctx.ResourceService
			local plot = ctx.PlotSystem.Get(player)
			local groups = {}
			if plot then
				table.insert(groups, plot)
			end
			local all = ctx.WildService and ctx.WildService.All and ctx.WildService.All()
			for _, field in (all and all[player]) or {} do
				table.insert(groups, field)
			end
			local cands = {}
			for _, g in groups do
				for part in RS.AliveIn(g) do
					local off = part.Position - v.Pos
					local d = flat(off).Magnitude
					if d <= v.V.Gulp and math.abs(off.Y) < 8 and not part:GetAttribute("Heavy") and not part:GetAttribute("Carried") and not RS.IsIced(part) then
						local blocked = RS.IsStuck(part) and g == plot and ctx.GrassService.LevelAt(player, part.Position) >= 4
						if not blocked then
							table.insert(cands, { part = part, d = d, g = g })
						end
					end
				end
			end
			table.sort(cands, function(a, b)
				return a.d < b.d
			end)
			local byGroup = {}
			for i = 1, math.min(room, #cands) do
				local c = cands[i]
				byGroup[c.g] = byGroup[c.g] or {}
				table.insert(byGroup[c.g], c.part)
			end
			for g, list in byGroup do
				for _, part in list do
					if RS.IsStuck(part) then
						RS.SetStuck(part, false)
					end
				end
				got += ctx.CollectionSystem.Credit(player, g, list, v.Pos)
			end
			if got > 0 then
				data.Tools.VacUsed += got
				data.Stats.VacuumItems = (data.Stats.VacuumItems or 0) + got
				player:SetAttribute("VacUsed", data.Tools.VacUsed)
				if data.Tools.VacUsed >= vac.Capacity then
					notify(player, "💥 Your vacuum is full and broke down — repair it in SHOP · TOOLS")
				end
			end
		end
	elseif data then
		notify(player, "🌪 The vortex faded — keep the Vacuum in your hands and it swallows the pile")
	end
	if ctx.Net and ctx.Net.ToolFX then
		ctx.Net.ToolFX:FireAllClients("VortexEnd", player.UserId, "Vacuum", v.Pos, Vector3.new(got, 0, 0))
	end
	return got
end

-- v1.7: while a Leaf Magnet / Mega Magnet works, every item that reaches YOU is
-- picked up at once — paid like at your Collect zone (combo included)
function ToolService.MagnetStep(player)
	local untilT = player:GetAttribute("MagnetUntil")
	if type(untilT) ~= "number" or serverTime() >= untilT then
		return 0
	end
	local root = rootOf(player)
	local kind = player:GetAttribute("MagnetKind")
	local def = TC().Consumables[kind] or TC().Consumables.LeafMagnet
	if not root then
		return 0
	end
	local RS = ctx.ResourceService
	local plot = ctx.PlotSystem.Get(player)
	local groups = {}
	if plot then
		table.insert(groups, plot)
	end
	local all = ctx.WildService and ctx.WildService.All and ctx.WildService.All()
	for _, field in (all and all[player]) or {} do
		table.insert(groups, field)
	end
	-- v1.10: leaves stuck in thick grass within the magnet's reach come loose, so the
	-- pull can move them (overgrown grass still holds them)
	if plot and ctx.GrassService and ctx.GrassService.Loosen then
		pcall(ctx.GrassService.Loosen, player, root.Position, def.Radius or 12)
	end
	local reach = def.Pickup
	if not reach then
		return 0 -- v2.43: the Leaf Magnet only PULLS; the Mega Magnet also collects what touches you
	end
	local got = 0
	for _, g in groups do
		local list = {}
		for part in RS.AliveIn(g) do
			local off = part.Position - root.Position
			if flat(off).Magnitude <= reach and math.abs(off.Y) < 5 and not part:GetAttribute("Carried") and not part:GetAttribute("Heavy") then
				local blocked = RS.IsStuck(part) and g == plot and ctx.GrassService and ctx.GrassService.LevelAt(player, part.Position) >= 4
				if not blocked then
					table.insert(list, part)
				end
			end
		end
		if #list > 0 then
			for _, part in list do
				if RS.IsStuck(part) then
					RS.SetStuck(part, false)
				end
			end
			got += ctx.CollectionSystem.Credit(player, g, list, root.Position)
		end
	end
	return got
end

---------------------------------------------------------------- mowers
local function mowersFolder()
	local root = ctx.WorldFolder
	local f = root and root:FindFirstChild("Mowers")
	if not f and root then
		f = Instance.new("Folder")
		f.Name = "Mowers"
		f.Parent = root
	end
	return f
end

-- v2.40 FENCES: while a player RIDES a mower their body is in the collision group
-- "Riders" (Config.Collision) — the tall invisible wall above the garden fences stops
-- riders (and items), but not a walking character. The character carries the attribute
-- LRRiding, so parts added to it meanwhile get the same group (the server's character
-- set-up reads it); a new character (respawn) always starts as a walker.
local function setRiding(player, on)
	local char = player.Character
	if not char then
		return
	end
	local C = ctx.Config.Collision
	local want = if on and C.Riders then C.Riders else C.Characters
	pcall(function()
		char:SetAttribute("LRRiding", if on then true else nil)
		for _, d in char:GetDescendants() do
			if d:IsA("BasePart") and d.CollisionGroup ~= want then
				d.CollisionGroup = want
			end
		end
	end)
end

function ToolService.Mount(player, id)
	local dataS = ctx.PlayerDataService.Get(player)
	local def = dataS and HB(player, TC().GrassStats(id, dataS.Tools.Up[id]))
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = rootOf(player)
	if not def or def.Kind ~= "Ride" or not hum or not root then
		return false
	end
	-- v2.8: you may ride the mower anywhere; it cuts grass only in your own garden
	ToolService.Dismount(player, true)
	local dataM = ctx.PlayerDataService.Get(player)
	local model, chassis = ctx.ToolModels.Build(id, "Vehicle", TC().HelperTier(id, dataM and dataM.Tools.Up[id]))
	local look = flat(root.CFrame.LookVector)
	look = if look.Magnitude > 1e-3 then look.Unit else Vector3.new(0, 0, -1)
	local groundY = root.Position.Y - hum.HipHeight - root.Size.Y / 2
	-- v2.12: the REAL ground under you (a jump or a step used to put the mower into
	-- the floor, and then it could not drive)
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	rp.FilterDescendantsInstances = { char, model, mowersFolder() }
	local hit = workspace:Raycast(root.Position, Vector3.new(0, -14, 0), rp)
	if hit then
		groundY = hit.Position.Y
	end
	local y = groundY + chassis.Size.Y / 2 + 0.05
	model:PivotTo(CFrame.lookAt(Vector3.new(root.Position.X, y, root.Position.Z), Vector3.new(root.Position.X, y, root.Position.Z) + look))
	-- nothing of the mower may be below the ground: lift the whole model so its lowest
	-- part is a little above it (it settles by itself)
	local lowest = math.huge
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			local cf = p.CFrame
			local h = math.abs(cf.RightVector.Y) * p.Size.X / 2 + math.abs(cf.UpVector.Y) * p.Size.Y / 2 + math.abs(cf.LookVector.Y) * p.Size.Z / 2
			lowest = math.min(lowest, p.Position.Y - h)
		end
	end
	if lowest < groundY + 0.25 then
		model:PivotTo(model:GetPivot() + Vector3.new(0, groundY + 0.25 - lowest, 0))
	end
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			if p ~= chassis then
				local w = Instance.new("WeldConstraint")
				w.Part0 = chassis
				w.Part1 = p
				w.Parent = p
				p.Massless = true
			end
			p.Anchored = false
		end
	end
	chassis.CollisionGroup = ctx.Config.Collision.Riders or ctx.Config.Collision.Characters -- (v2.40: the fences' invisible wall stops riders)
	-- v2.45: the chassis is only a carrier: it can no longer sink into / jam on the ground. The driver's
	-- client rides it over the surface with rays (MowerDrive) and stops it at walls / fences itself.
	chassis.CanCollide = false
	local att = Instance.new("Attachment")
	att.Parent = chassis
	local lv = Instance.new("LinearVelocity")
	lv.Name = "Drive"
	lv.Attachment0 = att
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	lv.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	lv.MaxAxesForce = Vector3.new(1e5, 1e5, 1e5) -- (v2.44: the driver's client also steers the height: it climbs)
	lv.VectorVelocity = Vector3.zero
	lv.Parent = chassis
	local av = Instance.new("AngularVelocity")
	av.Name = "Steer"
	av.Attachment0 = att
	av.RelativeTo = Enum.ActuatorRelativeTo.World
	av.MaxTorque = 0 -- (v2.44: the client turns it with the "Tilt" aligner below; this one is only the fallback)
	av.AngularVelocity = Vector3.zero
	av.Parent = chassis
	-- v2.44: the body follows the ground: the driver's client sets the aligner's CFrame every frame (yaw + the tilt of the slope)
	local tilt = Instance.new("AlignOrientation")
	tilt.Name = "Tilt"
	tilt.Mode = Enum.OrientationAlignmentMode.OneAttachment
	tilt.Attachment0 = att
	tilt.RigidityEnabled = false
	tilt.MaxTorque = 1e7
	tilt.MaxAngularVelocity = math.huge
	tilt.Responsiveness = 40
	tilt.CFrame = chassis.CFrame.Rotation
	tilt.Parent = chassis
	-- v2.12: exhaust smoke behind the mower (everyone sees it; the driver's client
	-- makes it thicker with speed)
	local exhaust = Instance.new("Attachment")
	exhaust.Name = "Exhaust"
	exhaust.Position = Vector3.new(0.6, chassis.Size.Y / 2 + 0.4, chassis.Size.Z / 2)
	exhaust.Parent = chassis
	local smoke = Instance.new("ParticleEmitter")
	smoke.Name = "Smoke"
	smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
	smoke.Color = ColorSequence.new(Color3.fromRGB(120, 120, 120), Color3.fromRGB(200, 200, 200))
	smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 1) })
	smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 2.4) })
	smoke.Lifetime = NumberRange.new(0.8, 1.5)
	smoke.Speed = NumberRange.new(1.5, 3)
	smoke.Acceleration = Vector3.new(0, 3, 0)
	smoke.SpreadAngle = Vector2.new(25, 25)
	smoke.Rate = 10
	smoke.Parent = exhaust
	local seat = model:FindFirstChild("Seat")
	model:SetAttribute("LeafMower", id)
	model:SetAttribute("OwnerUserId", player.UserId)
	model:SetAttribute("Speed", def.Speed)
	seat:SetAttribute("LeafMower", id)
	model.Name = "Mower_" .. player.UserId
	model.Parent = mowersFolder()
	pcall(function()
		chassis:SetNetworkOwner(player)
	end)
	local s = S(player)
	s.Mower, s.MowerId, s.MowerPos, s.MowerT = model, id, chassis.Position, ToolService.Now()
	setRiding(player, true) -- v2.40: on the mower the fences are a wall (Dismount takes it back)
	-- v2.45 safety net: the carrier does not collide, so the server checks every half second that it is not
	-- below the surface (it is lifted back) or out of the world (then you are put off)
	task.spawn(function()
		local C = ctx.Config.Collision
		local walls = { [C.PlotWall] = true, [C.RideWall or ""] = true, [C.ResWall] = true, [C.Ghost] = true }
		while st[player] and st[player].Mower == model and model.Parent do
			task.wait(0.5)
			local c = model.PrimaryPart
			if not c then
				break
			end
			local list: { Instance } = { model, mowersFolder() }
			if player.Character then
				table.insert(list, player.Character)
			end
			local p = RaycastParams.new()
			p.FilterType = Enum.RaycastFilterType.Exclude
			p.CollisionGroup = "Default" -- (the rider group no longer collides with the world: look as a normal part)
			p.RespectCanCollide = true
			for _, pl in ctx.Players:GetPlayers() do
				if pl.Character then
					table.insert(list, pl.Character)
				end
			end
			local hit
			for _ = 1, 6 do
				p.FilterDescendantsInstances = list
				hit = workspace:Raycast(c.Position + Vector3.new(0, 4, 0), Vector3.new(0, -120, 0), p)
				if hit and walls[hit.Instance.CollisionGroup] then
					table.insert(list, hit.Instance)
					hit = nil
				else
					break
				end
			end
			if hit and c.Position.Y < hit.Position.Y - 0.25 then
				model:PivotTo(model:GetPivot() + Vector3.new(0, hit.Position.Y + 0.4 - c.Position.Y, 0))
				c.AssemblyLinearVelocity = Vector3.zero
			elseif not hit and c.Position.Y < workspace.FallenPartsDestroyHeight + 50 then
				ToolService.Dismount(player)
				break
			end
		end
	end)
	seat.CanTouch = false -- (only the server seats you: nobody else can hop on)
	seat:Sit(hum)
	task.delay(0.6, function()
		-- couldn't sit (already seated, dying…)? no mower left behind
		if S(player).Mower == model and seat.Occupant ~= hum then
			ToolService.Dismount(player)
		end
	end)
	-- standing up (Space) = off the mower
	s.MowerConn = seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		if seat.Occupant == nil then
			task.defer(function()
				if S(player).Mower == model then
					ToolService.Dismount(player)
				end
			end)
		end
	end)
	return true
end

function ToolService.Dismount(player, keepTool)
	local s = st[player]
	if not s or not s.Mower then
		return
	end
	local m = s.Mower
	s.Mower = nil
	if s.MowerConn then
		s.MowerConn:Disconnect()
		s.MowerConn = nil
	end
	m:Destroy()
	setRiding(player, false) -- v2.40: on foot again — the fence can be jumped
	if not keepTool then
		local id = ToolService.Held(player)
		local def = id and TC().GrassTools[id]
		if def and def.Kind == "Ride" then
			local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if hum then
				hum:UnequipTools()
			end
		end
	end
end

-- 5×/s: mowers cut what is under them
function ToolService.MowStep(player, dt)
	local data = ctx.PlayerDataService.Get(player)
	local plot = ctx.PlotSystem.Get(player)
	local s = st[player]
	if not data or not plot or not s then
		return 0
	end
	local turbo = (player:GetAttribute("TurboUntil") or 0) > serverTime()
	local mult = if turbo then TC().Consumables.TurboFuel.SpeedMult else 1
	local deckCF, def, mowId
	if s.Mower and s.Mower.Parent and s.Mower.PrimaryPart then
		mowId = s.MowerId
		def = HB(player, TC().GrassStats(mowId, data.Tools.Up[mowId]))
		local deckM, speedM = ToolService.AbilityMult(player, mowId) -- (v2.43 Nitro)
		def = table.clone(def)
		def.Radius *= deckM
		mult *= speedM
		local chassis = s.Mower.PrimaryPart
		deckCF = chassis.CFrame * CFrame.new(0, 0, -0.3)
		-- (v2.43: no fuel = it doesn't move)
		local fuelLeft = ToolService.MeterState(data, mowId)
		s.Mower:SetAttribute("Speed", if fuelLeft and fuelLeft <= 0 then def.Speed * 0.25 else def.Speed * mult)
		if fuelLeft and fuelLeft <= 0 and ToolService.Now() - (s.FuelSaid or -1e9) > 6 then
			s.FuelSaid = ToolService.Now()
			notify(player, "⛽ Out of fuel — the tractor crawls. Fill the tank with Gasoline or in SHOP · TOOLS")
		end
		-- v2.8: riding outside your garden is fine — but nothing is cut there
		local lp = plot.CFrame:PointToObjectSpace(chassis.Position)
		if math.max(math.abs(lp.X), math.abs(lp.Z)) > plot.Size / 2 + 1 then
			s.MowerPos = nil
			return 0
		end
	else
		local id = ToolService.Held(player)
		def = id and HB(player, TC().GrassStats(id, data.Tools.Up[id]))
		if not def or def.Kind ~= "Push" then
			s.MowerPos = nil
			return 0
		end
		mowId = id
		local deckP = ToolService.AbilityMult(player, id) -- (v2.43 Overdrive)
		def = table.clone(def)
		def.Radius *= deckP
		local root = rootOf(player)
		if not root then
			return 0
		end
		deckCF = root.CFrame * TC().PushOffset * TC().PushDeck -- (v1.4: the mower rolls in front of you)
	end
	local pos = deckCF.Position
	local last = s.MowerPos
	s.MowerPos = pos
	if not last or dt <= 0 then
		return 0
	end
	local moved = flat(pos - last)
	-- (the anti-teleport limit: a mower on foot is limited by how fast a PLAYER can walk — sprint,
	-- pets, Overdrive — not by the 16 studs/s the stats list for it; a rider by the mower's own speed)
	local topSpeed = if def.Kind == "Push" then 24 * ToolService.WalkMult(player) else (def.Speed or 24)
	local maxSpeed = topSpeed * mult * 1.4 + 6
	if moved.Magnitude / dt > maxSpeed or moved.Magnitude < 0.05 then
		return 0 -- teleported (or standing still: nothing new under the deck)
	end
	-- v2.43: it burns fuel while it moves; the empty tank cuts nothing
	local fuelNow = ToolService.BurnFuel(player, mowId, dt)
	if fuelNow <= 0 then
		if ToolService.Now() - (s.FuelSaid or -1e9) > 6 then
			s.FuelSaid = ToolService.Now()
			notify(player, "⛽ Out of fuel — fill the tank with Gasoline or in SHOP · TOOLS")
		end
		return 0
	end
	local keys = ctx.GrassService.CellsIn(plot, pos, def.Radius)
	-- v2.8: no mown stripes are left on the lawn behind the mower
	return (ctx.GrassService.Cut(player, keys, def.Power))
end

---------------------------------------------------------------- remotes
function ToolService.Handle(player, req)
	if type(req) ~= "table" or type(req.Action) ~= "string" then
		return false, "Bad request"
	end
	local a = req.Action
	if a == "Buy" then
		return ToolService.Buy(player, req.Id)
	elseif a == "Equip" then
		return ToolService.Equip(player, req.Id)
	elseif a == "Upgrade" then
		return ToolService.Upgrade(player, req.Tool, req.Stat)
	elseif a == "Repair" then
		return ToolService.Repair(player)
	elseif a == "BuyItem" then
		return ToolService.BuyItem(player, req.Id, req.Count)
	elseif a == "Slot" then
		return ToolService.SetSlot(player, req.Id, req.On == true)
	elseif a == "Use" then
		return ToolService.Use(player, req.Id, req.Pos, req.Pet, req.Tool)
	elseif a == "RepairTool" then
		return ToolService.RepairTool(player, req.Id) -- v2.43
	elseif a == "Refuel" then
		return ToolService.Refuel(player, req.Id)
	elseif a == "Recharge" then
		return ToolService.Recharge(player) -- v2.32: the Leaf Blower's energy
	elseif a == "RechargeBlast" then
		return ToolService.RechargeBlast(player) -- v2.42: the Leaf Blaster's energy
	elseif a == "Hotbar" then
		return ToolService.SetHotbar(player, req.List)
	elseif a == "RepairPick" then
		return ToolService.PickRepair(player) -- v2.38: the pickaxe's durability
	end
	return false, "Unknown action"
end

function ToolService.Action(player, req)
	if type(req) ~= "table" then
		return
	end
	local a = req.A
	if a == "Cut" then
		ToolService.CutAt(player, req.Pos, req.Dir)
	elseif a == "Trim" then
		ToolService.Trim(player, req.Pos)
	elseif a == "Rake" then
		ToolService.RakeAt(player, req.Pos)
	elseif a == "Vac" then
		ToolService.Vacuum(player, req.Pos)
	elseif a == "Vortex" then
		ToolService.Vortex(player, req.Pos) -- v2.38: the vacuum's strike-key ability
	elseif a == "Whirl" then
		ToolService.Whirl(player) -- v2.40: the trimmer's strike-key ability
	elseif a == "Blow" then
		ToolService.BlowAt(player, req.Dir, req.Jet == true) -- v1.4 (v2.34: Jet = the gust carries the player)
	elseif a == "Ability" then
		ToolService.Ability(player, req.Pos) -- v2.43: the strike key of the grass tools
	elseif a == "Blast" then
		ToolService.BlastAt(player, req.Dir) -- v2.42: the Leaf Blaster's pulse
	elseif a == "Reload" then
		ToolService.BlastReload(player) -- v2.42
	elseif a == "Off" then
		ToolService.Dismount(player)
	elseif a == "Hold" then
		ToolService.HoldItem(player, req.K, req.Id) -- v2.37: what is in the hand (everybody sees it)
	elseif a == "Act" then
		ToolService.HandAct(player, req.K, req.Pos, req.S) -- v2.37: "I planted / placed / used it"
	end
end

function ToolService.OnLoaded(player)
	ToolService.Publish(player)
	ToolService.GiveTools(player)
end

function ToolService.Clear(player)
	ToolService.Dismount(player, true)
	st[player] = nil
end

function ToolService.Start()
	ctx.Net.ToolRequest.OnServerInvoke = function(player, req)
		return ToolService.Handle(player, req)
	end
	ctx.Net.ToolAction.OnServerEvent:Connect(function(player, req)
		ToolService.Action(player, req)
	end)
	local acc, batAcc = 0, 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		batAcc += dt
		if acc >= 0.2 then
			local step = acc
			acc = 0
			for _, player in ctx.Players:GetPlayers() do
				local s = st[player]
				if s and s.Vortex then
					-- v2.38: the vacuum's vortex turns / swallows its pile
					local okV, errV = pcall(ToolService.VortexStep, player)
					if not okV then
						s.Vortex = nil
						warn("[LeafRush] vortex: " .. tostring(errV))
					end
				end
				if player:GetAttribute("MagnetUntil") then
					local okM, errM = pcall(ToolService.MagnetStep, player)
					if not okM then
						warn("[LeafRush] magnet: " .. tostring(errM))
					end
				end
				if s and s.JetLast and ToolService.Now() - s.JetLast > 0.9 then
					-- v2.43: the JET stopped (button released / energy out / weapon put away): it recharges
					s.JetLast = nil
					local dataJ = ctx.PlayerDataService.Get(player)
					if dataJ then
						local cd = WB(player, HB(player, TC().Blower(dataJ.Tools.Up.Blower or {}))).JetCooldown
						s.JetReady = ToolService.Now() + cd
						player:SetAttribute("JetCd", cd)
						player:SetAttribute("JetReady", serverTime() + cd)
					end
				end
				if (s and s.Mower) or ToolService.Held(player) == "PushMower" then
					S(player)
					local ok, err = pcall(ToolService.MowStep, player, step)
					if not ok then
						warn("[LeafRush] mower: " .. tostring(err))
					end
				end
			end
		end
		if batAcc >= 1 then
			-- the trimmer recharges slowly while it isn't running
			local step = batAcc
			batAcc = 0
			local now = ToolService.Now()
			for _, player in ctx.Players:GetPlayers() do
				local data = ctx.PlayerDataService.Get(player)
				if data and data.Tools.Owned.Trimmer then
					local s = S(player)
					local max = TC().Trimmer(data.Tools.Up.Trimmer).Battery
					if now - s.LastTrim > 1 and data.Tools.Battery < max then
						data.Tools.Battery = math.min(max, data.Tools.Battery + TC().BatteryRecharge * step)
						ToolService.PublishBattery(player)
					end
				end
			end
		end
	end)
end

return ToolService
end)() end
SERVICE_MODULE = ms()
-- ---- mocks
local clock = 100
local delayed = {}
task = { delay = function(t, fn) table.insert(delayed, { at = clock + t, fn = fn }) end }
local function runDelayed()
	table.sort(delayed, function(a, b) return a.at < b.at end)
	for _, d in delayed do clock = math.max(clock, d.at); d.fn() end
	delayed = {}
end
local V = Vector3
local function mkPlayer(name, pos, look)
	local attrs = {}
	local root = { Position = pos, CFrame = { LookVector = look or V.new(0, 0, -1) }, Name = "HumanoidRootPart" }
	local tool = { Name = "t", IsA = function(_, c) return c == "Tool" end, GetAttribute = function(_, k) if k == "LeafTool" then return "Blaster" end end }
	local hum = { Health = 100 }
	local char = {
		FindFirstChild = function(_, n) if n == "HumanoidRootPart" then return root end end,
		FindFirstChildOfClass = function(_, c) if c == "Humanoid" then return hum end end,
		GetChildren = function() return { tool } end,
	}
	local pl = { Name = name, Character = char, Parent = true, UserId = #name }
	function pl:SetAttribute(k, v) attrs[k] = v end
	function pl:GetAttribute(k) return attrs[k] end
	pl.attrs = attrs
	return pl
end
local TCm = TC_MODULE
local shooter = mkPlayer("shooter", V.new(0, 0, 0))
local ahead = mkPlayer("ahead_", V.new(0, 0, -15))      -- in the line of fire
local aside = mkPlayer("aside", V.new(14, 0, -15))      -- far to the side
local behind = mkPlayer("behindd", V.new(0, 0, 10))     -- behind the shooter
local far = mkPlayer("far", V.new(0, 0, -60))           -- beyond the range
local players = { shooter, ahead, aside, behind, far }
local data = { Tools = { Owned = { Blaster = true }, Up = { Blaster = {} }, BlastUsed = 0 } }
local fx, knock, notes = {}, {}, {}
local ctx = {
	ToolConfig = TCm,
	PlayerDataService = { Get = function(p) return if p == shooter then data else nil end },
	Players = { GetPlayers = function() return players end },
	Net = {
		ToolFX = { FireAllClients = function(_, ...) table.insert(fx, { ... }) end },
		Knockback = { FireClient = function(_, who, dv, from) table.insert(knock, { who = who.Name, dv = dv, from = from }) end },
		Notify = { FireClient = function(_, p, t) table.insert(notes, t) end },
	},
	SecurityService = { Grace = function() end },
}
local S = SERVICE_MODULE
S.Now = function() return clock end
S.Init(ctx)
local function show(label) print(label, "mag=" .. tostring(shooter.attrs.BlastMag), "reloadAt=" .. tostring(shooter.attrs.BlastReloadAt), "left=" .. tostring(shooter.attrs.BlastLeft) .. "/" .. tostring(shooter.attrs.BlastMax), "seq=" .. tostring(shooter.attrs.BlastSeq)) end
local dir = V.new(0, 0, -1)
-- 6 shots 0.6 s apart, then the 7th during the reload
for i = 1, 7 do
	local n, why = S.BlastAt(shooter, dir)
	show(("shot %d -> pushed %s %s"):format(i, tostring(n), tostring(why)))
	clock += 0.6
end
runDelayed()
print("knockbacks after 7 shots (only the 6 real ones count):", #knock)
local names = {}
for _, k in knock do names[k.who] = (names[k.who] or 0) + 1 end
for n, c in names do print("  ", n, c) end
print("  sample dv:", knock[1].dv.X, knock[1].dv.Y, knock[1].dv.Z)
print("FX packets:", #fx, "first kind:", fx[1][1], "size/range/tier:", fx[1][6].X, fx[1][6].Y, fx[1][6].Z)
-- reload completes by the clock
clock += 3
local n = S.BlastAt(shooter, dir); show("after reload, shot -> " .. tostring(n))
-- too fast
local n2, why2 = S.BlastAt(shooter, dir); print("immediately again ->", n2, why2)
-- manual reload
clock += 1
print("manual reload ok?", S.BlastReload(shooter)); show("manual reload")
print("manual reload again (already reloading):", S.BlastReload(shooter))
-- energy
clock += 5
data.Tools.BlastUsed = 59
S.PublishBlast(shooter, true)
print("energy 59 used -> shot:", S.BlastAt(shooter, dir)); show("last pulse of energy")
clock += 5
print("empty ->", S.BlastAt(shooter, dir)); print("notes:", table.concat(notes, " | "))
-- recharge cost (no money system here)
print("recharge cost:", S.RechargeBlastCost(data))
-- bad inputs
data.Tools.BlastUsed = 0; clock += 5; S.PublishBlast(shooter, true)
print("nan dir:", S.BlastAt(shooter, V.new(0/0, 0, 0)), " zero dir:", S.BlastAt(shooter, V.new(0, 5, 0)), " string:", S.BlastAt(shooter, "x"))

-- ---------- a fully upgraded blaster breaks ice in the line of its pulse (3 hit points: 3 pulses)
data.Tools.Up.Blaster = { Power = 5, Rate = 5, Size = 5, Energy = 5 }
data.Tools.BlastUsed = 0
local ice = { Position = V.new(0, 0, -12), Parent = true, hp = 3 }
local off = { Position = V.new(20, 0, -12), Parent = true, hp = 3 }
ctx.PlotSystem = { Get = function() return {} end }
ctx.ResourceService = {
	AliveIn = function() local set = { [ice] = true, [off] = true } return next, set end,
	IsIced = function(part) return part.hp > 0 end,
	HitIce = function(part, dmg) part.hp -= dmg; return part.hp <= 0 end,
}
shooter.attrs.BlastReloadAt = nil
local bursts = 0
local heavyDuring
for i = 1, 3 do clock += 5; S.BlastAt(shooter, dir); heavyDuring = shooter.attrs.BlowHeavy; runDelayed() end
print((ice.hp <= 0 and "PASS" or "FAIL") .. " maxed blaster broke the ice block in 3 pulses (hp " .. ice.hp .. ")")
print((off.hp == 3 and "PASS" or "FAIL") .. " ice out of the line is untouched")
print((heavyDuring == true and "PASS" or "FAIL") .. " stones are loose while it fires")
data.Tools.Up.Blaster = { Power = 5, Rate = 5, Size = 5, Energy = 4 }
ice.hp = 3
clock += 5; S.BlastAt(shooter, dir); runDelayed()
print((ice.hp == 3 and "PASS" or "FAIL") .. " a blaster that is not fully upgraded leaves the ice alone")
