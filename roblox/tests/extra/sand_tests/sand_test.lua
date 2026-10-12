local P = PETCONFIG()
local PS = PETSERVICE()
local INC = INCUBATOR()
local fails, n = 0, 0
local function check(c, msg) n += 1 if not c then fails += 1 print("FAIL " .. msg) end end
-- config
local egg = P.Eggs.SandEgg
check(egg and egg.Island == 11 and egg.Price == 55000000 and egg.Rarity == "Mythic", "Sand Egg row")
local sum = 0 for id, w in egg.Contents do sum += w check(P.Pets[id] ~= nil, id .. " exists") end
check(math.abs(sum - 100) < 1e-6, "contents sum 100")
check(P.InShop("SandEgg"), "sold")
for _, id in { "DesertLizard", "Fennec", "DesertScorpion", "DesertOwl", "SandSerpent" } do
  check(P.Text(id, "Normal", 1, nil, "en") ~= "" and P.Text(id, "Rainbow", 10, nil, "ru") ~= "", id .. " text")
end
check(P.AbilityValue("DesertOwl", "Rainbow", "Luck", 1) == 0.15, "owl luck rainbow")
-- the owl's luck in the roll
local owlNow = { any = false, luck = 0 }
local data = { Plot = { Expansion = 0 }, Eggs = { Owned = { SandEgg = 3 }, Nests = {}, Opened = 0, NextNest = 1, FirstNest = true }, Pets = { Owned = {}, Equipped = {} } }
local added = {}
local ctx = {
  PetConfig = P,
  PlayerDataService = { Get = function() return data end },
  PlotSystem = { Get = function() return { Model = true, CFrame = proxy() } end },
  PlotMath = { PlotSize = function() return 100 end },
  Config = { Plot = {} },
  TreeTypes = { TimeText = function(s) return tostring(s) end },
  PetPowers = { OwlLuck = function() return owlNow.any, owlNow.luck end },
}
PS.Init(ctx)
ctx.PetService = { Roll = PS.Roll, Add = function(_, id, v) table.insert(added, id .. ":" .. v) return "u" .. #added end, Publish = function() INC.OwlRefresh(PL) end }
INC.Init(ctx)
INC.Spawn = function() end
INC.Despawn = function() end
PL = { UserId = 1, attrs = {}, SetAttribute = function(self, k, v) self.attrs[k] = v end, GetAttribute = function(self, k) return self.attrs[k] end }
-- roll statistics: with luck 10 the rare pets must come far more often
local function rare(luck)
  local r = Random.new(5) local c = 0
  for i = 1, 4000 do local id = PS.Roll(data, "SandEgg", r, luck) if id ~= "DesertLizard" then c += 1 end end
  return c
end
local r0, r1 = rare(0), rare(10)
print("rare without / with big luck", r0, r1)
check(r1 > r0 * 1.5, "owl luck raises the rarer pets")
-- place: a fate is decided, open hatches exactly it
local ok, msg, info = INC.Place(PL, "SandEgg", 0, 0)
check(ok, "place " .. tostring(msg))
local nest = data.Eggs.Nests[info.Nest]
check(type(nest.Pet) == "string" and type(nest.Var) == "string", "nest has a fate")
-- without an owl nothing is shown
check(PL.attrs.OwlNext == "", "no owl: OwlNext empty (" .. tostring(PL.attrs.OwlNext) .. ")")
-- undo gives the fate back, the next placement takes the same
local fate1 = nest.Pet .. ":" .. nest.Var
check(INC.Unplace(PL, info.Nest, "SandEgg", false), "unplace")
check(data.Eggs.Fate and data.Eggs.Fate.SandEgg and data.Eggs.Fate.SandEgg[1].P .. ":" .. data.Eggs.Fate.SandEgg[1].V == fate1, "fate queued")
ok, msg, info = INC.Place(PL, "SandEgg", 0, 0)
nest = data.Eggs.Nests[info.Nest]
check(nest.Pet .. ":" .. nest.Var == fate1, "same fate after undo")
nest.Ready = 0
INC.Now = function() return 10 end
local okO, _, payload = INC.Open(PL, info.Nest)
check(okO and payload.Id .. ":" .. payload.Variant == fate1, "hatched the fate " .. tostring(payload and payload.Id))
-- with an owl: the next inventory egg's fate is shown and is what the next placement gets
owlNow.any, owlNow.luck = true, 0.15
INC.OwlRefresh(PL)
local shown = PL.attrs.OwlNext
check(type(shown) == "string" and string.find(shown, "SandEgg=") ~= nil, "OwlNext shows the Sand Egg: " .. tostring(shown))
local shownPet = string.match(shown, "SandEgg=([^;]+)")
ok, msg, info = INC.Place(PL, "SandEgg", 0, 0)
nest = data.Eggs.Nests[info.Nest]
check(nest.Pet .. "|" .. nest.Var == shownPet, "the shown pet is in the placed egg")
nest.Ready = 0
INC.OpenDone(PL)
okO, _, payload = INC.Open(PL, info.Nest)
check(okO and payload.Id .. "|" .. payload.Variant == shownPet, "…and hatches")
-- an old nest without a fate still opens
data.Eggs.Nests.old = { Egg = "SandEgg", X = 5, Z = 5, Ready = 0, Total = 1 }
INC.OpenDone(PL)
okO, _, payload = INC.Open(PL, "old")
check(okO and P.Pets[payload.Id] ~= nil, "old nest opens")
print(string.format("sand tests: %d checks, %d failed", n, fails))
if fails == 0 then print("ALL SAND TESTS PASSED") end
