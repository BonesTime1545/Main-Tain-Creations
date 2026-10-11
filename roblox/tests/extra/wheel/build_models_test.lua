-- smoke test: the new pet shapes and cosmetic builders run without an error and make a sane number of parts
local function newObj(class, name)
	local o = { ClassName = class, Name = name, attrs = {}, kids = {} }
	function o:SetAttribute(k, v) self.attrs[k] = v end
	function o:GetAttribute(k) return self.attrs[k] end
	function o:GetChildren() return self.kids end
	function o:IsA(c) return c == "BasePart" or c == self.ClassName end
	function o:FindFirstChild(n) for _, k in self.kids do if k.Name == n then return k end end return nil end
	return o
end
-- ---------- PetShapes
do
	local BUILD = {}
	local count
	local function part(m, name, shape, size, color, cf, material)
		local p = newObj("Part", name)
		p.Size, p.Color, p.CF, p.Material = size, color, cf, material
		table.insert(m.kids, p)
		count += 1
		return p
	end
	local function anim(p, kind, phase) p:SetAttribute("Anim", kind); p:SetAttribute("Phase", phase); return p end
	local function eyes() end
	local function cuteEyes(m) part(m, "Eye", nil, nil, nil, nil); part(m, "Shine", nil, nil, nil, nil) end
	local function darker(c) return c end
	local function hwing(m, hinge, sx, rest, kind, specs)
		local out = {}
		for _, sp in specs do
			assert(type(sp[1]) == "string" and sp[3] ~= nil and sp[4] ~= nil and sp[5] ~= nil, "bad wing spec")
			table.insert(out, part(m, sp[1], sp[2], sp[3], sp[4], sp[5], sp[7]))
		end
		return out
	end
	local function swing(p) return p end
	local H = { part = part, anim = anim, eyes = eyes, cuteEyes = cuteEyes, darker = darker, BALL = "Ball", BLUSH = 1, hwing = hwing, swing = swing }
	local f = MOD_PetShapes()
	f(BUILD, H)
	for _, id in { "RaffleMouse", "FortuneFox", "SpotlightPeacock", "PrismPhoenix" } do
		check(type(BUILD[id]) == "function", id .. " has a shape builder")
		local m = newObj("Model", id)
		count = 0
		local ok, err = pcall(BUILD[id], m, Color3.fromRGB(255, 150, 190))
		check(ok, id .. " builds: " .. tostring(err))
		check(count >= 20 and count <= 120, id .. " part count " .. count)
		check(m:GetAttribute("Motion") ~= nil, id .. " has a Motion")
		if id == "PrismPhoenix" then
			check(m:GetAttribute("Rainbow") == true, "phoenix cycles colours")
			local tinted = 0
			for _, p in m.kids do if p:GetAttribute("Tint") then tinted += 1 end end
			check(tinted >= 8, "phoenix has tinted flame parts: " .. tinted)
		end
	end
end
-- ---------- DecorModels
do
	local Decor = {}
	local count
	local function part(m, props)
		local p = newObj("Part", props.Name)
		for k, v in props do p[k] = v end
		table.insert(m.kids, p)
		count += 1
		return p
	end
	local H = {
		part = part,
		limb = function(m, name) return part(m, { Name = name }) end,
		emitter = function() end,
		light = function() end,
		SMOKE = "s", FIRE = "f", climb = function() end,
	}
	local f = MOD_DecorModels()
	f(Decor, H)
	for _, id in { "WheelOfFortune", "JackpotTrophy" } do
		check(type(Decor[id]) == "function", id .. " builder exists")
		local m = newObj("Model", id)
		local base = newObj("Part", "Base")
		base.CFrame = { ToObjectSpace = function(self) return self end }
		table.insert(m.kids, base)
		count = 0
		local ok, err = pcall(Decor[id], m, { NextNumber = function() return 0.5 end }, DT.Defs[id])
		check(ok, id .. " builds: " .. tostring(err))
		check(count >= 15, id .. " part count " .. count)
		local moving = 0
		for _, p in m.kids do if p:GetAttribute("Spin") or p:GetAttribute("Bob") then moving += 1 end end
		check(moving >= 2, id .. " has moving parts: " .. moving)
	end
end
