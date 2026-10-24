"""VGA palette quality constraints and time-based cycling across assembled demos."""
import pathlib
import re

from emu import Run
from atlas_state_reference import NAMES

ROOT = pathlib.Path(__file__).resolve().parent.parent
ALL = ('CAUSAL', 'PHASE', 'HORIZON', 'COMMUTE', 'LIFT', 'MIRROR',
       'RESFIELD', 'SHUFFLE') + NAMES
families = {}
for name in ALL:
    source = (ROOT / 'src' / (name.lower()+'.asm')).read_text()
    family = int(re.search(r'%define PALETTE (\d+)', source).group(1))
    r = Run(name+'.COM').frames(1)
    values = r.dac()
    assert len(values) == 768 and all(0 <= c <= 63 for c in values), name
    rgb = [tuple(values[i:i+3]) for i in range(0, 768, 3)]
    assert len(set(rgb)) >= 64, (name, 'insufficient distinct colours')
    assert max(max(c)-min(c) for c in rgb) >= 30, (name, 'weak chroma')
    # Smooth 6-bit ramps: neighbouring indices change each channel by at most 1.
    assert all(abs(a-b) <= 1 for p, q in zip(rgb, rgb[1:])
               for a, b in zip(p, q)), (name, 'palette discontinuity')
    if family == 7:
        assert all(abs(a-b) <= 1 for a, b in zip(rgb[-1], rgb[0]))
        r.uc.mem_write(0x46C, (4).to_bytes(4, 'little'))
        r.frames(1)
        cycled = r.dac()[-768:]
        assert len(r.dac()) == 1536
        assert cycled == values[3:]+values[:3], (name, 'wrong cycle direction or length')
        r.uc.mem_write(0x46C, (1024).to_bytes(4, 'little'))
        r.frames(1)
        assert r.dac()[-768:] == values, (name, 'cycle does not wrap exactly')
    else:
        assert rgb[0] == (0, 0, 0)
        assert min(rgb[-1]) < max(rgb[-1]) and max(rgb[-1]) == 63
        assert sum(rgb[-1]) >= 120, (name, 'dim endpoint')
        assert all(sum(p) <= sum(q) for p, q in zip(rgb, rgb[1:])), name
        r.frames(1)
        assert len(r.dac()) == 768, (name, 'static palette rewritten unnecessarily')
    if family in families:
        assert families[family] == values, (name, 'inconsistent palette family')
    families[family] = values
    print(name, 'smooth vivid VGA palette and cycle PASS', flush=True)
assert len(families) == 7 and len({tuple(v) for v in families.values()}) == 7
print('Seven distinct palette families PASS')
