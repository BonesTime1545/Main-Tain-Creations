#!/bin/bash
# Runs every test on the scripts of the place, with the real Luau interpreter and tiny Roblox stubs.
#   ./run_all.sh [place.rbxl]            needs: luau (https://github.com/luau-lang/luau/releases) and
#                                        python3 with lz4 + zstandard (to read the place)
# The game's modules are joined with the stubs into one file per test (a generated "run_*.lua").
set -e
cd "$(dirname "$0")"
LUAU=${LUAU:-luau}
PLACE=${1:-../LeafRush_NEW_-_Islands_v42.rbxl}
SRC=$(mktemp -d)
python3 -s ../tools/export_scripts.py "$PLACE" "$SRC" >/dev/null
mod() { echo "local function $1() return (function()"; cat "$SRC/$2.lua"; echo "end)() end"; }
fail=0
run() { echo "=== $1"; if ! $LUAU "$2" > /tmp/lr_test_out.txt 2>&1 || grep -q '^FAIL\|FAILURES\|TOO CLOSE' /tmp/lr_test_out.txt; then fail=1; fi; cat /tmp/lr_test_out.txt; }
HTTP='game = { GetService = function() return { Heartbeat = { Connect = function() end }, JSONEncode = function() return "{}" end } end }
workspace = { GetServerTimeNow = function() return clock_ST or 0 end }'

# 1. the ladder of the grass tools, prices, the blower's max level
{ cat stubs.lua; echo 'local function ToolConfigModule()'; cat "$SRC/ToolConfig.lua"; echo; echo 'end'; echo 'T = ToolConfigModule()'; cat ladder_test.lua; cat island_test.lua; } > run_ladder.lua
run "ladder / prices / islands" run_ladder.lua
# 2. the server: blaster, durability, fuel, repair, abilities, upgrades
for t in service_test grass_test mow_test; do
  { cat stubs.lua; mod mc ToolConfig; echo 'TC_MODULE = mc()'; echo "$HTTP"; mod ms ToolService; echo 'SERVICE_MODULE = ms()'; cat $t.lua; } > run_$t.lua
  run "server: $t" run_$t.lua
done
# 3. the client: the pulse, the crashes, the magazine
{ cat client_stubs.lua; mod mc ToolConfig; echo 'TC_MODULE = mc()'; mod mt ToolController; echo 'CTL_MODULE = mt()'; cat client_test.lua; } > run_client.lua
run "client: blaster" run_client.lua
# 4. every model, every tier
{ cat stubs.lua; sed -n '1,/^CFrame = setmetatable/p' models_test.lua; mod mm ToolModels; echo 'ToolModels = mm()'; sed -n '/^local builtOk/,$p' models_test.lua; } > run_models.lua
run "models" run_models.lua
rm -rf "$SRC"
[ $fail = 0 ] && echo "ALL TESTS PASSED" || { echo "SOME TESTS FAILED"; exit 1; }
