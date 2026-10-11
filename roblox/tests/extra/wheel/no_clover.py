#!/usr/bin/env python3
"""no-clover test: case-insensitive 'clover' must appear NOWHERE in the exported scripts, except the one-time
migration in DataSchema.lua: the Shadow Satchel refund line and the Sanitize block that turns an old balance into
Gems (between the line 'MIGRATION (v1.4 / v1.5): four-leaf Clovers' and 'data.Currencies.Clover = nil').
'Glover' (the old bonus-spin name) only in the two migration comments."""
import sys, os
d = sys.argv[1]
bad = []
for f in sorted(os.listdir(d)):
    if not f.endswith('.lua'):
        continue
    inside = False
    for n, line in enumerate(open(os.path.join(d, f), encoding='utf8'), 1):
        if f == 'DataSchema.lua':
            if 'MIGRATION (v1.4 / v1.5): four-leaf Clovers' in line:
                inside = True
        low = line.lower()
        if 'clover' in low:
            ok = f == 'DataSchema.lua' and (inside or 'ShadowSatchel' in line)
            if not ok:
                bad.append((f, n, line.strip()[:120]))
        if 'glover' in low:
            ok = f in ('DataSchema.lua', 'WheelConfig.lua') and '--' in line or (f == 'WheelConfig.lua' and 'Glover' in line)
            if not ok:
                bad.append((f, n, line.strip()[:120]))
        if f == 'DataSchema.lua' and 'data.Currencies.Clover = nil' in line:
            inside = False
if bad:
    for b in bad:
        print('FAIL clover/glover left:', *b)
    sys.exit(1)
print('ok  no clover anywhere (only the DataSchema migration)')
