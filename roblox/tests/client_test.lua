local TC = TC_MODULE
local Controller = CTL_MODULE
local V = Vector3
SERVER_NOW = 1000
local sent, jsound = {}, 0
local deps = {
	Config = { Resources = { MaxSpeed = 70 }, Collision = { QueryGroup = "q" }, FX = { ToolSounds = { Cut = "c", Loop = "l" } } },
	ToolConfig = TC,
	Remote = { FireServer = function(_, req) table.insert(sent, req) end },
	Juice = setmetatable({ EffectsOn = function() return false end, Sound = function() jsound += 1 end }, { __index = function() return function() end end }),
	Controls = { Is = function() return false end, KeyName = function() return "Q" end },
	MyResources = function() return { {} } end,
}
local ctl = Controller.new(deps)
local function part(x, z, extra)
	local p = { Position = V.new(x, 0.3, z), Anchored = false, ReceiveAge = 0, Parent = true, AssemblyLinearVelocity = V.zero, AssemblyAngularVelocity = V.zero,
		CurrentPhysicalProperties = { Density = 0.25, Friction = 0.55, Elasticity = 0.05, FrictionWeight = 1, ElasticityWeight = 1 }, CustomPhysicalProperties = nil,
		attrs = extra or {}, IsA = function() return true end }
	function p:GetAttribute(k) return self.attrs[k] end
	table.insert(FAKE_PARTS, p)
	return p
end
local B = ctl.ToolConfig.Blaster({})
ctl.root = { Position = V.new(0, 3, 0), CFrame = { LookVector = V.new(0, 0, -1) } }
ctl.active, ctl.kind = true, "Blaster"
-- a field of leaves in front + a stone, an ice block, an anchored (stuck) one, one owned by another client, and one behind
local leaves = {}
for i = -2, 2 do for j = 1, 6 do table.insert(leaves, part(i * 1.2, -8 - j * 1.5)) end end
local stone, ice, stuck, foreign, behind = part(0, -9, { Heavy = true }), part(1, -9.5, { IceHP = 3 }), part(-1, -9.5), part(2, -9), part(0, 6)
stuck.Anchored = true; foreign.ReceiveAge = 0.3
local p = ctl:_newPulse(V.new(0, 3, -2), V.new(0, 0, -1), B.Size, B.Range, B.Speed, 1, true, 0.9, B.Power, 20)
local frames = 0
while #ctl.pulses > 0 and frames < 600 do ctl:_blastWorld(1 / 60); frames += 1 end
print(("pulse lived %d frames (%.2f s), range %.0f studs at %.0f studs/s"):format(frames, frames / 60, B.Range, B.Speed))
local moved, maxv, minvy = 0, 0, 1e9
for _, l in leaves do
	local v = l.AssemblyLinearVelocity
	if v.Magnitude > 0.1 then moved += 1; maxv = math.max(maxv, v.Magnitude); minvy = math.min(minvy, v.Y) end
end
print("leaves moved:", moved, "of", #leaves, " max speed", string.format("%.1f", maxv), "(anti-teleport limit 70)  min hop", string.format("%.1f", minvy))
print("stone moved?", stone.AssemblyLinearVelocity.Magnitude > 0, " ice moved?", ice.AssemblyLinearVelocity.Magnitude > 0, " anchored moved?", stuck.AssemblyLinearVelocity.Magnitude > 0, " foreign-owned moved?", foreign.AssemblyLinearVelocity.Magnitude > 0, " behind moved?", behind.AssemblyLinearVelocity.Magnitude > 0)
print("bouncy set on", ctl.flyN, "items; elasticity of a hit leaf:", leaves[10].CustomPhysicalProperties and leaves[10].CustomPhysicalProperties.Elasticity)

-- ---------------- stone: untouched by an ordinary pulse, nudged (a quarter speed) by a fully upgraded one
for i = #FAKE_PARTS, 1, -1 do FAKE_PARTS[i] = nil end
ctl.flying, ctl.flyN, ctl.pulses = {}, 0, {}
local st1, st2, leaf = part(0, -8, { Heavy = true }), part(0.5, -8, { Heavy = true }), part(-0.5, -8)
local p1 = ctl:_newPulse(V.new(0, 3, -2), V.new(0, 0, -1), B.Size, B.Range, B.Speed, 1, true, 0.9, B.Power, 20)
for _ = 1, 40 do ctl:_blastWorld(1 / 60) end
print("ordinary pulse: stone moved?", st1.AssemblyLinearVelocity.Magnitude > 0, "leaf moved?", leaf.AssemblyLinearVelocity.Magnitude > 0)
st1.AssemblyLinearVelocity, leaf.AssemblyLinearVelocity = V.zero, V.zero
ctl.flying, ctl.flyN, ctl.pulses = {}, 0, {}
local p2 = ctl:_newPulse(V.new(0, 3, -2), V.new(0, 0, -1), B.Size, B.Range, B.Speed, 1, true, 0.9, B.Power, 20)
p2.stone = true
for _ = 1, 40 do ctl:_blastWorld(1 / 60) end
local sv, lv = flatSpeed and 0 or 0, 0
print("maxed pulse: stone moved?", st1.AssemblyLinearVelocity.Magnitude > 0, string.format("stone %.1f vs leaf %.1f horizontal", math.sqrt(st1.AssemblyLinearVelocity.X ^ 2 + st1.AssemblyLinearVelocity.Z ^ 2), math.sqrt(leaf.AssemblyLinearVelocity.X ^ 2 + leaf.AssemblyLinearVelocity.Z ^ 2)))
-- ---------------- chain scenario
for i = #FAKE_PARTS, 1, -1 do FAKE_PARTS[i] = nil end
ctl.flying, ctl.flyN, ctl.pulses = {}, 0, {}
local A = part(1.5, -10)     -- inside the pulse (radius 2.2)
local Bp = part(3.0, -12.0)  -- outside it, but where A flies
local C = part(4.2, -14.0)   -- the next link
local far = part(-8, -10)    -- nowhere near
local pp = ctl:_newPulse(V.new(0, 3, -2), V.new(0, 0, -1), B.Size, B.Range, B.Speed, 1, true, 0.9, B.Power, 20)
local function step(dt)
	FAKE_T += dt
	for _, l in FAKE_PARTS do
		if l.Parent and not l.Anchored then
			local v = l.AssemblyLinearVelocity
			v = V.new(v.X * (1 - 0.6 * dt), v.Y - 196 * dt, v.Z * (1 - 0.6 * dt))
			local pos = l.Position + v * dt
			if pos.Y < 0.3 then
				local e = if l.CustomPhysicalProperties then l.CustomPhysicalProperties.Elasticity else 0.05
				pos = V.new(pos.X, 0.3, pos.Z)
				v = V.new(v.X * 0.97, math.abs(v.Y) * e, v.Z * 0.97)
				if v.Y < 1.5 then v = V.new(v.X, 0, v.Z) end
			end
			l.Position, l.AssemblyLinearVelocity = pos, v
		end
	end
	ctl:_blastWorld(dt)
end
for _ = 1, 40 do step(1 / 60) end
local function speed(p) return string.format("%.1f", p.AssemblyLinearVelocity.Magnitude) end
print("A (hit by pulse)", speed(A), " B (outside the pulse)", speed(Bp), " C (next link)", speed(C), " far", speed(far))
print("bump sounds:", jsound, " flying tracked:", ctl.flyN, " B depth:", ctl.flying[Bp] and ctl.flying[Bp].depth, " C depth:", ctl.flying[C] and ctl.flying[C].depth)
-- the physics is put back after ~1.3 s
for _ = 1, 150 do step(1 / 60) end
print("after 2.5 s: tracked", ctl.flyN, " A props back to nil:", A.CustomPhysicalProperties == nil, " B:", Bp.CustomPhysicalProperties == nil, " C:", C.CustomPhysicalProperties == nil)
-- a leaf collected (removed) mid-flight must not error
local D = part(0.2, -9); local pp2 = ctl:_newPulse(V.new(0, 3, -2), V.new(0, 0, -1), B.Size, B.Range, B.Speed, 1, true, 0.9, B.Power, 20)
for _ = 1, 10 do step(1 / 60) end
D.Parent = nil
for _ = 1, 40 do step(1 / 60) end
print("collected mid-flight handled; tracked:", ctl.flyN)
-- the magazine as the client sees it
LOCAL_ATTRS.BlastSeq = 1; LOCAL_ATTRS.BlastMag = 6; LOCAL_ATTRS.BlastReloadAt = 0; LOCAL_ATTRS.BlastLeft = 60; LOCAL_ATTRS.BlastMax = 60
ctl.lastUse = -1e9
ctl.tool = nil
local function st() local m, c, l, t = ctl:BlastState(); return ("%d/%d reload %.1f"):format(m, c, l) end
print("state:", st())
local fired = 0
for i = 1, 8 do
	ctl.lastUse = -1e9
	local ok = ctl:_blastFire(V.new(0, 0, -20))
	if ok then fired += 1 end
	print(i, "fired:", ok, st())
end
print("shots really fired:", fired, " sent to the server:", #sent, " first request:", sent[1] and sent[1].A, sent[1] and ("%.2f"):format(sent[1].Dir.Z))
SERVER_NOW += 3
print("3 s later:", st())
print("manual reload while full:", ctl:Reload())
