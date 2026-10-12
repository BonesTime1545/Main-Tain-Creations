#!/bin/bash
# round 15 · home: the Home Egg, its five pets, the egg prices, the Golden Retriever's tool boost.
# usage: LUAU=/path/to/luau bash run_home_tests.sh <dir with the patched .lua scripts (new/)>
HERE="$(cd "$(dirname "$0")" && pwd)"
LUAU=${LUAU:-luau}; D=$1
[ -d "$D" ] || { echo "usage: $0 <scripts dir>"; exit 2; }
OUT=$(mktemp --suffix=.lua)
{
cat <<'STUB'
local C3mt = {}
C3mt.__index = { Lerp = function(a) return a end, ToHex = function() return "ffffff" end }
Color3 = { fromRGB = function(r, g, b) return setmetatable({ R = r, G = g, B = b }, C3mt) end, new = function(r, g, b) return setmetatable({ R = r, G = g, B = b }, C3mt) end }
local V3 = {}
V3.__index = V3
V3.__add = function(a, b) return Vector3.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
V3.__sub = function(a, b) return Vector3.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
Vector3 = { new = function(x, y, z) return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V3) end }
local pmt = {}
local function proxy() return setmetatable({}, pmt) end
pmt.__index = function(t, k) local v = proxy(); rawset(t, k, v); return v end
pmt.__call = function() return proxy() end
for _, ev in { "__mul", "__add", "__sub", "__div", "__unm" } do pmt[ev] = function() return proxy() end end
Enum = proxy(); Vector2 = proxy(); NumberRange = proxy(); NumberSequence = proxy(); NumberSequenceKeypoint = proxy(); ColorSequence = proxy(); ColorSequenceKeypoint = proxy(); UDim2 = proxy(); UDim = proxy()
CFrame = { new = function(x, y, z) return { Off = Vector3.new(x, y, z) } end }
Random = { new = function() return { NextNumber = function(_, a, b) return (a or 0) + ((b or 1) - (a or 0)) * 0.5 end, NextInteger = function(_, a) return a end } end }
game = { GetService = function() return proxy() end }
workspace = { GetServerTimeNow = function() return 0 end }
warn = function(...) print("WARN", ...) end
task = { spawn = function() end, wait = function() end, delay = function() end, defer = function() end }
local LOADERS, LOADED = {}, {}
script = { Parent = { WaitForChild = function(_, n) return { __mod = n } end, FindFirstChild = function(_, n) return { __mod = n } end } }
require = function(m)
	local n = type(m) == "table" and m.__mod
	if n and LOADED[n] == nil then LOADED[n] = LOADERS[n]() end
	return n and LOADED[n] or proxy()
end
STUB
for m in PetConfig ToolConfig PetPowers RobuxConfig WheelConfig; do
  echo "LOADERS.$m = function() return (function()"; cat "$D/$m.lua"; echo "end)() end"
done
cat "$HERE/home_test.lua"
} > "$OUT"
$LUAU "$OUT"
