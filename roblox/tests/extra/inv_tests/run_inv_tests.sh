#!/bin/bash
# usage: LUAU=/path/to/luau bash run_inv_tests.sh <dir with the patched .lua scripts>
# Joins tiny Roblox stubs + Rarities, ToolConfig, BroomTypes, PetConfig, DecorTypes, DecorBoxConfig + inv_test.lua.
HERE="$(cd "$(dirname "$0")" && pwd)"
LUAU=${LUAU:-luau}; D=$1
[ -d "$D" ] || { echo "usage: $0 <scripts dir>"; exit 2; }
OUT=$(mktemp --suffix=.lua)
{
cat <<'STUB'
local C3mt = {}
C3mt.__index = { Lerp = function(a) return a end, ToHex = function() return "ffffff" end }
Color3 = { fromRGB = function(r, g, b) return setmetatable({ R = r, G = g, B = b }, C3mt) end, new = function(r, g, b) return setmetatable({ R = r, G = g, B = b }, C3mt) end }
local pmt = {}
local function proxy() return setmetatable({}, pmt) end
pmt.__index = function(t, k) local v = proxy(); rawset(t, k, v); return v end
pmt.__call = function() return proxy() end
for _, ev in { "__mul", "__add", "__sub", "__div", "__unm" } do pmt[ev] = function() return proxy() end end
Enum = proxy(); Vector3 = proxy(); Vector2 = proxy(); NumberRange = proxy(); NumberSequence = proxy(); NumberSequenceKeypoint = proxy(); ColorSequence = proxy(); ColorSequenceKeypoint = proxy(); UDim2 = proxy(); UDim = proxy(); CFrame = proxy()
game = { GetService = function() return proxy() end }
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
for m in Rarities ToolConfig BroomTypes PetConfig DecorTypes DecorBoxConfig; do
  echo "LOADERS.$m = function() return (function()"; cat "$D/$m.lua"; echo "end)() end"
done
cat "$HERE/inv_test.lua"
} > "$OUT"
$LUAU "$OUT"
