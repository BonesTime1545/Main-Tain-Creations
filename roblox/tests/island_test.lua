for tier = 1, 11 do
	local r = T.GrassIsland(tier)
	print(string.format("island %2d  tick x%.2f  max %.2f  infect %.2f  slow tall %.2f thick %.2f over %.2f", tier, r.Tick, r.Max, r.Infect, r.Slow[1], r.Slow[2], r.Slow[3]))
end
-- the real growth interval: base 150 s x tick / weather
for _, w in { { "Clear", 1 }, { "Rain", 1.7 }, { "Storm", 2 }, { "Paradise", 2.4 } } do
	print(string.format("island 5 in %-8s: a growth step every %.0f s", w[1], T.Grass.TickEvery * T.GrassIsland(5).Tick / w[2]))
end
local f = T.Features
