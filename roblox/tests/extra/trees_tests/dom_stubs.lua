-- a tiny fake DOM for ModelBuilder (parts are plain tables; CFrames are inert proxies)
local pmt2 = {}
local function px() return setmetatable({}, pmt2) end
pmt2.__index = function(t, k) return px() end
pmt2.__call = function() return px() end
for _, ev in { "__mul", "__add", "__sub", "__div", "__unm" } do pmt2[ev] = function() return px() end end
CFrame = setmetatable({ identity = px(), new = function() return px() end, Angles = function() return px() end, lookAt = function() return px() end, fromMatrix = function() return px() end }, { __index = function() return px() end })
local V3mt = getmetatable(Vector3.new(0, 0, 0))
V3mt.__index = function(v, k)
	if k == "Magnitude" then return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z) end
	if k == "Unit" then local m = math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z); return Vector3.new(v.X / m, v.Y / m, v.Z / m) end
	return nil
end
PARTS = 0
local Obj = {}
Obj.__index = Obj
function Obj:GetChildren() return self._kids end
function Obj:GetDescendants() local out = {} local function walk(o) for _, c in o._kids do table.insert(out, c); walk(c) end end walk(self) return out end
function Obj:FindFirstChild(n) for _, c in self._kids do if c.Name == n then return c end end return nil end
function Obj:FindFirstChildOfClass(n) for _, c in self._kids do if c.ClassName == n then return c end end return nil end
function Obj:IsA() return true end
function Obj:SetAttribute(k, v) self._attrs[k] = v end
function Obj:GetAttribute(k) return self._attrs[k] end
function Obj:Destroy() end
function Obj:ClearAllChildren() self._kids = {} end
Instance = { new = function(class)
	if class == "Part" then PARTS += 1 end
	local o = { ClassName = class, _kids = {}, _attrs = {}, Name = class, Transparency = 0, CFrame = px() }
	return setmetatable(o, { __index = Obj, __newindex = function(t, k, v)
		rawset(t, k, v)
		if k == "Parent" and type(v) == "table" and v._kids then table.insert(v._kids, t) end
	end })
end }
MODS["DecorTypes"] = function() return { Get = function() return nil end } end
MODS["Config"] = function() return { Plot = { CellSize = 5 } } end
MODS["DecorModels"] = function() return function() end end
warn = function() end
NumberSequenceKeypoint = setmetatable({}, { __index = function() return function() return px() end end })
ColorSequenceKeypoint = NumberSequenceKeypoint
UDim2 = NumberSequenceKeypoint
Random = { new = function(seed) local x = (math.floor(seed or 1) % 2147483646) + 1; local function nx() x = (x * 48271) % 2147483647; return x end; return { NextNumber = function(_, a, b) local r = nx() / 2147483647; if a then return a + (b - a) * r end return r end, NextInteger = function(_, a, b) return a + nx() % (b - a + 1) end } end }
