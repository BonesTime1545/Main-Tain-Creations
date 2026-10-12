#!/bin/bash
# usage: LUAU=/path/to/luau bash run_wheel_tests.sh <dir with the exported .lua scripts (the patched new/ dir)>
# Joins tiny Roblox stubs + the real modules (WheelConfig, WheelService, RewardService, DataSchema, PetConfig,
# MutationConfig, DecorTypes) + wheel_test.lua into one file and runs it with the Luau interpreter.
HERE="$(cd "$(dirname "$0")" && pwd)"
LUAU=${LUAU:-luau}; D=$1
[ -d "$D" ] || { echo "usage: $0 <scripts dir>"; exit 2; }
OUT=$(mktemp --suffix=.lua)
{
cat <<'STUB'
local C3mt = {}
C3mt.__index = { Lerp = function(a, b, t) return setmetatable({ R = a.R + (b.R - a.R) * t, G = a.G + (b.G - a.G) * t, B = a.B + (b.B - a.B) * t }, C3mt) end }
local C3 = {}
function C3.fromRGB(r, g, b) return setmetatable({ R = r / 255, G = g / 255, B = b / 255 }, C3mt) end
function C3.new(r, g, b) return setmetatable({ R = r, G = g, B = b }, C3mt) end
Color3 = C3
local pmt = {}
local function proxy() return setmetatable({}, pmt) end
pmt.__index = function(t, k) local v = proxy(); rawset(t, k, v); return v end
pmt.__call = function() return proxy() end
for _, ev in { "__mul", "__add", "__sub", "__div", "__unm" } do pmt[ev] = function() return proxy() end end
Enum = proxy(); Vector3 = proxy(); Vector2 = proxy(); NumberRange = proxy(); NumberSequence = proxy(); NumberSequenceKeypoint = proxy(); ColorSequence = proxy(); ColorSequenceKeypoint = proxy(); UDim2 = proxy(); UDim = proxy(); CFrame = proxy()
script = proxy()
local function jenc(v)
	if type(v) == "table" then
		local parts, keys = {}, {}
		for k in v do table.insert(keys, tostring(k)) end
		table.sort(keys)
		for _, k in keys do
			local val = v[k]
			if val == nil then val = v[tonumber(k)] end
			parts[#parts + 1] = '"' .. k .. '":' .. jenc(val)
		end
		return "{" .. table.concat(parts, ",") .. "}"
	end
	return type(v) == "string" and ('"' .. v .. '"') or tostring(v)
end
game = { GetService = function() return { JSONEncode = function(_, v) return jenc(v) end } end }
Random = { new = function() return { NextNumber = function() return math.random() end, NextInteger = function(_, a, b) return math.random(a, b) end } end }
warn = function(...) print("WARN", ...) end
task = { spawn = function() end, wait = function() end, delay = function() end }
STUB
for m in WheelConfig WheelService RewardService DataSchema PetConfig MutationConfig DecorTypes PetShapes DecorModels; do
  echo "local function MOD_$m() return (function()"; cat "$D/$m.lua"; echo "end)() end"
done
cat "$HERE/bpass_test.lua"
} > "$OUT"
echo "joined: $OUT" >&2
$LUAU "$OUT" || exit 1
