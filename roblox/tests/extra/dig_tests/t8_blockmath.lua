-- pure logic of BlockMath / BlockConfig (pit, slabs, variants, encode/decode, CheckChange)
local fails=0
local function eq(a,b,label) if a~=b then fails+=1 print("FAIL",label,"got",tostring(a),"expected",tostring(b)) end end
local b={}
-- pit: untouched earth is solid, dig, refill
eq(BM.Get(b,0,0,0),"D","untouched earth at level 0")
eq(BM.Get(b,0,0,-4),"D","untouched earth at level -4")
eq(BM.Get(b,0,0,-5),nil,"below the pit")
BM.Set(b,0,0,0,nil)
eq(BM.Get(b,0,0,0),nil,"dug level 0")
eq(BM.Get(b,0,0,-1),"D","level -1 still earth")
eq(BM.TopH(b,0,0),-1,"TopH after one dig = -1")
BM.Set(b,0,0,-1,nil); BM.Set(b,0,0,-2,nil); BM.Set(b,0,0,-3,nil); BM.Set(b,0,0,-4,nil)
eq(BM.TopH(b,0,0),-5,"TopH all dug = -5 (the bed)")
eq(BM.HasAny(b,0,0),true,"HasAny with a pit")
-- refill
for l=-4,0 do BM.Set(b,0,0,l,"D") end
eq(b.Pit,nil,"refilled with earth = no pit data left")
eq(BM.HasAny(b,0,0),false,"HasAny after refill")
-- a block in a hole, a coloured one stays explicit
BM.Set(b,1,1,0,nil); BM.Set(b,1,1,0,"R")
eq(BM.Get(b,1,1,0),"R","stone in the hole")
BM.Set(b,1,1,0,nil); BM.Set(b,1,1,0,"D",3)
eq(BM.Get(b,1,1,0),"D","coloured earth in the hole")
eq(BM.GetVariant(b,1,1,0),3,"its variant")
-- encode / decode round trip
BM.Set(b,2,2,1,"D"); BM.Set(b,2,2,2,"s"); BM.Set(b,3,0,1,"W"); BM.Set(b,3,3,-2,nil)
local d=BM.Decode(BM.Encode(b))
for cx=0,3 do for cz=0,3 do for l=-4,5 do
	eq(BM.Get(d,cx,cz,l),BM.Get(b,cx,cz,l),"roundtrip "..cx..","..cz..","..l)
	eq(BM.GetVariant(d,cx,cz,l),BM.GetVariant(b,cx,cz,l),"roundtrip var "..cx..","..cz..","..l)
end end end
-- sanitize keeps the pit, drops cells outside the garden
b.Pit["9,9"]="-"
local clean=BM.Sanitize(b,4)
eq(clean.Pit["9,9"],nil,"outside cell dropped")
eq(clean.Pit["3,3"]~=nil,true,"pit cell kept")
-- CheckChange
local size,cell=20,5
local function cc(blocks,cx,cz,l,code) local ok,why=BM.CheckChange(blocks,{},cx,cz,l,code,size,cell) return ok,why end
local e={}
eq((cc(e,1,1,1,"D")),true,"earth on the floor")
eq((cc(e,1,1,2,"D")),false,"floating block refused")
eq((cc(e,1,1,0,"D")),false,"earth into untouched earth refused")
eq((cc(e,1,1,0,nil)),true,"dig the floor")
eq((cc(e,1,1,-5,nil)),false,"can't dig below the pit")
eq((cc(e,1,1,6,"D")),false,"max height")
local why; eq((function() local ok,w=cc(e,1,1,0,"W") why=w return ok end)(),false,"no water in the pit")
local p={} BM.Set(p,1,1,0,nil)
eq((cc(p,1,1,0,"R")),true,"stone into the hole (neighbours support it)")
eq((cc(p,1,1,-1,"R")),false,"stone into untouched earth")
BM.Set(p,1,1,-1,nil)
eq((cc(p,1,1,-1,"R")),true,"stone into a dug slot")
local sl={} BM.Set(sl,1,1,1,"d")
eq((cc(sl,1,1,1,"d")),true,"slab onto the same slab")
eq((cc(sl,1,1,1,"r")),false,"other slab onto a slab refused")
eq(BM.TopH(sl,1,1),0.5,"TopH of a slab on the floor")
-- entrance: nothing above the ground there, digging is fine
local n=BM.IsEntrance(2,3,size,cell) 
eq(n,true,"gate cell")
eq((cc(e,2,3,1,"D")),false,"entrance stays free above ground")
eq((cc(e,2,3,0,nil)),true,"entrance can be dug")
print(fails==0 and "BLOCKMATH OK" or ("FAILURES "..fails))
