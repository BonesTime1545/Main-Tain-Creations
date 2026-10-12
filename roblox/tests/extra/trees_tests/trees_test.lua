-- Round 14 trees: every tree has a model spec, price, island, drops, rarity; the island ladder is monotonic.
local TT = require("TreeTypes")
local RT = require("ResourceTypes")
local Values = require("BaseResourceValues")
local Looks = require("ItemLooks")

local fails, checks = 0, 0
local function ok(cond, msg)
	checks += 1
	if not cond then
		fails += 1
		print("FAIL " .. msg)
	end
end

local RARITIES = { Common = true, Uncommon = true, Rare = true, Epic = true, Legendary = true, Mythic = true, Ancient = true, Divine = true }
local SHAPES = { Bush = true, Cactus = true, Palm = true, Lily = true, Stump = true, Shroom = true }
local function mbHas(kind, name)
	return string.find(MB_SRC, kind .. ' == "' .. name .. '"', 1, true) ~= nil
end
local function ruHas(text)
	return string.find(RU_SRC, '["' .. text .. '"]', 1, true) ~= nil
end

-- 1. every tree: model spec, price, island, drops (with a value and an item look), rarity, texts
local seen = {}
for _, id in TT.Order do
	local def = TT.Get(id)
	ok(def ~= nil, id .. ": in Order but no def")
	if not def then
		continue
	end
	seen[id] = true
	ok(type(def.Display) == "string" and def.Display ~= "", id .. ": Display")
	ok(type(def.Blurb) == "string" and def.Blurb ~= "", id .. ": Blurb")
	ok(ruHas(def.Display), id .. ": no Russian for its name " .. tostring(def.Display))
	ok(ruHas(def.Blurb), id .. ": no Russian for its blurb")
	ok(type(def.Price) == "number" and def.Price >= 0 and (def.Price > 0 or def.Starter), id .. ": price")
	ok(type(def.Island) == "number" and def.Island >= 0 and def.Island <= 22, id .. ": island")
	ok(RARITIES[def.Rarity] == true, id .. ": rarity " .. tostring(def.Rarity))
	ok(type(def.BuildTime) == "number" and def.BuildTime > 0, id .. ": build time")
	ok(def.MaxLevel == 10 and #def.UpgradeCosts >= 9, id .. ": 10 levels and their upgrade costs")
	for L = 2, 9 do
		ok(def.UpgradeCosts[L] > def.UpgradeCosts[L - 1], id .. ": upgrade costs grow (" .. L .. ")")
	end
	-- the model: a Visual with bark + leaves, and every Deco / Extra / Shape / Form it names is built
	local V = def.Visual
	ok(type(V) == "table" and V.Bark ~= nil and type(V.Leaves) == "table" and #V.Leaves >= 2, id .. ": Visual")
	if V then
		if V.Shape then
			ok(SHAPES[V.Shape] == true, id .. ": unknown Shape " .. tostring(V.Shape))
		end
		if V.Deco then
			ok(mbHas("kind", V.Deco), id .. ": ModelBuilder has no Deco " .. V.Deco)
		end
		if V.Extra then
			ok(mbHas("extra", V.Extra), id .. ": ModelBuilder has no Extra " .. V.Extra)
		end
		if V.Form then
			ok(V.Form == "Cone" or V.Form == "Tiered" or V.Form == "Flame", id .. ": Form " .. V.Form)
		end
		-- (something of its own: a shape, a form, a deco or an extra)
		ok(V.Shape or V.Form or V.Deco or V.Extra, id .. ": no look of its own")
	end
	for L = 1, def.MaxLevel do
		local lv = TT.Level(def, L)
		ok(#lv.DropTable >= 1 and lv.ProductionTime > 0 and lv.ProductionAmount >= 1, id .. ": drop table L" .. L)
		for _, e in lv.DropTable do
			ok(type(Values[e.Resource]) == "number" and Values[e.Resource] > 0, id .. ": value of " .. tostring(e.Resource))
			ok(type(RT[e.Resource]) == "table", id .. ": ResourceTypes." .. tostring(e.Resource))
			ok(type(Looks.Kits[e.Resource]) == "table", id .. ": ItemLooks kit of " .. tostring(e.Resource))
			if type(RT[e.Resource]) == "table" then
				ok(ruHas(RT[e.Resource].Display), id .. ": no Russian for the item " .. RT[e.Resource].Display)
			end
		end
	end
end
-- every new tree of the island list exists with the exact id
for _, id in { "AppleTree", "PearTree", "WeepingWillow", "OakTree", "Sakura", "HarvestApple", "SpringTree", "DarkOak", "FrostTree", "MountainPine", "Baobab", "Cactus", "Palm", "FireTree", "MutationTree", "StarTree" } do
	ok(seen[id] == true, "missing tree " .. id)
end
-- the kept special / unlock trees
for _, id in { "Bush", "LeafTree", "MushroomStump", "StreetMaple", "PhoenixTree", "GoldTree", "GoldenWillow", "WaterLily", "RoyalTree", "MutantShroom", "AncientOak", "CrownTree" } do
	ok(seen[id] == true, "kept tree missing: " .. id)
end
-- the island list of the user
local expect = { LeafTree = 0, AppleTree = 5, HarvestApple = 5, PearTree = 1, WeepingWillow = 2, OakTree = 3, Sakura = 4, HarvestApple = 5, SpringTree = 6, DarkOak = 7, FrostTree = 8, MountainPine = 9, Baobab = 10, Cactus = 10, Palm = 11, FireTree = 14, MutationTree = 16, StarTree = 18 }
for id, isl in expect do
	ok(TT[id].Island == isl, id .. " should be on island " .. isl .. " (is " .. tostring(TT[id].Island) .. ")")
end
local names = { DarkOak = "Gloomy Tree", FrostTree = "Snowy Spruce", Palm = "Coconut Palm", FireTree = "Lava Tree", MutationTree = "Mutated Tree", StarTree = "Galactic Tree" }
for id, n in names do
	ok(TT[id].Display == n, id .. " should be called " .. n)
end

-- 2. the island ladder: the island's own tree, island by island
local function inc(id, L)
	return TT.IncomePerHour(TT[id], L) / 3600
end
local prevInc1, prevInc10, prevPrice, prevBuild, prevBest = 0, 0, 0, 0, 0
print(string.format("%-4s %-15s %12s %8s %10s %10s %9s", "isl", "tree", "price", "build", "$/s L1", "$/s L10", "payback"))
for i = 0, TT.OpenIsland do
	local id = TT.IslandTree[i]
	local def = TT[id]
	ok(def and def.Island == i, "IslandTree[" .. i .. "] = " .. tostring(id) .. " is on that island")
	local i1, i10 = inc(id, 1), inc(id, 10)
	print(string.format("%-4d %-15s %12d %7ds %10.1f %10.1f %8.0fm", i, def.Display, def.Price, def.BuildTime, i1, i10, def.Price / i1 / 60))
	ok(i1 > prevInc1, "island " .. i .. ": Lvl 1 💰/s must grow")
	ok(i10 > prevInc10, "island " .. i .. ": Lvl 10 💰/s must grow")
	ok(def.Price > prevPrice, "island " .. i .. ": price must grow")
	ok(def.BuildTime > prevBuild, "island " .. i .. ": build time must grow")
	-- right after buying island i, its own tree is the best 💰/s of everything sold on islands < i
	ok(i1 > prevBest, "island " .. i .. ": its tree beats every tree of the lower islands")
	-- and the best of its own island (the two big 3x3 specials excepted: Ancient Oak (one per garden), Crown Tree)
	local best = 0
	for _, other in TT.Order do
		local o = TT[other]
		if o.Island == i and not o.NotSold and not o.Starter then
			best = math.max(best, inc(other, 1))
			if other ~= id and other ~= "AncientOak" and other ~= "CrownTree" then
				ok(inc(other, 1) <= i1, other .. " (island " .. i .. ") must not beat " .. id .. " at Lvl 1")
				ok(inc(other, 10) <= i10 + 1e-6, other .. " (island " .. i .. ") must not beat " .. id .. " at Lvl 10")
			end
		end
	end
	prevInc1, prevInc10, prevPrice, prevBuild, prevBest = i1, i10, def.Price, def.BuildTime, best
end
-- smooth: no island jumps more than ×2.2 in income or ×3.2 in price
for i = 1, TT.OpenIsland do
	local a, b = TT[TT.IslandTree[i - 1]], TT[TT.IslandTree[i]]
	local r = inc(b.Id, 1) / inc(a.Id, 1)
	ok(r > 1.2 and r < 2.2, "island " .. i .. ": income step ×" .. string.format("%.2f", r))
	local p = b.Price / a.Price
	ok(p > 1.8 and p < 3.2, "island " .. i .. ": price step ×" .. string.format("%.2f", p))
end

-- 3. the island rule: sold only on an owned island; 11+ coming soon; owned trees are not the shop's business
ok(TT.IslandOpen(TT.LeafTree, 1) and not TT.IslandOpen(TT.AppleTree, 5) and TT.IslandOpen(TT.AppleTree, 6), "Leaf Tree open on tier 1, Apple Tree needs the Farm")
ok(not TT.IslandOpen(TT.PearTree, 1) and TT.IslandOpen(TT.PearTree, 2), "Pear Tree needs tier 2")
ok(not TT.IslandOpen(TT.Baobab, 10) and TT.IslandOpen(TT.Baobab, 11), "Baobab needs tier 11")
ok(not TT.IslandOpen(TT.StarTree, 23) and TT.ComingSoon(TT.StarTree), "Galactic Tree is coming soon")
ok(not TT.IslandOpen(TT.Palm, 99), "Coconut Palm is coming soon")
ok(TT.TierOf("OakTree") == 4, "Oak tier 4")
ok(string.find(TT.IslandLockText(TT.OakTree), "Forest", 1, true) ~= nil, "lock text names the island")
ok(TT.Sakura.QuestFree == true and TT.Cactus.QuestFree == true, "Sakura / Cactus are sold with their island")
ok(TT.IslandTree[0] == "LeafTree", "the Meadow's own tree is the Leaf Tree")
ok(TT.Bush.EvolvesTo == "LeafTree", "the starter Bush grows into the Leaf Tree")
ok(TT.Baobab.Ground == "Sand" and TT.Cactus.Ground == "Sand" and TT.Palm.Ground == "Sand", "beach / desert trees on SAND")
ok(TT.MountainPine.Ground == "Stone" and TT.FutureGround.CrystalTree == "Stone", "mountain / cave trees on STONE")

-- 4. every tree that is NOT an island's own tree is opened by an unlock quest shown on its island
local Q = require("QuestConfig")
local own = { FireTree = true, MutationTree = true, StarTree = true, Palm = true, Cactus = true, AppleTree = true, Bush = true }
for i = 0, TT.OpenIsland do
	own[TT.IslandTree[i]] = true
end
for _, id in TT.Order do
	local def = TT[id]
	if not own[id] then
		local u = Q.UnlockOfTree[id]
		if id == "PhoenixTree" then
			u = Q.UnlockById.u_phoenix
		end
		ok(u ~= nil, id .. ": needs an unlock quest")
		if u then
			ok(type(u.Show) == "table" and u.Show.Island == def.Island, id .. ": its quest is shown on island " .. tostring(def.Island))
			ok(Q.UnlockTier(u, {}) == def.Island + 1, id .. ": UnlockTier = its island's tier")
			ok(ruHas(u.Title) or ruHas(def.Display), id .. ": quest title in Russian")
			ok(type(u.Measure) == "table" and type(u.Measure.Kind) == "string", id .. ": measure")
			if u.Measure.Kind == "TreeAt" then
				ok(TT[u.Measure.Tree] ~= nil and TT[u.Measure.Tree].Island <= def.Island, id .. ": TreeAt names a tree of its island or before")
			elseif u.Measure.Kind == "Collected" then
				ok(type(RT[u.Measure.Res]) == "table", id .. ": Collected names a real item")
			end
		end
	end
end
for id in { Sakura = 1, Cactus = 1, Palm = 1 } do
	local u = Q.UnlockOfTree[id]
	ok(u and u.Show and u.Show.Island == TT[id].Island, id .. ": its free-sapling quest is on its island")
end
ok(mbHas("kind", "Pears") and mbHas("extra", "Weeping") and mbHas("extra", "Baobab") and mbHas("extra", "PineCones") and mbHas("kind", "Spring") and mbHas("kind", "Harvest") and mbHas("kind", "Acorns"), "the new looks are built")

print(string.format("%d checks, %d failures", checks, fails))
if fails > 0 then
	print("FAILURES")
	error("trees test failed")
end
print("TREES TEST OK")
