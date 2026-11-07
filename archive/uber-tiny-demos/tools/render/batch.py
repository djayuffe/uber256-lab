import sys, os, subprocess
sys.path.insert(0, '/tmp/render')
import emu
D = '/Users/ulfbertilsson/Downloads/'
# name, com path, shown-as, how, step, frames, gif fps, gif size, colours
JOBS = {
 'ROOTS':   (D+'uber256-lab/ROOTS.COM', 'vsync', 2, 150, 25, (320, 200), 128),
 'ORDER':   (D+'uber256-lab/ORDER.COM', 'vsync', 1, 150, 25, (320, 200), 64),
 'WARP':    (D+'uber256-lab/WARP.COM', 'vsync', 3, 150, 23, (480, 300), 16),
 'LATCH':   (D+'uber256-lab/LATCH.COM', 'vsync', 2, 150, 25, (320, 200), 16),
 'STKRAIN': (D+'uber-micro-demos/STKRAIN.COM', 'instr', 120000, 100, 25, (480, 300), 16),
 'FLUX':    (D+'uber-micro-demos/FLUX.COM', 'instr', 120000, 100, 25, (480, 300), 16),
 'EVO1':    (D+'uber-micro-demos/EVO1.COM', 'instr', 120000, 100, 25, (480, 300), 16),
 'EVO2':    (D+'uber-micro-demos/EVO2.COM', 'instr', 120000, 100, 25, (480, 300), 16),
 'OVERSUB': (D+'uber-micro-demos/OVERSUB.COM', 'instr', 120000, 100, 25, (480, 300), 16),
 'SNOW':    (D+'uber-micro-demos/SNOW.COM', 'instr', 120000, 100, 25, (480, 300), 16),
 'UBER10':  (D+'uber10-dos-demo/UBER10.COM', 'tick', 1, 90, 18, (480, 300), 16),
 'UBER128': (D+'uber128-dos-demo/UBER128.COM', 'vsync', 3, 120, 23, (320, 200), 128),
 'MOIRE':   (D+'UBER256/MOIRE.COM', 'vsync', 3, 120, 23, (320, 200), 128),
 'UBER256': (D+'uber256-rotozoomer/UBER256.COM', 'vsync', 3, 120, 23, (320, 200), 128),
}
for name in sys.argv[1:]:
    com, how, step, n, fps, (w, h), cols = JOBS[name]
    out = f'/tmp/render/frames/{name}'; os.makedirs(out, exist_ok=True)
    for f in os.listdir(out): os.remove(os.path.join(out, f))
    m = emu.M(com, os.path.basename(com), hlt=(how == 'tick'))
    for i in range(n):
        if how == 'instr': m.run('instr', step)
        else:
            for _ in range(step): m.run(how)
        m.image().save(f'{out}/{i:04d}.png')
    subprocess.run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y', '-framerate', str(fps), '-i', f'{out}/%04d.png', '-vf',
                    f'scale={w}:{h}:flags=area,split[a][b];[a]palettegen=max_colors={cols}:stats_mode=full[p];[b][p]paletteuse=dither=none:diff_mode=rectangle',
                    f'/tmp/render/{name}.gif'], check=True)
    print(name, os.path.getsize(f'/tmp/render/{name}.gif'), 'mode', hex(m.mode), flush=True)
