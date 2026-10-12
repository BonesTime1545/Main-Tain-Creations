-- round 15 · home: Home Egg, its pets, egg prices by island, the tool boost, the PetPowers hooks
local P = require({ __mod = "PetConfig" })
local T = require({ __mod = "ToolConfig" })
local PP = require({ __mod = "PetPowers" })
local R = require({ __mod = "RobuxConfig" })
local fails, checks = 0, 0
local function check(c, msg)
	checks += 1
	if not c then
		fails += 1
		print("FAIL " .. msg)
	end
end
local function near(a, b)
	return type(a) == "number" and math.abs(a - b) < 1e-9
end

-- 1. the egg
local egg = P.Eggs.HomeEgg
check(egg ~= nil and egg.Display == "Home Egg" and egg.Island == 2 and egg.Price == 8000, "Home Egg: island 2 (Cottage), 💰8,000")
local want = { HomeBunny = 50, HomePuppy = 20, HomeCat = 15, HomeHamster = 10, GoldenRetriever = 5 }
local sum = 0
for id, w in egg.Contents do
	sum += w
	check(want[id] == w, "weight " .. id)
	check(P.Pets[id] ~= nil and P.EggOf(id) == "HomeEgg", "pet exists and hatches from the Home Egg: " .. id)
	check(table.find(P.Order, id) ~= nil, "in P.Order: " .. id)
	check(P.Text(id, "Normal", 1, nil, "en") ~= "" and P.Text(id, "Rainbow", 10, nil, "ru") ~= "", "texts " .. id)
end
check(sum == 100, "contents sum to 100")
check(P.InShop("HomeEgg"), "sold in the shop")
check(P.ValidateEggs(), "ValidateEggs")
check(P.EggOrder[2] == "HomeEgg", "EggOrder: after the Starter Egg")
check(P.IncubateTime("HomeEgg") == 480, "incubates 8 min")
local names = { HomeBunny = "Bunny", HomePuppy = "Puppy", HomeCat = "Cat", HomeHamster = "Hamster", GoldenRetriever = "Golden Retriever" }
local rar = { HomeBunny = "Common", HomePuppy = "Uncommon", HomeCat = "Rare", HomeHamster = "Epic", GoldenRetriever = "Legendary" }
for id, n in names do
	check(P.Pets[id].Display == n and P.Pets[id].Rarity == rar[id], "name / rarity " .. id)
end
-- the shop: Home replaces its "coming soon" card; prices grow with the island
local list = P.ShopList(11)
local last = -1
for _, r in list do
	if r.Island == 2 then
		check(r.Egg == "HomeEgg", "island 2 shows the Home Egg (no soon card)")
	end
	if r.Egg then
		check(P.Eggs[r.Egg].Price > last, "price grows with the island: " .. r.Egg)
		last = P.Eggs[r.Egg].Price
	end
end
local price = { StarterEgg = 500, HomeEgg = 8000, RainEgg = 30000, ForestEgg = 90000, BlossomEgg = 220000, NightEgg = 3600000, FrostEgg = 9000000 }
for id, p in price do
	check(P.Eggs[id].Price == p, "price " .. id)
	local e = R.ItemProducts[P.Eggs[id].Display]
	check(e ~= nil and e.Robux == R.ForMoney(p), "Robux line = ForMoney(price): " .. id .. " " .. tostring(e and e.Robux))
end
-- island order of the level-up factor
check(P.EggRank("StarterEgg") == 1 and P.EggRank("HomeEgg") == 2 and P.EggRank("RainEgg") == 3 and P.EggRank("ForestEgg") == 4 and P.EggRank("BlossomEgg") == 5, "EggRank: island order")
check(P.EggRank("NightEgg") < P.EggRank("FrostEgg"), "EggRank Night < Frost")
-- the wheel's "egg of your island"
local W = require({ __mod = "WheelConfig" })
if W.EggForTier then
	check(W.EggForTier(P.Eggs, 2) == "HomeEgg", "wheel: island egg of tier 2 = Home Egg")
end

-- 2. the numbers (spec = Lvl 1; Lvl 10 = × 1.9)
local spec = {
	HomeBunny = { "Jump", { 0.03, 0.05, 0.08, 0.12 } },
	HomePuppy = { "Speed", { 0.03, 0.05, 0.08, 0.12 } },
	HomeCat = { "Chance", { 0.05, 0.1, 0.15, 0.2 } },
	HomeHamster = { "Pct", { 0.02, 0.04, 0.06, 0.08 } },
	GoldenRetriever = { "Tool", { 0.05, 0.1, 0.15, 0.2 } },
}
for id, sp in spec do
	for i, v in { "Normal", "Golden", "Diamond", "Rainbow" } do
		check(near(P.AbilityValue(id, v, sp[1], 1), sp[2][i]), id .. " " .. v .. " L1")
		check(near(P.AbilityValue(id, v, sp[1], 10), sp[2][i] * 1.9), id .. " " .. v .. " L10")
	end
end
for i, v in { "Normal", "Golden", "Diamond", "Rainbow" } do
	check(P.AbilityValue("HomeHamster", v, "Every", 1) == ({ 300, 240, 180, 120 })[i], "Hamster every " .. v)
end
-- Moon Wolf's speed is still NOT level-scaled
check(P.AbilityValue("MoonWolf", "Normal", "Speed", 10) == P.AbilityValue("MoonWolf", "Normal", "Speed", 1), "Moon Wolf speed unchanged")

-- 3. ToolConfig.Boosted / BoostStats
local g = T.GrassStats("Scythe", {})
check(T.Boosted(g, 1) == g, "mult 1 = same table")
local b = T.Boosted(g, 1.2)
check(b ~= g and near(b.Radius, g.Radius * 1.2) and near(b.Cooldown, g.Cooldown / 1.2), "Scythe: radius ×, cooldown ÷")
check(b.Durability == g.Durability and b.Tier == g.Tier and b.Display == g.Display, "Scythe: durability / tier / name kept")
check(b.Power <= 100 and near(b.Power, math.min(g.Power * 1.2, 100)), "Scythe: power ≤ 100")
local m = T.Boosted(T.GrassStats("PushMower", {}), 1.2)
check(m.Power == 100, "mower power stays 100")
local bl = T.Blaster({})
local bb = T.Boosted(bl, 1.1)
check(bb.Energy == bl.Energy and bb.Magazine == bl.Magazine and near(bb.FireEvery, bl.FireEvery / 1.1) and near(bb.Range, bl.Range * 1.1), "Blaster boost")
local v = T.Boosted(T.Vacuum({}), 1.1)
check(v.Capacity == T.Vacuum({}).Capacity and near(v.Range, T.Vacuum({}).Range * 1.1), "Vacuum: capacity kept")
local pk = T.Boosted(T.Pickaxe({}), 1.25)
check(near(pk.HitEvery, T.Pickaxe({}).HitEvery / 1.25) and near(pk.Reach, T.Pickaxe({}).Reach * 1.25) and pk.Durability == T.Pickaxe({}).Durability, "Pickaxe boost")
check(T.Pickaxe({}).Reach == 14, "the config table itself is untouched")
local st = T.BoostStats({ Power = 10, SweepSize = 62, Speed = 14 }, 1.05)
check(st.Power == 10.5 and st.SweepSize == 65.1 and st.Speed == 14.7, "BoostStats ×, 2 decimals")

-- 4. PetPowers with a tiny context
local equipped = {}
local data = { Stats = { LVEarned = 0 }, LeafValue = 0 }
local granted, fired = 0, nil
local root = { Position = Vector3.new(0, 3, 0), CFrame = setmetatable({}, { __mul = function() return { Position = Vector3.new(0, 0.4, 3.4) } end }) }
local player = { UserId = 1, Character = { FindFirstChild = function() return root end }, Attr = {}, SetAttribute = function(self, k, v) self.Attr[k] = v end, GetAttribute = function(self, k) return self.Attr[k] end }
local refreshed, published = 0, 0
local ctx = {
	PetAbilityService = { Equipped = function() return equipped end, AV = function(e, key) return P.AbilityValue(e.Id, e.Variant, key, e.Level, e.Boost) end },
	PlayerDataService = { Get = function() return data end },
	CurrencyService = { Grant = function(_, gift) granted += gift.LeafValue; return true end },
	OfflineService = { GardenIncome = function() return 6000 end },
	BroomSystem = { InOwnYard = function() return true end, Publish = function() published += 1 end },
	PlotSystem = { Get = function() return { CFrame = { Position = Vector3.new(0, 0, 0) } } end },
	GearService = { RefreshSpeed = function() refreshed += 1 end },
	Net = { GameEvent = { FireAllClients = function(_, kind, payload) fired = payload end } },
}
PP.Init(ctx)
local function eq(id, variant, level)
	table.insert(equipped, { Uid = id .. #equipped, Slot = #equipped + 1, Id = id, Variant = variant, Level = level or 1, Def = P.Pets[id] })
	PP.Refresh(player)
end
check(PP.SpeedMult(player) == 1 and PP.JumpMult(player) == 1 and PP.ToolMult(player) == 1, "nothing equipped: ×1")
eq("HomePuppy", "Golden")
eq("HomeBunny", "Rainbow")
eq("HomeBunny", "Normal")
eq("GoldenRetriever", "Diamond")
check(near(PP.SpeedMult(player), 1.05), "Puppy: speed through SpeedMult " .. PP.SpeedMult(player))
check(near(PP.JumpMult(player), 1.15), "two Bunnies stack: jump ×1.15 " .. PP.JumpMult(player))
check(PP.ToolMult(player) == 1.15, "Retriever: tool ×1.15")
eq("MoonWolf", "Normal")
check(near(PP.SpeedMult(player), 1.05 + P.AbilityValue("MoonWolf", "Normal", "Speed", 1)), "Puppy + Moon Wolf add up, no cap")
PP.HomeTick(player)
check(player.Attr.ToolBoost == 1.15 and published == 1 and refreshed == 1, "HomeTick publishes ToolBoost and refreshes speed / jump once")
PP.HomeTick(player)
check(published == 1 and refreshed == 1, "HomeTick: nothing changed, nothing sent")
-- the Hamster's pouch: Pct × the hourly income (earned over the window, never below the garden's)
equipped = {}
eq("HomeHamster", "Golden")
local e = equipped[1]
PP.HomeTick(player) -- first sample: earned 0
local ok = PP.Timed.Pouch(player, e)
check(ok == true and granted == math.floor(0.04 * 6000 + 0.5), "pouch from the garden income when nothing was earned: " .. granted)
check(fired and fired.Kind == "Pouch" and fired.Amount == granted, "FX event")
granted = 0
data.Stats.LVEarned = 60000
check(near(PP.HourlyIncome(player), 60000 / 60 * 3600), "hourly income = earned since the first sample × 3600 / span (span at least 60 s)")
PP.Timed.Pouch(player, e)
check(granted == math.floor(0.04 * 3600000 + 0.5), "pouch = 4% of the hourly income: " .. granted)

print(string.format("home tests: %d checks, %d failed", checks, fails))
print(if fails == 0 then "ALL HOME TESTS PASSED" else "HOME TESTS FAILED")
