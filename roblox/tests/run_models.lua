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
-- a tiny fake DOM: enough for ToolModels to build every look
local Any = {}
setmetatable(Any, { __index = function() return Any end, __call = function() return Any end, __newindex = function() end,
	__mul = function() return Any end, __add = function() return Any end, __sub = function() return Any end, __div = function() return Any end, __unm = function() return Any end })
Enum, Color3, NumberRange, ColorSequence, NumberSequence, NumberSequenceKeypoint, Vector2, UDim2, PhysicalProperties = Any, Any, Any, Any, Any, Any, Any, Any, Any
local count = 0
local Obj = {}
Obj.__index = Obj
function Obj:GetChildren() return self._kids end
function Obj:GetDescendants() local out = {} local function walk(o) for _, c in o._kids do table.insert(out, c); walk(c) end end walk(self) return out end
function Obj:FindFirstChild(n) for _, c in self._kids do if c.Name == n then return c end end end
function Obj:IsA() return true end
function Obj:SetAttribute(k, v) self._attrs[k] = v end
function Obj:GetAttribute(k) return self._attrs[k] end
function Obj:Destroy() end
Instance = { new = function(class)
	count += 1
	local o = setmetatable({ ClassName = class, _kids = {}, _attrs = {}, Name = class, Size = Vector3.new(1, 1, 1), Transparency = 0, Material = Any, Color = Any }, Obj)
	return setmetatable(o, { __index = Obj, __newindex = function(t, k, v)
		rawset(t, k, v)
		if k == "Parent" and type(v) == "table" and v._kids then table.insert(v._kids, t) end
	end })
end }
CFrame = setmetatable({ fromMatrix = function() return Any end, new = function() return Any end, Angles = function() return Any end, lookAt = function() return Any end }, { __index = Any })
local function mm() return (function()
--[[
	Leaf Rush · ToolModels (shared, v1.2) — how every tool besides the broom looks

	Build(id, kind?, tier?) -> model, handle   (v1.7 tier: blower / vacuum upgrade look)
	  id    a ToolConfig id (Shears, Scythe, Trimmer, PushMower, Blower, Vacuum,
	        LeafMagnet …) — the Rake is drawn by BroomModel ("Rake")
	  kind  nil / "Tool": the hand-held version, built in HAND SPACE: the origin is
	        the grip (where the hand holds it), −Z points forward, +Y up — so a Tool
	        uses it with Grip = identity. "Vehicle": the full-size riding mower you
	        sit on (a VehicleSeat named "Seat", the body "Body" is the PrimaryPart).
	The same models are used for the hotbar / shop icons (ViewportFrames) and for the
	Tools in your hand, so what you buy is exactly what you hold.
]]

local ToolModels = {}

local M = Enum.Material

local function newModel(name)
	local m = Instance.new("Model")
	m.Name = name
	return m
end

local function add(model, class, props, cf)
	local p = Instance.new(class)
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		(p :: any)[k] = v
	end
	-- v2.18 TOY BRICKS EVERYWHERE: plastic with studs on every side (things that glow
	-- or are see-through keep their own material)
	do
		local mat = p.Material
		if mat ~= Enum.Material.Neon and mat ~= Enum.Material.Glass and mat ~= Enum.Material.ForceField and p.Transparency < 0.5 then
			p.Material = Enum.Material.Plastic
			p.TopSurface, p.BottomSurface = Enum.SurfaceType.Studs, Enum.SurfaceType.Studs
			p.FrontSurface, p.BackSurface = Enum.SurfaceType.Studs, Enum.SurfaceType.Studs
			p.LeftSurface, p.RightSurface = Enum.SurfaceType.Studs, Enum.SurfaceType.Studs
		end
	end
	p.CFrame = cf
	p.Parent = model
	return p
end

-- a cylinder (axis = X) from a to b
local function rod(model, a, b, d, color, mat, name)
	local dir = b - a
	local len = dir.Magnitude
	local u = dir / len
	local ref = if math.abs(u.Y) < 0.95 then Vector3.yAxis else Vector3.xAxis
	local v = ref:Cross(u).Unit
	local cf = CFrame.fromMatrix((a + b) / 2, u, v)
	return add(model, "Part", { Name = name or "Rod", Shape = Enum.PartType.Cylinder, Size = Vector3.new(len, d, d), Color = color, Material = mat or M.SmoothPlastic }, cf)
end

local function handlePart(model)
	return add(model, "Part", { Name = "Handle", Size = Vector3.new(0.25, 0.25, 0.25), Transparency = 1 }, CFrame.new())
end

local CHROME_ = Color3.fromRGB(225, 230, 240)
local WOOD = Color3.fromRGB(150, 104, 62)
local STEEL = Color3.fromRGB(190, 195, 205)
local DARK = Color3.fromRGB(45, 45, 52)

---------------------------------------------------------------- grass tools
local builders = {}

builders.Shears = function(m)
	local h = handlePart(m)
	-- two red handle loops and two steel blades pointing forward
	for s = -1, 1, 2 do
		rod(m, Vector3.new(0.18 * s, 0, 0.35), Vector3.new(0.1 * s, 0, -0.35), 0.18, Color3.fromRGB(215, 50, 45), M.SmoothPlastic, "Grip")
		add(m, "WedgePart", { Name = "Blade", Size = Vector3.new(0.06, 0.22, 1.5), Color = STEEL, Material = M.Metal }, CFrame.new(0.05 * s, 0, -1.1) * CFrame.Angles(0, math.rad(4 * s), if s > 0 then 0 else math.pi))
	end
	add(m, "Part", { Name = "Pivot", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 0.2, 0.2), Color = DARK, Material = M.Metal }, CFrame.new(0, 0, -0.38))
	return h
end

builders.WeedCutter = function(m)
	local h = handlePart(m)
	rod(m, Vector3.new(0, 0, 0.3), Vector3.new(0, -0.6, -2.4), 0.2, WOOD, M.Wood, "Shaft")
	rod(m, Vector3.new(0, 0.05, 0.35), Vector3.new(0, -0.02, 0.05), 0.26, Color3.fromRGB(60, 120, 60), M.Fabric, "Grip")
	-- a serrated, slightly curved blade at the end
	for k = 0, 4 do
		local z = -2.35 - k * 0.22
		add(m, "WedgePart", { Name = "Tooth", Size = Vector3.new(0.05, 0.28, 0.26), Color = STEEL, Material = M.Metal }, CFrame.new(0.25 * math.sin(k * 0.35), -0.65 - k * 0.03, z) * CFrame.Angles(0, 0, math.pi / 2))
	end
	add(m, "Part", { Name = "Blade", Size = Vector3.new(0.05, 0.16, 1.2), Color = STEEL, Material = M.Metal }, CFrame.new(0.12, -0.72, -2.8))
	return h
end

local function scythe(m, golden)
	local h = handlePart(m)
	local wood = if golden then Color3.fromRGB(240, 190, 60) else WOOD
	local mat = if golden then M.Foil else M.Wood
	-- the long snath runs down and forward; a small side grip at the hand
	rod(m, Vector3.new(0, 1.3, 0.8), Vector3.new(0, -2.1, -1.7), 0.22, wood, mat, "Snath")
	rod(m, Vector3.new(0, 0, 0), Vector3.new(0.55, 0.05, -0.1), 0.18, wood, mat, "SideGrip")
	-- a curved blade: segments along an arc at the bottom, sideways
	local base = Vector3.new(0, -2.05, -1.65)
	local prev = base
	for k = 1, 7 do
		local a = k / 7 * math.rad(95)
		local p = base + Vector3.new(-math.sin(a) * 2.6, -0.05, -(1 - math.cos(a)) * 1.2)
		local blade = rod(m, prev, p, 0.12 - k * 0.008, if golden then Color3.fromRGB(255, 225, 110) else STEEL, if golden then M.Neon else M.Metal, "Blade")
		blade.Size = Vector3.new(blade.Size.X, 0.08, 0.34)
		blade.Shape = Enum.PartType.Block
		prev = p
	end
	if golden then
		local s = Instance.new("Sparkles")
		s.SparkleColor = Color3.fromRGB(255, 220, 90)
		s.Parent = m:FindFirstChild("Blade")
	end
	return h
end
builders.Scythe = function(m)
	return scythe(m, false)
end
builders.GoldenScythe = function(m)
	return scythe(m, true)
end

-- v2.41: the Lawn Trimmer changes its look with its upgrade tier (1…4,
-- ToolConfig.HelperTier): the same shape and the same grip (so the hold pose and the
-- WHIRL fit as before) — colours here, the extra parts in tierDecor.Trimmer below
local TRIM_BODY = { Color3.fromRGB(245, 120, 30), Color3.fromRGB(50, 170, 80), Color3.fromRGB(95, 80, 235), Color3.fromRGB(35, 30, 45) }
local TRIM_LINE = { Color3.fromRGB(120, 230, 90), Color3.fromRGB(170, 255, 110), Color3.fromRGB(110, 220, 255), Color3.fromRGB(255, 215, 90) }
local TRIM_SHAFT = { STEEL, CHROME_, Color3.fromRGB(44, 50, 70), Color3.fromRGB(255, 205, 70) }

builders.Trimmer = function(m, _vehicle, tier)
	tier = math.clamp(math.floor(tonumber(tier) or 1), 1, 4)
	local h = handlePart(m)
	local ORANGE = TRIM_BODY[tier] or TRIM_BODY[1]
	rod(m, Vector3.new(0, 0.5, 1.1), Vector3.new(0, -2.3, -2.6), 0.16, TRIM_SHAFT[tier] or STEEL, M.Metal, "Shaft").Reflectance = if tier >= 4 then 0.3 elseif tier >= 2 then 0.15 else 0
	add(m, "Part", { Name = "Motor", Size = Vector3.new(0.55, 0.55, 0.9), Color = ORANGE, Material = M.SmoothPlastic, Reflectance = if tier >= 4 then 0.2 else 0 }, CFrame.new(0, 0.55, 1.15) * CFrame.Angles(math.rad(-37), 0, 0))
	add(m, "Part", { Name = "Battery", Size = Vector3.new(0.45, 0.35, 0.5), Color = DARK, Material = M.SmoothPlastic }, CFrame.new(0, 0.9, 1.45) * CFrame.Angles(math.rad(-37), 0, 0))
	rod(m, Vector3.new(-0.45, 0.05, -0.3), Vector3.new(0.45, 0.05, -0.3), 0.14, DARK, M.SmoothPlastic, "Bar")
	add(m, "Part", { Name = "Guard", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.12, 1.3, 1.3), Color = ORANGE, Material = M.SmoothPlastic }, CFrame.new(0, -2.25, -2.75) * CFrame.Angles(0, 0, math.pi / 2))
	add(m, "Part", { Name = "Head", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.22, 0.5, 0.5), Color = DARK, Material = M.Metal }, CFrame.new(0, -2.4, -2.7) * CFrame.Angles(0, 0, math.pi / 2))
	for s = -1, 1, 2 do
		add(m, "Part", { Name = "Line", Size = Vector3.new(1.1, 0.03, 0.03), Color = TRIM_LINE[tier] or TRIM_LINE[1], Material = M.Neon }, CFrame.new(s * 0.4, -2.45, -2.7))
	end
	return h
end

local function wheel(m, pos, r, w, color)
	return add(m, "Part", { Name = "Wheel", Shape = Enum.PartType.Cylinder, Size = Vector3.new(w, r * 2, r * 2), Color = color or DARK, Material = M.SmoothPlastic }, CFrame.new(pos))
end

builders.PushMower = function(m)
	local h = handlePart(m)
	local RED = Color3.fromRGB(200, 40, 40)
	local deckC = Vector3.new(0, -2.55, -2.9)
	add(m, "Part", { Name = "Deck", Size = Vector3.new(2.4, 0.5, 2.4), Color = RED, Material = M.SmoothPlastic }, CFrame.new(deckC))
	add(m, "Part", { Name = "Engine", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.8, 1.1, 1.1), Color = DARK, Material = M.Metal }, CFrame.new(deckC + Vector3.new(0, 0.6, 0)) * CFrame.Angles(0, 0, math.pi / 2))
	add(m, "Part", { Name = "Cap", Size = Vector3.new(0.5, 0.2, 0.5), Color = Color3.fromRGB(240, 200, 40), Material = M.SmoothPlastic }, CFrame.new(deckC + Vector3.new(0.2, 1.05, 0.1)))
	for _, sx in { -1.25, 1.25 } do
		for _, sz in { -0.9, 0.9 } do
			wheel(m, deckC + Vector3.new(sx, -0.25, sz), 0.4, 0.28)
		end
		rod(m, Vector3.new(sx * 0.3, 0, 0), deckC + Vector3.new(sx * 0.9, 0.25, 1.1), 0.12, STEEL, M.Metal, "HandleBar")
	end
	rod(m, Vector3.new(-0.45, 0, 0), Vector3.new(0.45, 0, 0), 0.16, DARK, M.SmoothPlastic, "Bar")
	add(m, "Part", { Name = "Bag", Size = Vector3.new(1.3, 0.9, 1), Color = Color3.fromRGB(60, 110, 60), Material = M.Fabric }, CFrame.new(deckC + Vector3.new(0, 0.2, 1.6)))
	return h
end

-- the riding mowers: a small tractor. Vehicle = full size with a VehicleSeat
local function rider(m, turbo, vehicle)
	local s = if vehicle then 1 else 0.55
	local BODY = if turbo then Color3.fromRGB(30, 30, 36) else Color3.fromRGB(60, 150, 60)
	local TRIM = if turbo then Color3.fromRGB(255, 60, 90) else Color3.fromRGB(245, 210, 50)
	add(m, "Part", { Name = "Body", Size = Vector3.new(3 * s, 0.9 * s, 5 * s), Color = BODY, Material = if turbo then M.Glass else M.SmoothPlastic }, CFrame.new(0, 1.3 * s, 0))
	add(m, "Part", { Name = "Hood", Size = Vector3.new(2.6 * s, 0.9 * s, 1.9 * s), Color = BODY, Material = M.SmoothPlastic }, CFrame.new(0, 2.1 * s, -1.4 * s))
	add(m, "Part", { Name = "Stripe", Size = Vector3.new(0.5 * s, 0.05 * s, 1.95 * s), Color = TRIM, Material = if turbo then M.Neon else M.SmoothPlastic }, CFrame.new(0, 2.58 * s, -1.4 * s))
	add(m, "Part", { Name = "Deck", Size = Vector3.new(3.8 * s, 0.35 * s, 2.2 * s), Color = TRIM, Material = M.Metal }, CFrame.new(0, 0.55 * s, -0.2 * s))
	for _, sx in { -1, 1 } do
		wheel(m, Vector3.new(sx * 1.55 * s, 0.6 * s, -1.6 * s), 0.6 * s, 0.5 * s)
		wheel(m, Vector3.new(sx * 1.6 * s, 0.9 * s, 1.5 * s), 0.9 * s, 0.7 * s)
	end
	rod(m, Vector3.new(0, 2.1 * s, 0.2 * s), Vector3.new(0, 2.9 * s, -0.25 * s), 0.12 * s, DARK, M.Metal, "Column")
	add(m, "Part", { Name = "SteeringWheel", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.1 * s, 1 * s, 1 * s), Color = DARK, Material = M.SmoothPlastic }, CFrame.new(0, 2.95 * s, -0.3 * s) * CFrame.Angles(0, math.rad(90), math.rad(55)))
	if turbo then
		for _, sx in { -0.5, 0.5 } do
			rod(m, Vector3.new(sx * s, 1.9 * s, 2.4 * s), Vector3.new(sx * s, 2.8 * s, 2.7 * s), 0.3 * s, STEEL, M.Metal, "Exhaust")
		end
		add(m, "Part", { Name = "Spoiler", Size = Vector3.new(3 * s, 0.12 * s, 0.7 * s), Color = TRIM, Material = M.Neon }, CFrame.new(0, 3.1 * s, 2.5 * s))
	end
	local seatCF = CFrame.new(0, 2.05 * s, 1.1 * s)
	if vehicle then
		local seat = add(m, "VehicleSeat", { Name = "Seat", Size = Vector3.new(1.6, 0.4, 1.4), Color = DARK, Material = M.Fabric, MaxSpeed = 0, Torque = 0, TurnSpeed = 0, HeadsUpDisplay = false }, seatCF)
		seat.CanTouch = false
		add(m, "Part", { Name = "SeatBack", Size = Vector3.new(1.6, 1.3, 0.3), Color = DARK, Material = M.Fabric }, CFrame.new(0, 2.8, 1.85))
		-- the one colliding part: a flat invisible chassis at wheel-bottom height
		local chassis = add(m, "Part", { Name = "Chassis", Size = Vector3.new(3, 0.3, 4.4), Transparency = 1, CanCollide = true, CanQuery = false }, CFrame.new(0, 0.15, 0))
		chassis.CustomPhysicalProperties = PhysicalProperties.new(2, 0.2, 0, 1, 1)
		m.PrimaryPart = chassis
		return chassis
	end
	add(m, "Part", { Name = "SeatTop", Size = Vector3.new(1.6 * s, 0.4 * s, 1.4 * s), Color = DARK, Material = M.Fabric }, seatCF)
	local h = handlePart(m)
	return h
end
builders.RidingMower = function(m, vehicle)
	return rider(m, false, vehicle)
end
builders.TurboMower = function(m, vehicle)
	return rider(m, true, vehicle)
end

---------------------------------------------------------------- helpers
-- v1.7: the blower and the vacuum change their look with their upgrade tier (1…4,
-- ToolConfig.HelperTier): colours first, then extra parts (see tierDecor below)
local BLOWER_BODY = { Color3.fromRGB(250, 190, 40), Color3.fromRGB(235, 105, 40), Color3.fromRGB(55, 135, 235), Color3.fromRGB(255, 205, 70) }
local VAC_BODY = { Color3.fromRGB(140, 80, 220), Color3.fromRGB(35, 175, 165), Color3.fromRGB(215, 50, 75), Color3.fromRGB(35, 30, 45) }

builders.Blower = function(m, _vehicle, tier)
	tier = tier or 1
	local h = handlePart(m)
	local YEL = BLOWER_BODY[tier] or BLOWER_BODY[1]
	add(m, "Part", { Name = "Body", Size = Vector3.new(0.8, 0.9, 1.3), Color = YEL, Material = if tier >= 4 then M.Metal else M.SmoothPlastic, Reflectance = if tier >= 4 then 0.25 else 0 }, CFrame.new(0.15, -0.35, 0.2))
	add(m, "Part", { Name = "Intake", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, 0.8, 0.8), Color = DARK, Material = M.Metal }, CFrame.new(0.6, -0.35, 0.3))
	rod(m, Vector3.new(0.15, -0.45, -0.3), Vector3.new(0.15, -1, -2.6), 0.42, YEL, if tier >= 4 then M.Metal else M.SmoothPlastic, "Tube")
	rod(m, Vector3.new(0.15, -0.97, -2.5), Vector3.new(0.15, -1.1, -3.1), 0.5 + (tier - 1) * 0.05, if tier >= 2 then CHROME_ else DARK, if tier >= 2 then M.Metal else M.SmoothPlastic, "Nozzle")
	add(m, "Part", { Name = "Nose", Size = Vector3.new(0.2, 0.2, 0.2), Transparency = 1 }, CFrame.new(0.15, -1.12, -3.2))
	-- v2.43: the ENERGY gauge on the side of the body: five segments, lit from the bottom
	add(m, "Part", { Name = "GaugeBack", Size = Vector3.new(0.05, 0.78, 0.2), Color = DARK, Material = M.Metal }, CFrame.new(-0.26, -0.35, 0.55))
	for k = 1, 5 do
		add(m, "Part", { Name = "Seg" .. k, Size = Vector3.new(0.07, 0.11, 0.14), Color = Color3.fromRGB(110, 230, 100), Material = M.Neon }, CFrame.new(-0.28, -0.69 + (k - 1) * 0.15, 0.55))
	end
	return h
end

builders.Vacuum = function(m, _vehicle, tier)
	tier = tier or 1
	local h = handlePart(m)
	local PURPLE = VAC_BODY[tier] or VAC_BODY[1]
	add(m, "Part", { Name = "Canister", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.3, 1.1, 1.1), Color = PURPLE, Material = if tier >= 4 then M.Metal else M.SmoothPlastic, Reflectance = if tier >= 4 then 0.2 else 0 }, CFrame.new(0.3, -0.25, 0.45) * CFrame.Angles(0, math.rad(90), 0))
	add(m, "Part", { Name = "Window", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.9, 0.8, 0.8), Color = Color3.fromRGB(180, 230, 255), Material = M.Glass, Transparency = 0.4 }, CFrame.new(0.3, 0.05, 0.45) * CFrame.Angles(0, math.rad(90), 0))
	rod(m, Vector3.new(0.3, -0.3, -0.2), Vector3.new(0.3, -1.6, -2.6), 0.3, Color3.fromRGB(70, 70, 80), M.SmoothPlastic, "Tube")
	add(m, "Part", { Name = "Nozzle", Size = Vector3.new(1.2, 0.2, 0.5), Color = PURPLE, Material = M.SmoothPlastic }, CFrame.new(0.3, -1.68, -2.7))
	add(m, "Part", { Name = "Nose", Size = Vector3.new(0.2, 0.2, 0.2), Transparency = 1 }, CFrame.new(0.3, -1.7, -2.8))
	add(m, "Part", { Name = "Light", Size = Vector3.new(0.2, 0.2, 0.2), Color = Color3.fromRGB(120, 255, 170), Material = M.Neon }, CFrame.new(0.3, 0.45, 0.45))
	return h
end

-- v2.42 the LEAF BLASTER: a chunky toy air cannon. A body with a wide chrome barrel ("Nose" =
-- the muzzle, where every pulse starts), a glowing air core on top and a drum on its right side
-- with SIX pips ("Pip1" … "Pip6"): the client lights one for every pulse left in the magazine.
-- Tiers 1…4 (ToolConfig.HelperTier): colours first, then extra parts (tierDecor.Blaster).
local BLASTER_BODY = { Color3.fromRGB(70, 190, 140), Color3.fromRGB(255, 150, 70), Color3.fromRGB(90, 150, 255), Color3.fromRGB(255, 215, 90) }
local BLASTER_GLOW = { Color3.fromRGB(190, 240, 255), Color3.fromRGB(255, 200, 120), Color3.fromRGB(130, 210, 255), Color3.fromRGB(150, 255, 235) }
ToolModels.BlasterGlow = BLASTER_GLOW -- (the controller lights the pips / tints the pulse with it)

builders.Blaster = function(m, _vehicle, tier)
	tier = tier or 1
	local h = handlePart(m)
	local BODY = BLASTER_BODY[tier] or BLASTER_BODY[1]
	local GLOW = BLASTER_GLOW[tier] or BLASTER_GLOW[1]
	local metal = tier >= 4
	-- grip and trigger
	add(m, "Part", { Name = "GripBlock", Size = Vector3.new(0.34, 0.85, 0.42), Color = DARK, Material = M.SmoothPlastic }, CFrame.new(0, -0.2, 0.15) * CFrame.Angles(math.rad(-14), 0, 0))
	add(m, "Part", { Name = "Trigger", Size = Vector3.new(0.1, 0.3, 0.1), Color = Color3.fromRGB(215, 60, 50), Material = M.SmoothPlastic }, CFrame.new(0, 0.05, -0.2))
	-- body, sight and the air core (glowing ball on top)
	add(m, "Part", { Name = "Body", Size = Vector3.new(0.66, 0.62, 1.8), Color = BODY, Material = if metal then M.Metal else M.SmoothPlastic, Reflectance = if metal then 0.25 else 0 }, CFrame.new(0, 0.38, -0.5))
	add(m, "Part", { Name = "Sight", Size = Vector3.new(0.14, 0.2, 0.55), Color = DARK, Material = M.SmoothPlastic }, CFrame.new(0, 0.79, -0.85))
	add(m, "Part", { Name = "Core", Shape = Enum.PartType.Ball, Size = Vector3.new(0.5, 0.5, 0.5), Color = GLOW, Material = M.Neon, Transparency = 0.2 }, CFrame.new(0, 0.62, 0.05))
	-- the barrel: a wide chrome tube with a dark muzzle ring and a glowing disc
	rod(m, Vector3.new(0, 0.38, -1.35), Vector3.new(0, 0.38, -2.55), 0.56, CHROME_, M.Metal, "Barrel")
	rod(m, Vector3.new(0, 0.38, -2.5), Vector3.new(0, 0.38, -2.72), 0.74, DARK, M.Metal, "Muzzle")
	add(m, "Part", { Name = "MuzzleGlow", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.06, 0.5, 0.5), Color = GLOW, Material = M.Neon, Transparency = 0.15 }, CFrame.new(0, 0.38, -2.74) * CFrame.Angles(0, math.rad(90), 0))
	add(m, "Part", { Name = "Nose", Size = Vector3.new(0.2, 0.2, 0.2), Transparency = 1 }, CFrame.new(0, 0.38, -2.85))
	-- v2.43: the ENERGY gauge on the left side of the body: five segments, lit from the bottom
	add(m, "Part", { Name = "GaugeBack", Size = Vector3.new(0.05, 0.5, 0.2), Color = DARK, Material = M.Metal }, CFrame.new(-0.35, 0.38, -0.5))
	for k = 1, 5 do
		add(m, "Part", { Name = "Seg" .. k, Size = Vector3.new(0.07, 0.07, 0.14), Color = Color3.fromRGB(110, 230, 100), Material = M.Neon }, CFrame.new(-0.37, 0.18 + (k - 1) * 0.1, -0.5))
	end
	-- the drum with the six pips (one per pulse in the magazine)
	add(m, "Part", { Name = "Drum", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.34, 0.9, 0.9), Color = DARK, Material = M.Metal }, CFrame.new(0.5, 0.3, -0.2))
	for k = 1, 6 do
		local a = math.rad((k - 1) * 60)
		add(m, "Part", { Name = "Pip" .. k, Shape = Enum.PartType.Ball, Size = Vector3.new(0.17, 0.17, 0.17), Color = GLOW, Material = M.Neon }, CFrame.new(0.7, 0.3 + math.cos(a) * 0.3, -0.2 + math.sin(a) * 0.3))
	end
	return h
end

-- v2.32 the PICKAXE (breaks the garden's blocks): held like a hammer — the shaft
-- rises from the hand, leaning forward; a curved steel head with two points
-- (front and back), a red collar and a leather grip
-- v2.38 its TIERS (ToolConfig.PickaxeTiers, 1 … 5): the same shape, another head —
--   1 Stone    a rough grey head on a wooden shaft
--   2 Iron     polished steel, chrome points, a dark collar
--   3 Gold     a shining golden head, a dark wooden shaft, a ruby, a warm glow
--   4 Diamond  a see-through crystal head with glowing points and a cold light
--   5 Rainbow  every piece of the head glows in its own colour (the client's Pickaxe
--              module turns the colours round: parts with the attribute "Hue"), white
--              shaft with glowing bands, sparkles
local PICK_LOOK = {
	{ Head = Color3.fromRGB(122, 125, 132), Tip = Color3.fromRGB(158, 161, 168), Collar = Color3.fromRGB(205, 60, 50), Shaft = WOOD, Grip = Color3.fromRGB(92, 60, 40) },
	{ Head = STEEL, Tip = CHROME_, Collar = DARK, Shaft = WOOD, Grip = Color3.fromRGB(70, 74, 86), Shine = 0.18 },
	{ Head = Color3.fromRGB(255, 200, 60), Tip = Color3.fromRGB(255, 236, 150), Collar = Color3.fromRGB(150, 28, 40), Shaft = Color3.fromRGB(104, 68, 42), Grip = Color3.fromRGB(120, 30, 40), Shine = 0.3, Glow = Color3.fromRGB(255, 215, 110) },
	{ Head = Color3.fromRGB(110, 228, 255), Tip = Color3.fromRGB(205, 250, 255), Collar = CHROME_, Shaft = Color3.fromRGB(44, 50, 70), Grip = Color3.fromRGB(60, 140, 190), Glass = true, Glow = Color3.fromRGB(140, 235, 255) },
	{ Head = Color3.fromRGB(255, 90, 90), Tip = Color3.fromRGB(255, 255, 255), Collar = Color3.fromRGB(255, 255, 255), Shaft = Color3.fromRGB(245, 245, 250), Grip = Color3.fromRGB(70, 60, 90), Rainbow = true, Glow = Color3.fromRGB(255, 255, 255) },
}

builders.Pickaxe = function(m, _vehicle, tier)
	tier = math.clamp(math.floor(tonumber(tier) or 1), 1, #PICK_LOOK)
	local L = PICK_LOOK[tier]
	local h = handlePart(m)
	local u = Vector3.new(0, 0.866, -0.5) -- along the shaft (up and forward)
	local f = Vector3.new(0, -0.5, -0.866) -- across it: forward and down
	rod(m, u * -0.65, u * 2.35, 0.22, L.Shaft, M.Wood, "Shaft")
	rod(m, u * -0.6, u * 0.2, 0.3, L.Grip, M.Fabric, "Grip")
	rod(m, u * -0.72, u * -0.6, 0.36, DARK, M.Metal, "Pommel")
	local c = u * 2.2
	-- one piece of the head: steel-like, crystal (Diamond) or glowing in its own hue (Rainbow)
	local hueN = 0
	local function dress(p, tip)
		if L.Rainbow then
			local hue = (hueN * 0.13) % 1
			hueN += 1
			p.Material = M.Neon
			p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
			p.FrontSurface, p.BackSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
			p.LeftSurface, p.RightSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
			p.Color = Color3.fromHSV(hue, 0.72, 1)
			p:SetAttribute("Hue", hue)
		elseif L.Glass then
			p.Material = if tip then M.Neon else M.Glass
			p.Transparency = if tip then 0.05 else 0.25
			p.Reflectance = 0.2
		elseif L.Shine then
			p.Reflectance = L.Shine
		end
		return p
	end
	-- (the arms of the head are listed back point -> front point, so the rainbow runs along it)
	local arms = {}
	for _, dir in { -1, 1 } do
		local d = f * dir
		local p1 = c + d * 0.24
		local p2 = c + d * 0.8 - u * 0.04
		local p3 = c + d * 1.25 - u * 0.2
		local p4 = c + d * 1.6 - u * 0.44
		local list = { { p1, p2, 0.34, L.Head, "Arm", false }, { p2, p3, 0.26, L.Head, "Arm", false }, { p3, p4, 0.16, L.Tip, if dir == 1 then "Tip" else "BackTip", true } }
		if dir == -1 then
			list = { list[3], list[2], list[1] }
		end
		for _, a in list do
			table.insert(arms, a)
		end
	end
	for i, a in arms do
		if i == 4 then
			dress(add(m, "Part", { Name = "Head", Size = Vector3.new(0.4, 0.5, 0.56), Color = L.Head, Material = M.Metal }, CFrame.fromMatrix(c, Vector3.xAxis, u)), false)
		end
		dress(rod(m, a[1], a[2], a[3], a[4], M.Metal, a[5]), a[6])
	end
	rod(m, c - u * 0.34, c - u * 0.22, 0.42, L.Collar, M.SmoothPlastic, "Collar")
	local head = m:FindFirstChild("Head")
	if tier == 3 then
		add(m, "Part", { Name = "Gem", Shape = Enum.PartType.Ball, Size = Vector3.new(0.26, 0.26, 0.26), Color = Color3.fromRGB(255, 60, 90), Material = M.Neon }, CFrame.new(c + Vector3.new(0.22, 0, 0)))
		add(m, "Part", { Name = "Gem", Shape = Enum.PartType.Ball, Size = Vector3.new(0.26, 0.26, 0.26), Color = Color3.fromRGB(255, 60, 90), Material = M.Neon }, CFrame.new(c - Vector3.new(0.22, 0, 0)))
		rod(m, u * 0.9, u * 1.02, 0.3, L.Head, M.Metal, "Band").Reflectance = 0.3
	elseif tier == 4 then
		add(m, "Part", { Name = "Core", Shape = Enum.PartType.Ball, Size = Vector3.new(0.34, 0.34, 0.34), Color = Color3.fromRGB(235, 255, 255), Material = M.Neon }, CFrame.new(c))
		for k = 0, 1 do
			rod(m, u * (0.75 + k * 0.5), u * (0.83 + k * 0.5), 0.3, L.Tip, M.Neon, "Band")
		end
	elseif tier >= 5 then
		for k = 0, 3 do
			local band = rod(m, u * (0.45 + k * 0.4), u * (0.53 + k * 0.4), 0.3, Color3.fromHSV((0.5 + k * 0.13) % 1, 0.72, 1), M.Neon, "Band")
			band:SetAttribute("Hue", (0.5 + k * 0.13) % 1)
		end
		local star = add(m, "Part", { Name = "Star", Shape = Enum.PartType.Ball, Size = Vector3.new(0.3, 0.3, 0.3), Color = Color3.fromRGB(255, 255, 255), Material = M.Neon }, CFrame.new(c + u * 0.36))
		local sp = Instance.new("Sparkles")
		sp.SparkleColor = Color3.fromRGB(255, 240, 255)
		sp.Parent = star
	end
	if L.Glow and head then
		local l = Instance.new("PointLight")
		l.Color = L.Glow
		l.Range = if tier >= 5 then 9 else 6
		l.Brightness = if tier >= 5 then 0.9 else 0.5
		l.Parent = head
	end
	return h
end

---------------------------------------------------------------- one-use items
local function magnet(m, color, tip, scale)
	local h = handlePart(m)
	local s = scale
	for sx = -1, 1, 2 do
		add(m, "Part", { Name = "Arm", Size = Vector3.new(0.45 * s, 1.1 * s, 0.45 * s), Color = color, Material = M.SmoothPlastic }, CFrame.new(sx * 0.5 * s, 0.35 * s, -0.4))
		add(m, "Part", { Name = "Tip", Size = Vector3.new(0.46 * s, 0.35 * s, 0.46 * s), Color = tip, Material = if tip == Color3.fromRGB(255, 255, 255) then M.SmoothPlastic else M.Neon }, CFrame.new(sx * 0.5 * s, 1.05 * s, -0.4))
	end
	add(m, "Part", { Name = "Bend", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.45 * s, 1.45 * s, 1.45 * s), Color = color, Material = M.SmoothPlastic }, CFrame.new(0, -0.15 * s, -0.4) * CFrame.Angles(0, math.rad(90), 0))
	return h
end
builders.LeafMagnet = function(m)
	return magnet(m, Color3.fromRGB(220, 50, 50), Color3.fromRGB(255, 255, 255), 1)
end
builders.MegaMagnet = function(m)
	local h = magnet(m, Color3.fromRGB(255, 200, 50), Color3.fromRGB(120, 220, 255), 1.3)
	local s = Instance.new("Sparkles")
	s.SparkleColor = Color3.fromRGB(255, 230, 120)
	s.Parent = m:FindFirstChild("Bend")
	return h
end

builders.GrassKiller = function(m)
	local h = handlePart(m)
	add(m, "Part", { Name = "Bottle", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.3, 0.8, 0.8), Color = Color3.fromRGB(80, 200, 120), Material = M.SmoothPlastic, Transparency = 0.1 }, CFrame.new(0, 0.1, -0.3) * CFrame.Angles(0, 0, math.pi / 2))
	add(m, "Part", { Name = "Label", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.5, 0.82, 0.82), Color = Color3.fromRGB(240, 240, 240), Material = M.SmoothPlastic }, CFrame.new(0, 0.1, -0.3) * CFrame.Angles(0, 0, math.pi / 2))
	add(m, "Part", { Name = "Head", Size = Vector3.new(0.45, 0.4, 0.7), Color = Color3.fromRGB(230, 60, 60), Material = M.SmoothPlastic }, CFrame.new(0, 0.95, -0.4))
	add(m, "Part", { Name = "Trigger", Size = Vector3.new(0.15, 0.4, 0.15), Color = Color3.fromRGB(230, 60, 60), Material = M.SmoothPlastic }, CFrame.new(0, 0.65, -0.72))
	return h
end

builders.BatteryPack = function(m)
	local h = handlePart(m)
	add(m, "Part", { Name = "Cell", Size = Vector3.new(0.9, 1.4, 0.6), Color = DARK, Material = M.SmoothPlastic }, CFrame.new(0, 0.2, -0.4))
	add(m, "Part", { Name = "Band", Size = Vector3.new(0.92, 0.35, 0.62), Color = Color3.fromRGB(90, 230, 90), Material = M.Neon }, CFrame.new(0, 0.55, -0.4))
	for sx = -1, 1, 2 do
		add(m, "Part", { Name = "Pole", Size = Vector3.new(0.18, 0.18, 0.18), Color = if sx < 0 then Color3.fromRGB(220, 60, 60) else STEEL, Material = M.Metal }, CFrame.new(sx * 0.25, 0.98, -0.4))
	end
	return h
end

builders.TurboFuel = function(m)
	local h = handlePart(m)
	add(m, "Part", { Name = "Can", Size = Vector3.new(0.55, 1.3, 1), Color = Color3.fromRGB(215, 40, 40), Material = M.SmoothPlastic }, CFrame.new(0, 0.2, -0.4))
	add(m, "Part", { Name = "Flame", Size = Vector3.new(0.57, 0.4, 0.5), Color = Color3.fromRGB(255, 190, 40), Material = M.Neon }, CFrame.new(0, 0.2, -0.4))
	rod(m, Vector3.new(0, 0.85, -0.7), Vector3.new(0, 1.25, -1.05), 0.16, DARK, M.Metal, "Spout")
	rod(m, Vector3.new(0, 0.95, -0.25), Vector3.new(0, 0.95, 0.05), 0.14, DARK, M.Metal, "Carry")
	return h
end

-- v2.32: the Leaf Blower's battery (a blue power cell with a plug)
builders.BlowerBattery = function(m)
	local h = handlePart(m)
	add(m, "Part", { Name = "Cell", Size = Vector3.new(1.1, 1.2, 0.7), Color = Color3.fromRGB(70, 150, 230), Material = M.SmoothPlastic }, CFrame.new(0, 0.2, -0.4))
	add(m, "Part", { Name = "Band", Size = Vector3.new(1.12, 0.3, 0.72), Color = Color3.fromRGB(120, 230, 255), Material = M.Neon }, CFrame.new(0, 0.5, -0.4))
	add(m, "Part", { Name = "Bolt", Size = Vector3.new(0.3, 0.45, 0.74), Color = Color3.fromRGB(255, 230, 80), Material = M.Neon }, CFrame.new(0, -0.1, -0.4) * CFrame.Angles(0, 0, math.rad(20)))
	for sx = -1, 1, 2 do
		add(m, "Part", { Name = "Pin", Size = Vector3.new(0.14, 0.3, 0.14), Color = STEEL, Material = M.Metal }, CFrame.new(sx * 0.25, 0.95, -0.4))
	end
	return h
end

-- v2.43: the Leaf Blaster's battery — a mint power cell with a glowing band, the six little
-- pips of its drum and a plug (the blaster's colours)
builders.BlasterBattery = function(m)
	local h = handlePart(m)
	local MINT = Color3.fromRGB(70, 190, 140)
	local GLOW = Color3.fromRGB(190, 240, 255)
	add(m, "Part", { Name = "Cell", Size = Vector3.new(1.15, 1.35, 0.8), Color = MINT, Material = M.SmoothPlastic }, CFrame.new(0, 0.15, -0.4))
	add(m, "Part", { Name = "Band", Size = Vector3.new(1.17, 0.26, 0.82), Color = GLOW, Material = M.Neon }, CFrame.new(0, 0.62, -0.4))
	for k = 0, 5 do
		local a = math.rad(k * 60)
		add(m, "Part", { Name = "Pip", Shape = Enum.PartType.Ball, Size = Vector3.new(0.13, 0.13, 0.13), Color = GLOW, Material = M.Neon }, CFrame.new(math.sin(a) * 0.3, 0.05 + math.cos(a) * 0.3, -0.81))
	end
	add(m, "Part", { Name = "Core", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.84, 0.3, 0.3), Color = GLOW, Material = M.Neon }, CFrame.new(0, 0.05, -0.4) * CFrame.Angles(0, math.rad(90), 0))
	add(m, "Part", { Name = "Bolt", Size = Vector3.new(0.16, 0.34, 0.86), Color = Color3.fromRGB(255, 230, 80), Material = M.Neon }, CFrame.new(0, -0.35, -0.4) * CFrame.Angles(0, 0, math.rad(22)))
	for sx = -1, 1, 2 do
		add(m, "Part", { Name = "Pin", Size = Vector3.new(0.14, 0.3, 0.14), Color = STEEL, Material = M.Metal }, CFrame.new(sx * 0.28, 0.98, -0.4))
	end
	return h
end

-- v2.43: Gasoline — a red jerrycan with a spout, a carrying handle, a cap and a flame label
builders.Gasoline = function(m)
	local h = handlePart(m)
	local RED = Color3.fromRGB(205, 45, 40)
	add(m, "Part", { Name = "Can", Size = Vector3.new(0.7, 1.35, 1.1), Color = RED, Material = M.SmoothPlastic }, CFrame.new(0, 0.2, -0.4))
	add(m, "Part", { Name = "Ridge", Size = Vector3.new(0.72, 0.1, 1.12), Color = Color3.fromRGB(150, 28, 28), Material = M.SmoothPlastic }, CFrame.new(0, 0.55, -0.4))
	add(m, "Part", { Name = "Ridge", Size = Vector3.new(0.72, 0.1, 1.12), Color = Color3.fromRGB(150, 28, 28), Material = M.SmoothPlastic }, CFrame.new(0, -0.15, -0.4))
	add(m, "Part", { Name = "Label", Size = Vector3.new(0.74, 0.55, 0.5), Color = Color3.fromRGB(250, 235, 200), Material = M.SmoothPlastic }, CFrame.new(0, 0.2, -0.4))
	add(m, "Part", { Name = "Flame", Size = Vector3.new(0.76, 0.34, 0.2), Color = Color3.fromRGB(255, 150, 30), Material = M.Neon }, CFrame.new(0, 0.2, -0.4) * CFrame.Angles(0, 0, math.rad(8)))
	rod(m, Vector3.new(0, 0.88, -0.78), Vector3.new(0, 1.35, -1.12), 0.2, Color3.fromRGB(240, 200, 50), M.SmoothPlastic, "Spout")
	add(m, "Part", { Name = "Cap", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.14, 0.34, 0.34), Color = Color3.fromRGB(40, 40, 46), Material = M.Metal }, CFrame.new(0, 1.37, -1.14) * CFrame.Angles(math.rad(-35), 0, math.pi / 2))
	rod(m, Vector3.new(0, 0.92, -0.05), Vector3.new(0, 0.92, 0.25), 0.16, DARK, M.Metal, "Carry")
	rod(m, Vector3.new(0, 0.88, -0.1), Vector3.new(0, 0.88, 0.2), 0.12, STEEL, M.Metal, "Carry")
	return h
end

-- v2.43: the Repair Kit — a red toolbox with a handle, silver clasps, a green cross and a wrench
-- and a hammer sticking out of it
builders.RepairKit = function(m)
	local h = handlePart(m)
	local RED = Color3.fromRGB(215, 55, 50)
	add(m, "Part", { Name = "Box", Size = Vector3.new(1.5, 0.8, 0.75), Color = RED, Material = M.SmoothPlastic }, CFrame.new(0, 0, -0.4))
	add(m, "Part", { Name = "Lid", Size = Vector3.new(1.54, 0.12, 0.79), Color = Color3.fromRGB(165, 35, 35), Material = M.SmoothPlastic }, CFrame.new(0, 0.46, -0.4))
	add(m, "Part", { Name = "Cross", Size = Vector3.new(0.12, 0.42, 0.78), Color = Color3.fromRGB(110, 235, 120), Material = M.Neon }, CFrame.new(0, -0.02, -0.4))
	add(m, "Part", { Name = "Cross", Size = Vector3.new(0.42, 0.12, 0.78), Color = Color3.fromRGB(110, 235, 120), Material = M.Neon }, CFrame.new(0, -0.02, -0.4))
	for sx = -1, 1, 2 do
		add(m, "Part", { Name = "Clasp", Size = Vector3.new(0.2, 0.3, 0.8), Color = STEEL, Material = M.Metal }, CFrame.new(sx * 0.6, 0.35, -0.4))
	end
	rod(m, Vector3.new(-0.4, 0.6, -0.4), Vector3.new(0.4, 0.6, -0.4), 0.14, DARK, M.Metal, "Handle")
	rod(m, Vector3.new(-0.42, 0.5, -0.4), Vector3.new(-0.42, 0.62, -0.4), 0.12, DARK, M.Metal, "HandlePost")
	rod(m, Vector3.new(0.42, 0.5, -0.4), Vector3.new(0.42, 0.62, -0.4), 0.12, DARK, M.Metal, "HandlePost")
	-- a wrench and a hammer sticking out of the lid
	rod(m, Vector3.new(-0.3, 0.45, -0.2), Vector3.new(-0.55, 1.2, -0.05), 0.12, STEEL, M.Metal, "Wrench")
	add(m, "Part", { Name = "WrenchHead", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.12, 0.34, 0.34), Color = STEEL, Material = M.Metal }, CFrame.lookAt(Vector3.new(-0.56, 1.24, -0.04), Vector3.new(-0.7, 1.7, 0.02)) * CFrame.Angles(0, math.rad(90), 0))
	rod(m, Vector3.new(0.3, 0.45, -0.55), Vector3.new(0.5, 1.15, -0.7), 0.12, Color3.fromRGB(150, 104, 62), M.Wood, "HammerShaft")
	add(m, "Part", { Name = "HammerHead", Size = Vector3.new(0.5, 0.22, 0.22), Color = DARK, Material = M.Metal }, CFrame.new(0.52, 1.2, -0.72))
	return h
end

-- v2.38: the Vacuum's battery — a big violet power cell with a carrying handle, two
-- glowing bands and a swirl (the vacuum's colours)
builders.VacuumBattery = function(m)
	local h = handlePart(m)
	local VIOLET = Color3.fromRGB(120, 70, 205)
	local GLOW = Color3.fromRGB(205, 160, 255)
	add(m, "Part", { Name = "Cell", Size = Vector3.new(1.25, 1.45, 0.85), Color = VIOLET, Material = M.SmoothPlastic }, CFrame.new(0, 0.15, -0.4))
	for _, y in { 0.62, -0.32 } do
		add(m, "Part", { Name = "Band", Size = Vector3.new(1.27, 0.2, 0.87), Color = GLOW, Material = M.Neon }, CFrame.new(0, y, -0.4))
	end
	add(m, "Part", { Name = "Swirl", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.89, 0.5, 0.5), Color = Color3.fromRGB(235, 215, 255), Material = M.Neon }, CFrame.new(0, 0.15, -0.4) * CFrame.Angles(0, math.rad(90), 0))
	add(m, "Part", { Name = "Bolt", Size = Vector3.new(0.16, 0.34, 0.91), Color = Color3.fromRGB(255, 230, 80), Material = M.Neon }, CFrame.new(0, 0.15, -0.4) * CFrame.Angles(0, 0, math.rad(22)))
	for sx = -1, 1, 2 do
		add(m, "Part", { Name = "Pin", Size = Vector3.new(0.16, 0.26, 0.16), Color = STEEL, Material = M.Metal }, CFrame.new(sx * 0.32, 1, -0.4))
		rod(m, Vector3.new(sx * 0.5, 0.86, -0.4), Vector3.new(sx * 0.5, 1.3, -0.4), 0.1, DARK, M.Metal, "Post")
	end
	rod(m, Vector3.new(-0.5, 1.3, -0.4), Vector3.new(0.5, 1.3, -0.4), 0.14, DARK, M.SmoothPlastic, "Carry")
	return h
end

-- v2.32 PET TOYS: a teddy bear — small & brown, medium with a bow, big & golden
local function teddy(m, s, fur, belly, bow, glowC)
	local h = handlePart(m)
	local c = CFrame.new(0, 0.2, -0.4)
	local function ball(name, size, color, off, mat)
		return add(m, "Part", { Name = name, Shape = Enum.PartType.Ball, Size = Vector3.one * size * s, Color = color, Material = mat or M.SmoothPlastic }, c * CFrame.new(off * s))
	end
	ball("Body", 0.95, fur, Vector3.new(0, 0, 0))
	ball("Belly", 0.6, belly, Vector3.new(0, -0.02, -0.24))
	ball("Head", 0.75, fur, Vector3.new(0, 0.72, 0))
	ball("Snout", 0.32, belly, Vector3.new(0, 0.64, -0.3))
	ball("Nose", 0.12, DARK, Vector3.new(0, 0.7, -0.45))
	for sx = -1, 1, 2 do
		ball("Ear", 0.3, fur, Vector3.new(sx * 0.3, 1.08, 0))
		ball("Eye", 0.1, DARK, Vector3.new(sx * 0.16, 0.84, -0.32))
		ball("Arm", 0.36, fur, Vector3.new(sx * 0.52, 0.12, -0.1))
		ball("Leg", 0.42, fur, Vector3.new(sx * 0.3, -0.48, -0.18))
	end
	if bow then
		for sx = -1, 1, 2 do
			add(m, "WedgePart", { Name = "Bow", Size = Vector3.new(0.12, 0.22, 0.26) * s, Color = bow, Material = M.SmoothPlastic }, c * CFrame.new(Vector3.new(sx * 0.16, 0.38, -0.36) * s) * CFrame.Angles(0, math.rad(sx * 90), 0))
		end
		ball("Knot", 0.14, bow, Vector3.new(0, 0.38, -0.38))
	end
	-- v2.46: an invisible box the size of the BIG toy: pictures that fit the camera to the
	-- model (hotbar, inventory) then show the three sizes at their real proportions
	add(m, "Part", { Name = "SizePad", Size = Vector3.one * 2.8, Transparency = 1 }, c * CFrame.new(0, 0.27 * s, 0))
	if glowC then
		ball("Heart", 0.22, glowC, Vector3.new(0, 0.02, -0.5), M.Neon)
	end
	return h
end
builders.SmallToy = function(m)
	return teddy(m, 0.65, Color3.fromRGB(176, 122, 76), Color3.fromRGB(232, 200, 158), nil, nil)
end
builders.MediumToy = function(m)
	return teddy(m, 1, Color3.fromRGB(196, 150, 222), Color3.fromRGB(246, 232, 250), Color3.fromRGB(90, 170, 255), nil)
end
builders.BigToy = function(m)
	return teddy(m, 1.45, Color3.fromRGB(255, 200, 70), Color3.fromRGB(255, 240, 190), Color3.fromRGB(235, 60, 80), Color3.fromRGB(255, 110, 140))
end

---------------------------------------------------------------- v1.2.1: the finishing touches
-- Every tool gets details on top of its base shape: glowing edges, brand stripes,
-- chrome caps, lights. (Names like Blade / Head / Nose stay — the client's effects
-- look for them.)
local BRASS = Color3.fromRGB(215, 170, 70)
local CHROME = Color3.fromRGB(225, 230, 240)
local decor = {}

local function glow(m, part, color, range)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range or 5
	l.Brightness = 0.4
	l.Parent = part
	return l
end

decor.Shears = function(m)
	for s = -1, 1, 2 do
		-- a bright cutting edge on each blade + a leather wrap on the grips
		add(m, "Part", { Name = "Edge", Size = Vector3.new(0.02, 0.03, 1.35), Color = Color3.fromRGB(200, 255, 190), Material = M.Neon }, CFrame.new(0.05 * s, -0.1 * s, -1.12) * CFrame.Angles(0, math.rad(4 * s), 0))
		add(m, "Part", { Name = "Wrap", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.22, 0.22, 0.22), Color = Color3.fromRGB(110, 70, 40), Material = M.Fabric }, CFrame.new(0.16 * s, 0, 0.15) * CFrame.Angles(0, math.rad(90), 0))
	end
	add(m, "Part", { Name = "Rivet", Shape = Enum.PartType.Ball, Size = Vector3.new(0.14, 0.14, 0.14), Color = BRASS, Material = M.Metal }, CFrame.new(0, 0.12, -0.38))
end

decor.WeedCutter = function(m)
	add(m, "Part", { Name = "Ferrule", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.18, 0.26, 0.26), Color = BRASS, Material = M.Metal }, CFrame.lookAt(Vector3.new(0, -0.5, -2.05), Vector3.new(0, -0.6, -2.4)) * CFrame.Angles(0, math.rad(90), 0))
	add(m, "Part", { Name = "Edge", Size = Vector3.new(0.02, 0.03, 1.15), Color = Color3.fromRGB(210, 255, 200), Material = M.Neon }, CFrame.new(0.15, -0.8, -2.8))
	add(m, "Part", { Name = "Tassel", Size = Vector3.new(0.08, 0.5, 0.08), Color = Color3.fromRGB(220, 60, 60), Material = M.Fabric }, CFrame.new(0, -0.25, 0.45))
end

local function scytheDecor(m, golden)
	for _, y in { 0.6, -0.9 } do
		local z = 0.8 + (y - 1.3) / (-3.4) * (-2.5)
		add(m, "Part", { Name = "Wrap", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 0.28, 0.28), Color = if golden then Color3.fromRGB(120, 30, 40) else Color3.fromRGB(90, 55, 30), Material = M.Fabric }, CFrame.lookAt(Vector3.new(0, y, z), Vector3.new(0, y - 1, z - 0.74)) * CFrame.Angles(0, math.rad(90), 0))
	end
	add(m, "Part", { Name = "Collar", Shape = Enum.PartType.Ball, Size = Vector3.new(0.34, 0.34, 0.34), Color = if golden then Color3.fromRGB(255, 240, 180) else BRASS, Material = M.Metal }, CFrame.new(0, -2.05, -1.65))
	-- a thin glowing edge along the whole blade
	local blades = {}
	for _, d in m:GetChildren() do
		if d.Name == "Blade" then
			table.insert(blades, d)
		end
	end
	for _, b in blades do
		local e = add(m, "Part", { Name = "Edge", Size = Vector3.new(b.Size.X, 0.03, 0.03), Color = if golden then Color3.fromRGB(255, 255, 210) else Color3.fromRGB(215, 255, 230), Material = M.Neon }, b.CFrame * CFrame.new(0, 0, -0.17))
		e.Transparency = 0.1
	end
	if golden then
		for k, b in { blades[2], blades[5] } do
			if b then
				add(m, "Part", { Name = "Gem", Shape = Enum.PartType.Ball, Size = Vector3.new(0.2, 0.2, 0.2), Color = if k == 1 then Color3.fromRGB(80, 200, 255) else Color3.fromRGB(255, 70, 110), Material = M.Neon }, b.CFrame * CFrame.new(0, 0.07, 0.05))
			end
		end
		glow(m, blades[4] or blades[1], Color3.fromRGB(255, 215, 90), 7)
	end
end
decor.Scythe = function(m)
	scytheDecor(m, false)
end
decor.GoldenScythe = function(m)
	scytheDecor(m, true)
end

decor.Trimmer = function(m, _vehicle, tier)
	tier = math.clamp(math.floor(tonumber(tier) or 1), 1, 4) -- (v2.41: the bar grips follow the tier's colour)
	local motorCF = CFrame.new(0, 0.55, 1.15) * CFrame.Angles(math.rad(-37), 0, 0)
	add(m, "Part", { Name = "BrandStripe", Size = Vector3.new(0.57, 0.12, 0.92), Color = DARK, Material = M.SmoothPlastic }, motorCF * CFrame.new(0, 0.1, 0))
	for k = -1, 1 do
		add(m, "Part", { Name = "Vent", Size = Vector3.new(0.02, 0.3, 0.06), Color = DARK, Material = M.Metal }, motorCF * CFrame.new(0.28, 0, k * 0.2))
	end
	add(m, "Part", { Name = "ChargeLight", Size = Vector3.new(0.3, 0.05, 0.08), Color = Color3.fromRGB(110, 255, 120), Material = M.Neon }, CFrame.new(0, 0.9, 1.45) * CFrame.Angles(math.rad(-37), 0, 0) * CFrame.new(0, 0.18, -0.15))
	add(m, "Part", { Name = "GuardRim", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.05, 1.36, 1.36), Color = DARK, Material = M.Metal }, CFrame.new(0, -2.18, -2.75) * CFrame.Angles(0, 0, math.pi / 2))
	for _, sx in { -0.45, 0.45 } do
		add(m, "Part", { Name = "BarGrip", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.25, 0.18, 0.18), Color = TRIM_BODY[tier] or TRIM_BODY[1], Material = M.SmoothPlastic }, CFrame.new(sx, 0.05, -0.3))
	end
end

decor.PushMower = function(m)
	local deckC = Vector3.new(0, -2.55, -2.9)
	for _, w in m:GetChildren() do
		if w.Name == "Wheel" then
			-- chrome hub caps
			add(m, "Part", { Name = "HubCap", Shape = Enum.PartType.Cylinder, Size = Vector3.new(w.Size.X + 0.04, 0.35, 0.35), Color = CHROME, Material = M.Metal }, w.CFrame)
		end
	end
	add(m, "Part", { Name = "DeckStripe", Size = Vector3.new(2.42, 0.08, 0.5), Color = Color3.fromRGB(250, 250, 250), Material = M.SmoothPlastic }, CFrame.new(deckC + Vector3.new(0, 0.2, -0.7)))
	add(m, "Part", { Name = "Exhaust", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 0.2, 0.2), Color = CHROME, Material = M.Metal }, CFrame.new(deckC + Vector3.new(-0.6, 0.8, 0.2)) * CFrame.Angles(0, 0, math.pi / 2))
	add(m, "Part", { Name = "Lamp", Size = Vector3.new(0.4, 0.15, 0.08), Color = Color3.fromRGB(255, 250, 200), Material = M.Neon }, CFrame.new(deckC + Vector3.new(0, 0.1, -1.22)))
end

local function riderDecor(m, turbo, vehicle)
	local s = if vehicle then 1 else 0.55
	for _, sx in { -0.8, 0.8 } do
		local lamp = add(m, "Part", { Name = "Headlight", Shape = Enum.PartType.Ball, Size = Vector3.new(0.4 * s, 0.4 * s, 0.4 * s), Color = Color3.fromRGB(255, 250, 210), Material = M.Neon }, CFrame.new(sx * s, 2.1 * s, -2.36 * s))
		if vehicle then
			local sl = Instance.new("SpotLight")
			sl.Face = Enum.NormalId.Front
			sl.Range = 16
			sl.Angle = 50
			sl.Brightness = 0.8
			sl.Color = Color3.fromRGB(255, 245, 210)
			sl.Parent = lamp
		end
	end
	for _, w in m:GetChildren() do
		if w.Name == "Wheel" then
			add(m, "Part", { Name = "HubCap", Shape = Enum.PartType.Cylinder, Size = Vector3.new(w.Size.X + 0.04 * s, w.Size.Y * 0.45, w.Size.Z * 0.45), Color = if turbo then Color3.fromRGB(255, 60, 90) else CHROME, Material = if turbo then M.Neon else M.Metal }, w.CFrame)
		end
	end
	add(m, "Part", { Name = "Grille", Size = Vector3.new(1.6 * s, 0.5 * s, 0.05 * s), Color = CHROME, Material = M.DiamondPlate }, CFrame.new(0, 2.05 * s, -2.36 * s))
	if turbo then
		for _, sx in { -1, 1 } do
			add(m, "Part", { Name = "Flame", Size = Vector3.new(0.08 * s, 0.4 * s, 1.6 * s), Color = Color3.fromRGB(255, 140, 40), Material = M.Neon }, CFrame.new(sx * 1.52 * s, 1.35 * s, -0.2 * s))
		end
	end
end
decor.RidingMower = function(m, vehicle)
	riderDecor(m, false, vehicle)
end
decor.TurboMower = function(m, vehicle)
	riderDecor(m, true, vehicle)
end

decor.Blower = function(m)
	add(m, "Part", { Name = "Strap", Size = Vector3.new(0.12, 1.2, 0.3), Color = Color3.fromRGB(40, 40, 46), Material = M.Fabric }, CFrame.new(-0.3, 0.1, 0.25) * CFrame.Angles(0, 0, math.rad(20)))
	add(m, "Part", { Name = "Dial", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.06, 0.34, 0.34), Color = CHROME, Material = M.Metal }, CFrame.new(-0.26, -0.2, 0.1))
	for k = 0, 2 do
		add(m, "Part", { Name = "Vent", Size = Vector3.new(0.82, 0.04, 0.12), Color = DARK, Material = M.Metal }, CFrame.new(0.15, -0.55 + k * 0.18, 0.86))
	end
	local ring = add(m, "Part", { Name = "NozzleRing", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.12, 0.62, 0.62), Color = Color3.fromRGB(120, 210, 255), Material = M.Neon }, CFrame.lookAt(Vector3.new(0.15, -1.1, -3.05), Vector3.new(0.15, -1.1, -4)) * CFrame.Angles(0, math.rad(90), 0))
	ring.Transparency = 0.2
end

decor.Vacuum = function(m)
	add(m, "Part", { Name = "GlowRing", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.1, 1.16, 1.16), Color = Color3.fromRGB(180, 120, 255), Material = M.Neon }, CFrame.new(0.3, -0.25, -0.2) * CFrame.Angles(0, math.rad(90), 0))
	add(m, "Part", { Name = "Bag", Size = Vector3.new(0.8, 0.9, 0.6), Color = Color3.fromRGB(90, 70, 130), Material = M.Fabric }, CFrame.new(0.3, -0.3, 1.25))
	add(m, "Part", { Name = "NozzleTrim", Size = Vector3.new(1.24, 0.06, 0.54), Color = CHROME, Material = M.Metal }, CFrame.new(0.3, -1.58, -2.7))
	local sw = add(m, "Part", { Name = "Swirl", Shape = Enum.PartType.Ball, Size = Vector3.new(0.5, 0.5, 0.5), Color = Color3.fromRGB(200, 170, 255), Material = M.Neon, Transparency = 0.5 }, CFrame.new(0.3, 0.05, 0.45))
	glow(m, sw, Color3.fromRGB(180, 130, 255), 4)
end

decor.LeafMagnet = function(m)
	for _, t in m:GetChildren() do
		if t.Name == "Tip" then
			add(m, "Part", { Name = "Spark", Size = t.Size * Vector3.new(1.02, 0.25, 1.02), Color = Color3.fromRGB(120, 200, 255), Material = M.Neon }, t.CFrame * CFrame.new(0, t.Size.Y / 2, 0))
		end
	end
end
decor.MegaMagnet = function(m)
	decor.LeafMagnet(m)
	local bend = m:FindFirstChild("Bend")
	if bend then
		glow(m, bend, Color3.fromRGB(255, 220, 110), 7)
	end
end
decor.GrassKiller = function(m)
	add(m, "Part", { Name = "Skull", Size = Vector3.new(0.84, 0.18, 0.18), Color = Color3.fromRGB(40, 40, 40), Material = M.SmoothPlastic }, CFrame.new(0, 0.1, -0.3))
	add(m, "Part", { Name = "Mist", Shape = Enum.PartType.Ball, Size = Vector3.new(0.3, 0.3, 0.3), Color = Color3.fromRGB(150, 255, 170), Material = M.Neon, Transparency = 0.4 }, CFrame.new(0, 0.95, -0.85))
end
decor.BatteryPack = function(m)
	local cell = m:FindFirstChild("Cell")
	if cell then
		glow(m, cell, Color3.fromRGB(110, 255, 120), 4)
	end
	add(m, "Part", { Name = "Bolt", Size = Vector3.new(0.1, 0.4, 0.62), Color = Color3.fromRGB(255, 230, 80), Material = M.Neon }, CFrame.new(0, 0.05, -0.4) * CFrame.Angles(math.rad(25), 0, 0))
end
decor.TurboFuel = function(m)
	add(m, "Part", { Name = "Cap", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.12, 0.24, 0.24), Color = BRASS, Material = M.Metal }, CFrame.new(0, 1.28, -1.07) * CFrame.Angles(math.rad(-40), 0, math.pi / 2))
	add(m, "Part", { Name = "Stripe", Size = Vector3.new(0.57, 0.08, 1.02), Color = Color3.fromRGB(250, 250, 250), Material = M.SmoothPlastic }, CFrame.new(0, 0.62, -0.4))
end

---------------------------------------------------------------- v1.7 upgrade tiers
local tierDecor = {}
local GOLD = Color3.fromRGB(255, 205, 70)
-- Leaf Blower: 2 Pro = chrome nozzle, a booster and a racing stripe · 3 Turbo = a
-- glowing turbine at the intake and fins · 4 Legendary = gold, neon streaks, wings
tierDecor.Blower = function(m, tier)
	local glowC = ({ nil, Color3.fromRGB(255, 170, 90), Color3.fromRGB(110, 200, 255), Color3.fromRGB(120, 255, 240) })[tier]
	if tier >= 2 then
		add(m, "Part", { Name = "Stripe", Size = Vector3.new(0.82, 0.14, 1.32), Color = Color3.fromRGB(250, 250, 250), Material = M.SmoothPlastic }, CFrame.new(0.15, -0.2, 0.2))
		rod(m, Vector3.new(0.15, -0.7, -1.3), Vector3.new(0.15, -0.8, -1.85), 0.55, CHROME, M.Metal, "Booster")
		add(m, "Part", { Name = "BoosterBand", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.08, 0.6, 0.6), Color = glowC, Material = M.Neon }, CFrame.lookAt(Vector3.new(0.15, -0.75, -1.57), Vector3.new(0.15, -0.84, -2.6)) * CFrame.Angles(0, math.rad(90), 0))
	end
	if tier >= 3 then
		local tur = add(m, "Part", { Name = "Turbine", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.1, 0.72, 0.72), Color = glowC, Material = M.Neon, Transparency = 0.15 }, CFrame.new(0.71, -0.35, 0.3))
		for k = 0, 3 do
			add(m, "Part", { Name = "Blade", Size = Vector3.new(0.04, 0.68, 0.1), Color = CHROME, Material = M.Metal }, CFrame.new(0.8, -0.35, 0.3) * CFrame.Angles(math.rad(k * 45), 0, 0))
		end
		for sx = -1, 1, 2 do
			add(m, "WedgePart", { Name = "Fin", Size = Vector3.new(0.06, 0.35, 0.7), Color = BLOWER_BODY[tier], Material = M.SmoothPlastic }, CFrame.new(0.15 + sx * 0.44, -0.12, 0.4))
		end
		glow(m, tur, glowC, 5)
	end
	if tier >= 4 then
		for k = 0, 1 do
			add(m, "Part", { Name = "Streak", Size = Vector3.new(0.05, 0.05, 1.2), Color = glowC, Material = M.Neon }, CFrame.lookAt(Vector3.new(0.15 + (k * 2 - 1) * 0.2, -0.6 - 0.1, -1.4), Vector3.new(0.15 + (k * 2 - 1) * 0.2, -1.05, -2.8)))
		end
		for sx = -1, 1, 2 do
			add(m, "WedgePart", { Name = "Wing", Size = Vector3.new(0.05, 0.5, 1.0), Color = GOLD, Material = M.Metal, Reflectance = 0.3 }, CFrame.new(0.15 + sx * 0.5, -0.55, 0.25) * CFrame.Angles(0, 0, sx * math.rad(-25)))
		end
		add(m, "Part", { Name = "Crown", Shape = Enum.PartType.Ball, Size = Vector3.new(0.28, 0.28, 0.28), Color = glowC, Material = M.Neon }, CFrame.new(0.15, 0.15, 0.2))
	end
end
-- Vacuum: 2 Pro = chrome bands and a bigger window · 3 Turbo = glowing rings and a
-- wide nozzle with teeth · 4 Legendary = black & gold, a glowing vortex core, antennas
tierDecor.Vacuum = function(m, tier)
	local glowC = ({ nil, Color3.fromRGB(90, 255, 220), Color3.fromRGB(255, 110, 130), GOLD })[tier]
	if tier >= 2 then
		for k = -1, 1, 2 do
			add(m, "Part", { Name = "Band", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.1, 1.16, 1.16), Color = CHROME, Material = M.Metal }, CFrame.new(0.3, -0.25, 0.45 + k * 0.5) * CFrame.Angles(0, math.rad(90), 0))
		end
		add(m, "Part", { Name = "Gauge", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.06, 0.3, 0.3), Color = glowC, Material = M.Neon }, CFrame.new(-0.28, -0.25, 0.45))
	end
	if tier >= 3 then
		for k = 0, 2 do
			add(m, "Part", { Name = "Ring", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.06, 0.4, 0.4), Color = glowC, Material = M.Neon }, CFrame.lookAt(Vector3.new(0.3, -0.55 - k * 0.38, -0.55 - k * 0.72), Vector3.new(0.3, -1.6, -2.6)) * CFrame.Angles(0, math.rad(90), 0))
		end
		add(m, "Part", { Name = "WideNozzle", Size = Vector3.new(1.6, 0.14, 0.62), Color = VAC_BODY[tier], Material = M.SmoothPlastic }, CFrame.new(0.3, -1.64, -2.72))
		for k = 0, 4 do
			add(m, "WedgePart", { Name = "Tooth", Size = Vector3.new(0.06, 0.14, 0.14), Color = CHROME, Material = M.Metal }, CFrame.new(-0.35 + k * 0.325, -1.78, -2.98))
		end
	end
	if tier >= 4 then
		local core = add(m, "Part", { Name = "Vortex", Shape = Enum.PartType.Ball, Size = Vector3.new(0.7, 0.7, 0.7), Color = glowC, Material = M.Neon, Transparency = 0.25 }, CFrame.new(0.3, 0.05, 0.45))
		glow(m, core, glowC, 6)
		for k = 0, 2 do
			add(m, "Part", { Name = "GoldBand", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.06, 1.18, 1.18), Color = GOLD, Material = M.Metal, Reflectance = 0.3 }, CFrame.new(0.3, -0.25, 0.45 + (k - 1) * 0.3) * CFrame.Angles(0, math.rad(90), 0))
		end
		for sx = -1, 1, 2 do
			rod(m, Vector3.new(0.3 + sx * 0.3, 0.3, 0.45), Vector3.new(0.3 + sx * 0.45, 0.85, 0.5), 0.05, GOLD, M.Metal, "Antenna")
			add(m, "Part", { Name = "AntennaTip", Shape = Enum.PartType.Ball, Size = Vector3.new(0.14, 0.14, 0.14), Color = glowC, Material = M.Neon }, CFrame.new(0.3 + sx * 0.45, 0.88, 0.5))
		end
	end
end

-- v2.41 Lawn Trimmer: 2 Pro = a chrome shaft, a wide guard skirt, a SECOND cutting line
-- and a racing stripe · 3 Turbo = a glowing head with a blur of spinning line, glowing
-- rings down the shaft, fins and a booster · 4 Legendary = black & gold, an ENERGY RING
-- round the head, golden bands and wings, a gem
tierDecor.Trimmer = function(m, tier)
	local body = TRIM_BODY[tier] or TRIM_BODY[1]
	local line = TRIM_LINE[tier] or TRIM_LINE[1]
	local glowC = ({ nil, Color3.fromRGB(170, 255, 110), Color3.fromRGB(110, 220, 255), Color3.fromRGB(120, 255, 240) })[tier] or line
	local motorCF = CFrame.new(0, 0.55, 1.15) * CFrame.Angles(math.rad(-37), 0, 0)
	local A, B = Vector3.new(0, 0.5, 1.1), Vector3.new(0, -2.3, -2.6) -- the shaft, top -> head
	local function along(t)
		return A + (B - A) * t
	end
	local headC = Vector3.new(0, -2.45, -2.7) -- where the line turns
	if tier >= 2 then
		-- the second line, across the first one
		for s = -1, 1, 2 do
			add(m, "Part", { Name = "Line", Size = Vector3.new(0.03, 0.03, 1.1), Color = line, Material = M.Neon }, CFrame.new(headC + Vector3.new(0, 0, s * 0.4)))
		end
		add(m, "Part", { Name = "GuardSkirt", Size = Vector3.new(1.5, 0.3, 0.1), Color = body, Material = M.SmoothPlastic }, CFrame.new(0, -2.36, -2.06))
		add(m, "Part", { Name = "GuardBand", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.05, 1.44, 1.44), Color = CHROME, Material = M.Metal, Reflectance = 0.2 }, CFrame.new(0, -2.3, -2.75) * CFrame.Angles(0, 0, math.pi / 2))
		add(m, "Part", { Name = "Stripe", Size = Vector3.new(0.14, 0.57, 0.92), Color = Color3.fromRGB(250, 250, 250), Material = M.SmoothPlastic }, motorCF)
		rod(m, along(0.44), along(0.5), 0.26, CHROME, M.Metal, "Collar").Reflectance = 0.2
		add(m, "Part", { Name = "Gauge", Size = Vector3.new(0.47, 0.08, 0.2), Color = glowC, Material = M.Neon }, CFrame.new(0, 0.9, 1.45) * CFrame.Angles(math.rad(-37), 0, 0) * CFrame.new(0, 0.16, 0.1))
	end
	if tier >= 3 then
		local glowHead = add(m, "Part", { Name = "HeadGlow", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.1, 0.66, 0.66), Color = glowC, Material = M.Neon, Transparency = 0.1 }, CFrame.new(0, -2.53, -2.7) * CFrame.Angles(0, 0, math.pi / 2))
		add(m, "Part", { Name = "Blur", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.04, 1.9, 1.9), Color = line, Material = M.Neon, Transparency = 0.78 }, CFrame.new(headC) * CFrame.Angles(0, 0, math.pi / 2))
		for k = 0, 2 do
			rod(m, along(0.58 + k * 0.1), along(0.6 + k * 0.1), 0.24, glowC, M.Neon, "Ring")
		end
		for sx = -1, 1, 2 do
			add(m, "WedgePart", { Name = "Fin", Size = Vector3.new(0.06, 0.3, 0.6), Color = body, Material = M.SmoothPlastic }, motorCF * CFrame.new(sx * 0.31, 0.2, 0.1))
		end
		rod(m, (motorCF * CFrame.new(0, -0.38, 0.4)).Position, (motorCF * CFrame.new(0, -0.38, -0.4)).Position, 0.24, CHROME, M.Metal, "Booster")
		add(m, "Part", { Name = "BoosterGlow", Shape = Enum.PartType.Ball, Size = Vector3.new(0.22, 0.22, 0.22), Color = glowC, Material = M.Neon }, motorCF * CFrame.new(0, -0.38, 0.46))
		glow(m, glowHead, glowC, 6)
	end
	if tier >= 4 then
		-- the energy ring: eight glowing pieces round the head
		local R, N = 1.05, 8
		local prev = headC + Vector3.new(R, 0.06, 0)
		for k = 1, N do
			local a = k / N * math.pi * 2
			local p = headC + Vector3.new(math.cos(a) * R, 0.06, math.sin(a) * R)
			rod(m, prev, p, 0.08, if k % 2 == 0 then GOLD else glowC, M.Neon, "EnergyRing")
			prev = p
		end
		add(m, "Part", { Name = "GoldRim", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.07, 1.5, 1.5), Color = GOLD, Material = M.Metal, Reflectance = 0.3 }, CFrame.new(0, -2.21, -2.75) * CFrame.Angles(0, 0, math.pi / 2))
		for k = 0, 2 do
			rod(m, along(0.12 + k * 0.12), along(0.15 + k * 0.12), 0.23, GOLD, M.Metal, "GoldBand").Reflectance = 0.3
		end
		for sx = -1, 1, 2 do
			add(m, "WedgePart", { Name = "Wing", Size = Vector3.new(0.05, 0.5, 0.9), Color = GOLD, Material = M.Metal, Reflectance = 0.3 }, motorCF * CFrame.new(sx * 0.36, 0.05, 0.05) * CFrame.Angles(0, 0, sx * math.rad(-25)))
		end
		local gem = add(m, "Part", { Name = "Crown", Shape = Enum.PartType.Ball, Size = Vector3.new(0.26, 0.26, 0.26), Color = glowC, Material = M.Neon }, motorCF * CFrame.new(0, 0.36, -0.2))
		local sp = Instance.new("Sparkles")
		sp.SparkleColor = Color3.fromRGB(255, 225, 120)
		sp.Parent = gem
	end
end

-- v2.43 EVERY FINAL UPGRADE of the Leaf Blaster changes it (levels = data.Tools.Up.Blaster):
--   Pulse Power 5   red heavy muzzle brake with side vents and red stripes
--   Fire Rate 5     a ring of glowing rotor discs along the barrel + a second, shorter barrel
--   Pulse Size 5    the muzzle opens into a big glowing funnel
--   Energy 5        two fat glowing energy tanks on the back
local function blasterMaxed(m, levels, tier)
	local glowC = BLASTER_GLOW[tier] or BLASTER_GLOW[1]
	local function top(stat)
		return type(levels) == "table" and (tonumber(levels[stat]) or 0) >= 5
	end
	if top("Power") then
		local red = Color3.fromRGB(215, 50, 45)
		rod(m, Vector3.new(0, 0.38, -2.2), Vector3.new(0, 0.38, -2.62), 0.86, red, M.Metal, "PowerBrake")
		for sx = -1, 1, 2 do
			add(m, "Part", { Name = "PowerVent", Size = Vector3.new(0.06, 0.34, 0.5), Color = DARK, Material = M.Metal }, CFrame.new(sx * 0.44, 0.38, -2.4))
			add(m, "Part", { Name = "PowerStripe", Size = Vector3.new(0.05, 0.1, 1.5), Color = red, Material = M.SmoothPlastic }, CFrame.new(sx * 0.34, 0.5, -0.45))
		end
	end
	if top("Rate") then
		for k = 0, 2 do
			add(m, "Part", { Name = "RateRotor", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.08, 0.84, 0.84), Color = glowC, Material = M.Neon, Transparency = 0.2 }, CFrame.new(0, 0.38, -1.55 - k * 0.35) * CFrame.Angles(0, math.rad(90), 0))
		end
		rod(m, Vector3.new(0, 0.82, -1.0), Vector3.new(0, 0.82, -2.1), 0.2, CHROME_, M.Metal, "RateBarrel")
	end
	if top("Size") then
		local funnel = rod(m, Vector3.new(0, 0.38, -2.7), Vector3.new(0, 0.38, -3.15), 1.15, glowC, M.Neon, "SizeFunnel")
		funnel.Transparency = 0.45
		add(m, "Part", { Name = "SizeRing", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.1, 1.25, 1.25), Color = CHROME_, Material = M.Metal }, CFrame.new(0, 0.38, -2.7) * CFrame.Angles(0, math.rad(90), 0))
	end
	if top("Energy") then
		for sx = -1, 1, 2 do
			local tank = rod(m, Vector3.new(sx * 0.3, 0.55, 0.45), Vector3.new(sx * 0.3, 0.55, 1.25), 0.5, glowC, M.Neon, "EnergyTank")
			tank.Transparency = 0.3
			add(m, "Part", { Name = "TankCap", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.12, 0.56, 0.56), Color = DARK, Material = M.Metal }, CFrame.new(sx * 0.3, 0.55, 1.28) * CFrame.Angles(0, math.rad(90), 0))
		end
	end
end

-- Leaf Blaster: 2 Pro = a white stripe and chrome fins · 3 Turbo = glowing booster rings on
-- the barrel and a bigger core · 4 Legendary = gold bands, neon streaks and a crown
tierDecor.Blaster = function(m, tier)
	local glowC = BLASTER_GLOW[tier] or BLASTER_GLOW[1]
	if tier >= 2 then
		add(m, "Part", { Name = "Stripe", Size = Vector3.new(0.68, 0.06, 1.2), Color = Color3.fromRGB(250, 250, 250), Material = M.SmoothPlastic }, CFrame.new(0, 0.71, -0.5))
		for sx = -1, 1, 2 do
			add(m, "Part", { Name = "Fin", Size = Vector3.new(0.06, 0.34, 0.7), Color = CHROME_, Material = M.Metal }, CFrame.new(sx * 0.36, 0.42, 0.15))
		end
	end
	if tier >= 3 then
		for k = 0, 1 do
			add(m, "Part", { Name = "BoosterRing", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.1, 0.7, 0.7), Color = glowC, Material = M.Neon, Transparency = 0.1 }, CFrame.new(0, 0.38, -1.7 - k * 0.4) * CFrame.Angles(0, math.rad(90), 0))
		end
		local core = m:FindFirstChild("Core")
		if core then
			core.Size = Vector3.new(0.62, 0.62, 0.62)
			glow(m, core, glowC, 5)
		end
	end
	if tier >= 4 then
		for k = 0, 1 do
			add(m, "Part", { Name = "GoldBand", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.12, 0.64, 0.64), Color = GOLD, Material = M.Metal, Reflectance = 0.3 }, CFrame.new(0, 0.38, -1.45 - k * 0.8) * CFrame.Angles(0, math.rad(90), 0))
		end
		for k = 0, 1 do
			add(m, "Part", { Name = "Streak", Size = Vector3.new(0.05, 0.05, 1.3), Color = glowC, Material = M.Neon }, CFrame.new((k * 2 - 1) * 0.34, 0.5, -0.45))
		end
		add(m, "Part", { Name = "Crown", Shape = Enum.PartType.Ball, Size = Vector3.new(0.26, 0.26, 0.26), Color = glowC, Material = M.Neon }, CFrame.new(0, 0.98, -0.2))
	end
end

---------------------------------------------------------------- v2.43 grass tool tiers
--[[
	Shears, Grass Cutter, Scythe, Push Mower and Riding Mower have five tiers
	(ToolConfig.GrassTiers). Tier 1 is the plain tool; 2-4 are repainted (and get extra
	parts) here; tier 5 of the Scythe IS the Golden Scythe and tier 5 of the Riding Mower
	IS the Turbo Mower (their own builders above).
]]
local TIER_METAL = { STEEL, Color3.fromRGB(150, 158, 172), Color3.fromRGB(105, 170, 235), Color3.fromRGB(235, 120, 85), Color3.fromRGB(255, 215, 90) }
local TIER_ACCENT = { Color3.fromRGB(215, 50, 45), Color3.fromRGB(70, 130, 220), Color3.fromRGB(70, 190, 100), Color3.fromRGB(170, 90, 235), Color3.fromRGB(255, 205, 70) }
local TIER_GLOW = { Color3.fromRGB(200, 255, 190), Color3.fromRGB(190, 225, 255), Color3.fromRGB(130, 215, 255), Color3.fromRGB(255, 170, 110), Color3.fromRGB(255, 232, 130) }

local function sparkle(part, color)
	if part then
		local sp = Instance.new("Sparkles")
		sp.SparkleColor = color
		sp.Parent = part
	end
end

local function recolor(m, names, color, material, reflectance)
	for _, p in m:GetChildren() do
		if names[p.Name] and p:IsA("BasePart") then
			p.Color = color
			if material then
				p.Material = material
			end
			if reflectance then
				p.Reflectance = reflectance
			end
		end
	end
end

local tierPaint = {}
-- (tier 5 of the Shears / the Grass Cutter / the Push Mower = the "golden" one: every piece is in its tier colour)
tierPaint.Shears = function(m, tier)
	recolor(m, { Blade = true }, TIER_METAL[tier], M.Metal, 0.1 * tier)
	recolor(m, { Grip = true }, TIER_ACCENT[tier])
	recolor(m, { Edge = true }, TIER_GLOW[tier])
	if tier >= 4 then
		sparkle(m:FindFirstChild("Blade"), TIER_GLOW[tier])
		add(m, "Part", { Name = "Jewel", Shape = Enum.PartType.Ball, Size = Vector3.new(0.2, 0.2, 0.2), Color = TIER_GLOW[tier], Material = M.Neon }, CFrame.new(0, 0.2, -0.38))
	end
	if tier >= 3 then
		add(m, "Part", { Name = "Collar", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.34, 0.3, 0.3), Color = TIER_METAL[tier], Material = M.Metal }, CFrame.new(0, 0, -0.38))
	end
end
tierPaint.WeedCutter = function(m, tier)
	recolor(m, { Tooth = true, Blade = true }, TIER_METAL[tier], M.Metal, 0.1 * tier)
	recolor(m, { Edge = true }, TIER_GLOW[tier])
	recolor(m, { Grip = true }, TIER_ACCENT[tier])
	if tier >= 3 then
		recolor(m, { Shaft = true }, TIER_METAL[tier], M.Metal)
		add(m, "Part", { Name = "ShaftBand", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 0.3, 0.3), Color = TIER_ACCENT[tier], Material = M.Neon }, CFrame.new(0, -0.3, -1.2) * CFrame.Angles(0, 0, math.pi / 2))
	end
	if tier >= 4 then
		sparkle(m:FindFirstChild("Blade"), TIER_GLOW[tier])
	end
end
tierPaint.Scythe = function(m, tier)
	recolor(m, { Blade = true }, TIER_METAL[tier], M.Metal, 0.1 * tier)
	if tier >= 3 then
		recolor(m, { Snath = true, SideGrip = true }, Color3.fromRGB(70, 56, 46), M.Wood)
		for _, y in { 0.2, -1.4 } do
			add(m, "Part", { Name = "SnathBand", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.32, 0.3, 0.3), Color = TIER_ACCENT[tier], Material = M.Neon }, CFrame.lookAt(Vector3.new(0, y, 0.8 + (y - 1.3) / (-3.4) * (-2.5)), Vector3.new(0, y - 1, 0.8 + (y - 1.3) / (-3.4) * (-2.5) - 0.74)) * CFrame.Angles(0, math.rad(90), 0))
		end
	end
	if tier >= 4 then
		sparkle(m:FindFirstChild("Blade"), TIER_GLOW[tier])
	end
end
tierPaint.PushMower = function(m, tier)
	recolor(m, { Deck = true }, TIER_ACCENT[tier], if tier >= 5 then M.Metal else M.SmoothPlastic)
	if tier >= 5 then
		sparkle(m:FindFirstChild("Deck"), TIER_GLOW[tier])
	end
	recolor(m, { HandleBar = true }, TIER_METAL[tier], M.Metal)
	local deckC = Vector3.new(0, -2.55, -2.9)
	if tier >= 3 then
		add(m, "Part", { Name = "SideStripe", Size = Vector3.new(2.45, 0.1, 0.18), Color = TIER_GLOW[tier], Material = M.Neon }, CFrame.new(deckC + Vector3.new(0, 0.2, 0.55)))
	end
	if tier >= 4 then
		add(m, "Part", { Name = "Underglow", Size = Vector3.new(2.2, 0.06, 2.2), Color = TIER_GLOW[tier], Material = M.Neon, Transparency = 0.35 }, CFrame.new(deckC + Vector3.new(0, -0.27, 0)))
		add(m, "Part", { Name = "Fin", Size = Vector3.new(0.08, 0.6, 0.9), Color = TIER_METAL[tier], Material = M.Metal }, CFrame.new(deckC + Vector3.new(0, 1.0, 0.9)))
	end
end
tierPaint.RidingMower = function(m, tier, vehicle)
	local s = if vehicle then 1 else 0.55
	recolor(m, { Body = true, Hood = true }, ({ Color3.fromRGB(60, 150, 60), Color3.fromRGB(60, 110, 200), Color3.fromRGB(205, 70, 60), Color3.fromRGB(125, 70, 190) })[tier] or Color3.fromRGB(60, 150, 60), M.SmoothPlastic)
	recolor(m, { Deck = true, Stripe = true }, TIER_METAL[tier], M.Metal)
	if tier >= 3 then
		for _, sx in { -0.5, 0.5 } do
			rod(m, Vector3.new(sx * s, 1.9 * s, 2.4 * s), Vector3.new(sx * s, 2.7 * s, 2.65 * s), 0.26 * s, TIER_METAL[tier], M.Metal, "Exhaust")
		end
	end
	if tier >= 4 then
		add(m, "Part", { Name = "Spoiler", Size = Vector3.new(3 * s, 0.12 * s, 0.7 * s), Color = TIER_GLOW[tier], Material = M.Neon }, CFrame.new(0, 3.0 * s, 2.5 * s))
	end
end

-- v2.51: the Grass Salt — a glass shaker full of white crystals with a silver cap and a green
-- label crossed out in red
builders.GrassSalt = function(m)
	local h = handlePart(m)
	add(m, "Part", { Name = "Jar", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.3, 0.85, 0.85), Color = Color3.fromRGB(235, 245, 250), Material = M.SmoothPlastic, Transparency = 0.15 }, CFrame.new(0, 0.1, -0.3) * CFrame.Angles(0, 0, math.pi / 2))
	add(m, "Part", { Name = "Label", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.5, 0.87, 0.87), Color = Color3.fromRGB(90, 190, 90), Material = M.SmoothPlastic }, CFrame.new(0, 0.1, -0.3) * CFrame.Angles(0, 0, math.pi / 2))
	add(m, "Part", { Name = "Cross", Size = Vector3.new(0.62, 0.12, 0.9), Color = Color3.fromRGB(230, 60, 60), Material = M.Neon }, CFrame.new(0, 0.1, -0.3) * CFrame.Angles(0, 0, math.rad(40)))
	add(m, "Part", { Name = "Cap", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 0.9, 0.9), Color = STEEL, Material = M.Metal }, CFrame.new(0, 0.92, -0.3) * CFrame.Angles(0, 0, math.pi / 2))
	for i = -1, 1 do
		add(m, "Part", { Name = "Hole", Size = Vector3.new(0.1, 0.06, 0.1), Color = DARK, Material = M.SmoothPlastic }, CFrame.new(i * 0.2, 1.14, -0.3))
	end
	return h
end

-- (round 15) the Cow's Milk Bottle: a white bottle with a blue label, a short neck and a red cap
builders.MilkBottle = function(m)
	local h = handlePart(m)
	local MILK = Color3.fromRGB(250, 250, 245)
	add(m, "Part", { Name = "Bottle", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.0, 0.8, 0.8), Color = MILK, Material = M.SmoothPlastic }, CFrame.new(0, 0.2, -0.3) * CFrame.Angles(0, 0, math.pi / 2))
	add(m, "Part", { Name = "Label", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.42, 0.83, 0.83), Color = Color3.fromRGB(90, 160, 235), Material = M.SmoothPlastic }, CFrame.new(0, 0.15, -0.3) * CFrame.Angles(0, 0, math.pi / 2))
	add(m, "Part", { Name = "Shoulder", Shape = Enum.PartType.Ball, Size = Vector3.new(0.8, 0.8, 0.8), Color = MILK, Material = M.SmoothPlastic }, CFrame.new(0, 0.62, -0.3))
	add(m, "Part", { Name = "Neck", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 0.42, 0.42), Color = MILK, Material = M.SmoothPlastic }, CFrame.new(0, 1.0, -0.3) * CFrame.Angles(0, 0, math.pi / 2))
	add(m, "Part", { Name = "Cap", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.18, 0.5, 0.5), Color = Color3.fromRGB(225, 60, 55), Material = M.SmoothPlastic }, CFrame.new(0, 1.24, -0.3) * CFrame.Angles(0, 0, math.pi / 2))
	add(m, "Part", { Name = "Drop", Shape = Enum.PartType.Ball, Size = Vector3.new(0.22, 0.22, 0.22), Color = Color3.new(1, 1, 1), Material = M.SmoothPlastic }, CFrame.new(0, 0.15, -0.72))
	return h
end

---------------------------------------------------------------- API
function ToolModels.Has(id)
	return builders[id] ~= nil
end

-- tier (v1.7, optional): the blower's / vacuum's upgrade tier 1…4 (v2.41: the Lawn
-- Trimmer's too; the Rake's tiers are drawn by BroomModel.Build(…, tier))
-- v2.43: levels (data.Tools.Up[id], optional): what is maxed shows on the Leaf Blaster
local FIVE_TIERS = { Shears = true, WeedCutter = true, Scythe = true, PushMower = true, RidingMower = true }
function ToolModels.Build(id, kind, tier, levels)
	local m = newModel("LeafTool_" .. tostring(id))
	local f = builders[id]
	local h
	tier = math.clamp(math.floor(tonumber(tier) or 1), 1, if id == "Pickaxe" then #PICK_LOOK elseif FIVE_TIERS[id] then 5 else 4) -- (v2.38: the pickaxe has 5 · v2.43: so do the grass tools)
	-- v2.43: the last tier of the Scythe is the Golden Scythe, of the Riding Mower the Turbo Mower
	local look = id
	if id == "Scythe" and tier >= 5 then
		look = "GoldenScythe"
	elseif id == "RidingMower" and tier >= 5 then
		look = "TurboMower"
	end
	f = builders[look]
	if f then
		h = f(m, kind == "Vehicle", tier)
		if decor[look] then
			decor[look](m, kind == "Vehicle", tier) -- (v2.41: + tier, for the trimmer's colours)
		end
		if tierPaint[id] and tier > 1 and look == id then
			tierPaint[id](m, tier, kind == "Vehicle")
		end
		if id == "Blaster" then
			blasterMaxed(m, levels, tier)
		end
		if tierDecor[id] and tier > 1 then
			tierDecor[id](m, tier)
		end
		if tier > 1 then
			m:SetAttribute("Tier", tier)
		end
	else
		h = handlePart(m)
		add(m, "Part", { Name = "Box", Size = Vector3.new(0.8, 0.8, 0.8), Color = STEEL }, CFrame.new(0, 0, -0.5))
	end
	if not m.PrimaryPart then
		m.PrimaryPart = h
	end
	return m, h
end

return ToolModels
end)() end
ToolModels = mm()
local builtOk = 0
local function try(label, f)
	local ok, err = pcall(f)
	if not ok then print("FAIL", label, err) else builtOk += 1 end
end
for _, id in { "Shears", "WeedCutter", "Scythe", "PushMower", "RidingMower", "Trimmer", "Blower", "Vacuum", "Blaster", "Pickaxe" } do
	for tier = 1, 5 do
		for _, kind in { false, "Vehicle" } do
			-- (the original Trimmer's tier 3-4 extras use vector maths this tiny fake DOM does not have:
			-- they fail the same way on the untouched v41 file — not part of what is tested here)
			if (kind == false or id == "RidingMower") and not (id == "Trimmer" and tier >= 3) then
				try(id .. " tier " .. tier .. " " .. tostring(kind), function()
					local m, h = ToolModels.Build(id, kind or nil, tier, { Power = 5, Rate = 5, Size = 5, Energy = 5 })
					assert(m and h, "no model")
				end)
			end
		end
	end
end
local m = ToolModels.Build("Blaster", nil, 4, { Power = 5, Rate = 5, Size = 5, Energy = 5 })
local names = {}
for _, c in m:GetChildren() do names[c.Name] = (names[c.Name] or 0) + 1 end
print("blaster maxed parts:", names.PowerBrake, names.RateRotor, names.SizeFunnel, names.EnergyTank, " seg:", names.Seg1, names.Seg5, " pips:", names.Pip6)
local b = ToolModels.Build("Blower", nil, 1)
local bn = {} for _, c in b:GetChildren() do bn[c.Name] = true end
print("blower gauge:", bn.GaugeBack, bn.Seg1, bn.Seg5)
local g = ToolModels.Build("Scythe", nil, 5)
local gn = {} for _, c in g:GetChildren() do gn[c.Name] = true end
print("scythe tier5 uses golden builder (Snath, Blade):", gn.Snath, gn.Blade)
for _, id in { "BlasterBattery", "Gasoline", "RepairKit", "BlowerBattery", "VacuumBattery" } do
	local mm = ToolModels.Build(id)
	print((#mm:GetChildren() >= 6 and "PASS " or "FAIL ") .. id .. " is a real model (" .. #mm:GetChildren() .. " parts, not a white cube)")
end
for _, id in { "Shears", "WeedCutter", "PushMower" } do
	local t1, t5 = ToolModels.Build(id, nil, 1), ToolModels.Build(id, nil, 5)
	print((#t5:GetChildren() > #t1:GetChildren() and "PASS " or "FAIL ") .. id .. " tier 5 looks different from tier 1 (" .. #t1:GetChildren() .. " -> " .. #t5:GetChildren() .. " parts)")
end
print("built ok:", builtOk)
