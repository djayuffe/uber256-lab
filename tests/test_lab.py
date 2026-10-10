#!/usr/bin/env python3
"""Run each 256-byte demo in an emulated 16-bit CPU (Unicorn, x87 included), entered the way DOS
enters a .COM, and check what it does to the hardware: mode 13h, palette, animation, FPU, sound, Esc."""
import pathlib, sys
from unicorn import Uc, UC_ARCH_X86, UC_MODE_16, UC_HOOK_INSN, UC_HOOK_INTR, UC_HOOK_MEM_UNMAPPED
from unicorn.x86_const import *

ROOT = pathlib.Path(__file__).resolve().parent.parent
SEG = 0x1000; LIN = SEG << 4
fails = []
def check(ok, msg):
    print(("  PASS  " if ok else "  FAIL  ") + msg)
    if not ok: fails.append(msg)

class Run:
    def __init__(self, name):
        self.com = (ROOT / name).read_bytes()
        uc = self.uc = Uc(UC_ARCH_X86, UC_MODE_16)     # fresh Uc per run: Unicorn caches translated blocks
        uc.mem_map(0, 0x10000); uc.mem_map(LIN, 0x10000); uc.mem_map(0xA0000, 0x30000)
        uc.mem_write(LIN + 0x100, self.com); uc.mem_write(LIN, b"\xCD\x20")
        for r in (UC_X86_REG_CS, UC_X86_REG_DS, UC_X86_REG_ES, UC_X86_REG_SS): uc.reg_write(r, SEG)
        uc.reg_write(UC_X86_REG_SP, 0xFFFE); uc.reg_write(UC_X86_REG_FLAGS, 0x202)
        uc.reg_write(UC_X86_REG_CX, 0xFF); uc.reg_write(UC_X86_REG_SI, 0x100); uc.reg_write(UC_X86_REG_DI, 0xFFFE)
        uc.reg_write(UC_X86_REG_DX, 0x192); uc.reg_write(UC_X86_REG_BP, 0x091C)
        self.outs, self.ints, self.unmapped = [], [], []
        self.p60, self.p61, self.vs_reads, self.vs_stop, self.exited = 0, 0, 0, None, False
        uc.hook_add(UC_HOOK_INSN, self.on_in, None, 1, 0, UC_X86_INS_IN)
        uc.hook_add(UC_HOOK_INSN, self.on_out, None, 1, 0, UC_X86_INS_OUT)
        uc.hook_add(UC_HOOK_INTR, self.on_intr)
        uc.hook_add(UC_HOOK_MEM_UNMAPPED, lambda u, a, ad, sz, v, d: self.unmapped.append(hex(ad)) or False)
        self.started = False
    def on_in(self, uc, port, size, ud):
        if port == 0x3DA:                              # retrace bit toggles every read
            self.vs_reads += 1
            if self.vs_stop and self.vs_reads >= self.vs_stop: uc.emu_stop()
            return 8 if self.vs_reads & 1 else 0
        return self.p60 if port == 0x60 else (self.p61 if port == 0x61 else 0)
    def on_out(self, uc, port, size, v, ud):
        if port == 0x61: self.p61 = v & 255
        self.outs.append((port, v & (0xFFFF if size == 2 else 255)))
    def on_intr(self, uc, n, ud):
        self.ints.append((n, uc.reg_read(UC_X86_REG_AX)))
        if n == 0x20: self.exited = True; uc.emu_stop()
    def frames(self, n, per=40):
        """Run until n more retrace waits have been polled (about n frames)."""
        self.vs_stop = self.vs_reads + n * per
        start = self.uc.reg_read(UC_X86_REG_IP) if self.started else 0x100
        self.started = True
        self.uc.emu_start(start, 0xFFFF0, count=30_000_000)
        return self
    def screen(self): return bytes(self.uc.mem_read(0xA0000, 0x10000))
    def dac(self): return [v for p, v in self.outs if p == 0x3C9]
    def run_until_exit(self, esc_after, per=40):
        self.frames(esc_after, per); self.p60 = 1
        self.vs_stop = None
        self.uc.emu_start(self.uc.reg_read(UC_X86_REG_IP), 0xFFFF0, count=30_000_000)

def lit(scr): return sum(1 for b in scr if b)

def common(name, r):
    check(len(r.com) <= 256, f"{name}: {len(r.com)} bytes (limit 256)")
    check(r.ints[0] == (0x10, 0x13), f"{name}: first call is INT 10h, AX = 0013h (mode 13h)")
    check(len(r.dac()) >= 768, f"{name}: programs all 256 DAC colours ({len(r.dac())} values)")
    check(max(r.dac()[:768]) > 20, f"{name}: palette is not black")
    check(not r.unmapped, f"{name}: touches no memory outside video RAM and its segment {r.unmapped[:3]}")

def attractor(name, uses_sound=True):
    print(f"\n== {name} ==")
    r = Run(name + ".COM").frames(1)
    common(name, r)
    check(any(b in (0xD9, 0xDB) for b in r.com) and r.com.count(b"\xD9\xFE") >= 2, f"{name}: uses the x87 FPU (fsin/fcos)")
    s1 = r.screen(); n1 = lit(s1)
    check(500 < n1 < 30000, f"{name}: a curve is drawn, not noise or a blank screen ({n1} lit pixels)")
    ys = [i // 320 for i, b in enumerate(s1) if b]; xs = [i % 320 for i, b in enumerate(s1) if b]
    check(max(ys) - min(ys) < 190 and max(xs) - min(xs) < 300 and min(ys) > 0, f"{name}: the attractor stays on screen (x {min(xs)}..{max(xs)}, y {min(ys)}..{max(ys)})")
    check(len({b for b in s1}) > 12, f"{name}: many brightness levels (accumulation, not on/off): {len(set(s1))}")
    r.frames(6); s2 = r.screen()
    check(sum(1 for a, b in zip(s1, s2) if a != b) > 2000, f"{name}: the picture evolves frame to frame (parameter morph + fade)")
    if uses_sound:
        check(r.p61 & 3 == 3 and any(p == 0x42 for p, v in r.outs), f"{name}: speaker on, PIT channel 2 re-tuned from the orbit")
    r2 = Run(name + ".COM"); r2.run_until_exit(3)
    check(r2.exited and (0x10, 0x03) in r2.ints, f"{name}: Esc restores text mode 3 and returns to DOS")

attractor("GALAXY")
attractor("CLIFF")

print("\n== SELFTEX ==")
r = Run("SELFTEX.COM").frames(2); common("SELFTEX", r)
s = r.screen()
check(lit(s) > 5000 and len(set(s)) > 30, f"SELFTEX: the screen is textured by the program's own bytes ({len(set(s))} colours, {lit(s)} lit)")
check(not any(p == 0x42 for p, v in r.outs), "SELFTEX: no sound, just the texture")
r.frames(3); s2 = r.screen()
check(sum(1 for a, b in zip(s, s2) if a != b) > 5000, "SELFTEX: the texture scrolls (time is added to the lookup index)")
rx = Run("SELFTEX.COM"); rx.run_until_exit(2)
check(rx.exited and (0x10, 0x03) in rx.ints, "SELFTEX: Esc restores text mode 3 and returns to DOS")

print("\n== FIRE ==")
r = Run("FIRE.COM").frames(1); common("FIRE", r)
s = r.screen()
bottom = sum(s[y * 320 + x] for y in range(190, 198) for x in range(320)) / (8 * 320)
top = sum(s[y * 320 + x] for y in range(0, 20) for x in range(320)) / (20 * 320)
mid = sum(s[y * 320 + x] for y in range(165, 175) for x in range(320)) / (10 * 320)
check(bottom > 60, f"FIRE: the bottom is hot (mean heat {bottom:.0f})")
check(bottom > mid > top and top < 3, f"FIRE: the heat dies off as it rises (bottom {bottom:.0f}, middle {mid:.0f}, top {top:.1f})")
check(len(set(s)) > 100, f"FIRE: a smooth ramp of heat values, not on/off ({len(set(s))} distinct)")
check(not any(p == 0x42 for p, v in r.outs), "FIRE: no sound")
r.frames(1); s2 = r.screen()
check(sum(1 for a, b in zip(s, s2) if a != b) > 3000, "FIRE: the flames move (feedback + fresh noise every frame)")
rx = Run("FIRE.COM"); rx.run_until_exit(1)
check(rx.exited and (0x10, 0x03) in rx.ints, "FIRE: Esc restores text mode 3 and returns to DOS")

print("\n== JULIA ==")
r = Run("JULIA.COM").frames(1, per=2); common("JULIA", r)
s = r.screen()
black = sum(1 for b in s[:64000] if b == 0)
check(len(set(s[:64000])) > 6, f"JULIA: escape-time colour bands ({len(set(s[:64000]))} distinct colours)")
check(5000 < black < 55000, f"JULIA: the set itself (never escapes) is black and fills part of the screen ({black} of 64000 pixels)")
check(s[:64000] == s[:64000][::-1] or sum(1 for a, b in zip(s[:64000], s[:64000][::-1]) if a == b) > 50000, "JULIA: the image is point-symmetric (Julia sets are symmetric under z -> -z)")
check(not any(p == 0x42 for p, v in r.outs) and not any(b in (0xD9, 0xDB, 0xDD) for b in r.com[:60]), "JULIA: no FPU and no sound: pure 8.8 fixed-point integer maths")
r.frames(3, per=2); s2 = r.screen()
check(sum(1 for a, b in zip(s[:64000], s2[:64000]) if a != b) > 500, "JULIA: the constant c circles, so the picture changes frame to frame")
rx = Run("JULIA.COM"); rx.run_until_exit(1, per=2)
check(rx.exited and (0x10, 0x03) in rx.ints, "JULIA: Esc restores text mode 3 and returns to DOS")

print("\n== ESCHER ==")
r = Run("ESCHER.COM").frames(1, per=2); common("ESCHER", r)
s1 = r.screen()[:64000]
check(len(set(s1)) > 100 and sum(1 for b in s1 if b) > 30000, f"ESCHER: the texture is drawn once ({len(set(s1))} distinct colours)")
r.frames(5, per=2); s2 = r.screen()[:64000]
check(s1 == s2, "ESCHER: after that no pixel is ever written again: the whole animation is CRTC registers")
crtc = [(p, v) for p, v in r.outs if p == 0x3D4]
idx = [v & 255 for p, v in crtc]
check(len(crtc) >= 12 and idx[:6] == [0x0C, 0x0D, 0x18, 0x0C, 0x0D, 0x18], f"ESCHER: each frame writes CRTC start address high (0Ch) and low (0Dh) and line compare (18h) ({len(crtc)} writes)")
starts = {((v >> 8) << 8) | (crtc[i + 1][1] >> 8) for i, (p, v) in enumerate(crtc) if v & 255 == 0x0C and i + 1 < len(crtc)}
check(len(starts) >= 5 and max(starts) < 0x4000, f"ESCHER: the start address moves ({len(starts)} distinct values, all inside video memory)")
splits = [v >> 8 for p, v in crtc if v & 255 == 0x18]
check(all(b - a == 1 for a, b in zip(splits, splits[1:])), "ESCHER: the line-compare split sweeps down one scan line per frame")
check(not any(p == 0x42 for p, v in r.outs), "ESCHER: no sound")
rx = Run("ESCHER.COM"); rx.run_until_exit(1, per=2)
check(rx.exited and (0x10, 0x03) in rx.ints, "ESCHER: Esc restores text mode 3 (which also resets the CRTC) and returns to DOS")

print("\n== CHLADNI ==")
r = Run("CHLADNI.COM").frames(1, per=2); common("CHLADNI", r)
s = r.screen()[:64000]
bright = sum(1 for b in s if b > 200)
check(any(b in (0xD9, 0xDB) for b in r.com) and r.com.count(b"\xD9\xFE") >= 4, "CHLADNI: four FSIN per pixel on the x87 FPU")
check(2000 < bright < 40000 and len(set(s)) > 100, f"CHLADNI: bright nodal lines on a dark plate with smooth falloff ({bright} bright pixels, {len(set(s))} levels)")
mirror = sum(1 for y in range(200) for x in range(1, 320) if s[y * 320 + x] == s[y * 320 + 320 - x])
flip = sum(1 for y in range(1, 200) for x in range(320) if s[y * 320 + x] == s[(200 - y) * 320 + x])
check(mirror > 0.97 * 200 * 319 and flip > 0.97 * 199 * 320, f"CHLADNI: |f| is symmetric left-right and top-bottom, as the plate equation requires ({mirror / (200 * 319):.1%} / {flip / (199 * 320):.1%})")
check(r.p61 & 3 == 3 and any(p == 0x42 for p, v in r.outs), "CHLADNI: the speaker is on and PIT channel 2 is retuned from the mode number")
r.frames(2, per=2); s2 = r.screen()[:64000]
check(sum(1 for a, b in zip(s, s2) if a != b) > 1000, "CHLADNI: the mode number drifts, so the figure changes")
rx = Run("CHLADNI.COM"); rx.run_until_exit(1, per=2)
check(rx.exited and (0x10, 0x03) in rx.ints, "CHLADNI: Esc restores text mode 3 and returns to DOS")

print("\nRESULT: " + ("ALL PASS" if not fails else f"{len(fails)} FAILED"))
sys.exit(1 if fails else 0)
