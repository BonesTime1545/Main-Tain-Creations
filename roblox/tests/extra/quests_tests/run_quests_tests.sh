#!/bin/bash
# usage: LUAU=/path/to/luau bash run_quests_tests.sh <dir with the exported .lua scripts (the patched new/ dir)>
# Round 13 quests: tiny Roblox stubs + the real QuestConfig / MetaConfig / DataSchema + quests_test.lua,
# joined into one file and run with the Luau interpreter (pure logic: calendar, streak, quest pick).
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
Random = { new = function(seed) local x = (math.floor(seed or 1) % 2147483646) + 1; local function nx() x = (x * 48271) % 2147483647; return x end; return { NextNumber = function() return nx() / 2147483647 end, NextInteger = function(_, a, b) return a + nx() % (b - a + 1) end } end }
require = function() return { Ids = { "en", "ru" } } end
warn = function(...) print("WARN", ...) end
task = { spawn = function() end, wait = function() end, delay = function() end }
STUB
for m in QuestConfig MetaConfig DataSchema; do
  echo "local function MOD_$m() return (function()"; cat "$D/$m.lua"; echo "end)() end"
done
cat "$HERE/quests_test.lua"
} > "$OUT"
echo "joined: $OUT" >&2
$LUAU "$OUT" || exit 1
