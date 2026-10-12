#!/usr/bin/env python3
"""Run each 256-byte demo in an emulated 16-bit CPU (Unicorn, x87 included), entered the way DOS enters a .COM, and
check what it does to the hardware: video mode, palette, animation, FPU, the timer hook and the MIDI it plays, Esc."""
import math, struct, sys
from unicorn.x86_const import UC_X86_REG_BX, UC_X86_REG_BP, UC_X86_REG_DI
from emu import Run, BIOS_1C

fails = []
def check(ok, msg):
    print(("  PASS  " if ok else "  FAIL  ") + msg)
    if not ok: fails.append(msg)

PENTA = {0, 2, 4, 7, 9}                     # C major pentatonic, the scale every demo plays in

def lit(scr): return sum(1 for b in scr if b)

def common(name, r, mode=0x13, colours=256):
    check(len(r.com) <= 256, f"{name}: {len(r.com)} bytes (limit 256)")
    check(r.ints[0] == (0x10, mode), f"{name}: first call is INT 10h, AX = {mode:04X}h")
    if mode == 0x13:
        check(len(r.dac()) >= 3 * colours, f"{name}: programs {colours} DAC colours ({len(r.dac())} values)")
        check(max(r.dac()[:768]) > 20, f"{name}: palette is not black")
    check(not r.unmapped and (name == "FLOWTEX" or not r.high), f"{name}: touches no memory outside video RAM and its segment {r.unmapped[:3]}")
    check(not any(p in (0x42, 0x43, 0x61) for p, v in r.outs), f"{name}: never touches the PC speaker or PIT channel 2")

def music(name, r, program, ticks=64, lo=12, hi=None, between=0, scale=PENTA):
    """The timer hook and what it plays over `ticks` timer ticks (with `between` main-program instructions between
    ticks, for music that follows the drawing). Returns the note-ons."""
    seg, off = r.vector(0x1C)
    check(r.vec_sets and r.vec_sets[0][0] == 0x1C and (seg, off) == (0x1000, r.vec_sets[0][2]),
          f"{name}: hooks INT 1Ch (the 18.2 Hz timer tick) through DOS, with DS = its own segment")
    for k in range(ticks):
        if between: r.step(between)
        r.tick(1)
    check(r.isr_back and not r.isr_clobbers, f"{name}: the tick handler returns with IRET and preserves every register and segment (entered with DS = 0040h)")
    check(r.uart and any(p == 0x331 and v == 0x3F for p, v in r.outs), f"{name}: puts the MPU-401 into UART mode (3Fh to port 331h)")
    progs = {p for ch, p in r.programs()}
    check(progs == {program}, f"{name}: General MIDI program {program} on channel 1 ({sorted(progs)})")
    notes = [n for n in r.note_ons() if n[0] > 1]
    hi = hi if hi is not None else ticks
    check(lo <= len(notes) <= hi * 5, f"{name}: {len(notes)} notes in {ticks} ticks ({ticks / 18.2:.1f} s)")
    pcs = sorted({n[2] for n in notes if n[1] != 9})
    check(notes and all(n[2] % 12 in scale and 24 <= n[2] <= 103 and 0 < n[3] < 128 for n in notes if n[1] != 9),
          f"{name}: every pitched note is in {'C major pentatonic' if scale == PENTA else 'the chromatic scale'}, inside 24..103, with a valid velocity ({pcs})")
    return notes

def groove(name, notes):
    """groove.inc: GM drums on channel 10 every 4 ticks (kick, hat, snare, hat) and a bass on channel 2 with each kick."""
    drums = [(t, n) for t, ch, n, v in notes if ch == 9]
    want = {0: 36, 4: 42, 8: 38, 12: 42}
    check(len(drums) >= 8 and all(t % 4 == 0 and n == want[t % 16] for t, n in drums),
          f"{name}: drums on channel 10 every fourth tick: kick, hi-hat, snare, hi-hat ({len(drums)} hits)")
    bass = [(t, n) for t, ch, n, v in notes if ch == 1]
    check(len(bass) >= 3 and all(t % 16 == 0 and n == 36 + [0, 2, 4, 7, 9][(t // 16 * 4) % 256 % 5] for t, n in bass),
          f"{name}: a bass note on channel 2 with every kick, walking down the pentatonic scale ({[n for t, n in bass]})")
def mel(notes): return [n for n in notes if n[1] == 0]

def leaves(name, r, polls=1):
    r.run_until_exit(polls)
    check(r.exited and (0x10, 0x03) in r.ints and r.vector(0x1C) == BIOS_1C and r.vec_sets[-1][0] == 0x1C,
          f"{name}: Esc restores text mode 3, puts the old INT 1Ch vector back and returns to DOS")

# --------------------------------------------------------------------------------------------------------------
def attractor(name, program, every_tick):
    print(f"\n== {name} ==")
    r = Run(name + ".COM").frames(1)
    common(name, r)
    check(r.com.count(b"\xD9\xFE") >= 2 and b"\xD9\xFF" in r.com, f"{name}: uses the x87 FPU (fsin/fcos)")
    s1 = r.screen(); n1 = lit(s1)
    check(500 < n1 < 30000, f"{name}: a curve is drawn, not noise or a blank screen ({n1} lit pixels)")
    ys = [i // 320 for i, b in enumerate(s1) if b]; xs = [i % 320 for i, b in enumerate(s1) if b]
    check(max(ys) - min(ys) < 190 and max(xs) - min(xs) < 300 and min(ys) > 0, f"{name}: the attractor stays on screen (x {min(xs)}..{max(xs)}, y {min(ys)}..{max(ys)})")
    check(len(set(s1)) > 12, f"{name}: many brightness levels (accumulation, not on/off): {len(set(s1))}")
    r.frames(6); s2 = r.screen()
    check(sum(1 for a, b in zip(s1, s2) if a != b) > 2000, f"{name}: the picture evolves frame to frame (parameter morph + fade)")
    # the morph is bounded: a and d swing by s*cos(s*t) per frame, so run the clock across a whole cycle
    data = 0x10000 + 0x100 + len(r.com) - 20
    a0 = struct.unpack('<f', bytes(r.uc.mem_read(data, 4)))[0]; seen = []
    for k in range(12):
        r.uc.mem_write(0x46C, (k * 900).to_bytes(4, 'little')); r.frames(30)
        seen.append(struct.unpack('<f', bytes(r.uc.mem_read(data, 4)))[0])
    check(all(abs(a - a0) < 4 for a in seen) and max(seen) - min(seen) > 0.01, f"{name}: the morph stays bounded as the clock runs ({min(seen):.3f}..{max(seen):.3f})")
    notes = music(name, r, program)
    gaps = {b[0] - a[0] for a, b in zip(notes, notes[1:])}
    check(gaps == ({1} if every_tick else {2}), f"{name}: a note every {'tick' if every_tick else 'other tick'}, from the orbit ({len({n[2] for n in notes})} different notes)")
    leaves(name, Run(name + ".COM"), 3)

attractor("GALAXY", 11, False)
attractor("CLIFF", 12, True)

print("\n== SELFTEX ==")
r = Run("SELFTEX.COM"); r.uc.mem_write(0x46C, bytes(4)); r.polls(2); common("SELFTEX", r)
s = r.screen()[:64000]
code = r.com + bytes(256 - len(r.com))
check(all(s[y * 320:(y + 1) * 320] == bytes([y]) * 320 for y in range(61)), "SELFTEX: above the horizon each row is one colour, a sky ramp")
ground = s[61 * 320:]
water = [b for b in ground if 64 <= b < 128]; fields = [b for b in ground if b >= 128 and b != 136]
check(set(water) <= {64 | (c & 63) for c in code} and set(fields) <= {128 | c for c in code} and not any(b < 64 for b in ground),
      "SELFTEX: every ground pixel is a code byte: water (64 + byte AND 63), fields (128 + byte) or the dark shore")
rows = [s[y * 320:(y + 1) * 320] for y in range(61, 200)]
cols = [[x for x, b in enumerate(row) if 64 <= b < 128] for row in rows]
check(all(c for c in cols) and len(cols[-1]) > 60 and len(cols[2]) < 30, f"SELFTEX: a river in perspective: water in every row below the horizon, wide in front ({len(cols[-1])} px), narrow far away ({len(cols[2])} px)")
centres = [sum(c) / len(c) for c in cols]
check(max(centres) - min(centres) > 40, f"SELFTEX: the river bends (its centre moves {max(centres) - min(centres):.0f} pixels across the rows)")
r2 = Run("SELFTEX.COM"); r2.uc.mem_write(0x46C, (60).to_bytes(4, 'little')); r2.polls(2); s2 = r2.screen()[:64000]
check(sum(1 for a, b in zip(s, s2) if a != b) > 5000, "SELFTEX: three seconds later the river has moved and the water has flowed (time is the BIOS clock)")
check(b"\x0f\x31" not in r.com, "SELFTEX: integer only")
notes = mel(music("SELFTEX", r, 108))
check(notes and all(t % 2 == 0 and n == ((code[(t >> 1) & 255] & 30) + 46) * 6 // 5 for t, _, n, _ in notes),
      "SELFTEX: the melody is the program's own bytes, one per step, in order")
leaves("SELFTEX", Run("SELFTEX.COM"), 2)

print("\n== FLOWTEX ==")
r = Run("FLOWTEX.COM").frames(2); common("FLOWTEX", r)
s = r.screen()[:64000]
code = r.com + bytes(256 - len(r.com))
def flow_table():
    T = bytearray(65536)
    for k in range(65536):
        i, f = (k >> 5) & 255, k & 31
        a, b = code[i], code[(i + 1) & 255]
        T[k] = (a + ((b - a) * f >> 5)) & 255
    return T
FT = flow_table()
check(bytes(r.uc.mem_read(0x20000, 65536)) == bytes(FT), "FLOWTEX: the 64 KB table above the program is the code, 32 linearly interpolated steps between neighbouring bytes")
tt = int.from_bytes(r.uc.mem_read(0x1FF00, 2), 'little') - 1
check(all(s[y * 320 + x] == FT[(tt + (x + 1) * y // 32) & 0xFFFF] for y in range(0, 200, 3) for x in range(0, 320, 3)),
      "FLOWTEX: every pixel is the table at t + x*y/32: code[x*y/1024 + t/32], interpolated")
def roughness(px): return sum(abs(px(x + 1, y) - px(x, y)) for y in range(0, 200, 2) for x in range(319)) / (100 * 319)
d = roughness(lambda x, y: s[y * 320 + x]); dc = roughness(lambda x, y: code[((x * y >> 6) + tt) & 255])
check(d * 5 < dc, f"FLOWTEX: big smooth flows, not pixel noise: mean step between neighbours {d:.1f}, against {dc:.1f} for the classic code[x*y/64 + t]")
pal = r.dac()[:768]
check(all(pal[k * 3] >= pal[k * 3 + 1] >= pal[k * 3 + 2] for k in range(256)) and all(pal[k * 3] == k >> 2 for k in range(256)),
      "FLOWTEX: one sepia-to-ivory ramp: R = i/4, G and B a little less (few colours)")
r.frames(32); s2 = r.screen()[:64000]
tt2 = int.from_bytes(r.uc.mem_read(0x1FF00, 2), 'little') - 1
check(tt2 == tt + 32 and sum(1 for a, b in zip(s, s2) if a != b) > 20000, "FLOWTEX: the field flows, 1/32 of a code byte a frame")
check(r.high and not r.unmapped, "FLOWTEX: uses only its own segment, the 64 KB above it and video RAM")
notes = mel(music("FLOWTEX", r, 46))
tt3 = int.from_bytes(r.uc.mem_read(0x1FF00, 2), 'little')
want = []
for k in range(64):
    tick = k + 1 + int.from_bytes(r.uc.mem_read(0x46C, 4), 'little') - 64
    if not tick & 1:
        n = ((code[((tt3 >> 5) + ((tick >> 1) & 3)) & 255] & 30) + 46) * 6 // 5
        want += [n, n - 24]
check([n for _, _, n, _ in notes] == want[:len(notes)] and len(notes) >= 40,
      "FLOWTEX: a harp arpeggio of the four code bytes flowing in at the corner, each note doubled two octaves down")
leaves("FLOWTEX", Run("FLOWTEX.COM"), 2)

print("\n== GOLDTEX ==")
r = Run("GOLDTEX.COM").frames(3); common("GOLDTEX", r)
s = r.screen()[:64000]
code = r.com + bytes(512)
t = r.uc.reg_read(UC_X86_REG_BP) - 1
def gold_px(x, y, t):
    tex = code[((x * y >> 6) + t) & 255]
    gold = code[((x >> 4) + (y & ~15) + (t >> 4)) & 255] & 15 == 0
    return 132 + 4 * ((x & 15) + (y & 15)) if gold else tex & 127
check(all(s[y * 320 + x] == gold_px(x, y, t) for y in range(0, 200, 3) for x in range(0, 320, 3)),
      "GOLDTEX: every pixel is code[x*y/64 + t] (the classic SELFTEX bands), or, where the code byte for its 16x16 block is a multiple of 16, a gold tile: a smooth diagonal ramp 132 + 4(u + v)")
r3 = Run("GOLDTEX.COM").frames(2); r3.uc.reg_write(UC_X86_REG_BP, 0x1234); r3.frames(1); s3 = r3.screen()[:64000]
check(all(s3[y * 320 + x] == gold_px(x, y, 0x1234) for y in range(0, 200, 3) for x in range(0, 320, 3)), "GOLDTEX: the same at t = 1234h (time past 8 bits)")
gold = sum(1 for b in s if b >= 0x80) / 64000
check(0.04 < gold < 0.35, f"GOLDTEX: golden blocks cover part of the screen ({gold:.0%})")
check(all((s[y * 320 + x] >= 0x80) == (s[(y | 15) * 320 + (x | 15)] >= 0x80) for y in range(0, 192, 5) for x in range(0, 320, 5)), "GOLDTEX: gold comes in whole 16x16 blocks")
pal = r.dac()[-768:]
goldpal = [pal[k * 3:k * 3 + 3] for k in range(129, 256)]
check(all(R >= 32 and G == R - 8 and B == R - 32 for R, G, B in goldpal) and len({R for R, G, B in goldpal}) >= 30,
      "GOLDTEX: colours 129..255 are polished gold, from (32, 24, 0) to a white-gold (63, 55, 31), in a smooth band")
r.frames(40); pal2 = r.dac()[-768:]
check(pal2[387:] != pal[387:] and pal2[:384] != pal[:384], "GOLDTEX: both the code colours and the gold flow (a band of light sweeps over the tiles)")
s2 = r.screen()[:64000]
check(sum(1 for a, b in zip(s, s2) if (a >= 0x80) != (b >= 0x80)) > 2000, "GOLDTEX: the golden blocks hop across the grid as time moves")
notes = music("GOLDTEX", r, 9)
m = mel(notes)
check([n[2] for n in m[0::2]] == [((code[(t >> 1) & 255] & 30) + 46) * 6 // 5 for t, _, _, _ in m[0::2]] and all(b[2] == a[2] + 12 for a, b in zip(m[0::2], m[1::2])),
      "GOLDTEX: the melody is the program's own bytes in order, doubled an octave up")
groove("GOLDTEX", notes)
leaves("GOLDTEX", Run("GOLDTEX.COM"), 2)

print("\n== FIRE ==")
r = Run("FIRE.COM").frames(25); common("FIRE", r)
s = r.screen()
bottom = sum(s[y * 320 + x] for y in range(190, 198) for x in range(320)) / (8 * 320)
top = sum(s[y * 320 + x] for y in range(0, 20) for x in range(320)) / (20 * 320)
mid = sum(s[y * 320 + x] for y in range(165, 175) for x in range(320)) / (10 * 320)
check(bottom > 60, f"FIRE: the bottom is hot (mean heat {bottom:.0f})")
check(bottom > mid > top and top < 3, f"FIRE: the heat dies off as it rises (bottom {bottom:.0f}, middle {mid:.0f}, top {top:.1f})")
check(len(set(s)) > 100, f"FIRE: a smooth ramp of heat values, not on/off ({len(set(s))} distinct)")
r.frames(1); s2 = r.screen()
check(sum(1 for a, b in zip(s, s2) if a != b) > 3000, "FIRE: the flames move (feedback + fresh noise every frame)")
r.frames(30)
notes = []
for k in range(40):
    r.frames(1); before = len(r.note_ons()); t = int.from_bytes(r.uc.mem_read(0x46C, 4), 'little') + 1
    probe = ((((t >> 1) * 1283) & 0xFFFF) | 0xB000) if not t & 1 else None
    heat = r.screen()[probe] if probe is not None else None
    r.tick(1); new = mel(r.note_ons()[before:])
    if probe is not None: notes.append((heat, [n[2] for n in new]))
check(all((h >= 40) == bool(n) for h, n in notes) and sum(1 for h, n in notes if n) >= 3,
      f"FIRE: a guitar note exactly when the probe is in a flame ({sum(1 for h, n in notes if n)} of {len(notes)} steps)")
check(all(n[0] == ((h >> 3 & 30) + 40) * 6 // 5 for h, n in notes if n), "FIRE: hotter pixels play higher notes")
m = music("FIRE", r, 24, ticks=200, lo=1)
groove("FIRE", m)
leaves("FIRE", Run("FIRE.COM"))

print("\n== JULIA ==")
r = Run("JULIA.COM").polls(1); r.tick(1); common("JULIA", r, colours=255)
check(r.dac() and all(p != 0x3C8 or v == 1 for p, v in r.outs), "JULIA: the tick handler rewrites the palette from colour 1: the bands flow, the set (colour 0) stays black")
s = r.screen()[:64000]
black = s.count(0)
check(len(set(s)) > 6, f"JULIA: escape-time colour bands ({len(set(s))} distinct colours)")
check(5000 < black < 55000, f"JULIA: the set itself (never escapes) is black and fills part of the screen ({black} of 64000 pixels)")
check(s == s[::-1], "JULIA: the image is exactly point-symmetric (z -> -z): the bottom half is the top half mirrored")
check(not any(b in (0xD9, 0xDB, 0xDD) for b in r.com[:60]), "JULIA: no FPU: pure 8.8 fixed-point integer maths")
r.polls(3); s2 = r.screen()[:64000]
check(sum(1 for a, b in zip(s, s2) if a != b) > 500, "JULIA: the constant c circles, so the picture changes frame to frame")
r2 = Run("JULIA.COM"); r2.uc.emu_start(0x100, 0xFFFFF, count=400_000)       # stop part-way through a frame
di = r2.uc.reg_read(UC_X86_REG_DI); pix = r2.screen()[di - 1]
r2.tick(1); got = [n[2] for n in mel(r2.note_ons())]
check(got == ([] if pix == 0 else [(((pix >> 2) & 30) + 44) * 6 // 5]), f"JULIA: each tick plays the pixel just drawn (colour {pix} -> {got})")
music("JULIA", r, 8, lo=4, between=150_000)
leaves("JULIA", Run("JULIA.COM"))

print("\n== ESCHER ==")
r = Run("ESCHER.COM").frames(4); common("ESCHER", r)
pan = [v for p, v in r.outs if p == 0x3C0]
check(pan[0::2] == [0x33] * len(pan[0::2]) and set(pan[1::2]) <= {0, 2, 4, 6}, "ESCHER: pixel panning (0, 2, 4, 6) refines the 4-pixel start-address steps")
s1 = r.screen()[:64000]
check(len(set(s1)) > 100 and lit(s1) > 30000, f"ESCHER: the texture is drawn once ({len(set(s1))} distinct colours)")
r.frames(30); s2 = r.screen()[:64000]
check(s1 == s2, "ESCHER: after that no pixel is ever written again: the whole animation is CRTC registers")
crtc = [v for p, v in r.outs if p == 0x3D4]
check(crtc[:2] == [0x0F07, 0x0109], "ESCHER: clears line-compare bits 8 and 9 (CR07 bit 4, CR09 bit 6), so the split is on screen on a real VGA")
idx = [v & 255 for v in crtc[2:]]
check(len(idx) >= 12 and idx[:6] == [0x0C, 0x0D, 0x18, 0x0C, 0x0D, 0x18], f"ESCHER: each frame writes CRTC start address high (0Ch) and low (0Dh) and line compare (18h)")
starts = {((v >> 8) << 8) | (crtc[2:][i + 1] >> 8) for i, v in enumerate(crtc[2:]) if v & 255 == 0x0C and i + 1 < len(crtc) - 2}
check(len(starts) >= 5 and max(starts) < 0x4000, f"ESCHER: the start address moves ({len(starts)} distinct values, all inside video memory)")
splits = [v >> 8 for v in crtc if v & 255 == 0x18]
check(all(b - a == 1 for a, b in zip(splits, splits[1:])), "ESCHER: the line-compare split sweeps down one scan line per frame")
seq = [e for e in r.events if e[1] in (0x3DA,) or (e[1] == 0x3D4 and e[2] & 255 == 0x18)]
per, n, last = [], 0, 0
for kind, port, val in seq:
    if port == 0x3DA:
        if val == 8 and last == 0: n += 1
        last = val
    else: per.append(n); n = 0
check(len(per) > 20 and set(per[1:]) == {1}, f"ESCHER: exactly one retrace between steps ({len(per)} steps): it waits for the end of a retrace, then the start of the next")
notes = music("ESCHER", r, 11, scale=set(range(12)))
steps = {}
for t, ch, n, v in notes: steps.setdefault(t, []).append((n, v))
st = list(steps.values())
check(all(len(c) == 5 and [b[0] - a[0] for a, b in zip(c, c[1:])] == [12] * 4 for c in st), "ESCHER: every step is five notes an octave apart")
pcs = [c[0][0] % 12 for c in st]
check(all((b - a) % 12 == 1 for a, b in zip(pcs, pcs[1:])), "ESCHER: each step is a semitone above the last, for ever (a Shepard scale)")
check(all(v == 127 - 3 * abs(n - 54) for c in st for n, v in c), "ESCHER: loudness is a bell over pitch (127 - 3|n - 54|), so the top and bottom voices fade in and out unnoticed")
leaves("ESCHER", Run("ESCHER.COM"))

print("\n== CHLADNI ==")
r = Run("CHLADNI.COM").frames(1); common("CHLADNI", r)
s = r.screen()[:64000]
bright = sum(1 for b in s if b > 200)
check(r.com.count(b"\xD9\xFE") == 3, "CHLADNI: three FSINs in the code: the mode number, and the sin(aX), sin(bX) table")
check(2000 < bright < 40000 and len(set(s)) > 100, f"CHLADNI: bright nodal lines on a dark plate with smooth falloff ({bright} bright pixels, {len(set(s))} levels)")
def plate(a, x, y):
    X, Y = (x - 159.5) * 0.02, (y - 99.5) * 0.02
    f = abs(math.sin(a * X) * math.sin(6 * Y) - math.sin(6 * X) * math.sin(a * Y)) * 600
    return 255 - min(255, round(f))
ok = sum(1 for y in range(0, 200, 7) for x in range(0, 320, 7) if abs(plate(3.0, x, y) - s[y * 320 + x]) <= 1)
check(ok > 0.99 * 29 * 46, f"CHLADNI: the pixels are the plate equation for a = 3 at t = 0 ({ok} of {29 * 46} samples within 1)")
mirror = sum(1 for y in range(200) for x in range(320) if s[y * 320 + x] == s[y * 320 + 319 - x])
flip = sum(1 for y in range(200) for x in range(320) if s[y * 320 + x] == s[(199 - y) * 320 + x])
check(mirror == 64000 and flip > 0.97 * 64000, f"CHLADNI: |f| is drawn mirrored left-right, and is symmetric top-bottom ({flip / 64000:.1%})")
[r.frames(105) for _ in range(3)]; s2 = r.screen()[:64000]
a = 3 + math.sin(0.0029874 * 315)
ok = sum(1 for y in range(0, 200, 7) for x in range(0, 320, 7) if abs(plate(a, x, y) - s2[y * 320 + x]) <= 1)
check(ok > 0.99 * 29 * 46 and sum(1 for p, q in zip(s, s2) if p != q) > 1000, f"CHLADNI: 315 frames (4.5 s) later the mode number is 3 + sin(0.0029874 frames) = {a:.2f}, and the figure has changed")
notes = []
for k in range(60):
    t = int.from_bytes(r.uc.mem_read(0x46C, 4), 'little') + 1
    probe = ((t >> 1) * 323) & 0xFFFF if not t & 1 else None
    pix = r.screen()[probe] if probe is not None else None
    before = len(r.note_ons()); r.tick(1)
    if probe is not None: notes.append((pix, [n[2] for n in r.note_ons()[before:]]))
check(all((p >= 128) == bool(n) for p, n in notes) and sum(1 for p, n in notes if n) >= 3, f"CHLADNI: a bell rings exactly when the probe crosses a nodal line ({sum(1 for p, n in notes if n)} of {len(notes)} steps)")
music("CHLADNI", r, 14, lo=3)
leaves("CHLADNI", Run("CHLADNI.COM"))

print("\n== LATCH ==")
r = Run("LATCH.COM").frames(3)
common("LATCH", r, mode=0x0D)
gc = [v for p, v in r.outs if p == 0x3CE]
check(gc[:3] == [0x0F01, 0x1803, 0x0305], "LATCH: graphics controller set up as set/reset on all planes (GR01 = 0Fh), logical function XOR (GR03 = 18h), write mode 3 (GR05 = 03h)")
colours = [v >> 8 for v in gc[3:] if v & 255 == 0]
check(len(colours) >= 3 and all((b - a) & 255 == 1 for a, b in zip(colours, colours[1:])), f"LATCH: the set/reset colour (GR00) is the frame counter, rewritten every frame")
check(b"\x26\xAC\xD0\xD8\xAA\xE2" in r.com, "LATCH: the inner loop is es lodsb / rcr al,1 / stosb / loop: each byte read loads the VGA latches from the row below, each write lands one row up")
check(all(v == 1 for p, v in r.outs if p == 0x3C8) and len(r.dac()) >= 2 * 189, "LATCH: the 63 DAC colours above black are rewritten every frame (a flowing rainbow); black stays black")
pan = [v for p, v in r.outs if p == 0x3C0]
check(pan[0::2] == [0x33] * len(pan[0::2]) and set(pan[1::2]) <= set(range(8)) and len(pan) >= 4, "LATCH: the attribute controller's pixel panning (13h) is set every frame, 0..7")
r.uc.mem_write(0x46C, bytes(4))
notes = music("LATCH", r, 10, ticks=64)
ruler = [60 + [0, 2, 4, 7, 9, 12, 14][(k & -k).bit_length() - 1] for k in range(1, 32)]
groove("LATCH", notes)
check([n[2] for n in mel(notes)][:31] == ruler, "LATCH: the melody is the ruler sequence (trailing zeros of the step: 0 1 0 2 0 1 0 3 ...), the Sierpinski rhythm")
leaves("LATCH", Run("LATCH.COM"))

print("\n== WARP ==")
r = Run("WARP.COM")
r.uc.mem_write(0xB8000, bytes((i * 7) & 255 for i in range(4000)))
before = bytes(r.uc.mem_read(0xB8000, 4000)); r.frames(70)
check(len(r.com) <= 256, f"WARP: {len(r.com)} bytes (limit 256)")
crtc = [v for p, v in r.outs if p == 0x3D4]
idx = {v & 255 for v in crtc}
check(idx == {0x08, 0x09, 0x13}, f"WARP: writes only CRTC registers 08h, 09h and 13h, never the timing registers ({sorted(map(hex, idx))})")
check({v >> 8 for v in crtc if v & 255 == 8} == set(range(16)), "WARP: CR08 (preset row scan) bobs the screen through 0..15 scan lines")
pan = [v for p, v in r.outs if p == 0x3C0]
check(pan[0::2] == [0x33] * len(pan[0::2]) and set(pan[1::2]) == set(range(8)), "WARP: the attribute controller's pixel panning (13h) shimmers through 0..7")
check(all(v == 1 for p, v in r.outs if p == 0x3C8) and len(r.dac()) >= 189 * 60, "WARP: the 63 DAC colours above black are rewritten every frame (black stays black)")
h = [v >> 8 for v in crtc if v & 255 == 0x09]
check(all(x & 0x40 for x in h) and min(x & 31 for x in h) == 3 and max(x & 31 for x in h) == 18 and len({x & 31 for x in h}) == 16, f"WARP: CR09 keeps bit 6 and steps the character height through all 16 values from 4 to 19 scan lines")
st = [v >> 8 for v in crtc if v & 255 == 0x13]
check(set(st) <= set(range(36, 44)) and len(set(st)) >= 3, f"WARP: CR13 (row stride) stays within 36..43 words of the normal 40 ({sorted(set(st))})")
check(bytes(r.uc.mem_read(0xB8000, 4000)) == before and all(n == 0x21 for n, ax in r.ints), "WARP: the text in video memory is never touched; no BIOS call while it runs (DOS only to hook the timer)")
check(not any(p in (0x42, 0x43, 0x61) for p, v in r.outs), "WARP: never touches the PC speaker")
notes = []
for k in range(40):
    r.frames(1); bl = r.uc.reg_read(UC_X86_REG_BX) & 255
    tri = (~bl & 255 if bl & 32 else bl) & 30
    before = len(r.note_ons()); r.tick(1); new = [n[2] for n in mel(r.note_ons()[before:])]
    if k: notes.append((tri, new, r.ticks_done))
check(all(n == ([] if tk & 1 else [(t + 46) * 6 // 5]) for t, n, tk in notes), "WARP: every other tick plays the current character-height triangle as a pentatonic degree: the arpeggio rises as the text stretches")
groove("WARP", music("WARP", r, 4))
leaves("WARP", Run("WARP.COM"), 2)

print("\n== ORDER ==")
r = Run("ORDER.COM").frames(2); common("ORDER", r)
s1 = r.screen()[:64000]
bands = {b >> 5 for b in s1}
check(len(bands) >= 5, f"ORDER: at least five of the possible orderings appear as regions ({sorted(bands)})")
check(sum(1 for i in range(1, 64000) if s1[i] >> 5 == s1[i-1] >> 5) > 0.97 * 64000, "ORDER: the regions are large and coherent (97%+ of horizontal neighbours share an ordering)")
t = r.uc.reg_read(UC_X86_REG_BP) - 1
def order_px(x, y, t):
    a = ((x * y) >> 6) + t & 255; b = x - 2 * t & 255; c = 3 * y + t & 255
    return (((a < b) << 2 | (b < c) << 1 | (a < c)) << 5) + (a >> 3)
check(all(s1[y * 320 + x] == order_px(x, y, t) for y in range(0, 200, 3) for x in range(0, 320, 3)), "ORDER: every pixel is the ordering of (x*y/64 + t, x - 2t, 3y + t) and the shade of the first")
check(b"\xF7\xF1" not in r.com and b"\xF7\xF3" not in r.com, "ORDER: no division (the three expressions are kept incrementally)")
r.frames(2); s2 = r.screen()[:64000]
check(sum(1 for a, b in zip(s1, s2) if a >> 5 != b >> 5) > 1000, "ORDER: the region boundaries move as t changes")
notes = music("ORDER", r, 45)
groove("ORDER", notes)
leaves("ORDER", Run("ORDER.COM"))

print("\n== ROOTS ==")
r = Run("ROOTS.COM"); r.uc.mem_write(0x46C, bytes(4)); r.polls(1); common("ROOTS", r)
s1 = r.screen()[:64000]
white = [i for i in range(320, 64000) if s1[i] & 127 == 127 and i % 320]
pos = sum(1 for b in s1 if not b & 128) / 64000
check(300 < len(white) < 6000 and 0.1 < pos < 0.9, f"ROOTS: thin root curves ({len(white)} white pixels) between positive and negative regions ({pos:.0%} positive)")
check(all((s1[i] ^ s1[i-1]) & 128 or (s1[i] ^ s1[i-320]) & 128 for i in white), "ROOTS: every white pixel is a real sign change against its left or upper neighbour")
def v(X, Y, T, S): return (X * X >> 2) * X + X * (256 * S - 96 * T - 96 * Y) + Y * Y * T
T = S = -32
check(all((s1[i] ^ s1[i - 1]) & 128 or (s1[i] >> 7) != (v(i - 160, -101, T, S) < 0) for i in range(1, 320) if s1[i] & 127 == 127)
      and all((s1[y * 320] ^ s1[y * 320 - 320]) & 128 for y in range(1, 200) if s1[y * 320] & 127 == 127)
      and (s1[0] & 127 != 127 or (s1[0] >> 7) != (v(-160, -101, T, S) < 0)),
      "ROOTS: no false roots along the top row (its upper neighbour is the row above the screen, drawn off screen) or the left column (no left neighbour)")
ok = sum(1 for y in range(1, 200, 5) for x in range(1, 320, 5) if (s1[y * 320 + x] >> 7) == (v(x - 160, y - 100, T, S) < 0))
check(ok > 0.995 * 40 * 64, f"ROOTS: the sign of every pixel is the sign of the cubic at t = 0 ({ok} of {40 * 64} samples)")
check(not any(op in r.com for op in (b"\xDB\xE3", b"\xD9\xFE", b"\xD9\xFF")), "ROOTS: 32-bit integer maths only (no FPU)")
r.uc.mem_write(0x46C, (48).to_bytes(4, 'little')); r.polls(2); s2 = r.screen()[:64000]
check(sum(1 for a, b in zip(s1, s2) if (a ^ b) & 128) > 1000, "ROOTS: the sign regions (and so the roots) move as the clock moves T and S")
notes = music("ROOTS", r, 114)
check(all(b[0] - a[0] == 1 for a, b in zip(notes, notes[1:])), "ROOTS: steel drums on every tick, playing T (the patched coefficient) as a pentatonic line")
leaves("ROOTS", Run("ROOTS.COM"))

print("\nRESULT: " + ("ALL PASS" if not fails else f"{len(fails)} FAILED"))
sys.exit(1 if fails else 0)
