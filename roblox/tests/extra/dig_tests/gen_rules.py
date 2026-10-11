# headless harness for the ROUND 6 "rules" tests (pure modules only). Usage:
#   LUAU=luau SRC=<dir with the exported .lua scripts> OLD=<dir with the scripts BEFORE round 6 (for the WaterFlow comparison)> python3 gen_rules.py t9_rules.lua | luau
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.environ['SRC']; OLD = os.environ.get('OLD', SRC)
out = [open(HERE + '/prelude.lua').read()]
out.append('MODS={}\nLOADED={}\n')
out.append('''SHARED={}
SHARED.WaitForChild=function(self,n) return {__mod=n, Parent=SHARED, WaitForChild=SHARED.WaitForChild} end
require=function(m) local n=m.__mod or m.Name if LOADED[n] then return LOADED[n] end m.Parent=m.Parent or SHARED local v=MODS[n](m) LOADED[n]=v return v end
TREEDEFS={}
''')
out.append('MODS.TreeTypes=function() return {Get=function(id) return TREEDEFS[id] end} end\nMODS.DecorTypes=function() return {} end\n')
for m in ['BlockConfig', 'BlockMath', 'WaterFlow', 'PlotMath', 'TreePlacement']:
    out.append('MODS.%s=function(script)\n%s\nend\n' % (m, open('%s/%s.lua' % (SRC, m)).read()))
out.append('MODS.OldWaterFlow=function(script)\n%s\nend\n' % open('%s/WaterFlow.lua' % OLD).read())
out.append(open(HERE + '/test.lua').read().split('local BlockService')[0].split('\n', 0)[0] if False else '')
out.append(open(sys.argv[1]).read())
sys.stdout.write('\n'.join(out))
