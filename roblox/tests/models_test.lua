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
print("built ok:", builtOk)
