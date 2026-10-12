-- round 13 "inv": the pure functions behind the Inventory's stat lines and reward lists
local T = require({ __mod = "ToolConfig" })
local BT = require({ __mod = "BroomTypes" })
local P = require({ __mod = "PetConfig" })
local B = require({ __mod = "DecorBoxConfig" })
local fails, checks = 0, 0
local function check(c, msg) checks += 1; if not c then fails += 1; print("FAIL " .. msg) end end

-- 1. every egg: chances sum to 100 %, no wheel pet, = PityInfo's chances at luck 1
local eggs = 0
for id in P.Eggs do
	eggs += 1
	for _, luck in { 1, 1.5, 3 } do
		local sum = 0
		local rows = P.EggRewards(id, luck)
		check(#rows > 0, id .. " has rewards")
		for _, r in rows do
			sum += r.Chance
			check(r.Def.Source ~= "Wheel", id .. ": no wheel pet " .. r.Id)
			check(r.Chance > 0, id .. " chance > 0")
		end
		check(math.abs(sum - 1) < 1e-9, id .. " sums to 100% at luck " .. luck .. " (" .. sum .. ")")
	end
	local base = {}
	for _, e in P.PityInfo(id) do base[e.Id] = e.Chance end
	for _, r in P.EggRewards(id) do
		if base[r.Id] then check(math.abs(base[r.Id] - r.Chance * 100) < 1e-6, id .. " matches PityInfo for " .. r.Id) end
	end
end
-- luck makes rare pets likelier
do
	local id = P.EggOrder[#P.EggOrder]
	local a, b = P.EggRewards(id, 1), P.EggRewards(id, 3)
	local function rareShare(rows) local s = 0; for _, r in rows do if P.Rarities[r.Rarity].Order >= 3 then s += r.Chance end end; return s end
	check(rareShare(b) >= rareShare(a), "luck raises the rare share")
end
check(#P.EggRewards("Nope") == 0, "unknown egg -> empty")

-- 2. every box: sums to 100 %, no WheelOnly cosmetic
local boxes = 0
for _, id in B.Order do
	boxes += 1
	local sum = 0
	for _, r in B.Rewards(id) do
		sum += r.Chance
		check(not r.Def.WheelOnly, id .. ": no wheel cosmetic")
	end
	check(math.abs(sum - 1) < 1e-9, id .. " box sums to 100%")
end

-- 3. stat lines: every tool / item / broom, every tier, all values are strings with digits
local function lines(list, what)
	check(type(list) == "table" and #list > 0, what .. " has stat lines")
	for _, l in list do
		check(type(l.Label) == "string" and type(l.Value) == "string" and l.Value ~= "", what .. " line ok")
		check(not string.find(l.Value, "nan") and not string.find(l.Value, "inf"), what .. " finite " .. l.Value)
	end
end
local ids = {}
for _, id in T.GrassOrder do table.insert(ids, id) end
for _, id in T.HelperOrder do table.insert(ids, id) end
for _, id in T.ConsumableOrder do table.insert(ids, id) end
for _, id in ids do
	lines(T.StatLines(id, {}), id)
	lines(T.StatLines(id, nil), id .. " (no state)")
	local top = T.TopLevels and T.TopLevels(id) or nil
	if top then lines(T.StatLines(id, { Up = { [id] = top } }), id .. " (maxed)") end
end
-- upgrades change the numbers: the Shears' radius at the last tier is bigger
do
	local function val(list, label) for _, l in list do if l.Label == label then return tonumber(l.Value) end end end
	local a = val(T.StatLines("Shears", {}), "Cutting radius")
	local b = val(T.StatLines("Shears", { Up = { Shears = { Tier = 4 } } }), "Cutting radius")
	check(a and b and b > a, "tier raises the radius " .. tostring(a) .. " -> " .. tostring(b))
	local p1 = T.StatLines("Pickaxe", { Up = { Pickaxe = { Tier = 4 } } })
	check(val(p1, "Reach") == T.PickaxeTiers[5].Reach, "rainbow pickaxe reach")
end
for _, id in BT.Order or {} do lines(BT.StatLines(id), "broom " .. id) end
print(string.format("inv tests: %d eggs, %d boxes, %d tools, %d checks, %d failures", eggs, boxes, #ids, checks, fails))
if fails > 0 then print("FAILURES") error("failed") end
