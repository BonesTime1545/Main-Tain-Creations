local TT = require("TreeTypes")
local MB = require("ModelBuilder")
local fails = 0
local rows = {}
for _, id in TT.Order do
	local counts = {}
	for L = 1, 10 do
		PARTS = 0
		local model = Instance.new("Model")
		local okB, err = pcall(MB.Tree, model, { Type = "Tree", TreeType = id, Level = L, X = 0, Z = 0, Rot = 0 }, 5)
		if not okB then
			fails += 1
			print("FAIL " .. id .. " L" .. L .. ": " .. tostring(err))
		end
		counts[L] = PARTS
	end
	table.insert(rows, { id, counts[1], counts[4], counts[7], counts[10] })
end
for _, r in rows do
	print(string.format("%-14s parts L1 %3d  L4 %3d  L7 %3d  L10 %3d", r[1], r[2], r[3], r[4], r[5]))
end
local maxOld = 0
for _, r in rows do
	if ({ AppleTree = 1, DarkOak = 1, FrostTree = 1, GoldenWillow = 1, AncientOak = 1, StarTree = 1, CrownTree = 1, RoyalTree = 1 })[r[1]] then
		maxOld = math.max(maxOld, r[5])
	end
end
for _, r in rows do
	if ({ PearTree = 1, WeepingWillow = 1, OakTree = 1, HarvestApple = 1, SpringTree = 1, MountainPine = 1, Baobab = 1 })[r[1]] and r[5] > maxOld * 1.15 then
		fails += 1
		print("FAIL " .. r[1] .. " has far more parts at Lvl 10 than the old trees (" .. r[5] .. " > " .. maxOld .. ")")
	end
end
if fails > 0 then
	print("FAILURES")
	error("models test failed")
end
print("TREE MODELS OK (every tree, every level)")
