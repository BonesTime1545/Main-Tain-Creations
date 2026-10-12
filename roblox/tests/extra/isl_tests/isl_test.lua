local fails = 0
local function check(ok, msg) if not ok then fails += 1; print("FAIL " .. msg) end end
local I = ICmod()
local S = DSmod()
-- 1. the ladder
check(#I.Tiers == 23, "23 islands, got " .. #I.Tiers)
check(I.MaxTier == 11, "MaxTier 11")
local names = { "Meadow", "Cottage", "Swamp", "Forest", "FlowerMeadow", "Farm", "SpringForest", "DarkForest", "SnowyForest", "Mountains", "Desert",
	"Beach", "Jungle", "Underwater", "Volcano", "RoboLab", "MutatedForest", "Cave", "Space", "MagicForest", "Paradise", "Hell", "RainbowForest" }
for i, t in I.Tiers do
	check(t.Id == names[i], "island " .. i .. " is " .. tostring(t.Id))
	check(t.Soon == (i > 11), "Soon flag of " .. t.Id)
	check(type(t.Display) == "string" and type(t.Blurb) == "string" and type(t.Icon) == "string", "texts of " .. t.Id)
	check(type(t.Level) == "number" and type(t.Cost) == "number", "level/cost of " .. t.Id)
	if i > 1 then
		check(t.Level > I.Tiers[i - 1].Level, "levels rise at " .. t.Id)
		check(t.Cost > I.Tiers[i - 1].Cost, "costs rise at " .. t.Id)
		local r = t.Cost / math.max(I.Tiers[i - 1].Cost, 1)
		if i > 2 then check(r >= 2 and r <= 4, "smooth cost step at " .. t.Id .. " x" .. r) end
		-- 2. every island has its own complete palette
		local pal = I.PaletteOf(i)
		check(pal ~= nil, "palette of " .. t.Id)
		if pal then
			for _, k in { "Soil", "Rock", "Warm", "Deep", "Wood", "WoodDark", "Roof", "Leaf", "Glow", "Trim", "TrimPost", "Accent", "Water", "Grass", "Stem" } do
				check(pal[k] ~= nil, t.Id .. " palette has " .. k)
			end
			check(type(pal.Petals) == "table" and #pal.Petals >= 3, t.Id .. " petals")
		end
		check(I.Body[t.Id] ~= nil and I.Look[t.Id] ~= nil, t.Id .. " has its own Body + Look entry")
	end
end
check(I.PaletteOf(1) == nil and I.PreviewPalette(1) ~= nil, "the Meadow keeps the baked colours, has a preview")
-- palettes differ from island to island (soil + roof + grass)
local seen = {}
for i = 2, #I.Tiers do
	local p = I.PaletteOf(i)
	local key = string.format("%.3f %.3f %.3f|%.3f %.3f|%.3f", p.Soil.R, p.Soil.G, p.Soil.B, p.Roof.R, p.Roof.G, p.Grass.R)
	check(seen[key] == nil, "palette of " .. I.Tiers[i].Id .. " equals " .. tostring(seen[key]))
	seen[key] = I.Tiers[i].Id
end
-- 3. the old look ids resolve
for old, new in { FrostWoods = "SnowyForest", MapleTown = "Forest", GoldenGrove = "Farm", WillowLake = "Swamp", RoyalGarden = "FlowerMeadow", MutantSwamp = "MutatedForest", AncientWoods = "Forest", StarGarden = "Space", RainbowParadise = "RainbowForest", Volcano = "Volcano", DarkForest = "DarkForest", Meadow = "Meadow" } do
	check(I.ById[old] ~= nil and I.ById[old].Id == new, "old id " .. old .. " -> " .. new)
end
-- 4. trees of the islands
check(I.TreeTier("LeafTree") == 1 and I.TreeTier("AppleTree") == 6 and I.TreeTier("HarvestApple") == 6 and I.TreeTier("PearTree") == 2 and I.TreeTier("Baobab") == 11, "tree tiers")
check(I.TreeComingSoon("Palm") and I.TreeComingSoon("FireTree") and I.TreeComingSoon("StarTree") and not I.TreeComingSoon("Cactus"), "coming soon trees")
check(I.TreeXP("StarTree", 1) <= I.MaxTier, "a coming-soon tree's XP is capped")
check(I.Ground.W.Tier == 3 and I.Ground.S.Tier == 4, "water with the Swamp, sand stays at 4")
-- 5. the migration
for i = 1, 11 do
	check(S.IslandNewCum[i] == I.CumCost(i), "DataSchema.IslandNewCum[" .. i .. "] == IslandConfig.CumCost")
end
local prev = 0
for old = 1, 12 do
	local new, refund = S.IslandRemap(old)
	print(string.format("old tier %2d (paid %11d) -> new tier %2d %-14s refund %d", old, S.IslandOldCum[old], new, I.Tiers[new].Id, refund))
	check(new >= prev, "monotonic")
	check(new <= 11, "capped")
	check(I.CumCost(new) + refund <= S.IslandOldCum[old], "never more than paid")
	if old <= 11 then check(new == old, "old tier " .. old .. " keeps its number") end
	prev = new
end
local n11, r11 = S.IslandRemap(11)
local n12, r12 = S.IslandRemap(12)
check(n11 == 11 and r11 == 184905000 - 91898000, "old 11 refund")
check(n12 == 11 and r12 == 434905000 - 91898000, "old 12 refund")
check(S.IslandRemap(0) == 1 and S.IslandRemap(99) == 11 and S.IslandRemap("x") == 1, "bad input")
-- 5b. the migration inside DataSchema.Sanitize runs once
do
	local d = S.Defaults(); d.Island = { Tier = 12, Look = 7 }; d.LeafValue = 5
	S.Sanitize(d)
	check(d.Island.Tier == 11 and d.Island.Look == 0 and d.Island.V == 2 and d.LeafValue == 5 + 343007000 and d.Island.Refund == 343007000, "sanitize migrates a tier-12 save")
	S.Sanitize(d)
	check(d.Island.Tier == 11 and d.LeafValue == 5 + 343007000, "the migration runs once")
	local e = S.Defaults(); e.Island = { Tier = 5, Look = 3 }
	S.Sanitize(e)
	check(e.Island.Tier == 5 and e.Island.Look == 0 and e.Island.Refund == nil, "a tier-5 save keeps tier 5")
	local f = S.Defaults(); S.Reconcile(f); S.Sanitize(f)
	check(f.Island.Tier == 1 and f.Island.V == 2 and f.LeafValue == 0, "a new save")
end
-- 6. the egg shop
local P = PCmod()
local list = P.ShopList(I.MaxTier)
local got = {}
for _, r in list do table.insert(got, (r.Egg or ("soon:" .. r.Soon)) .. "@" .. r.Island) end
local want = "StarterEgg@1,HomeEgg@2,RainEgg@3,ForestEgg@4,BlossomEgg@5,FarmEgg@6,HarvestEgg@7,NightEgg@8,FrostEgg@9,soon:Wind Egg@10,soon:Sand Egg@11"
check(table.concat(got, ",") == want, "shop order: " .. table.concat(got, ","))
for _, id in { "FireEgg", "RobotEgg", "MutationEgg", "CelestialEgg", "GoldenEgg" } do
	check(not P.InShop(id) and P.Eggs[id] ~= nil, id .. " hidden but still exists")
end
check(P.Eggs.BlossomEgg.Display == "Flower Egg" and P.Eggs.CelestialEgg.Display == "Stardust Egg", "renamed eggs")
check(P.Eggs.CelestialEgg.Island == nil and P.Unobtainable.CelestialEgg == "BlossomEgg", "the Stardust Egg can't be obtained")
for id, e in P.Eggs do
	if e.Island then check(I.Tiers[e.Island] ~= nil, id .. " names a real island") end
	if e.Island and e.Island <= 11 then check(P.InShop(id), id .. " of a playable island is sold") end
end
-- 6b. nothing grants the old Celestial Egg any more
local W0 = WCmod()
for i, row in W0.Pass.Rewards do
	for _, side in { row.Free, row.Premium } do
		check(not (side and side.Egg and side.Egg[1] == "CelestialEgg"), "battle pass tier " .. i .. " gives no Celestial Egg")
	end
end
-- 7. the wheel's "egg of your island"
local W = WCmod()
local exp = { "StarterEgg", "HomeEgg", "RainEgg", "ForestEgg", "BlossomEgg", "FarmEgg", "HarvestEgg", "NightEgg", "FrostEgg", "FrostEgg", "FrostEgg" }
for tier = 1, 11 do
	check(W.EggForTier(P.Eggs, tier) == exp[tier], "island egg of tier " .. tier .. " = " .. W.EggForTier(P.Eggs, tier))
end
print(if fails == 0 then "ISL TESTS OK" else ("FAILURES: " .. fails))
