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
