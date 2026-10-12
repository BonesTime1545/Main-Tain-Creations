-- round 13 quests: pure logic tests (calendar, streak saver, bonuses, quest pick, migration)
local Q = MOD_QuestConfig()
local M = MOD_MetaConfig()
local Schema = MOD_DataSchema()
local fails, checks = 0, 0
local function check(c, msg)
	checks += 1
	if not c then
		fails += 1
		print("FAIL " .. msg)
	end
end

-- 1. the calendar: 30 days, milestones, every reward has a text, wraps after 30
check(#M.Calendar == 30, "30 calendar days")
for _, i in { 7, 14, 21, 30 } do
	check(M.Calendar[i].Big == true, "day " .. i .. " is a big day")
end
for i, d in M.Calendar do
	check(type(d.Reward) == "table" and M.CalendarText(d.Reward) ~= "", "day " .. i .. " has a reward text")
end
check(M.NextCal(0) == 1 and M.NextCal(29) == 30 and M.NextCal(30) == 1, "NextCal wraps")
check(M.NextCal(99) == 1 and M.NextCal(-5) == 1, "NextCal clamps junk")

-- 2. streak + calendar rules
local function play(d, today)
	local pv = M.LoginPreview(d, today)
	if pv.Claimable then
		M.LoginApply(d, today, pv)
	end
	return pv
end
do
	local d = { Day = -1, Streak = 0, Best = 0, Total = 0, Cal = 0, Grace = 1 }
	local pv = play(d, 100)
	check(pv.Cal == 1 and d.Streak == 1 and d.Cal == 1 and d.Total == 1, "first claim = day 1, streak 1")
	check(not M.LoginPreview(d, 100).Claimable, "same day twice is not claimable")
	play(d, 101)
	check(d.Streak == 2 and d.Cal == 2, "next day: streak 2, day 2")
	-- one missed day: the saver keeps the streak, calendar just continues
	pv = play(d, 103)
	check(pv.Saved and d.Streak == 3 and d.Cal == 3 and d.Grace == 0, "one missed day saved by the saver")
	-- another single missed day without a saver: streak restarts, calendar keeps its place
	pv = play(d, 105)
	check(pv.Broken and d.Streak == 1 and d.Cal == 4, "no saver: streak 1, calendar continues at day 4")
	check(d.Best == 3, "best streak remembered")
	-- 7 in a row recharge the saver
	for t = 106, 111 do
		play(d, t)
	end
	check(d.Streak == 7 and d.Grace == 1, "7 days in a row charge the saver again (streak " .. d.Streak .. ", grace " .. d.Grace .. ")")
	-- a long break never resets the calendar
	local cal = d.Cal
	play(d, 200)
	check(d.Cal == cal + 1 and d.Streak == 1, "a long break: calendar +1, streak 1")
end
do
	local d = { Day = 10, Streak = 4, Grace = 1 }
	check(M.StreakAlive(d, 11) and M.StreakAlive(d, 12) and not M.StreakAlive(d, 13), "StreakAlive with the saver")
	d.Grace = 0
	check(not M.StreakAlive(d, 12), "StreakAlive without the saver")
end
do -- the calendar wraps after day 30
	local d = { Day = 0, Streak = 1, Cal = 30, Grace = 1 }
	play(d, 1)
	check(d.Cal == 1, "after day 30 comes day 1")
end
check(M.StreakGems(0) == 0 and M.StreakGems(7) == 10 and M.StreakGems(100) == 40, "streak gems")

-- 3. bonuses: weekend by UTC weekday, live event by name
local monday = 4 -- unix day 0 = Thursday 1970-01-01, day 4 = Monday (QuestConfig.Week uses the same +3)
check(M.Weekday(monday) == 0, "day 4 is a Monday")
check(#M.LoginBonuses(monday, nil) == 0, "no bonus on a Monday")
check(#M.LoginBonuses(monday + 5, nil) == 1 and #M.LoginBonuses(monday + 6, nil) == 1, "weekend bonus Sat / Sun")
check(#M.LoginBonuses(monday, "Leaf Tornado") == 1 and #M.LoginBonuses(monday + 5, "X") == 2, "live event bonus")

-- 4. quest pick: no duplicates, different kinds first, the always quest, feature filter
check(#Q.Daily >= 35 and #Q.Weekly >= 20, "many quests (" .. #Q.Daily .. " daily, " .. #Q.Weekly .. " weekly)")
local ids = {}
for _, list in { Q.Daily, Q.Weekly } do
	for _, q in list do
		check(not ids[q.Id], "unique id " .. q.Id)
		ids[q.Id] = true
		check(type(q.Text) == "string" and string.find(q.Text, "%s", 1, true) ~= nil, q.Id .. " text has %s")
		check(type(q.Reward) == "table" and (q.Reward.Gems or q.Reward.Money or q.Reward.Egg), q.Id .. " has a reward")
	end
end
for seed = 1, 300 do
	for _, scope in { { Q.Daily, Q.DailyCount }, { Q.Weekly, Q.WeeklyCount } } do
		local out = Q.Pick(scope[1], scope[2], seed * 7919 + 13)
		check(#out == scope[2], "pick count")
		local seen, kinds = {}, {}
		for _, id in out do
			check(not seen[id], "no duplicate quest in a set")
			seen[id] = true
			local k = Q.ById[id].Kind
			check(not kinds[k], "no two quests of the same kind (" .. k .. ")")
			kinds[k] = true
		end
		if scope[1] == Q.Daily then
			check(out[1] == "d_clean", "the Clean quest comes first")
		end
	end
end
do -- a player without islands never gets a feature quest
	local allow = function(def)
		return def.Feature == nil
	end
	for seed = 1, 200 do
		for _, id in Q.Pick(Q.Daily, Q.DailyCount, seed, allow) do
			check(Q.ById[id].Feature == nil, "feature filter: " .. id)
		end
	end
	-- a tiny pool: fills up with the same kind rather than giving fewer quests
	local pool = { { Id = "a", Kind = "X" }, { Id = "b", Kind = "X" }, { Id = "c", Kind = "X" } }
	local out = Q.Pick(pool, 2, 5)
	check(#out == 2 and out[1] ~= out[2], "small pool still gives distinct quests")
	local dup = { { Id = "a", Kind = "X" }, { Id = "a", Kind = "Y" } }
	check(#Q.Pick(dup, 2, 5) == 1, "a duplicate id in the pool is taken once")
end
do -- money targets
	Q.MoneyScale = function(a, e) return a * (e + 1) end
	local def = Q.ById.d_money
	check(Q.Target(def, 0) == 8000 and Q.Target(def, 3) == 32000, "money target scales")
	Q.MoneyScale = nil
end

-- 5. migration: an old save's daily state gets Cal / Grace, junk is cleaned
do
	local raw = Schema.Defaults()
	raw.Daily = { Day = 500, Streak = 6, Best = 9, Total = 40 }
	local data = Schema.Prepare(raw)
	check(data.Daily.Cal == 0 and data.Daily.Grace == 1 and data.Daily.Streak == 6 and data.Daily.Day == 500, "old daily state migrated (Cal 0, Grace 1, streak kept)")
	raw = Schema.Defaults()
	raw.Daily = { Day = 500, Streak = 6, Best = 9, Total = 40, Cal = 999, Grace = "x" }
	data = Schema.Prepare(raw)
	check(data.Daily.Cal == 30 and data.Daily.Grace == 1, "junk Cal / Grace sanitised")
	check(data.Settings.ShowQuestClaim == true, "ShowQuestClaim defaults ON")
end

print(string.format("quests tests: %d checks, %d failed", checks, fails))
if fails > 0 then
	error("quests tests failed")
end
