local MS = require({ __mod = "MutationSystem" })
local PP = require({ __mod = "PetPowers" })
local fails = 0
local function check(c, msg) if not c then fails += 1; print("FAIL " .. msg) end end
local function near(a, b) return math.abs(a - b) <= 1e-6 * math.max(1, math.abs(b)) end
-- plain items: the ball is worth their sum, no mutation
local key, vm, value = PP.WoolValue({ { Value = 1 }, { Value = 24 }, { Value = 14 }, { Value = 1 } }, 1, MS)
check(key == nil and near(value, 40) and near(vm, 40), "plain: " .. tostring(key) .. " " .. value)
-- one Golden leaf + 3 apples: Golden on all, price = 73 x 25
key, vm, value = PP.WoolValue({ { Value = 1, Key = "Golden" }, { Value = 24 }, { Value = 24 }, { Value = 24 } }, 1, MS)
check(key == "Golden" and near(value, 73 * 25), "golden: " .. tostring(key) .. " " .. value)
check(near(1 * vm * MS.Multiplier(key), value), "vm x unit x mult = value")
-- two bases: only the priciest stays (Rainbow over Golden), the others add up on top
key, vm, value = PP.WoolValue({ { Value = 10, Key = "Golden+Wet" }, { Value = 10, Key = "Rainbow" }, { Value = 10, Key = "Burning" } }, 1, MS)
check(MS.Has(key, "Rainbow") and not MS.Has(key, "Golden") and MS.Has(key, "Wet") and MS.Has(key, "Burning"), "bases: " .. tostring(key))
check(near(value, 30 * MS.Multiplier(key)), "bases value " .. value)
-- never less than the items one by one
key, vm, value = PP.WoolValue({ { Value = 100, Key = "Rainbow" }, { Value = 1, Key = "Golden" } }, 1, MS)
check(value >= 100 * MS.Multiplier("Rainbow") + 25 - 1e-6, "never less: " .. value)
-- the cap
key, vm, value = PP.WoolValue({ { Value = 1e14, Key = "Rainbow+Neon+Majestic" } }, 1, MS)
check(value <= MS.MaxValue, "capped " .. value)
-- combos: Wet + Frost -> Frozen
key = PP.WoolValue({ { Value = 1, Key = "Wet" }, { Value = 1, Key = "Frost" } }, 1, MS)
print("wet + frost ->", key)
print(if fails == 0 then "FARM TESTS OK" else ("FAILURES: " .. fails))
