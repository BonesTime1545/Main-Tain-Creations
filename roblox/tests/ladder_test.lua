local order = { "Shears", "WeedCutter", "Scythe", "PushMower", "Trimmer", "RidingMower" }
local prev, fails = nil, 0
print("tool            base rate   max rate   base / previous max")
for _, id in order do
	local base = T.MowRate(id, {})
	local top = T.MowRate(id, T.TopLevels(id))
	local ratio = if prev then base / prev else 0
	local ok = not prev or ratio >= 1.25
	if not ok then fails += 1 end
	print(string.format("%-14s %8.1f %10.1f %14s %s", id, base, top, prev and string.format("%.2f", ratio) or "-", ok and "" or "  <-- TOO CLOSE"))
	prev = top
end
print("names: " .. table.concat(T.GrassTiers.Scythe.Names, " > ") .. " | " .. table.concat(T.GrassTiers.RidingMower.Names, " > "))
for _, id in order do
	local d = T.GrassStats(id, { Tier = 4 })
	local d0 = T.GrassStats(id, {})
	print(string.format("%-12s tier5 '%s' R %.2f P %.0f cd %s speed %s dur %s fuel %s ab %s", id, tostring(d.Display), d.Radius, d.Power, tostring(d.Cooldown), tostring(d.Speed), tostring(d.Durability), tostring(d.Fuel), tostring(d.AbCooldown)))
end
print("GoldenScythe/TurboMower still sold?", T.GrassTools.GoldenScythe, T.GrassTools.TurboMower, " in order:", table.find(T.GrassOrder, "GoldenScythe"))
print("price problems:", #T.CheckItemPrices())
for _, m in T.CheckItemPrices() do print("  " .. m); fails += 1 end
for _, id in order do local d = T.GrassTools[id]; print(string.format("%-12s %-10s %9d", id, d.Rarity, d.Price)) end
print("blaster", T.Helpers.Blaster.Rarity, T.Helpers.Blaster.Price, "upgrades:", T.UpgradeCost("Blaster","Power",0), T.UpgradeCost("Blaster","Power",4))
local BM = T.Blower({ Force = 5, Range = 5, Cone = 5, Energy = 5 })
print("blower maxed:", BM.Maxed, BM.IceDamage, BM.StoneNudge, "jet cd", BM.JetCooldown, " | not maxed:", T.Blower({ Force = 5 }).Maxed, T.Blower({}).JetCooldown)
print(fails == 0 and "LADDER OK" or ("FAILURES: " .. fails))
