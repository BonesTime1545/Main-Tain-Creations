local BM = require({ __mod = "BlockMath" })
local WF = require({ __mod = "WaterFlow" })
local n = 20
math.randomseed(3)
local b = {}
for cx = 0, n - 1 do for cz = 0, n - 1 do
	local h = math.random(0, 120)
	for l = 1, h do BM.Set(b, cx, cz, l, "D") end
end end
for i = 1, 30 do BM.Set(b, math.random(0, n-1), math.random(0, n-1), 125, "W") end
for cx = 5, 9 do for cz = 5, 9 do for l = -4, 0 do BM.Set(b, cx, cz, l, nil) end end end
BM.Set(b, 7, 7, -2, "W")
for i = 1, 20 do
	local w = WF.Compute(b, n)
	local t = BM.Encode(b)
	local d = BM.Decode(t)
	if i == 1 then print("count", w.Count, "enc bytes", #t, "top", BM.TopLevel(d)) end
end
print("done 20x (compute+encode+decode)")
