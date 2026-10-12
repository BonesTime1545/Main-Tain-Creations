#!/bin/bash
# usage: LUAU=/path/to/luau bash run_farm_tests.sh <dir with the patched .lua scripts (new/)>
# Round 15 farm: the Sheep's Wool Ball price / mutations (PetPowers.WoolValue with the real MutationSystem).
HERE="$(cd "$(dirname "$0")" && pwd)"; LUAU=${LUAU:-luau}; D=$1
[ -d "$D" ] || { echo "usage: $0 <scripts dir>"; exit 2; }
OUT=$(mktemp --suffix=.lua)
{
cat <<'STUB'
local C3mt = {}
C3mt.__index = { Lerp = function(a) return a end }
Color3 = { fromRGB = function(r, g, b) return setmetatable({ R = r, G = g, B = b }, C3mt) end, new = function(r, g, b) return setmetatable({ R = r, G = g, B = b }, C3mt) end }
local pmt = {}
local function proxy() return setmetatable({}, pmt) end
pmt.__index = function(t, k) local v = proxy(); rawset(t, k, v); return v end
pmt.__call = function() return proxy() end
for _, ev in { "__mul", "__add", "__sub", "__div", "__unm" } do pmt[ev] = function() return proxy() end end
Enum = proxy(); Vector3 = proxy(); Vector2 = proxy(); NumberRange = proxy(); NumberSequence = proxy(); NumberSequenceKeypoint = proxy(); ColorSequence = proxy(); ColorSequenceKeypoint = proxy(); UDim2 = proxy(); CFrame = proxy()
Random = { new = function() return { NextNumber = function() return 0.5 end, NextInteger = function(_, a) return a end } end }
game = proxy(); workspace = proxy()
local LOADERS, LOADED = {}, {}
script = { Parent = { WaitForChild = function(_, n) return { __mod = n } end } }
require = function(m) local n = m.__mod; if LOADED[n] == nil then LOADED[n] = LOADERS[n]() end; return LOADED[n] end
STUB
for m in MutationConfig MutationSystem PetPowers; do
  echo "LOADERS.$m = function() return (function()"; cat "$D/$m.lua"; echo "end)() end"
done
cat "$HERE/farm_test.lua"
} > "$OUT"
$LUAU "$OUT"
