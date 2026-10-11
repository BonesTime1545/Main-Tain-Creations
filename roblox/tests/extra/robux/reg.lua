local function R(n) return require({__mod=n}) end
local BT, TC, PC, TT, DT, DB, IC, EC, ECo, RC = R("BroomTypes"), R("ToolConfig"), R("PetConfig"), R("TreeTypes"), R("DecorTypes"), R("DecorBoxConfig"), R("IslandConfig"), R("Economy"), R("EndgameConfig"), R("RobuxConfig")
local function fmt(n) local s = tostring(math.floor(n)); local r = s:reverse():gsub("(%d%d%d)", "%1,"):reverse(); return (r:gsub("^,", "")) end
local function ForGems(g) return RC.TierUp(math.ceil(g * 0.29)) end
local lines = {}
local function head(t, sub) table.insert(lines, ""); table.insert(lines, "\t-- ---------- " .. t .. " ----------" .. (sub and ("  " .. sub) or "")) end
local function entry(name, robux, note)
	table.insert(lines, string.format('\t[%q] = { Id = 0, Robux = %d }, -- ✏️ PASTE DEVELOPER PRODUCT ID   (%s)', name, robux, note))
end
local function m(money) return entry end
head("🧹 BROOMS (BROOM SHOP)")
for _, id in BT.Order do local d = BT.Defs[id]; if (d.Price or 0) > 0 then entry(d.Display, RC.ForMoney(d.Price), "💰" .. fmt(d.Price)) end end
head("✂️ GRASS TOOLS & MOWERS (BROOM SHOP · TOOLS)")
for _, id in TC.GrassOrder do local d = TC.GrassTools[id]; if (d.Price or 0) > 0 then entry(d.Display, RC.ForMoney(d.Price), "💰" .. fmt(d.Price)) end end
head("🧤 HELPERS: rake, blower, vacuum, pickaxe, blaster")
for _, id in TC.HelperOrder do local d = TC.Helpers[id]; if (d.Price or 0) > 0 then entry(d.Display, RC.ForMoney(d.Price), "💰" .. fmt(d.Price)) end end
head("🔋 ONE-USE ITEMS (batteries, fuel, magnets, toys …) — price of ONE piece")
local ids = {} for id, d in TC.Consumables do table.insert(ids, id) end
table.sort(ids, function(a, b) if TC.Consumables[a].Price ~= TC.Consumables[b].Price then return TC.Consumables[a].Price < TC.Consumables[b].Price end return a < b end)
for _, id in ids do local d = TC.Consumables[id]; entry(d.Display, RC.ForMoney(d.Price), "💰" .. fmt(d.Price)) end
head("🥚 EGGS (EGG SHOP)")
local eids = {} for id in PC.Eggs do table.insert(eids, id) end table.sort(eids, function(a,b) return (PC.Eggs[a].Price or 0) < (PC.Eggs[b].Price or 0) end)
for _, id in eids do local e = PC.Eggs[id]; if not e.Secret and e.Price and (not PC.InShop or PC.InShop(id)) then entry(e.Display, RC.ForMoney(e.Price), "💰" .. fmt(e.Price)) end end
head("🌳 TREES (BUILD SHOP · TREES) — buying a sapling")
for _, id in TT.Order do local d = TT.Get(id); if d and not d.Starter and not d.NotSold then entry(d.Display, RC.ForMoney(TT.PriceFor(d, 0)), "💰" .. fmt(TT.PriceFor(d, 0))) end end
head("🏠 BUILDINGS / STATIONS (BUILD SHOP · BUILDINGS)")
for _, id in DT.Order do local d = DT.Defs[id]; if d and not d.FriendOnly and (d.Station or d.Building) and not (d.Cost and (d.Cost.Gems or d.Cost.Clover)) and (d.Cost and d.Cost.LeafValue or d.Price) then local p = d.Cost and d.Cost.LeafValue or d.Price; entry(d.Display, RC.ForMoney(p), "💰" .. fmt(p)) end end
head("🎁 COSMETIC BOXES (BUILD SHOP · COSMETICS)")
for _, id in DB.Order do local b = DB.Boxes[id]; entry(b.Display, RC.ForMoney(b.Price), "💰" .. fmt(b.Price) .. " · island " .. b.Island) end
head("🚧 FENCE SKINS (GARDEN · FENCE)")
for _, f in IC.FenceSkins do if f.Cost then entry(f.Display, RC.ForMoney(f.Cost), "💰" .. fmt(f.Cost)) elseif f.Gems then entry(f.Display, ForGems(f.Gems), "💎" .. f.Gems) end end
head("🏝 ISLANDS (GARDEN · ISLAND)")
for i, t in IC.Tiers do if t.Cost > 0 then entry(t.Display, RC.ForMoney(t.Cost), "💰" .. fmt(t.Cost) .. " · island " .. i) end end
head("♾ SHOP · UPGRADES")
entry("Unlimited Build Height", RC.BuildHeightRobux, "fixed price; falls back to the 299 tier product")
print(table.concat(lines, "\n"))
