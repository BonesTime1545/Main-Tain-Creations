#!/bin/bash
# runs every tN_*.lua of this folder against the scripts in $SRC with the luau interpreter $LUAU
cd "$(dirname "$0")"
LUAU=${LUAU:-luau}
: "${SRC:?set SRC to the folder with the exported .lua scripts}"
export SRC
for t in t2_random_pit t6_random_undo_smash t7_guard t8_blockmath t5_trace t10_bottom; do
	echo "=== $t"; python3 -s gen.py $t.lua > /tmp/dig_run_$t.lua && $LUAU /tmp/dig_run_$t.lua
done
echo "=== t4_island_carve (real island 1, rotated plot)"; ROT=1 python3 -s gen.py t4_island_carve.lua > /tmp/dig_run_t4.lua && $LUAU /tmp/dig_run_t4.lua
