-- ---- mocks
local clock = 100
local delayed = {}
task = { delay = function(t, fn) table.insert(delayed, { at = clock + t, fn = fn }) end }
local function runDelayed()
	table.sort(delayed, function(a, b) return a.at < b.at end)
	for _, d in delayed do clock = math.max(clock, d.at); d.fn() end
	delayed = {}
end
local V = Vector3
local function mkPlayer(name, pos, look)
	local attrs = {}
	local root = { Position = pos, CFrame = { LookVector = look or V.new(0, 0, -1) }, Name = "HumanoidRootPart" }
	local tool = { Name = "t", IsA = function(_, c) return c == "Tool" end, GetAttribute = function(_, k) if k == "LeafTool" then return "Blaster" end end }
	local hum = { Health = 100 }
	local char = {
		FindFirstChild = function(_, n) if n == "HumanoidRootPart" then return root end end,
		FindFirstChildOfClass = function(_, c) if c == "Humanoid" then return hum end end,
		GetChildren = function() return { tool } end,
	}
	local pl = { Name = name, Character = char, Parent = true, UserId = #name }
	function pl:SetAttribute(k, v) attrs[k] = v end
	function pl:GetAttribute(k) return attrs[k] end
	pl.attrs = attrs
	return pl
end
local TCm = TC_MODULE
local shooter = mkPlayer("shooter", V.new(0, 0, 0))
local ahead = mkPlayer("ahead_", V.new(0, 0, -15))      -- in the line of fire
local aside = mkPlayer("aside", V.new(14, 0, -15))      -- far to the side
local behind = mkPlayer("behindd", V.new(0, 0, 10))     -- behind the shooter
local far = mkPlayer("far", V.new(0, 0, -60))           -- beyond the range
local players = { shooter, ahead, aside, behind, far }
local data = { Tools = { Owned = { Blaster = true }, Up = { Blaster = {} }, BlastUsed = 0 } }
local fx, knock, notes = {}, {}, {}
local ctx = {
	ToolConfig = TCm,
	PlayerDataService = { Get = function(p) return if p == shooter then data else nil end },
	Players = { GetPlayers = function() return players end },
	Net = {
		ToolFX = { FireAllClients = function(_, ...) table.insert(fx, { ... }) end },
		Knockback = { FireClient = function(_, who, dv, from) table.insert(knock, { who = who.Name, dv = dv, from = from }) end },
		Notify = { FireClient = function(_, p, t) table.insert(notes, t) end },
	},
	SecurityService = { Grace = function() end },
}
local S = SERVICE_MODULE
S.Now = function() return clock end
S.Init(ctx)
local function show(label) print(label, "mag=" .. tostring(shooter.attrs.BlastMag), "reloadAt=" .. tostring(shooter.attrs.BlastReloadAt), "left=" .. tostring(shooter.attrs.BlastLeft) .. "/" .. tostring(shooter.attrs.BlastMax), "seq=" .. tostring(shooter.attrs.BlastSeq)) end
local dir = V.new(0, 0, -1)
-- 6 shots 0.6 s apart, then the 7th during the reload
for i = 1, 7 do
	local n, why = S.BlastAt(shooter, dir)
	show(("shot %d -> pushed %s %s"):format(i, tostring(n), tostring(why)))
	clock += 0.6
end
runDelayed()
print("knockbacks after 7 shots (only the 6 real ones count):", #knock)
local names = {}
for _, k in knock do names[k.who] = (names[k.who] or 0) + 1 end
for n, c in names do print("  ", n, c) end
print("  sample dv:", knock[1].dv.X, knock[1].dv.Y, knock[1].dv.Z)
print("FX packets:", #fx, "first kind:", fx[1][1], "size/range/tier:", fx[1][6].X, fx[1][6].Y, fx[1][6].Z)
-- reload completes by the clock
clock += 3
local n = S.BlastAt(shooter, dir); show("after reload, shot -> " .. tostring(n))
-- too fast
local n2, why2 = S.BlastAt(shooter, dir); print("immediately again ->", n2, why2)
-- manual reload
clock += 1
print("manual reload ok?", S.BlastReload(shooter)); show("manual reload")
print("manual reload again (already reloading):", S.BlastReload(shooter))
-- energy
clock += 5
data.Tools.BlastUsed = 59
S.PublishBlast(shooter, true)
print("energy 59 used -> shot:", S.BlastAt(shooter, dir)); show("last pulse of energy")
clock += 5
print("empty ->", S.BlastAt(shooter, dir)); print("notes:", table.concat(notes, " | "))
-- recharge cost (no money system here)
print("recharge cost:", S.RechargeBlastCost(data))
-- bad inputs
data.Tools.BlastUsed = 0; clock += 5; S.PublishBlast(shooter, true)
print("nan dir:", S.BlastAt(shooter, V.new(0/0, 0, 0)), " zero dir:", S.BlastAt(shooter, V.new(0, 5, 0)), " string:", S.BlastAt(shooter, "x"))

-- ---------- a fully upgraded blaster breaks ice in the line of its pulse (3 hit points: 3 pulses)
data.Tools.Up.Blaster = { Power = 5, Rate = 5, Size = 5, Energy = 5 }
data.Tools.BlastUsed = 0
local ice = { Position = V.new(0, 0, -12), Parent = true, hp = 3 }
local off = { Position = V.new(20, 0, -12), Parent = true, hp = 3 }
ctx.PlotSystem = { Get = function() return {} end }
ctx.ResourceService = {
	AliveIn = function() local set = { [ice] = true, [off] = true } return next, set end,
	IsIced = function(part) return part.hp > 0 end,
	HitIce = function(part, dmg) part.hp -= dmg; return part.hp <= 0 end,
}
shooter.attrs.BlastReloadAt = nil
local bursts = 0
local heavyDuring
for i = 1, 3 do clock += 5; S.BlastAt(shooter, dir); heavyDuring = shooter.attrs.BlowHeavy; runDelayed() end
print((ice.hp <= 0 and "PASS" or "FAIL") .. " maxed blaster broke the ice block in 3 pulses (hp " .. ice.hp .. ")")
print((off.hp == 3 and "PASS" or "FAIL") .. " ice out of the line is untouched")
print((heavyDuring == true and "PASS" or "FAIL") .. " stones are loose while it fires")
data.Tools.Up.Blaster = { Power = 5, Rate = 5, Size = 5, Energy = 4 }
ice.hp = 3
clock += 5; S.BlastAt(shooter, dir); runDelayed()
print((ice.hp == 3 and "PASS" or "FAIL") .. " a blaster that is not fully upgraded leaves the ice alone")
