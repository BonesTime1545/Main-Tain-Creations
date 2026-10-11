#!/bin/bash
# usage: LUAU=/path/to/luau bash run_pettext_test.sh <dir with PetConfig.lua and MutationConfig.lua> <pettext_test.lua>
LUAU=${LUAU:-luau}; D=$1; T=$2; OUT=$(mktemp)
{
cat <<'STUB'
local C3 = {}
function C3.fromRGB(r, g, b) return { R = r, G = g, B = b } end
function C3.new(r, g, b) return { R = r, G = g, B = b } end
Color3 = C3
function rgb(r, g, b) return Color3.fromRGB(r, g, b) end
local function proxy() return setmetatable({}, { __index = function(t, k) local v = proxy(); rawset(t, k, v); return v end, __call = function() return proxy() end }) end
Enum = proxy(); Vector3 = proxy(); Vector2 = proxy(); NumberRange = proxy(); NumberSequence = proxy(); NumberSequenceKeypoint = proxy(); ColorSequence = proxy(); ColorSequenceKeypoint = proxy(); UDim2 = proxy()
STUB
echo 'local function PETCONFIG() return (function()'; cat "$D/PetConfig.lua"; echo 'end)() end'
echo 'local function MUTCONFIG() return (function()'; cat "$D/MutationConfig.lua"; echo 'end)() end'
[ -n "$LR_ALL" ] && echo "ALL_PRINT = true"; cat "$T"
} > $OUT
echo $OUT >&2; $LUAU $OUT
