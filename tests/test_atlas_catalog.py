"""Keep launcher, capture inventory and source-proposal ledger synchronized."""
import pathlib
import re
import runpy
import csv

ROOT = pathlib.Path(__file__).resolve().parent.parent
launcher = (ROOT / 'run-dosbox.sh').read_text()
groups = {}
for key in ('ORDER', 'ATLAS'):
    groups[key] = re.search(r'^'+key+r'="([^"]+)"$', launcher, re.M).group(1).upper().split()
    assert len(groups[key]) == len(set(groups[key])), (key, 'duplicate demo')
sources = {path.stem.upper() for path in (ROOT / 'src').glob('*.asm')}
assert set(groups['ORDER']) == sources, 'launcher missing a standalone demo'
capture = runpy.run_path(str(ROOT / 'tools' / 'render_temporal.py'))
assert set(groups['ATLAS']) == set(capture['ALL_NAMES'])
assert len(capture['ALL_NAMES']) == len(set(capture['ALL_NAMES']))
assert set(groups['ATLAS']) <= sources
show = (ROOT / 'src' / 'mega' / 'atlas_program.inc').read_text()
show_names = re.findall(r'^\s+ENTRY ([a-z]+),', show, re.M)
assert len(show_names) == len(groups['ATLAS'])
assert {name.upper() for name in show_names} == set(groups['ATLAS'])
for line in show.splitlines():
    if line.strip().startswith('ENTRY '):
        fields = next(csv.reader([line.strip()[6:]], skipinitialspace=True))
        assert len(fields) == 6, 'incomplete playlist metadata'
        name = fields[0].upper()
        assert fields[1] == 'SZ_'+name and fields[3] == name
        assert fields[5] == 'build/'+name+'.MEG', 'playlist embeds the wrong effect binary'
assert (ROOT / 'ATLAS.COM').is_file()
ledger = (ROOT / 'docs' / 'ATLAS_COVERAGE.md').read_text()
rows = re.findall(r'^\| ([A-O][0-9]{2}) \| ([^|]+) \| ([^|]+) \|$', ledger, re.M)
assert {row[0] for row in rows} == {f'{letter}{n:02d}' for letter in 'ABCDEFGHIJKLMNO' for n in range(1, 11)}
assert len(rows) == 150
adapted = [row for row in rows if row[2].startswith('Adapted:')]
names = {row[2].split()[1] for row in adapted}
assert names == set(groups['ATLAS']), 'ledger adaptation references missing or unused demo'
assert len(adapted) == len(names)+1  # CAUSAL explicitly adapts two proposal IDs
for name in names:
    assert (ROOT / 'docs' / (name.lower()+'-atlas.png')).is_file(), name
print('Atlas launcher, captures and all 150 coverage entries PASS')
