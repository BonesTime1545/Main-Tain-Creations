"""Export every script of a .rbxl as <out_dir>/<Name>.lua.
   python3 -s export_scripts.py place.rbxl out_dir        (needs: pip install lz4 zstandard)
   Names are unique in this place. rbxwrite.py puts edited files back (see ../README.md)."""
import os, pickle, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from tree import parse
classes, inst, props, parent = parse(sys.argv[1])
os.makedirs(sys.argv[2], exist_ok=True)
byc = {}
for r, c in inst.items():
    byc.setdefault(c, []).append(r)
n = 0
for c, l in byc.items():
    if classes[c] in ("ModuleScript", "LocalScript", "Script"):
        for i, name in enumerate(props[(c, "Name")]):
            open(os.path.join(sys.argv[2], name + ".lua"), "w", encoding="utf8", newline="").write(props[(c, "Source")][i])
            n += 1
print(n, "scripts exported")
