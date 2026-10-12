-- Season 1 Battle Pass tests (round 13, agent "bpass"). Joined with stubs + the real modules by run_bpass_tests.sh
local W = MOD_WheelConfig()
local Schema = MOD_DataSchema()
local P = MOD_PetConfig()
local DT = MOD_DecorTypes()
local RewardService = MOD_RewardService()
local WheelService = MOD_WheelService()
local PS = W.Pass

local fails, checks = 0, 0
local function check(cond, msg)
	checks += 1
	if not cond then
		fails += 1
		print("FAIL " .. msg)
	end
end

---------------------------------------------------------------- 1. config + tier math
do
	check(PS.Tiers >= 30 and PS.Tiers <= 40, "30-40 tiers")
	check(#PS.Rewards == PS.Tiers, "one reward row per tier")
	check(PS.End - PS.Start == 30 * 86400, "the season lasts 30 days")
	check(W.PassTier(0) == 0 and W.PassTier(PS.TierXP - 1) == 0 and W.PassTier(PS.TierXP) == 1, "tier boundaries")
	check(W.PassTier(PS.TierXP * PS.Tiers * 5) == PS.Tiers, "tier capped at the last one")
	check(W.PassTier(-5) == 0 and W.PassTier(0 / 0) == 0 and W.PassTier(nil) == 0, "bad XP = tier 0")
	local into, need, t = W.PassProgress(PS.TierXP * 3 + 250)
	check(into == 250 and need == PS.TierXP and t == 3, "progress inside a tier")
	local _, need2 = W.PassProgress(PS.TierXP * PS.Tiers)
	check(need2 == 0, "no XP needed at the last tier")
	local f = W.PassSetFlag("", 5)
	check(f == "00001" and W.PassFlag(f, 5) and not W.PassFlag(f, 4) and not W.PassFlag(f, 6), "flags string")
	f = W.PassSetFlag(f, 2)
	check(f == "01001", "second flag keeps the first: " .. f)
	check(W.PassSetFlag(f, 2) == f, "setting twice is a no-op")
	check(W.PassOpen(PS.Start) and W.PassOpen(PS.End - 1) and not W.PassOpen(PS.Start - 1) and not W.PassOpen(PS.End), "open window [Start, End)")

	-- claim rules
	local now = PS.Start + 86400
	local st = { XP = PS.TierXP * 3, Premium = false, F = "", P = "" }
	check(W.PassCanClaim(st, "Free", 1, now), "free tier 1 claimable")
	check(W.PassCanClaim(st, "Free", 3, now), "free tier 3 claimable")
	local ok, why = W.PassCanClaim(st, "Free", 4, now)
	check(not ok and string.find(why, "tier 4"), "tier 4 not reached")
	ok, why = W.PassCanClaim(st, "Premium", 1, now)
	check(not ok and why == "Needs the Premium Pass", "premium needs the pass")
	check(not W.PassCanClaim(st, "Free", 0, now) and not W.PassCanClaim(st, "Free", 1.5, now) and not W.PassCanClaim(st, "Bogus", 1, now) and not W.PassCanClaim(st, "Free", PS.Tiers + 1, now), "bad tier / track refused")
	ok, why = W.PassCanClaim(st, "Free", 1, PS.End)
	check(not ok and why == "Season 1 is over", "closed after the end")
	ok = W.PassCanClaim(st, "Free", 1, PS.Start - 10)
	check(not ok, "closed before the start")
	st.F = W.PassSetFlag(st.F, 1)
	ok, why = W.PassCanClaim(st, "Free", 1, now)
	check(not ok and why == "Already claimed", "claimed once only")
	check(#W.PassClaimable(st, now) == 2, "two free left (tiers 2, 3)")
	-- premium is retroactive: buying it later unlocks the premium row of every tier already reached
	st.Premium = true
	check(#W.PassClaimable(st, now) == 5, "premium adds tiers 1-3 at once")
	check(#W.PassClaimable(st, PS.End + 1) == 0, "nothing after the season")

	-- every reward names things that exist
	local exPets, exDecor, title = 0, 0, false
	for i, row in PS.Rewards do
		for _, track in { "Free", "Premium" } do
			local r = row[track]
			check(type(r) == "table" and next(r) ~= nil, "tier " .. i .. " " .. track .. " has a reward")
			local lines = W.PassRewardLines(r)
			check(#lines >= 1, "tier " .. i .. " " .. track .. " has card lines")
			if r.Egg then
				check(r.Egg[1] == "Island" or P.Eggs[r.Egg[1]] ~= nil, "egg exists: " .. tostring(r.Egg[1]))
				check(r.Egg[1] == "Island" or (P.Eggs[r.Egg[1]] and true), "egg")
			end
			for _, e in r.Items or {} do
				check(PS.ItemNames[e[1]] ~= nil and e[2] > 0, "item named: " .. e[1])
			end
			for _, b in r.Boosts or {} do
				check(PS.BoostNames[b[1]] ~= nil and b[2] >= 3600, "boost known: " .. b[1])
			end
			if r.Pet then
				exPets += 1
				local def = P.Pets[r.Pet]
				check(def ~= nil and def.Exclusive == true and def.Source == "Pass", r.Pet .. " is a SEASON 1 exclusive pet")
				check(P.EggOf == nil or P.EggOf(r.Pet) == nil, r.Pet .. " is in no egg")
				check(table.find(P.Order, r.Pet) ~= nil, r.Pet .. " in PetConfig.Order")
				for _, lang in { "en", "ru" } do
					for _, lvl in { 1, 10 } do
						local t = P.Text(r.Pet, "Normal", lvl, nil, lang)
						check(t ~= "" and not string.find(t, "{") and not string.find(t, "nan"), r.Pet .. " text " .. lang .. lvl .. ": " .. t)
					end
				end
			end
			if r.Decor then
				exDecor += 1
				local def = DT.Defs[r.Decor]
				check(def ~= nil and def.PassOnly == true and def.WheelOnly == true and DT.IsCosmetic(def), r.Decor .. " is a pass-only cosmetic")
				check(def and string.find(def.Blurb, "SEASON 1 EXCLUSIVE", 1, true) ~= nil, r.Decor .. " blurb tag")
				check(def and def.Rarity ~= nil and DT.Order[def.Order] == r.Decor, r.Decor .. " rarity + unique order")
			end
			title = title or r.Title == true
		end
	end
	check(exPets == 3 and exDecor == 2 and title, "3 exclusive pets, 2 cosmetics and the title")
	-- the renamed peacock
	check(P.Pets.SpotlightPeacock.Display == "Peacock" and W.ById.SpotlightPeacock.Display == "PEACOCK", "Spotlight Peacock is now just Peacock (same id)")
end

---------------------------------------------------------------- 2. the server with a fake game
local function newGame(now)
	local data = Schema.Defaults()
	Schema.Sanitize(data)
	local player = { Name = "Tester", DisplayName = "Tester", attrs = {}, Parent = true, CharacterAdded = { Connect = function() end } }
	function player:SetAttribute(k, v)
		self.attrs[k] = v
	end
	local log = { notify = {}, contents = {} }
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
		Spend = function(_, cost)
			if (cost.Gems or 0) > data.Currencies.Gems then
				return false, "Need more Gems"
			end
			data.Currencies.Gems -= cost.Gems or 0
			return true
		end,
	}
	ctx.PetService = {
		Add = function(_, id, variant)
			local uid = "p" .. data.Pets.NextId
			data.Pets.NextId += 1
			data.Pets.Owned[uid] = { Id = id, Variant = variant or "Normal", Level = 1 }
			return uid
		end,
		Publish = function() end,
	}
	ctx.PlotSystem = { NewObjectId = function(d) local n = (d.Plot.NextObjectId or 1); d.Plot.NextObjectId = n + 1; return "o" .. n end }
	ctx.BuildService = { PublishSlots = function() end }
	ctx.PresetService = { Publish = function() end }
	ctx.MonetizationService = { GrantContents = function(_, c) table.insert(log.contents, c); return 1, { "ok" } end }
	ctx.EconomyService = { Throttle = function() return true end }
	ctx.Players = { GetPlayers = function() return { player } end }
	ctx.Net = { Notify = { FireClient = function(_, _, text) table.insert(log.notify, text) end } }
	ctx.IslandService = { Tier = function() return 5 end, Can = function() return true end }
	RewardService.Init(ctx)
	WheelService.Init(ctx)
	ctx.RewardService = RewardService
	ctx.WheelService = WheelService
	WheelService.Now = function() return now end
	return ctx, data, player, log
end

do
	local now = PS.Start + 3 * 86400 + 100
	local ctx, data, player, log = newGame(now)
	local pass = WheelService.PassOf(data)
	check(pass.XP == 0 and pass.Premium == false, "fresh pass")
	-- quests / daily give XP by reward reason (through RewardService.Grant)
	RewardService.Grant(player, { Money = 10 }, "quest")
	check(pass.XP == PS.XP.quest, "a claimed quest gives pass XP: " .. pass.XP)
	RewardService.Grant(player, { Money = 10 }, "daily")
	check(pass.XP == PS.XP.quest + PS.XP.daily, "the daily reward gives pass XP")
	RewardService.Grant(player, { Gems = 5 }, "daily")
	check(pass.XP == PS.XP.quest + PS.XP.daily, "a second part of the same daily claim gives no more pass XP")
	RewardService.Grant(player, { Gems = 1 }, "wheel")
	check(pass.XP == PS.XP.quest + PS.XP.daily, "other reasons give nothing")
	-- the play trickle is capped per day
	local before = pass.XP
	for _ = 1, 10000 do
		WheelService.PassTrack(player, "Clean", 1)
	end
	check(math.abs(pass.XP - before - PS.PlayCap) < 1e-6, "trickle capped at PlayCap per day: " .. (pass.XP - before))
	WheelService.PassTrack(player, "Strike", 1)
	check(math.abs(pass.XP - before - PS.PlayCap) < 1e-6, "untracked kinds give nothing")
	-- claims
	pass.XP = PS.TierXP * 10 + 5
	local gems0 = data.Currencies.Gems
	local ok, msg = WheelService.PassClaim(player, "Free", 1)
	check(ok, "claim free 1: " .. tostring(msg))
	check(data.Currencies.Gems == gems0 + PS.Rewards[1].Free.Gems, "free 1 paid gems")
	ok = WheelService.PassClaim(player, "Free", 1)
	check(not ok, "no double claim")
	ok, msg = WheelService.PassClaim(player, "Premium", 1)
	check(not ok and msg == "Needs the Premium Pass", "premium refused without the pass")
	ok = WheelService.PassClaim(player, "Free", 11)
	check(not ok, "tier 11 not reached")
	-- tier 5 = the free exclusive cosmetic
	local stored = 0
	for _ in data.Plot.Stored do stored += 1 end
	ok = WheelService.PassClaim(player, "Free", 5)
	local stored2 = 0
	for _, rec in data.Plot.Stored do
		stored2 += 1
	end
	check(ok and stored2 == stored + 1, "the Season Banner went into the inventory")
	-- gems: not enough, then enough
	data.Currencies.Gems = 10
	ok = WheelService.PassBuyGems(player)
	check(not ok and pass.Premium == false, "not enough gems")
	data.Currencies.Gems = PS.GemPrice + 7
	ok = WheelService.PassBuyGems(player)
	check(ok and pass.Premium == true and data.Currencies.Gems == 7, "premium bought with gems")
	ok, msg = WheelService.PassBuyGems(player)
	check(not ok and msg == "You already own the Premium Pass", "no second premium")
	-- retroactive: premium tier 1 is claimable now; tier 10 premium = the falcon
	ok = WheelService.PassClaim(player, "Premium", 1)
	check(ok, "premium tier 1 after buying")
	ok = WheelService.PassClaim(player, "Premium", 10)
	local falcons = 0
	for _, p in data.Pets.Owned do if p.Id == "LaurelFalcon" then falcons += 1 end end
	check(ok and falcons == 1, "the Laurel Falcon from premium tier 10")
	-- claim all takes the rest (tiers 2-10, minus the claimed ones)
	local left = #W.PassClaimable(pass, now)
	ok, msg = WheelService.PassClaimAll(player)
	check(ok and #W.PassClaimable(pass, now) == 0 and left == 9 + 7, "claim all (" .. left .. "): " .. tostring(msg))
	check(#log.contents >= 3, "items / boosts / height go through MonetizationService.GrantContents")
	ok = WheelService.PassClaimAll(player)
	check(not ok, "nothing left to claim")
	check(player.attrs.PassReady == 0 and type(player.attrs.PassState) == "string", "published state + badge")
	-- a Robux receipt while premium is owned: refund in gems
	local g = data.Currencies.Gems
	ok = WheelService.PassGrantPremium(player, 0, 500)
	check(ok and data.Currencies.Gems == g + 500, "duplicate receipt refunded as gems")
	-- the last tier: the lion + the title
	pass.XP = PS.TierXP * PS.Tiers
	ok = WheelService.PassClaim(player, "Premium", PS.Tiers)
	check(ok and pass.Title == "S1" and player.attrs.PassTitle == PS.TitleText, "the champion title")
	-- the season ends
	WheelService.Now = function() return PS.End + 5 end
	local xp = pass.XP
	pass.XP = PS.TierXP * 20
	xp = pass.XP
	RewardService.Grant(player, { Gems = 1 }, "quest")
	check(pass.XP == xp, "no XP after the season")
	ok, msg = WheelService.PassClaim(player, "Free", 15)
	check(not ok and msg == "Season 1 is over", "no claims after the season")
	ok = WheelService.PassBuyGems(player)
	check(not ok, "no buying after the season")
end

do
	-- Premium + 10 tiers (Robux)
	local _, data, player = newGame(PS.Start + 100)
	local ok = WheelService.PassGrantPremium(player, 10, 0)
	local pass = WheelService.PassOf(data)
	check(ok and pass.Premium and W.PassTier(pass.XP) == 10, "premium + 10 tiers")
	-- the season record of another season starts over (the title stays)
	data.Pass = { Season = 0, XP = 99999, Premium = true, F = "111", P = "111", Title = "S1" }
	pass = WheelService.PassOf(data)
	check(pass.XP == 0 and pass.Premium == false and pass.F == "" and pass.Title == "S1", "another season's record resets")
end

---------------------------------------------------------------- 3. the save
do
	local d = { Pass = { Season = "x", XP = 0 / 0, Premium = "yes", F = "10a1", P = string.rep("1", 200), Day = {}, DayXP = -4, Title = string.rep("x", 40) } }
	local p = Schema.SanitizePass(d)
	check(p.Season == 1 and p.XP == 0 and p.Premium == false and p.F == "" and p.P == "" and p.Day == -1 and p.DayXP == 0 and p.Title == nil, "garbage sanitised")
	local d2 = { Pass = { Season = 1, XP = 2700.5, Premium = true, F = "0101", P = "1", Day = 20000, DayXP = 120, Title = "S1" } }
	p = Schema.SanitizePass(d2)
	check(p.XP == 2700.5 and p.Premium and p.F == "0101" and p.P == "1" and p.Title == "S1", "good record kept")
	local d3 = {}
	p = Schema.SanitizePass(d3)
	check(p.XP == 0 and d3.Pass == p, "old saves get a fresh pass")
end

---------------------------------------------------------------- 4. the models build
local function newObj(class, name)
	local o = { ClassName = class, Name = name, attrs = {}, kids = {} }
	function o:SetAttribute(k, v) self.attrs[k] = v end
	function o:GetAttribute(k) return self.attrs[k] end
	function o:GetChildren() return self.kids end
	function o:IsA(c) return c == "BasePart" or c == self.ClassName end
	function o:FindFirstChild(n) for _, k in self.kids do if k.Name == n then return k end end return nil end
	return o
end
do
	local BUILD = {}
	local count
	local function part(m, name, shape, size, color, cf, material)
		local p = newObj("Part", name)
		table.insert(m.kids, p)
		count += 1
		return p
	end
	local function anim(p, kind, phase) p:SetAttribute("Anim", kind); return p end
	local function hwing(m, hinge, sx, rest, kind, specs)
		local out = {}
		for _, sp in specs do
			assert(type(sp[1]) == "string" and sp[3] ~= nil and sp[4] ~= nil and sp[5] ~= nil, "bad wing spec")
			table.insert(out, part(m, sp[1]))
		end
		return out
	end
	local H = { part = part, anim = anim, eyes = function() end, cuteEyes = function(m) part(m, "Eye") end, darker = function(c) return c end, BALL = "Ball", BLUSH = 1, hwing = hwing, swing = function(p) return p end }
	MOD_PetShapes()(BUILD, H)
	for _, id in { "RibbonOtter", "LaurelFalcon", "ChampionLion" } do
		local m = newObj("Model", id)
		count = 0
		local ok, err = pcall(BUILD[id], m, Color3.fromRGB(240, 170, 60))
		check(ok, id .. " builds: " .. tostring(err))
		check(count >= 20 and count <= 120, id .. " part count " .. tostring(count))
		check(m:GetAttribute("Motion") ~= nil, id .. " has a Motion")
	end
end
do
	local Decor = {}
	local count
	local function part(m, props)
		local p = newObj("Part", props.Name)
		for k, v in props do p[k] = v end
		table.insert(m.kids, p)
		count += 1
		return p
	end
	local H = { part = part, limb = function(m, name) return part(m, { Name = name }) end, emitter = function() end, light = function() end, SMOKE = "s", FIRE = "f", climb = function() end }
	MOD_DecorModels()(Decor, H)
	for _, id in { "SeasonBanner", "ChampionPodium" } do
		local m = newObj("Model", id)
		local base = newObj("Part", "Base")
		base.CFrame = { ToObjectSpace = function(self) return self end }
		table.insert(m.kids, base)
		count = 0
		local ok, err = pcall(Decor[id], m, { NextNumber = function() return 0.5 end }, DT.Defs[id])
		check(ok, id .. " builds: " .. tostring(err))
		check(count >= 12, id .. " part count " .. tostring(count))
	end
end

print(string.format("battle pass tests: %d checks, %d failed", checks, fails))
if fails > 0 then
	print("FAILURES")
	error("battle pass tests failed")
end
print("ALL BATTLE PASS TESTS PASSED")
