#!/bin/bash
# usage: run_offers.sh <dir with the exported .lua scripts (new/)> <luau binary>
SRC=${1:-new}; LUAU=${2:-luau}
OUT=$(mktemp)
mod() { echo "local function $1() return (function()"; cat "$SRC/$2.lua"; echo "end)() end"; }
{
cat <<'STUB'
local Players = { Connect = nil }
local PD = {}
Enum = { ProductPurchaseDecision = { NotProcessedYet = "NotProcessedYet", PurchaseGranted = "PurchaseGranted" } }
local services = {
	MarketplaceService = {}, RunService = { IsStudio = function() return false end },
	HttpService = { JSONEncode = function(_, t) return "{}" end, JSONDecode = function() return {} end },
	Players = { GetPlayerByUserId = function(self, id) return self.player end },
}
game = { GetService = function(_, n) return services[n] or {} end }
services.Players.PlayerRemoving = { Connect = function() end }
Players = services.Players
typeof = function(v) if type(v) == "table" and v.SetAttribute then return "Instance" end return type(v) end
STUB
mod RobuxConfigModule RobuxConfig; mod DataSchemaModule DataSchema; mod EconomyServiceModule EconomyService; mod MonetizationServiceModule MonetizationService
cat $(dirname "$0")/offers_test.lua
} > "$OUT"
$LUAU "$OUT" 2>&1 | grep -v "TEST\] LOADED"
rm -f "$OUT"
