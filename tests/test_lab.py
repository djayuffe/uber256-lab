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
        self.outs.append((port, v & 255))
    def on_intr(self, uc, n, ud):
        self.ints.append((n, uc.reg_read(UC_X86_REG_AX)))
        if n == 0x20: self.exited = True; uc.emu_stop()
    def frames(self, n):
        """Run until n more retrace waits have been polled (about n frames)."""
        self.vs_stop = self.vs_reads + n * 40
        start = self.uc.reg_read(UC_X86_REG_IP) if self.started else 0x100
        self.started = True
        self.uc.emu_start(start, 0xFFFF0, count=30_000_000)
        return self
    def screen(self): return bytes(self.uc.mem_read(0xA0000, 0x10000))
    def dac(self): return [v for p, v in self.outs if p == 0x3C9]
    def run_until_exit(self, esc_after):
        self.frames(esc_after); self.p60 = 1
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

print("\nRESULT: " + ("ALL PASS" if not fails else f"{len(fails)} FAILED"))
sys.exit(1 if fails else 0)
