-- petinfo test: P.Text for every pet. Run (from the scratchpad copy):
--   cat > /tmp/run.lua <<X ... X ; see bottom of this file: the harness joins PetConfig + MutationConfig + this test.
-- Usage:  bash run_pettext_test.sh   (joins stubs, PetConfig.lua, MutationConfig.lua and this file, runs luau)
local P = PETCONFIG()
local MC = MUTCONFIG()
local fails = 0
local function fail(msg)
	fails += 1
	print("FAIL " .. msg)
end
local combos = {
	{ "Normal", 1 }, { "Normal", 5 }, { "Normal", 10 }, { "Golden", 1 }, { "Golden", 10 }, { "Diamond", 10 }, { "Rainbow", 1 }, { "Rainbow", 10 },
}
local count = 0
local scaled = {} -- pets whose text really differs L1 normal vs L10 Rainbow
local same = {}
for _, id in P.Order do
	local def = P.Pets[id]
	if def then
		count += 1
		for _, lang in { "en", "ru" } do
			local seen = {}
			for _, c in combos do
				local t = P.Text(id, c[1], c[2], nil, lang)
				if t == "" then fail(id .. " " .. lang .. " empty") end
				for _, bad in { "nan", "nil", "%%s", "%?", "{", "}", "inf", "%.%." } do
					if string.find(t, bad) then fail(id .. " " .. lang .. " " .. c[1] .. c[2] .. " contains '" .. bad .. "': " .. t) end
				end
				if lang == "ru" and string.find((string.gsub(t, "%(Q%)", "")), "[A-Za-z]") then fail(id .. " ru has latin letters: " .. t) end
				if lang == "en" then
					for _, ab in { def.Ability.Name } do
						if ab and string.find(t, ab, 1, true) and ab ~= def.Display then fail(id .. " shows its ability name '" .. ab .. "': " .. t) end
					end
					if string.find(t, "%a+:") and string.find(t, "^%u[%a%- ]+: ") then fail(id .. " looks like 'Name: text': " .. t) end
				end
				seen[c[1] .. c[2]] = t
			end
			if lang == "en" then
				if seen.Normal1 ~= seen.Rainbow10 then table.insert(scaled, id) else table.insert(same, id) end
			end
			-- with a toy the live text must not break
			local tt = P.Text(id, "Golden", 3, 0.5, lang)
			if tt == "" or string.find(tt, "nan") or string.find(tt, "%?") then fail(id .. " toy text: " .. tt) end
		end
	end
end
print("pets checked:", count, " differing L1 Normal vs L10 Rainbow:", #scaled, " identical:", #same)
local lvlSame = {}
for _, id in P.Order do
	if P.Pets[id] and P.Text(id, "Normal", 1, nil, "en") == P.Text(id, "Normal", 10, nil, "en") then table.insert(lvlSame, id) end
end
print("text does NOT change with the level (real logic: the key is not level-scaled), only with the form:", table.concat(lvlSame, ", "))
if #same > 0 then print("identical (no scaling in the real logic):", table.concat(same, ", ")) end

-- the mutation multipliers named in the texts are MutationConfig's
for id, m in P.TextMutations do
	local d = MC.Defs[id]
	if not d then fail("no mutation " .. id)
	elseif d.Multiplier ~= m[1] then fail(id .. " x" .. m[1] .. " vs MutationConfig x" .. d.Multiplier) end
end

-- numbers equal AbilityValue / the caps of the logic
local function has(t, s) return string.find(t, s, 1, true) ~= nil end
if not has(P.Text("AncientSprout", "Normal", 1, nil, "en"), "×2.05") then fail("Ancient Sprout L1 normal not x2.05") end
if not has(P.Text("AncientSprout", "Rainbow", 10, nil, "en"), "×6") then fail("Ancient Sprout Rainbow L10 not x6") end
if not has(P.Text("MutationBeast", "Rainbow", 10, nil, "en"), "50%") then fail("Mutation Beast chance not capped at 50%") end
if not has(P.Text("RainFrog", "Rainbow", 10, nil, "en"), "90%") then fail("Rain Frog not capped at 90%") end
if not has(P.Text("GardenBunny", "Normal", 10, nil, "en"), "11.4%") then fail("Garden Bunny L10: " .. P.Text("GardenBunny", "Normal", 10, nil, "en")) end
if not has(P.Text("LittleSquirrel", "Normal", 10, nil, "en"), "5 items") then fail("Squirrel L10 count: " .. P.Text("LittleSquirrel", "Normal", 10, nil, "en")) end

print("---- examples")
local function ex(id, v, l)
	print(string.format("[%s %s L%d]", id, v, l))
	print("  EN: " .. P.Text(id, v, l, nil, "en"))
	print("  RU: " .. P.Text(id, v, l, nil, "ru"))
end
ex("AncientSprout", "Normal", 1)
ex("AncientSprout", "Rainbow", 10)
ex("GardenBunny", "Normal", 1)
ex("GardenBunny", "Rainbow", 10)
ex("LittleSquirrel", "Normal", 1)
ex("LittleSquirrel", "Golden", 10)
ex("MutationBeast", "Normal", 1)
ex("MutationBeast", "Rainbow", 10)
ex("EclipseMoth", "Normal", 1)
ex("EclipseMoth", "Rainbow", 10)
ex("BlossomDragon", "Normal", 1)
ex("Saturn", "Diamond", 7)
print("---- toy +50% on Golden L3 Squirrel: " .. P.Text("LittleSquirrel", "Golden", 3, 0.5, "en"))
if ALL_PRINT then
	for _, id in P.Order do
		for _, lang in { "en", "ru" } do
			print(id, lang, "L1: " .. P.Text(id, "Normal", 1, nil, lang))
			print(id, lang, "L10R: " .. P.Text(id, "Rainbow", 10, nil, lang))
		end
	end
end
print(if fails == 0 then "ALL PETTEXT TESTS PASSED" else ("FAILURES: " .. fails))

-- round 12: Ancient Sprout Mult scales with level (L1 = old number, L10 = old x 6/3.6, Rainbow L10 = 6); MoonWolf speed uncapped
do
	local want10 = { Normal = 3.42, Golden = 4.17, Diamond = 5, Rainbow = 6 }
	local want1 = { Normal = 2.05, Golden = 2.5, Diamond = 3, Rainbow = 3.6 }
	local prev = {}
	for _, v in { "Normal", "Golden", "Diamond", "Rainbow" } do
		for L = 1, 10 do
			local m = P.AbilityValue("AncientSprout", v, "Mult", L)
			if L == 1 and math.abs(m - want1[v]) > 1e-9 then fail("Sprout L1 " .. v .. " = " .. m) end
			if L == 10 and math.abs(m - want10[v]) > 1e-9 then fail("Sprout L10 " .. v .. " = " .. m) end
			if prev[v] and m < prev[v] then fail("Sprout not monotonic " .. v) end
			prev[v] = m
		end
		if not has(P.Text("AncientSprout", v, 10, nil, "en"), "×" .. (tostring(want10[v]))) then fail("Sprout text L10 " .. v .. ": " .. P.Text("AncientSprout", v, 10, nil, "en")) end
	end
	if not has(P.Text("AncientSprout", "Rainbow", 10, nil, "ru"), "×6") then fail("Sprout ru text") end
	-- Moon Wolf Speed is not capped at 0.4 any more (a boosted Rainbow wolf at L10)
	local sp = P.AbilityValue("MoonWolf", "Rainbow", "Speed", 10, 1)
	if sp <= 0.4 and sp ~= 0.52 then fail("MoonWolf speed " .. sp) end
	if not has(P.Text("MoonWolf", "Rainbow", 10, 1, "en"), tostring(math.floor(sp * 100 + 0.5)) .. "%") then fail("MoonWolf text " .. P.Text("MoonWolf", "Rainbow", 10, 1, "en")) end
end
