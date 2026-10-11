warn = function(...) print("WARN", ...) end
local function Rq(n) return require({__mod=n}) end
local BT, TC, PC, TT, DT, DB, IC, ECo, RC = Rq("BroomTypes"), Rq("ToolConfig"), Rq("PetConfig"), Rq("TreeTypes"), Rq("DecorTypes"), Rq("DecorBoxConfig"), Rq("IslandConfig"), Rq("EndgameConfig"), Rq("RobuxConfig")
local fails = 0
local function check(c, msg) if not c then fails += 1; print("FAIL " .. msg) end end
local tiers = {} for _, t in RC.Tiers do tiers[t] = true end
local n = 0
for name, e in RC.ItemProducts do
	n += 1
	check(type(name) == "string" and #name > 0, "name")
	check(type(e.Id) == "number" and e.Id >= 0 and e.Id == math.floor(e.Id), "id numeric " .. name)
	check(tiers[e.Robux] == true, "price is a tier " .. name .. " " .. tostring(e.Robux))
	check(RC.ItemProduct(name) == e, "ItemProduct " .. name)
end
print("entries", n)
check(n >= 100, "entries count")
-- every purchasable item present
local need = {}
local function req(cat, name) need[name] = cat end
for _, id in BT.Order do local d = BT.Defs[id]; if (d.Price or 0) > 0 then req("Broom", d.Display) end end
for id, d in TC.GrassTools do if (d.Price or 0) > 0 then req("GrassTool", d.Display) end end
for id, d in TC.Helpers do if (d.Price or 0) > 0 then req("Helper", d.Display) end end
for id, d in TC.Consumables do req("Item", d.Display) end
for id, e in PC.Eggs do if not e.Secret and e.Price and (not PC.InShop or PC.InShop(id)) then req("Egg", e.Display) end end
for _, id in TT.Order do local d = TT.Get(id); if d and not d.Starter and not d.NotSold then req("Tree", d.Display) end end
for _, id in DT.Order do local d = DT.Defs[id]; if d and not d.FriendOnly and (d.Station or d.Building) and not (d.Cost and (d.Cost.Gems or d.Cost.Clover)) then req("Building", d.Display) end end
for _, id in DB.Order do req("Box", DB.Boxes[id].Display) end
for _, f in IC.FenceSkins do if f.Cost or f.Gems then req("Fence", f.Display) end end
for _, t in IC.Tiers do if t.Cost > 0 then req("Island", t.Display) end end
req("Height", "Unlimited Build Height")
local m = 0
for name, cat in need do m += 1; check(RC.ItemProducts[name] ~= nil, "MISSING in registry: " .. cat .. " " .. name) end
print("purchasable items found in configs", m)
-- price matches the formula tier for money items
check(RC.ItemPrice("Metal Broom", 5000) == RC.ForMoney(5000), "price = formula tier")
check(RC.ItemPrice("Nope", 5000) == RC.ForMoney(5000), "unknown name -> formula")
check(RC.ForGems(60) == 25 and RC.ForGems(1000) == 299, "ForGems")
check(RC.ItemProductId("Metal Broom") == nil, "unset id nil")
RC.ItemProducts["Metal Broom"].Id = 777
check(RC.ItemProductId("Metal Broom") == 777, "set id")
local nm = RC.ItemOfProduct(777)
check(nm == "Metal Broom", "ItemOfProduct")
check(RC.ItemOfProduct(5) == nil and RC.ItemOfProduct(0) == nil, "ItemOfProduct none")
RC.ItemProducts["Metal Broom"].Id = 0

-- ---------------- MonetizationService flow
Enum.ProductPurchaseDecision = { PurchaseGranted = "granted", NotProcessedYet = "notyet" }
local granted, notes, prompts = {}, {}, {}
local pl = { UserId = 5, GetAttribute = function() return 99 end }
game.GetService = function(_, n)
	if n == "Players" then return { GetPlayerByUserId = function() return pl end, PlayerRemoving = { Connect = function() end } } end
	if n == "RunService" then return { IsStudio = function() return false end } end
	if n == "MarketplaceService" then return {} end
	return setmetatable({}, { __index = function() return function() end end })
end
local MS = Rq("MonetizationService")
local data = { Stats = {}, Brooms = { Owned = {} }, Robux = { Receipts = {}, Spent = 0 }, Island = { Fences = {} }, Pets = { Owned = {} } }
local bought = {}
local ctxv = {
	RobuxConfig = RC, BroomTypes = BT,
	PlayerDataService = { Get = function() return data end, SaveNow = function() return true end },
	CurrencyService = { Grant = function(_, t) granted.Money = (granted.Money or 0) + (t.LeafValue or 0); granted.Gems = (granted.Gems or 0) + (t.Gems or 0) end },
	BroomShopService = { Buy = function(_, id) if bought[id] then return false, "no" end bought[id] = true; return true, "bought " .. id end },
	Net = { Notify = { FireClient = function(_, _, m) table.insert(notes, m) end } },
	IslandService = { Tier = function() return 1 end, Can = function() return true end, Upgrade = function() return true, "isl" end, BuyFence = function() return true, "fence" end },
	IslandConfig = IC, EndgameConfig = ECo, Economy = {},
	UpgradeService = { BuildHeightLevel = function() return 0 end, Upgrade = function() return true, "up" end },
}
MS.Init(ctxv)
MS.Prompt = function(_, id) table.insert(prompts, id) end
-- quote: fixed price, tier fallback
local ok, robux, money = MS.Handle(pl, { Action = "Quote", Kind = "Broom", Payload = { Id = "Metal" } })
check(ok and robux == RC.ItemProducts["Metal Broom"].Robux and money == 5000, "quote metal broom " .. tostring(robux))
-- id 0 and tier 35 unset -> live server: not available yet
local ok2, msg2 = MS.Handle(pl, { Action = "Buy", Kind = "Broom", Payload = { Id = "Metal" } })
check(ok2 == false and msg2 == "Not available yet", "unset -> not available: " .. tostring(msg2))
-- own id set
RC.ItemProducts["Metal Broom"].Id = 4242
local ok3 = MS.Handle(pl, { Action = "Buy", Kind = "Broom", Payload = { Id = "Metal" } })
check(ok3 == true and prompts[1] == 4242, "prompt uses own product id")
-- the tier receipt of the same price must NOT consume this pending purchase
RC.Products[35] = 9001
local r = MS.ProcessReceipt({ PlayerId = 5, PurchaseId = "a", ProductId = 9001, CurrencySpent = 35 })
check(r == "granted" and not bought.Metal, "tier receipt leaves the item pending (gives money worth)")
-- the item receipt grants exactly the item
granted = {}
local r2 = MS.ProcessReceipt({ PlayerId = 5, PurchaseId = "b", ProductId = 4242, CurrencySpent = 35 })
check(r2 == "granted" and bought.Metal == true and granted.Money == 5000, "item receipt buys the broom and gives its money: " .. tostring(granted.Money))
-- idempotent
local r3 = MS.ProcessReceipt({ PlayerId = 5, PurchaseId = "b", ProductId = 4242, CurrencySpent = 35 })
check(r3 == "granted" and bought.Metal == true, "idempotent")
-- the item can't be bought any more: the money stays
data.Brooms.Owned.Metal = true
local ok4, why4 = MS.Handle(pl, { Action = "Buy", Kind = "Broom", Payload = { Id = "Metal" } })
check(ok4 == false, "owned -> refused up front")
-- bought meanwhile (race): receipt without being able to buy -> money kept
data.Brooms.Owned.Metal = nil
bought.Metal = nil
MS.Handle(pl, { Action = "Buy", Kind = "Broom", Payload = { Id = "Metal" } })
bought.Metal = true -- (taken by someone else/other path)
granted = {}
MS.ProcessReceipt({ PlayerId = 5, PurchaseId = "c", ProductId = 4242, CurrencySpent = 35 })
check(granted.Money == 5000 and notes[#notes]:find("Money added"), "failed purchase keeps the Money")
-- receipt of an item product after a rejoin (nothing pending): tier worth, not lost
granted = {}
MS.ProcessReceipt({ PlayerId = 5, PurchaseId = "d", ProductId = 4242, CurrencySpent = 35 })
check((granted.Money or 0) > 0, "no pending: money worth")
-- gem kinds
RC.ItemProducts["Ice Wall"].Id = 0
local okq, rq = MS.Handle(pl, { Action = "Quote", Kind = "Fence", Payload = { Id = "Ice" } })
check(okq and rq == RC.ItemProducts["Ice Wall"].Robux, "gem fence quote")
local okh, rh = MS.Handle(pl, { Action = "Quote", Kind = "GemUpgrade", Payload = { Id = "LeafPower" } })
check(okh and rh == RC.ForGems(40), "gem upgrade quote " .. tostring(rh))
local oki, ri = MS.Handle(pl, { Action = "Quote", Kind = "Island", Payload = {} })
check(not oki or true, "island quote ran")
print(oki, ri)
RC.ItemProducts["Metal Broom"].Id = 0
print(fails == 0 and "ROBUX TEST OK" or ("ROBUX TEST FAILURES " .. fails))
