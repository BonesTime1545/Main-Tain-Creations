import sys,os
AG=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
NEW=AG+'/new/'
def build(mods, tail, out):
    s=open('/home/user/Main-Tain-Creations/roblox/tests/stubs.lua').read()
    s+='''
local anyMT = {}
anyMT.__index = function(t,k) return setmetatable({}, anyMT) end
anyMT.__call = function(t,...) return setmetatable({}, anyMT) end
Color3 = { fromHex=function() return {} end, fromRGB = function(r,g,b) return {R=r,G=g,B=b} end, new=function(r,g,b) return {R=r,G=g,B=b} end, fromHSV=function() return {} end }
Vector2 = { new = function(x,y) return {X=x,Y=y} end }
UDim2 = setmetatable({}, anyMT)
UDim = setmetatable({}, anyMT)
Enum = setmetatable({}, anyMT)
BrickColor = setmetatable({}, anyMT)
Instance = { new = function() return setmetatable({}, anyMT) end }
NumberSequence = setmetatable({}, anyMT); NumberSequenceKeypoint = setmetatable({}, anyMT); ColorSequenceKeypoint = setmetatable({}, anyMT); NumberRange = setmetatable({}, anyMT); TweenInfo = setmetatable({}, anyMT); Rect = setmetatable({}, anyMT); Region3 = setmetatable({}, anyMT); Ray = setmetatable({}, anyMT); PhysicalProperties = setmetatable({}, anyMT); Font = setmetatable({}, anyMT)
ColorSequence = setmetatable({}, anyMT)
Random = { new = function() return { NextNumber=function() return 0.5 end, NextInteger=function() return 1 end } end }
game = { GetService = function() return setmetatable({ IsStudio=function() return false end, IsServer=function() return true end, IsClient=function() return false end, Heartbeat={Connect=function() end} }, anyMT) end }
workspace = { GetServerTimeNow = function() return 0 end, GetAttribute=function() return nil end }
local __srcs, __cache = {}, {}
local __parent = { WaitForChild = function(_, n) return {__mod = n} end, FindFirstChild = function(_, n) return {__mod = n} end }
local __script = { Parent = __parent }
local __realRequire = require
function require(x)
	if type(x) == "table" and x.__mod then
		local n = x.__mod
		if __cache[n] == nil then
			local f = __srcs[n]
			if not f then error("no module " .. n) end
			__cache[n] = f(__script)
		end
		return __cache[n]
	end
	return __realRequire(x)
end
'''
    for m in mods:
        src=open(NEW+m+'.lua',encoding='utf8').read()
        s+='__srcs["%s"] = function(script)\n%s\nend\n'%(m,src)
    s+=open(tail).read()
    open(out,'w',encoding='utf8').write(s)
if __name__=='__main__':
    build(sys.argv[3].split(','), sys.argv[1], sys.argv[2])
