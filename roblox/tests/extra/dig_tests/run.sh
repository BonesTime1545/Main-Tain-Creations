#!/bin/bash
# SRC = dir with the exported scripts (new/), LUAU = luau interpreter
cd "$(dirname "$0")"
: "${SRC:?}"; export SRC
python3 -s gen.py t13_rules8.lua > /tmp/t13_run.lua && ${LUAU:-luau} /tmp/t13_run.lua
