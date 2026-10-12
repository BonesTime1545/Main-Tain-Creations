#!/bin/bash
# usage: LUAU=/path/to/luau bash run_isl_tests.sh <dir with the patched .lua scripts (new/)>
# Round 14 isl: the 23-island ladder, palettes, aliases, the save migration (DataSchema.IslandRemap),
# the egg shop order (PetConfig.ShopList) and the wheel's island egg (WheelConfig.EggForTier).
HERE="$(cd "$(dirname "$0")" && pwd)"; LUAU=${LUAU:-luau}; D=$1
[ -d "$D" ] || { echo "usage: $0 <scripts dir>"; exit 2; }
OUT=$(mktemp --suffix=.lua)
{
cat <<'STUB'
local C3mt = {}
C3mt.__index = { Lerp = function(a, b, t) return setmetatable({ R = a.R + (b.R - a.R) * t, G = a.G + (b.G - a.G) * t, B = a.B + (b.B - a.B) * t }, C3mt) end }
Color3 = { fromRGB = function(r, g, b) return setmetatable({ R = r / 255, G = g / 255, B = b / 255 }, C3mt) end, new = function(r, g, b) return setmetatable({ R = r, G = g, B = b }, C3mt) end }
local pmt = {}
local function proxy() return setmetatable({}, pmt) end
pmt.__index = function(t, k) local v = proxy(); rawset(t, k, v); return v end
pmt.__call = function() return proxy() end
for _, ev in { "__mul", "__add", "__sub", "__div", "__unm" } do pmt[ev] = function() return proxy() end end
Enum = proxy(); Vector3 = proxy(); Vector2 = proxy(); NumberRange = proxy(); NumberSequence = proxy(); NumberSequenceKeypoint = proxy(); ColorSequence = proxy(); ColorSequenceKeypoint = proxy(); UDim2 = proxy(); UDim = proxy(); CFrame = proxy()
script = proxy()
game = proxy()
require = function() error("no require in tests") end
STUB
echo 'local function ICmod()'; cat "$D/IslandConfig.lua"; echo 'end'
echo 'local function DSmod()'; cat "$D/DataSchema.lua"; echo 'end'
echo 'local function PCmod()'; cat "$D/PetConfig.lua"; echo 'end'
echo 'local function WCmod()'; cat "$D/WheelConfig.lua"; echo 'end'
cat "${TESTFILE:-$HERE/isl_test.lua}"
} > "$OUT"
$LUAU "$OUT"; rc=$?; rm -f "$OUT"; exit $rc
