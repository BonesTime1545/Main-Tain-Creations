#!/bin/bash
# usage: LUAU=/path/to/luau bash run_trees_tests.sh <dir with the exported .lua scripts (the patched new/ dir)>
# Round 14 trees: tiny Roblox stubs + the real TreeDropTables / BaseResourceValues / TreeTypes / ResourceTypes /
# ItemLooks (+ the sources of ModelBuilder and ru.lua as text) + trees_test.lua, joined into one file and run.
HERE="$(cd "$(dirname "$0")" && pwd)"
LUAU=${LUAU:-luau}; D=$1
[ -d "$D" ] || { echo "usage: $0 <scripts dir>"; exit 2; }
OUT=$(mktemp --suffix=.lua)
mod() { echo "MODS[\"$1\"] = function() return (function()"; cat "$D/$1.lua"; echo; echo "end)() end"; }
{
cat "$HERE/stubs.lua"
for m in TreeDropTables BaseResourceValues TreeTypes ResourceTypes ItemLooks QuestConfig; do mod $m; done
echo 'MB_SRC = [==========['; cat "$D/ModelBuilder.lua"; echo ']==========]'
echo 'RU_SRC = [==========['; cat "$D/ru.lua"; echo ']==========]'
cat "$HERE/trees_test.lua"
} > "$OUT"
$LUAU "$OUT"; rc=$?
rm -f "$OUT"
exit $rc
