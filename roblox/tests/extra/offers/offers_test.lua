-- offers_test.lua — pure logic of SHOP offers / bundles / permanent x2 Money.
-- Run through tests/run_offers.sh (joins the game's modules: RobuxConfig, DataSchema, EconomyService, MonetizationService).
local fails, checks = 0, 0
local function check(cond, msg)
	checks += 1
	if not cond then
		fails += 1
		print("FAIL: " .. msg)
	end
end
local function eq(a, b, msg)
	check(a == b, msg .. " (got " .. tostring(a) .. ", want " .. tostring(b) .. ")")
end

local R = RobuxConfigModule()

---------------------------------------------------------------- the list
local nOffer, nBundle = 0, 0
local seenId, seenName = {}, {}
for _, o in R.Offers do
	check(not seenId[o.Id], "unique id " .. o.Id)
	check(not seenName[o.Name], "unique name " .. o.Name)
	seenId[o.Id], seenName[o.Name] = true, true
	check(R.OfferProducts[o.Name] ~= nil, "a product id line exists for " .. o.Name)
	check(type(o.Robux) == "number" and o.Robux > 0, "price of " .. o.Id)
	check(type(o.Desc) == "string" and o.Desc ~= "", "desc of " .. o.Id)
	if o.Kind == "Offer" then nOffer += 1 end
	if o.Kind == "Bundle" then
		nBundle += 1
		check(o.Worth and o.Worth > o.Robux, "bundle " .. o.Id .. " is worth more than it costs")
		check(#R.ContentsList(o) >= 4, "bundle " .. o.Id .. " lists its contents")
	end
end
for name in R.OfferProducts do
	check(R.OfferByName[name] ~= nil, "every product line names an offer: " .. name)
end
check(nOffer >= 8 and nOffer <= 14, "8-14 donate offers, got " .. nOffer)
check(nBundle >= 4, "bundles: " .. nBundle)
check(R.OfferById.Double and R.OfferById.Double.Once, "x2 exists and is one-time")
-- Id = 0 everywhere in the shipped config: nothing has a product yet
check(R.OfferProductOf(R.OfferById.Starter) == nil, "unset product = nil")

-- bundle totals
local st = R.ContentsTotals(R.OfferById.Starter)
eq(st.Gems, 200, "starter gems"); eq(st.Money, 100000, "starter money"); eq(st.Eggs, 2, "starter eggs"); eq(st.Tools, 1, "starter tools"); eq(st.BoostSeconds, 3600, "starter boost")
local mg = R.ContentsTotals(R.OfferById.Mega)
eq(mg.Gems, 1500, "mega gems"); eq(mg.Eggs, 4, "mega eggs"); eq(mg.Tools, 3, "mega tools"); eq(mg.BoostSeconds, 3 * 3 * 3600, "mega boosts")
local pp = R.ContentsTotals(R.OfferById.PetPack)
eq(pp.Eggs, 6, "pet pack eggs"); eq(pp.Items, 4, "pet pack toys")
for _, o in R.Offers do
	if o.Kind == "Bundle" then
		check(R.OfferRefundGems(o) >= o.Robux, "refund gems >= price for " .. o.Id)
	end
end
eq(R.DurationText(3600), "1 hour", "1 hour"); eq(R.DurationText(10800), "3 hours", "3 hours"); eq(R.DurationText(1800), "30 min", "30 min")
eq(R.Commas(1000000), "1,000,000", "commas"); eq(R.Commas(25000), "25,000", "commas 25k")

---------------------------------------------------------------- x2 applied ONCE
local now = 1000000
eq(R.MoneyMult(nil, now), 1, "no record")
eq(R.MoneyMult("junk", now), 1, "junk record")
eq(R.MoneyMult({}, now), 1, "empty record")
eq(R.MoneyMult({ Double = true }, now), 2, "forever x2")
eq(R.MoneyMult({ Double = false, Boosts = { Money2 = now + 60 } }, now), 2, "timed x2")
eq(R.MoneyMult({ Boosts = { Money2 = now - 1 } }, now), 1, "expired boost")
eq(R.MoneyMult({ Double = true, Boosts = { Money3 = now + 60 } }, now), 6, "x2 forever * x3 boost")
eq(R.MoneyMult({ Double = true, Boosts = { Money2 = now + 60, Money3 = now + 60 } }, now), 6, "two money boosts: the best one only, not 12")
eq(R.XPMult({ Boosts = { XP = now + 5 } }, now), 2, "xp boost"); eq(R.XPMult({ Double = true }, now), 1, "x2 money does not touch xp")
local lk = R.LuckBonus({ Boosts = { Luck = now + 5 } }, now)
eq(lk.PetLuck, 0.5, "luck boost pet luck"); eq(R.LuckBonus({}, now).PetLuck, 0, "no luck")
-- adding boosts
local O = { Boosts = {} }
eq(R.AddBoost(O, "Money2", 3600, now), now + 3600, "boost start")
eq(R.AddBoost(O, "Money2", 3600, now + 100), now + 7200, "a running boost is extended")
eq(R.AddBoost(O, "Money2", 30 * 86400, now), now + R.OfferBoostMaxSeconds, "capped at 7 days")
eq(R.AddBoost(O, "Bogus", 60, now), nil, "unknown boost"); eq(R.AddBoost(O, "XP", -5, now), nil, "negative seconds")

---------------------------------------------------------------- DataSchema sanitising
local S = DataSchemaModule()
local d = { Offers = { Double = "yes", Supporter = 1e9, Bundles = { Starter = 5, ["bad key!"] = 1, Neg = -3, Big = 1e12, Nan = 0 / 0 }, Boosts = { Money2 = 1e15, Luck = -4, Evil = 5, XP = 0 / 0 }, Junk = 1 } }
S.SanitizeOffers(d)
eq(d.Offers.Double, false, "Double must be exactly true"); eq(d.Offers.Supporter, 99, "supporter clamped")
eq(d.Offers.Bundles.Starter, 5, "bundle count kept"); eq(d.Offers.Bundles["bad key!"], nil, "bad key dropped"); eq(d.Offers.Bundles.Neg, nil, "negative dropped"); eq(d.Offers.Bundles.Big, 9999, "huge clamped"); eq(d.Offers.Bundles.Nan, nil, "nan dropped")
check(d.Offers.Boosts.Money2 <= os.time() + 8 * 86400, "boost end clamped"); eq(d.Offers.Boosts.Luck, nil, "negative boost dropped"); eq(d.Offers.Boosts.Evil, nil, "unknown boost dropped"); eq(d.Offers.Boosts.XP, nil, "nan boost dropped"); eq(d.Offers.Junk, nil, "unknown field dropped")
local d2 = {}
S.SanitizeOffers(d2)
check(d2.Offers and d2.Offers.Double == false and next(d2.Offers.Bundles) == nil, "missing record -> defaults")
local d3 = { Offers = { Double = true, Supporter = 2, Bundles = { Starter = 1 }, Boosts = { Luck = os.time() + 100 } } }
S.SanitizeOffers(d3); S.SanitizeOffers(d3)
check(d3.Offers.Double == true and d3.Offers.Supporter == 2 and d3.Offers.Bundles.Starter == 1 and d3.Offers.Boosts.Luck, "a valid record survives (twice)")
check(S.Defaults().Offers and S.Defaults().Offers.Double == false, "defaults have the Offers record")
check(R.OfferOwned(d3.Offers, R.OfferById.Double), "owned double"); check(R.OfferOwned(d3.Offers, R.OfferById.Starter), "owned starter (one-time)"); check(not R.OfferOwned(d3.Offers, R.OfferById.PetPack), "pet pack is never 'owned'")

---------------------------------------------------------------- EconomyService.ValueOf: the factor once
local Eco = EconomyServiceModule()
Eco.Init({
	ResourceTypes = { Leaf = { Value = 10 } },
	MutationTypes = { Get = function() return nil end, ItemValue = function(v, a) return v * a end, ClampValue = function(v) return v end },
	RobuxConfig = R,
})
local base = Eco.ValueOf({ Rebirth = { Multiplier = 1 }, Stats = {} }, "Leaf", nil, 3)
local dbl = Eco.ValueOf({ Rebirth = { Multiplier = 1 }, Stats = {}, Offers = { Double = true } }, "Leaf", nil, 3)
eq(base, 30, "plain value"); eq(dbl, 60, "x2 forever: exactly twice, once")
local both = Eco.ValueOf({ Rebirth = { Multiplier = 3 }, Stats = {}, Offers = { Double = true } }, "Leaf", nil, 3)
eq(both, 180, "x2 stacks multiplicatively with the rebirth multiplier")

---------------------------------------------------------------- MonetizationService: grant / refusal / receipts
local MS = MonetizationServiceModule()
local gems, money, eggs, notes = 0, 0, {}, {}
local data = {
	Robux = { Receipts = {}, Spent = 0 }, Stats = {}, Eggs = { Owned = {} }, Tools = { Owned = { Shears = true }, Grass = "Shears" },
	Rebirth = { Upgrades = {} },
}
local player = { SetAttribute = function(self, k, v) self[k] = v end }
local saved = 0
MS.Init({
	RobuxConfig = R,
	PlayerDataService = { Get = function() return data end, SaveNow = function() saved += 1 return true end },
	CurrencyService = { Grant = function(_, g, why) gems += g.Gems or 0; money += g.LeafValue or 0; check(why == "robux", "robux-gifts are labelled so (never counted as earnings)") return true end },
	PetConfig = { Eggs = { NightEgg = { Display = "Night Egg" }, GoldenEgg = { Display = "Golden Egg" }, CelestialEgg = { Display = "Celestial Egg" } } },
	ToolConfig = {
		KindOf = function(id) return (id == "Pickaxe" or id == "Rake") and "Helper" or "Grass" end,
		Def = function(id) return { Display = id, Icon = "T", Price = 1000 } end,
		Consumables = { TurboFuel = {}, GrassSalt = {}, RepairKit = {}, MediumToy = {}, BigToy = {} },
	},
	ToolService = { GiveItem = function(_, _, n) return n end, GiveTools = function() end, Publish = function() end },
	EndgameConfig = { BuildHeight = { Steps = { 1, 2, 3, 4, 5, 6, 7 }, Max = 8 } },
	UpgradeService = { BuildHeightLevel = function(dd) return dd.Rebirth.Upgrades.BuildHeight or 0 end, Publish = function() end },
	Net = { Notify = { FireClient = function(_, _, m) table.insert(notes, m) end } },
})
local studio = false
MS.IsStudio = function() return studio end
MS.Now = function() return 5000 end
R.StudioSimulate = true

local ok, msg = MS.OfferStart(player, "Double")
eq(ok, false, "live server, product id 0: refused"); eq(msg, "Not available yet", "…with the explanation")
check(data.Offers == nil or data.Offers.Double == false, "nothing granted")
ok, msg = MS.OfferStart(player, "nope")
eq(ok, false, "unknown offer"); 
studio = true
ok, msg = MS.OfferStart(player, "Double")
check(ok and data.Offers.Double == true, "Studio simulation grants the x2"); check(string.find(msg, "simulated") ~= nil, "…and says it is simulated")
eq(player.DoubleMoney, 1, "attribute DoubleMoney published")
check(player.OfferState ~= nil, "OfferState published")
ok, msg = MS.OfferStart(player, "Double")
eq(ok, false, "a second x2 is refused before any prompt"); eq(msg, "You already own it", "…with a message")
-- a receipt for an owned x2 (race) gives Gems, not a second x2
R.OfferProducts["2x Money Forever"] = 777
local Players = game:GetService("Players")
Players.player = player
local gemsBefore = gems
local dec = MS.ProcessReceipt({ PlayerId = 1, PurchaseId = "A1", ProductId = 777, CurrencySpent = 999 })
eq(dec, "PurchaseGranted", "receipt granted"); eq(gems - gemsBefore, 999 * 3, "owned x2 -> gems instead"); eq(data.Offers.Bought.Double, 1, "bought counter unchanged by a refund... only counted once")
local g2 = gems
dec = MS.ProcessReceipt({ PlayerId = 1, PurchaseId = "A1", ProductId = 777, CurrencySpent = 999 })
eq(dec, "PurchaseGranted", "same receipt again is idempotent"); eq(gems, g2, "…and gives nothing again")
-- a bundle through the receipt
R.OfferProducts["Starter Pack"] = 888
dec = MS.ProcessReceipt({ PlayerId = 1, PurchaseId = "B1", ProductId = 888, CurrencySpent = 149 })
eq(dec, "PurchaseGranted", "starter receipt"); eq(data.Offers.Bundles.Starter, 1, "starter marked as claimed")
eq(data.Eggs.Owned.NightEgg, 2, "2 night eggs"); check(data.Tools.Owned.Scythe == true, "scythe owned"); eq(data.Tools.Grass, "Scythe", "scythe is the better grass tool -> slot 2")
check(data.Offers.Boosts.Money2 == 5000 + 3600, "money boost running 1 hour")
eq(money, 100000, "starter money granted as a gift"); 
eq(player.BoostMoneyMult, 2, "boost attribute")
-- the same one-time pack again (new receipt): refunded as gems, nothing doubled
local eggsBefore, gb = data.Eggs.Owned.NightEgg, gems
dec = MS.ProcessReceipt({ PlayerId = 1, PurchaseId = "B2", ProductId = 888, CurrencySpent = 149 })
eq(dec, "PurchaseGranted", "second starter receipt handled"); eq(data.Eggs.Owned.NightEgg, eggsBefore, "no second set of eggs"); eq(gems - gb, 149 * 3, "gems instead")
ok, msg = MS.OfferStart(player, "Starter"); eq(ok, false, "one-time bundle refused after claiming")
-- a repeatable bundle stacks and a build-height bundle stops at the Robux-only step
R.OfferProducts["Pet Pack"] = 999
MS.ProcessReceipt({ PlayerId = 1, PurchaseId = "C1", ProductId = 999, CurrencySpent = 399 })
MS.ProcessReceipt({ PlayerId = 1, PurchaseId = "C2", ProductId = 999, CurrencySpent = 399 })
eq(data.Offers.Bundles.PetPack, 2, "pet pack can be bought again"); eq(data.Eggs.Owned.GoldenEgg, 6, "6 golden eggs after two pet packs")
check(data.Offers.Boosts.Luck == 5000 + 7200, "luck boosts add up")
data.Rebirth.Upgrades.BuildHeight = 6
R.OfferProducts["Builder Pack"] = 1010
local gb2 = gems
MS.ProcessReceipt({ PlayerId = 1, PurchaseId = "D1", ProductId = 1010, CurrencySpent = 299 })
eq(data.Rebirth.Upgrades.BuildHeight, 7, "build height capped below UNLIMITED (the last step is the 299 R$ product)")
check(gems - gb2 >= 150 + 100, "the step that did not fit became gems")
-- an unknown product goes to the original handler (tiers) — it returns NotProcessedYet there
local d4 = MS.ProcessReceipt({ PlayerId = 1, PurchaseId = "Z", ProductId = 424242, CurrencySpent = 1 })
eq(d4, "NotProcessedYet", "not an offer product: left to the tier code")
-- the receipt is saved before it is confirmed
check(saved >= 5, "SaveNow ran for every granted receipt")
-- a grant that fails entirely is retried
local data0 = data
R.OfferProducts["Cash Pack S"] = 1111
local prevGrant = MS.Init
-- (unknown player data)
Players.player = nil
eq(MS.ProcessReceipt({ PlayerId = 1, PurchaseId = "E1", ProductId = 1111, CurrencySpent = 50 }), "NotProcessedYet", "player gone: Roblox asks again")

print(string.format("offers_test: %d checks, %d failures", checks, fails))
if fails > 0 then
	print("FAILURES")
end
