-- tiny Roblox stubs (pure data modules only)
local C3mt = {}
C3mt.__index = { Lerp = function(a, b, t) return setmetatable({ R = a.R + (b.R - a.R) * t, G = a.G + (b.G - a.G) * t, B = a.B + (b.B - a.B) * t }, C3mt) end }
Color3 = { fromRGB = function(r, g, b) return setmetatable({ R = r / 255, G = g / 255, B = b / 255 }, C3mt) end, new = function(r, g, b) return setmetatable({ R = r, G = g, B = b }, C3mt) end }
local V3mt = {}
local function v3(x, y, z) return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V3mt) end
local function num(v) return type(v) == "number" end
V3mt.__add = function(a, b) return v3(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
V3mt.__sub = function(a, b) return v3(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
V3mt.__mul = function(a, b)
	if num(a) then return v3(a * b.X, a * b.Y, a * b.Z) end
	if num(b) then return v3(a.X * b, a.Y * b, a.Z * b) end
	return v3(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
V3mt.__div = function(a, b) return v3(a.X / b, a.Y / b, a.Z / b) end
V3mt.__unm = function(a) return v3(-a.X, -a.Y, -a.Z) end
Vector3 = { new = v3, one = v3(1, 1, 1), zero = v3(0, 0, 0) }
Vector2 = { new = function(x, y) return { X = x, Y = y } end }
local pmt = {}
local function proxy() return setmetatable({}, pmt) end
pmt.__index = function(t, k) local v = proxy(); rawset(t, k, v); return v end
pmt.__call = function() return proxy() end
for _, ev in { "__mul", "__add", "__sub", "__div", "__unm" } do pmt[ev] = function() return proxy() end end
Enum = proxy(); CFrame = proxy(); NumberRange = proxy(); NumberSequence = proxy(); ColorSequence = proxy()
MODS = {}
local loaded = {}
script = { Parent = { WaitForChild = function(_, n) return n end } }
function require(n)
	if loaded[n] == nil then
		assert(MODS[n], "no module " .. tostring(n))
		loaded[n] = MODS[n]()
	end
	return loaded[n]
end
