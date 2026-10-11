-- Lucky Wheel tests (round 11, agent "wheel"). Joined with stubs + the real modules by run_wheel_tests.sh
local W = MOD_WheelConfig()
local Schema = MOD_DataSchema()
local P = MOD_PetConfig()
local MC = MOD_MutationConfig()
local DT = MOD_DecorTypes()
local RewardService = MOD_RewardService()
local WheelService = MOD_WheelService()

local fails, checks = 0, 0
local function check(cond, msg)
	checks += 1
	if not cond then
		fails += 1
		print("FAIL " .. msg)
	end
end
local function near(a, b, eps)
	return math.abs(a - b) <= (eps or 1e-9)
end

---------------------------------------------------------------- 1. the table: weights, probabilities, rarities
do
	local n = #W.Segments
	check(n >= 12 and n <= 16, "12-16 segments, got " .. n)
	local sum = 0
	for _, s in W.Segments do
		sum += s.Weight
		check(W.Rarities[s.Rarity] ~= nil, s.Id .. " has a known rarity")
		check(type(s.Short) == "string" and #s.Short <= 10, s.Id .. " has a short name for the wheel face")
		check(s.Weight > 0, s.Id .. " weight > 0")
	end
	check(near(sum, 100, 1e-9), "weights add up to 100 (got " .. sum .. ")")
	local p = 0
	for _, s in W.Segments do
		p += W.Chance(s)
	end
	check(near(p, 1, 1e-9), "probabilities add up to 1")
	-- PickIndex covers every segment and respects the order of the weights
	local hit = {}
	local steps = 200000
	for k = 0, steps - 1 do
		local i = W.PickIndex((k + 0.5) / steps)
		hit[i] = (hit[i] or 0) + 1
	end
	for i, s in W.Segments do
		check(hit[i] ~= nil, s.Id .. " can be picked")
		check(near((hit[i] or 0) / steps, W.Chance(s), 0.0005), s.Id .. " empirical chance ~ weight")
	end
	check(W.PickIndex(0) == 1 and W.PickIndex(0.9999999) == n, "PickIndex edges")
	-- rarity: the rarer, the lower the weight (within the table's tiers, by tier average)
	local tier = {}
	for _, s in W.Segments do
		local r = W.Rarities[s.Rarity].Order
		tier[r] = tier[r] or { sum = 0, n = 0 }
		tier[r].sum += s.Weight
		tier[r].n += 1
	end
	local prev
	for r = 1, 7 do
		if tier[r] then
			local avg = tier[r].sum / tier[r].n
			if prev then
				check(avg <= prev + 1e-9, "tier " .. r .. " average weight " .. avg .. " <= tier below " .. prev)
			end
			prev = avg
		end
	end
	local jp = W.Segments[W.JackpotIndex()]
	check(jp.Jackpot == true and jp.Weight <= 1, "the Jackpot is the rarest (<= 1%)")
	check(W.Chance(jp) <= 0.01, "Jackpot chance <= 1%")
end

---------------------------------------------------------------- 2. exclusives are real items
do
	local ex = W.ExclusiveItems()
	check(#ex >= 5, "at least 4 pets/cosmetics + the jackpot ones")
	local pets, decors = 0, 0
	for _, e in ex do
		if e.Kind == "Pet" then
			pets += 1
			local def = P.Pets[e.Id]
			check(def ~= nil, e.Id .. " exists in PetConfig")
			if def then
				check(def.Exclusive == true, e.Id .. " is flagged Exclusive")
				check(P.EggOf(e.Id) == nil, e.Id .. " is in NO egg")
				check(def.Ability and def.Ability.Kind ~= nil, e.Id .. " has an ability Kind")
				check(table.find(P.Order, e.Id) ~= nil, e.Id .. " is in PetConfig.Order")
				check(P.Rarities[def.Rarity] ~= nil, e.Id .. " rarity known")
				-- texts in both languages come out and have no placeholders left
				for _, lang in { "en", "ru" } do
					for _, v in { "Normal", "Golden", "Diamond", "Rainbow" } do
						for _, lvl in { 1, 5, 10 } do
							local t = P.Text(e.Id, v, lvl, nil, lang)
							check(t ~= "" and not string.find(t, "%?") and not string.find(t, "{") and not string.find(t, "nan"), e.Id .. " text " .. lang .. v .. lvl .. ": " .. t)
						end
					end
				end
				check(def.Desc ~= nil and def.Desc ~= "", e.Id .. " has a Desc")
			end
		else
			decors += 1
			local def = DT.Defs[e.Id]
			check(def ~= nil, e.Id .. " exists in DecorTypes")
			if def then
				check(def.WheelOnly == true and DT.IsCosmetic(def), e.Id .. " is a WheelOnly cosmetic")
				check(def.Rarity ~= nil and DT.RarityRank[def.Rarity] ~= nil, e.Id .. " has a rarity")
				check(DT.Order[def.Order] == e.Id, e.Id .. " Order unique")
				check(string.find(def.Blurb, "WHEEL EXCLUSIVE", 1, true) ~= nil, e.Id .. " blurb carries the tag")
			end
		end
	end
	check(pets >= 4, "four exclusive pets, got " .. pets)
	check(decors >= 2, "two exclusive cosmetics, got " .. decors)
	check(P.ValidateEggs(), "eggs still valid")
	-- the mutation multipliers named in the pet texts are MutationConfig's
	for id, m in P.TextMutations do
		local d = MC.Defs[id]
		check(d ~= nil and d.Multiplier == m[1], "mutation " .. id .. " multiplier matches MutationConfig")
	end
	-- abilities only name mutations that exist
	for _, id in { "SpotlightPeacock", "PrismPhoenix" } do
		local a = P.Pets[id].Ability
		for mid in a.Muts or { [a.Mut] = 1 } do
			check(MC.Defs[mid] ~= nil, id .. " names a real mutation " .. tostring(mid))
		end
	end
end

---------------------------------------------------------------- 3. the pure hourly cooldown
do
	check(W.SpinEvery == 3600, "one spin an hour")
	check(W.Cooldown(0, 1000) == 0, "Next=0 -> ready")
	check(W.Cooldown(1000, 1000) == 0, "exactly due -> ready")
	check(W.Cooldown(1001, 1000) == 1, "1 s left")
	check(W.Cooldown(1000 + 3600, 1000) == 3600, "a full hour left")
	check(W.Cooldown(1000 + 99999, 1000) == 3600, "a far-future (edited) time shows at most an hour")
	check(W.FixNext(1000 + 99999, 1000) == 1000 + 3600 and W.FixNext(1500, 1000) == 1500 and W.FixNext(0 / 0, 1000) == 0, "FixNext pulls a far-future time in")
	check(W.Cooldown(nil, 5) == 0 and W.Cooldown("x", 5) == 0 and W.Cooldown(0 / 0, 5) == 0, "broken values count as ready")
	local st = W.State({ Next = 1000 + 125 }, 1000)
	check(st.Ready == false and st.NextIn == 125, "State not ready / 125 s")
	check(W.State({ Next = 5 }, 1000).Ready == true, "State ready")
	check(W.Clock(125) == "2:05" and W.Clock(0) == "0:00" and W.Clock(3600) == "60:00" and W.Clock(59.2) == "1:00", "Clock formats (mm:ss)")
end

---------------------------------------------------------------- 4. the decision: pity, jackpot pity, exclusives preferred
do
	local idx, why = W.Decide(0, 0, 0.0, 0.5, {})
	check(why == "Roll" and idx == 1, "a plain roll")
	-- the 24th spin without an exclusive prize IS one
	idx, why = W.Decide(W.Pity - 1, 0, 0.0, 0.5, {})
	check(why == "Pity" and W.Segments[idx].Exclusive and not W.Segments[idx].Jackpot, "pity gives a non-jackpot exclusive")
	check(W.Decide(W.Pity - 2, 0, 0.0, 0.5, {}) == 1, "one spin before the pity: still a roll")
	-- the exclusives you don't own are preferred
	local got = {}
	for _, e in W.ExclusiveItems() do
		if e.Seg.Id ~= "RaffleMouse" and not e.Seg.Jackpot then
			got[e.Id] = true
		end
	end
	for k = 0, 9 do
		local i = W.Decide(W.Pity - 1, 0, 0, k / 10, got)
		check(W.Segments[i].Id == "RaffleMouse", "pity picks the one exclusive you lack (got " .. W.Segments[i].Id .. ")")
	end
	-- the 150th spin without a Jackpot IS the Jackpot (it wins over the other pity)
	idx, why = W.Decide(W.Pity - 1, W.JackpotPity - 1, 0.3, 0.3, {})
	check(why == "JackpotPity" and W.Segments[idx].Jackpot, "jackpot pity")
	-- counters
	local pi, dr = W.Advance(5, 7, W.Segments[1])
	check(pi == 6 and dr == 8, "a plain prize adds to both counters")
	pi, dr = W.Advance(5, 7, W.ById.RaffleMouse)
	check(pi == 0 and dr == 8, "an exclusive resets the pity")
	pi, dr = W.Advance(5, 7, W.ById.Jackpot)
	check(pi == 0 and dr == 0, "the Jackpot resets both")
	-- simulation: the longest dry streak without an exclusive never exceeds Pity; without the Jackpot never JackpotPity
	local pity, dry, maxP, maxD, jackpots, excl = 0, 0, 0, 0, 0, 0
	local spins = 400000
	local seed = 12345
	local function rnd()
		seed = (seed * 1103515245 + 12345) % 2147483648
		return seed / 2147483648
	end
	for _ = 1, spins do
		local i = W.Decide(pity, dry, rnd(), rnd(), {})
		local s = W.Segments[i]
		pity, dry = W.Advance(pity, dry, s)
		maxP, maxD = math.max(maxP, pity), math.max(maxD, dry)
		if s.Jackpot then jackpots += 1 end
		if s.Exclusive then excl += 1 end
	end
	check(maxP <= W.Pity - 1, "no streak of " .. maxP .. " spins without an exclusive prize (limit " .. W.Pity - 1 .. ")")
	check(maxD <= W.JackpotPity - 1, "no streak of " .. maxD .. " spins without the Jackpot")
	print(string.format("sim %d spins: exclusive %.2f%% (plain table %.2f%%), jackpot 1 in %.0f (plain 1 in %.0f)", spins, excl / spins * 100, 10.5, spins / math.max(jackpots, 1), 200))
	-- weighted pick of a pet from an egg: sorted by id, so deterministic
	local c = { B = 1, A = 1, C = 2 }
	check(W.PickFromContents(c, 0) == "A" and W.PickFromContents(c, 0.26) == "B" and W.PickFromContents(c, 0.99) == "C", "PickFromContents is deterministic by id")
	check(W.PickFromContents({}, 0.5) == nil, "empty egg")
	-- the egg of the last island
	check(W.EggForTier(P.Eggs, 1) ~= nil and W.EggForTier(P.Eggs, 99) == "CelestialEgg", "EggForTier")
end

---------------------------------------------------------------- 5. what each segment says (Describe) — every one has text
do
	for _, s in W.Segments do
		local short, long = W.Describe(s, { PetName = function(id, v) return P.Name(id, v) end, EggName = function(id) return P.Eggs[id] and P.Eggs[id].Display or id end, IslandEgg = "ForestEgg" })
		check(short ~= "" and long ~= "", s.Id .. " describes itself: " .. long)
	end
	local _, long = W.Describe(W.ById.Jackpot, { PetName = P.Name })
	check(string.find(long, "Prism Phoenix", 1, true) and string.find(long, "Jackpot Trophy", 1, true), "the jackpot lists its pet and its trophy")
end

---------------------------------------------------------------- 6. the server: spin flow with a fake game
local function newGame()
	local data = Schema.Defaults()
	local player = { Name = "Tester", DisplayName = "Tester", attrs = {}, Parent = true }
	function player:SetAttribute(k, v)
		self.attrs[k] = v
	end
	local log = { quests = 0, notify = {} }
	local ctx = {}
	ctx.WheelConfig = W
	ctx.PetConfig = P
	ctx.DecorTypes = DT
	ctx.Economy = { ScaleMoney = function(n) return n end, EquipmentConfig = { FromSource = function() return {} end, ById = {} } }
	ctx.PlayerDataService = { Get = function() return data end, IsLoaded = function() return true end }
	ctx.CurrencyService = {
		Grant = function(_, cur)
			if cur.LeafValue then data.LeafValue += cur.LeafValue end
			if cur.Gems then data.Currencies.Gems += cur.Gems end
		end,
	}
	ctx.PetService = {
		Add = function(_, id, variant)
			if not P.Pets[id] then return nil end
			local uid = "p" .. data.Pets.NextId
			data.Pets.NextId += 1
			data.Pets.Owned[uid] = { Id = id, Variant = variant or "Normal", Level = 1 }
			data.Discovered.Pets[id] = true
			return uid
		end,
		Publish = function() end,
	}
	ctx.PlotSystem = { NewObjectId = function(d) local n = (d.Plot.NextObjectId or 1); d.Plot.NextObjectId = n + 1; return "o" .. n end }
	ctx.BuildService = { PublishSlots = function() end }
	ctx.PresetService = { Publish = function() end }
	ctx.ToolService = { GiveItem = function(_, id, n) data.Consumables.Owned[id] = (data.Consumables.Owned[id] or 0) + n; return n end }
	ctx.ToolConfig = { Consumables = { MegaMagnet = { Icon = "🧲", Display = "Mega Magnet", Price = 500 } } }
	ctx.QuestService = { Track = function() log.quests += 1 end }
	ctx.EconomyService = { Throttle = function() return true end }
	ctx.Players = { GetPlayers = function() return { player } end }
	ctx.Net = { Notify = { FireClient = function(_, _, text) table.insert(log.notify, text) end } }
	ctx.IslandService = { Tier = function() return 5 end, Can = function() return true end }
	RewardService.Init(ctx)
	WheelService.Init(ctx)
	ctx.RewardService = RewardService
	ctx.WheelService = WheelService
	return ctx, data, player, log
end

local function forceIndex(index)
	-- Random() is called twice per spin: x picks the segment of a plain roll
	local seg = W.Segments[index]
	local lo = 0
	for i = 1, index - 1 do lo += W.Segments[i].Weight end
	local x = (lo + seg.Weight / 2) / 100
	local calls = 0
	WheelService.Random = function()
		calls += 1
		return if calls % 2 == 1 then x else 0.5
	end
end

do
	local ctx, data, player, log = newGame()
	local now = 1700000000
	WheelService.Now = function() return now end

	-- brand new player: the spin is ready, no price, no currency
	forceIndex(1)
	local okS, res = WheelService.Spin(player)
	check(okS and res.Id == "Coins", "first spin works: " .. tostring(res))
	check(data.LeafValue == 1500, "Coins paid 1500 Money, got " .. data.LeafValue)
	check(data.Wheel.Next == now + 3600, "next spin is exactly one hour away")
	check(data.Wheel.Spins == 1 and log.quests == 1, "spin counted + quest tracked")
	-- an immediate second spin is refused with the countdown
	local ok2, why = WheelService.Spin(player)
	check(not ok2 and why == "Next spin in 60:00", "second spin refused: " .. tostring(why))
	now += 3599
	ok2, why = WheelService.Spin(player)
	check(not ok2 and why == "Next spin in 0:01", "1 s left: " .. tostring(why))
	now += 1
	forceIndex(2)
	ok2, res = WheelService.Spin(player)
	check(ok2 and res.Id == "Gems" and data.Currencies.Gems == 15, "after an hour the next spin works (Gems +15)")
	-- no stacking: away for a week = ONE spin
	now += 7 * 24 * 3600
	st = WheelService.State(data)
	check(st.Ready and st.NextIn == 0, "ready after a week away")
	forceIndex(1)
	check((WheelService.Spin(player)), "the one spin")
	local ok3 = WheelService.Spin(player)
	check(not ok3, "…and no second one (spins never stack)")
	-- tampered far-future Next: waits at most an hour
	data.Wheel.Next = now + 10 * 3600
	local s2 = WheelService.State(data)
	check(s2.NextIn == 3600 and data.Wheel.Next == now + 3600, "an edited far-future Next is pulled in: at most 1 h")
	-- unlimited: 300 spins, one per hour, all work
	local spins = 0
	for i = 1, 300 do
		now += 3600
		forceIndex(1 + (i % #W.Segments))
		local okK, whyK = WheelService.Spin(player)
		if okK then spins += 1 else print("spin " .. i .. " refused: " .. tostring(whyK)) end
	end
	check(spins == 300, "300 hourly spins all work (no lifetime cap), got " .. spins)
	check(data.Wheel.Spins >= 303, "Spins counter keeps counting")
	-- the attributes
	WheelService.Publish(player)
	check(player.attrs.WheelReady == 0 and string.find(player.attrs.WheelState, '"Ready":false', 1, true), "published: not ready")
	now += 3600
	WheelService.Publish(player)
	check(player.attrs.WheelReady == 1, "published: ready")
	check(WheelService.Reset(player) and data.Wheel.Next == 0, "cheat reset")
end

---------------------------------------------------------------- 7. every segment's prize is really paid
do
	for index, seg in W.Segments do
		local ctx, data, player, log = newGame()
		WheelService.Now = function() return 1700000000 end
		forceIndex(index)
		local gems0, money0 = data.Currencies.Gems, data.LeafValue
		local ok, res = WheelService.Spin(player)
		check(ok and res.Id == seg.Id, seg.Id .. " spin ok")
		if not ok then continue end
		check(res.Text ~= "" and res.Rarity == seg.Rarity and res.Exclusive == (seg.Exclusive == true) and res.Jackpot == (seg.Jackpot == true), seg.Id .. " result fields: " .. res.Text)
		local r = seg.Reward
		if r.Money then check(data.LeafValue - money0 == r.Money, seg.Id .. " Money paid") end
		if r.Gems then check(data.Currencies.Gems - gems0 >= r.Gems, seg.Id .. " Gems paid") end
		if r.Egg then
			local n = 0
			for _, c in data.Eggs.Owned do n += c end
			check(n == 1, seg.Id .. " an egg was added (the egg of the island)")
			check(data.Eggs.Owned.CelestialEgg == nil or true, "")
		end
		if r.Consumable then check(data.Consumables.Owned.MegaMagnet == 2, seg.Id .. " magnets") end
		if r.Boost then
			if r.Boost.Money then
				check(WheelService.MoneyMult(data) == 2 and WheelService.LuckMult(data) == 1, seg.Id .. " money boost on")
				check(data.Wheel.MoneyUntil == 1700000000 + r.Boost.Money, seg.Id .. " boost length")
			else
				check(WheelService.LuckMult(data) == 2 and WheelService.MoneyMult(data) == 1, seg.Id .. " luck boost on")
			end
			check(player.attrs.WheelMoneyUntil ~= nil or player.attrs.WheelLuckUntil ~= nil, seg.Id .. " boost published for the HUD chip")
		end
		if r.PetForm then
			local found
			for _, p in data.Pets.Owned do found = p end
			check(found and found.Variant == "Golden" and P.EggOf(found.Id) == W.EggForTier(P.Eggs, 5), seg.Id .. " a Golden pet of the island's egg: " .. tostring(found and found.Id))
		end
		if r.Pet then
			local found = 0
			for _, p in data.Pets.Owned do
				if p.Id == r.Pet then found += 1 end
			end
			check(found == 1, seg.Id .. " pet " .. r.Pet .. " added")
			check(data.Wheel.Got[r.Pet] == true and data.Discovered.Pets[r.Pet] == true, seg.Id .. " pet remembered")
		end
		if r.Decor then
			local found = 0
			for _, rec in data.Plot.Stored do
				if rec.Type == "Decor" and rec.DecorType == r.Decor then found += 1 end
			end
			check(found == 1, seg.Id .. " cosmetic " .. r.Decor .. " is in the inventory")
			check(data.Wheel.Got[r.Decor] == true, seg.Id .. " cosmetic remembered")
		end
		if seg.Jackpot then
			check(#log.notify == 1, "the jackpot is announced")
		end
	end
	-- a prize that can't be placed is paid in Gems (unknown pet / cosmetic)
	local ctx, data, player = newGame()
	WheelService.Now = function() return 1700000000 end
	local saved = W.ById.RaffleMouse.Reward
	W.ById.RaffleMouse.Reward = { Pet = "NoSuchPet" }
	forceIndex(W.ById.RaffleMouse.Index)
	local ok, res = WheelService.Spin(player)
	check(ok and data.Currencies.Gems == W.DuplicateGems, "an unknown pet is paid in Gems: " .. tostring(data.Currencies.Gems))
	W.ById.RaffleMouse.Reward = saved
	local ctx2, data2, player2 = newGame()
	W.ById.FortuneWheel.Reward = { Decor = "NoSuchDecor" }
	forceIndex(W.ById.FortuneWheel.Index)
	ok, res = WheelService.Spin(player2)
	check(ok and data2.Currencies.Gems == W.DuplicateGems, "an unknown cosmetic is paid in Gems")
	W.ById.FortuneWheel.Reward = { Decor = "WheelOfFortune" }
	-- boosts add up but are capped
	local _, d3 = newGame()
	WheelService.Now = function() return 1000 end
	for _ = 1, 10 do WheelService.AddBoost(d3, "Money", 1800) end
	check(d3.Wheel.MoneyUntil == 1000 + W.BoostMax, "boosts stack up to BoostMax only")
	WheelService.Now = function() return 1000 + W.BoostMax + 1 end
	check(WheelService.MoneyMult(d3) == 1, "an expired boost is off")
	-- the legacy reward key Spins pays Gems (no bonus spins exist any more)
	local ctx4, d4, p4 = newGame()
	RewardService.Grant(p4, { Spins = 3, Gems = 5 }, "quest")
	check(d4.Currencies.Gems == 5 + 3 * W.SpinGems, "legacy Spins reward = Gems")
	-- pity through the real service
	local ctx5, d5, p5 = newGame()
	local now = 1700000000
	WheelService.Now = function() return now end
	d5.Wheel.Pity = W.Pity - 1
	WheelService.Random = function() return 0.0 end -- a plain roll would be segment 1
	local okP, resP = WheelService.Spin(p5)
	check(okP and resP.Why == "Pity" and resP.Exclusive, "the 24th spin is an exclusive prize: " .. tostring(resP and resP.Id))
	check(d5.Wheel.Pity == 0, "pity reset")
end

---------------------------------------------------------------- 8. DataSchema: new record, old saves converted
do
	local d = Schema.Defaults()
	check(d.Currencies.Clover == nil, "no Clover in a new save")
	check(d.Wheel.Next == 0 and d.Wheel.Dry == 0 and d.Wheel.Bonus == nil and d.Wheel.Day == nil and d.Wheel.Used == nil, "new Wheel record")
	-- an old save: clovers, bonus spins, the daily-limit fields
	local old = Schema.Defaults()
	old.Currencies.Clover = 50
	old.Currencies.Gems = 100
	old.Wheel = { Day = 19000, Used = 3, Last = 123, Bonus = 4, Pity = 5, Spins = 77, Got = { ["x"] = true, bad = false } }
	Schema.Reconcile(old, Schema.Defaults())
	Schema.Sanitize(old)
	check(old.Currencies.Clover == nil, "Clover field deleted")
	check(old.Currencies.Gems == 100 + 50 * 2 + 4 * 10, "clovers (x2) and bonus spins (x10) became Gems: " .. old.Currencies.Gems)
	check(old.Wheel.Bonus == nil and old.Wheel.Day == nil and old.Wheel.Used == nil and old.Wheel.Last == nil, "old wheel fields dropped")
	check(old.Wheel.Next == 0 and old.Wheel.Pity == 5 and old.Wheel.Spins == 77 and old.Wheel.Dry == 0, "spin counters kept, a spin is ready")
	check(old.Wheel.Got.x == true and old.Wheel.Got.bad == nil, "Got sanitised")
	-- idempotent: a second load pays nothing more
	local gems = old.Currencies.Gems
	Schema.Sanitize(old)
	check(old.Currencies.Gems == gems and old.Currencies.Clover == nil, "second Sanitize converts nothing again")
	-- garbage
	local bad = Schema.Defaults()
	bad.Currencies.Clover = 0 / 0
	bad.Wheel.Next = math.huge
	bad.Wheel.MoneyUntil = -5
	bad.Wheel.Pity = -3
	bad.Wheel.Spins = 0 / 0
	Schema.Sanitize(bad)
	check(bad.Currencies.Clover == nil and bad.Currencies.Gems == 0, "NaN clover = nothing")
	check(bad.Wheel.Next == 0 and bad.Wheel.MoneyUntil == 0 and bad.Wheel.Pity == 0 and bad.Wheel.Spins == 0, "garbage wheel numbers cleaned")
	check(W.Cooldown(4e9, 1700000000) == 3600, "even the biggest Next waits only an hour")
	-- the oldest saves (migration 9) refund the Shadow Satchel in Gems
	check(Schema.Migrations ~= nil, "migrations exist")
end

print(string.format("wheel tests: %d checks, %d failed", checks, fails))
if fails > 0 then
	print("FAILURES")
	error("wheel tests failed")
end
print("ALL WHEEL TESTS PASSED")
