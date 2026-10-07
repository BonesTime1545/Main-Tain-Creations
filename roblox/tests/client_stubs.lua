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
