#!/bin/bash
# usage: LUAU=/path/to/luau bash run_models_tests.sh <scripts dir>
# Builds EVERY tree at every level with the real ModelBuilder in a tiny fake DOM (catches nil errors in the looks)
# and prints the part counts (the new trees must stay in the range of the old ones).
HERE="$(cd "$(dirname "$0")" && pwd)"
LUAU=${LUAU:-luau}; D=$1
[ -d "$D" ] || { echo "usage: $0 <scripts dir>"; exit 2; }
OUT=$(mktemp --suffix=.lua)
mod() { echo "MODS[\"$1\"] = function() return (function()"; cat "$D/$1.lua"; echo; echo "end)() end"; }
{
cat "$HERE/stubs.lua"
cat "$HERE/dom_stubs.lua"
for m in TreeDropTables BaseResourceValues TreeTypes ModelBuilder; do mod $m; done
cat "$HERE/models_test.lua"
} > "$OUT"
$LUAU "$OUT"; rc=$?
rm -f "$OUT"
exit $rc
