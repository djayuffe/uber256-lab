"""Exercise launch selection and rebuilding with a DOSBox test double."""
import os
import pathlib
import re
import subprocess

ROOT = pathlib.Path(__file__).resolve().parent.parent
env = dict(os.environ, DOSBOX_BIN=str(ROOT / 'tests' / 'stubs' / 'dosbox'))


def launch(*args, expected=0):
    result = subprocess.run([str(ROOT / 'run-dosbox.sh'), *args], cwd=ROOT,
                            env=env, capture_output=True, text=True)
    assert result.returncode == expected, (args, result.stdout, result.stderr)
    return result.stdout


names = {path.stem for path in (ROOT / 'src').glob('*.asm')}
listing = launch('--list')
assert all(name in listing.splitlines() for name in names)
assert 'atlas-show' in listing and 'usage:' in launch('--help')
launch(expected=1)
launch('does-not-exist', expected=1)
before = (ROOT / 'ATLAS.COM').stat().st_mtime_ns
show = launch('atlas-show')
assert re.findall(r'^([A-Z]+\.COM)$', show, re.M) == ['ATLAS.COM']
assert (ROOT / 'ATLAS.COM').stat().st_mtime_ns > before, 'existing binaries were not rebuilt'
assert re.findall(r'^([A-Z]+\.COM)$', launch('*tex'), re.M) == ['SELFTEX.COM', 'GOLDTEX.COM', 'FLOWTEX.COM']
atlas = re.findall(r'^([A-Z]+\.COM)$', launch('atlas'), re.M)
playlist = (ROOT / 'src' / 'mega' / 'atlas_program.inc').read_text()
atlas_names = re.findall(r'^\s+ENTRY ([a-z]+),', playlist, re.M)
assert len(atlas) == len(atlas_names) and len(set(atlas)) == len(atlas_names)
assert all((ROOT / name).is_file() for name in atlas)
print('Launcher: listing, help, errors, patterns, atlas show and fresh rebuild PASS')
