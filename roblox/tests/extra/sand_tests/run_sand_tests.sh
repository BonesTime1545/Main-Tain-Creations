#!/bin/bash
# round 16 · sand: egg fates (IncubatorService) + the Owl's luck in PetService.Roll + the Sand Egg config.
# usage: LUAU=/path/to/luau bash run_sand_tests.sh <dir with the patched .lua scripts (new/)>
HERE="$(cd "$(dirname "$0")" && pwd)"; LUAU=${LUAU:-luau}; D=$1; OUT=$(mktemp --suffix=.lua)
{
cat <<'STUB'
local C3 = {}
function C3.fromRGB(r, g, b) return { R = r, G = g, B = b } end
function C3.new(r, g, b) return { R = r, G = g, B = b } end
Color3 = C3
function proxy() return setmetatable({}, { __index = function(t, k) local v = proxy(); rawset(t, k, v); return v end, __call = function() return proxy() end }) end
Enum = proxy(); Vector3 = proxy(); Vector2 = proxy(); NumberRange = proxy(); NumberSequence = proxy(); NumberSequenceKeypoint = proxy(); ColorSequence = proxy(); ColorSequenceKeypoint = proxy(); UDim2 = proxy()
CFrame = proxy(); Instance = proxy()
Random = { new = function(seed) if seed then math.randomseed(seed) end return { NextNumber = function(_, a, b) a = a or 0; b = b or 1; return a + (b - a) * math.random() end, NextInteger = function(_, a, b) return math.random(a, b) end } end }
game = { GetService = function() return { JSONEncode = function(_, t) local ks = {} for k, v in t do table.insert(ks, k .. "=" .. tostring(v)) end table.sort(ks) return table.concat(ks, ";") end, PromptTriggered = { Connect = function() end } } end }
warn = function(...) print("WARN", ...) end
task = { spawn = function() end, delay = function() end, wait = function() end }
STUB
echo 'local function PETCONFIG() return (function()'; cat "$D/PetConfig.lua"; echo 'end)() end'
echo 'local function PETSERVICE() return (function()'; cat "$D/PetService.lua"; echo 'end)() end'
echo 'local function INCUBATOR() return (function()'; cat "$D/IncubatorService.lua"; echo 'end)() end'
cat "$HERE/sand_test.lua"
} > $OUT
$LUAU $OUT
