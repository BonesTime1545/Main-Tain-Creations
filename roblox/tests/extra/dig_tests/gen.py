# headless harness for the block system (luau CLI + tiny Roblox stubs). Usage:
#   LUAU=/path/to/luau SRC=/path/to/exported/scripts bash run.sh        (SRC = dir with BlockService.lua, BlockMath.lua …)
# Each tN_*.lua is appended to the stubs + modules; ROT=1 also loads the real island 1 geometry (island1.lua).
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.environ['SRC']
real = ['BlockConfig', 'BlockMath', 'WaterFlow', 'PlotMath', 'BlockService', 'BlockFX']
out = [open(HERE + '/prelude.lua').read()]
if os.environ.get('ROT'):
    out.append(open(HERE + '/island1.lua').read())
    out.append('ROTPLOT=CFrame.new(217,0.04,125)*CFrame.Angles(0,math.rad(-120),0)*CFrame.new(0,0,40)\n')
out.append('MODS={}\nLOADED={}\n')
out.append('''SHARED={}
SHARED.WaitForChild=function(self,n) return {__mod=n, Parent=SHARED, WaitForChild=SHARED.WaitForChild} end
require=function(m) local n=m.__mod or m.Name if LOADED[n] then return LOADED[n] end m.Parent=m.Parent or SHARED local v=MODS[n](m) LOADED[n]=v return v end
''')
out.append('MODS.TreeTypes=function() return {Get=function() return nil end} end\nMODS.DecorTypes=function() return {} end\n')
for m in real:
    out.append('MODS.%s=function(script)\n%s\nend\n' % (m, open('%s/%s.lua' % (SRC, m)).read()))
out.append(open(HERE + '/test.lua').read())
out.append(open(sys.argv[1]).read())
sys.stdout.write('\n'.join(out))
