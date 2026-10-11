local function R(n) return require({__mod=n}) end
local BT, TC, PC, TT, DT, DB, IC, EC, ECo = R("BroomTypes"), R("ToolConfig"), R("PetConfig"), R("TreeTypes"), R("DecorTypes"), R("DecorBoxConfig"), R("IslandConfig"), R("Economy"), R("EndgameConfig")
local out = {}
local function add(cat, name, money, id, extra) print(table.concat({cat, name, tostring(money), id, extra or ""}, "\t")) end
for _, id in BT.Order do local d = BT.Defs[id]; if (d.Price or 0) > 0 then add("Broom", d.Display, d.Price, id) end end
for _, id in TC.GrassOrder do local d = TC.GrassTools[id]; if (d.Price or 0) > 0 then add("GrassTool", d.Display, d.Price, id) end end
for _, id in TC.HelperOrder do local d = TC.Helpers[id]; if (d.Price or 0) > 0 then add("Helper", d.Display, d.Price, id) end end
local ids = {} for id in TC.Consumables do table.insert(ids, id) end table.sort(ids)
for _, id in ids do local d = TC.Consumables[id]; add("Item", d.Display, d.Price, id) end
local eids = {} for id in PC.Eggs do table.insert(eids, id) end table.sort(eids, function(a,b) return (PC.Eggs[a].Price or 0) < (PC.Eggs[b].Price or 0) end)
for _, id in eids do local e = PC.Eggs[id]; if not e.Secret and e.Price and (not PC.InShop or PC.InShop(id)) then add("Egg", e.Display, e.Price, id) end end
for _, id in TT.Order do local d = TT.Get(id); if d and not d.Starter and not d.NotSold then add("Tree", d.Display, TT.PriceFor(d, 0), id) elseif d then add("TreeX", d.Display, 0, id, tostring(d.NotSold or d.Starter)) end end
for _, id in DT.Order do local d = DT.Defs[id]; if d and not d.FriendOnly then
	local cost = d.Cost or {LeafValue = d.Price}
	local cos = DT.IsCosmetic and DT.IsCosmetic(d)
	add("Decor", d.Display, cost.LeafValue or 0, id, (cost.Gems and "gems" or "") .. (cost.Clover and "clover" or "") .. (cos and "cosmetic" or "") .. ((d.Station or d.Building) and "building" or "")) end end
for _, id in DB.Order do local b = DB.Boxes[id]; add("Box", b.Display, b.Price, id) end
for _, f in IC.FenceSkins do if f.Cost or f.Gems then add("Fence", f.Display, f.Cost or 0, f.Id, f.Gems and "gems" or "") end end
for i, t in IC.Tiers do add("Island", t.Display, t.Cost, t.Id, tostring(i)) end
for _, r in EC.Robots do add("Robot", r.Display, 0, r.Id) end
for _, u in ECo.GemUnlocks do add("GemUnlock", u.Display, u.Gems, u.Id) end
for _, u in ECo.GemUpgrades do add("GemUpgrade", u.Display, u.Cost(0), u.Id, tostring(u.Max)) end
