"""A 16-bit DOS .COM runner on Unicorn (x87 included), entered the way DOS enters a program.

INT, IN and OUT are trapped. What it models:
  - port 3DAh: the retrace bit alternates on every read, so a frame is one 0 -> 8 transition seen by the program
    (that counts frames the same way for a single 'wait for retrace' loop and a 'wait for end, then start' pair);
  - INT 21h AH=35h/25h: a real interrupt-vector table at 0000:0000, preloaded with a fake BIOS handler for 1Ch;
  - the timer: tick() advances the BIOS tick count at 0040:006Ch and calls the installed INT 1Ch handler the way
    the BIOS INT 08h handler does (with DS = 0040h, as on an IBM BIOS, so a handler that trusts DS is caught);
  - ports 330h/331h: an MPU-401 in UART mode; bytes written to 330h after a 3Fh to 331h are captured as MIDI.
"""
import pathlib
from unicorn import Uc, UC_ARCH_X86, UC_MODE_16, UC_HOOK_INSN, UC_HOOK_INTR, UC_HOOK_MEM_UNMAPPED
from unicorn.x86_const import *

ROOT = pathlib.Path(__file__).resolve().parent.parent
SEG = 0x1000; LIN = SEG << 4
BIOS_1C = (0xF000, 0xFF53)        # the IBM BIOS dummy IRET that INT 1Ch points at after boot
SENTINEL = 0x0500                 # 0000:0500 holds INT 0FFh: the fake BIOS returns there from INT 1Ch

class Run:
    def __init__(self, name, data=None):
        self.com = data if data is not None else (ROOT / name).read_bytes()
        uc = self.uc = Uc(UC_ARCH_X86, UC_MODE_16)     # fresh Uc per run: Unicorn caches translated blocks
        uc.mem_map(0, 0x20000); uc.mem_map(0xA0000, 0x60000)
        uc.mem_write(LIN + 0x100, self.com); uc.mem_write(LIN, b"\xCD\x20")
        uc.mem_write(LIN + 2, (0xA000).to_bytes(2, 'little'))   # PSP:2, top of memory (DOSBox: 9FFFh/A000h)
        uc.mem_write(0x1C * 4, BIOS_1C[1].to_bytes(2, 'little') + BIOS_1C[0].to_bytes(2, 'little'))
        uc.mem_write(SENTINEL, b"\xCD\xFF")
        for r in (UC_X86_REG_CS, UC_X86_REG_DS, UC_X86_REG_ES, UC_X86_REG_SS): uc.reg_write(r, SEG)
        uc.reg_write(UC_X86_REG_SP, 0xFFFE); uc.reg_write(UC_X86_REG_FLAGS, 0x202)
        uc.reg_write(UC_X86_REG_CX, 0xFF); uc.reg_write(UC_X86_REG_SI, 0x100); uc.reg_write(UC_X86_REG_DI, 0xFFFE)
        uc.reg_write(UC_X86_REG_DX, 0x192); uc.reg_write(UC_X86_REG_BP, 0x091C)
        self.outs, self.ints, self.unmapped, self.midi, self.vec_sets = [], [], [], [], []
        self.p60, self.p61, self.vs_reads, self.vs_last, self.frames_seen = 0, 0, 0, 0, 0
        self.kb_reads, self.kb_stop, self.events = 0, None, []
        self.frame_stop, self.exited, self.uart, self.ticks_done = None, False, False, 0
        uc.hook_add(UC_HOOK_INSN, self.on_in, None, 1, 0, UC_X86_INS_IN)
        uc.hook_add(UC_HOOK_INSN, self.on_out, None, 1, 0, UC_X86_INS_OUT)
        uc.hook_add(UC_HOOK_INTR, self.on_intr)
        uc.hook_add(UC_HOOK_MEM_UNMAPPED, lambda u, a, ad, sz, v, d: self.unmapped.append(hex(ad)) or False)
        self.started = False

    # ---- hardware
    def on_in(self, uc, port, size, ud):
        if port == 0x3DA:
            self.vs_reads += 1
            v = 8 if self.vs_reads & 1 else 0
            if v == 8 and self.vs_last == 0:
                self.frames_seen += 1
                if self.frame_stop is not None and self.frames_seen >= self.frame_stop: uc.emu_stop()
            self.vs_last = v
            self.events.append(('in', port, v))
            return v
        if port == 0x60:                                # every demo polls the keyboard once per frame
            self.kb_reads += 1
            if self.kb_stop is not None and self.kb_reads >= self.kb_stop: uc.emu_stop()
            return self.p60
        return self.p61 if port == 0x61 else 0
    def on_out(self, uc, port, size, v, ud):
        if size == 2 and port in (0x330, 0x331):          # a word write to the MPU is two byte writes, port then port+1
            self.on_out(uc, port, 1, v & 255, ud); self.on_out(uc, port + 1, 1, v >> 8, ud); return
        v &= 0xFFFF if size == 2 else 255
        if port == 0x61: self.p61 = v
        if port == 0x331 and v == 0x3F: self.uart = True
        if port == 0x330 and self.uart: self.midi.append((self.ticks_done, v))
        self.outs.append((port, v)); self.events.append(('out', port, v))
    def on_intr(self, uc, n, ud):
        ax = uc.reg_read(UC_X86_REG_AX)
        self.ints.append((n, ax))
        if n == 0x20: self.exited = True; uc.emu_stop()
        elif n == 0xFF: uc.emu_stop()                       # back from INT 1Ch into the fake BIOS
        elif n == 0x21 and ax >> 8 == 0x35:
            k = ax & 255; v = uc.mem_read(k * 4, 4)
            uc.reg_write(UC_X86_REG_BX, int.from_bytes(v[:2], 'little')); uc.reg_write(UC_X86_REG_ES, int.from_bytes(v[2:], 'little'))
        elif n == 0x21 and ax >> 8 == 0x25:
            k = ax & 255; ds = uc.reg_read(UC_X86_REG_DS); dx = uc.reg_read(UC_X86_REG_DX)
            uc.mem_write(k * 4, dx.to_bytes(2, 'little') + ds.to_bytes(2, 'little'))
            self.vec_sets.append((k, ds, dx))
        elif n == 0x21 and ax >> 8 == 0x4C: self.exited = True; uc.emu_stop()

    # ---- running
    def frames(self, n, per=None):
        """Run until the program has seen n more vertical retraces."""
        self.frame_stop = self.frames_seen + n
        start = self.uc.reg_read(UC_X86_REG_IP) if self.started else 0x100
        self.started = True
        self.uc.emu_start(start, 0xFFFFF, count=60_000_000)
        self.frame_stop = None
        return self
    def polls(self, n):
        """Run until the program has polled the keyboard n more times (once per frame, with or without a retrace wait)."""
        self.kb_stop = self.kb_reads + n
        start = self.uc.reg_read(UC_X86_REG_IP) if self.started else 0x100
        self.started = True
        self.uc.emu_start(start, 0xFFFFF, count=60_000_000)
        self.kb_stop = None
        return self
    def step(self, n):
        """Run n more instructions of the main program."""
        start = self.uc.reg_read(UC_X86_REG_IP) if self.started else 0x100
        self.started = True
        self.uc.emu_start(start, 0xFFFFF, count=n)
        return self
    def run_until_exit(self, esc_after, per=None):
        self.polls(esc_after); self.p60 = 1
        self.uc.emu_start(self.uc.reg_read(UC_X86_REG_IP), 0xFFFFF, count=60_000_000)
    def vector(self, k):
        v = self.uc.mem_read(k * 4, 4); return int.from_bytes(v[2:], 'little'), int.from_bytes(v[:2], 'little')
    def tick(self, n=1):
        """n timer ticks: the BIOS tick count goes up and INT 1Ch runs, entered as the BIOS INT 08h handler enters it."""
        uc = self.uc
        for _ in range(n):
            t = int.from_bytes(uc.mem_read(0x46C, 4), 'little') + 1
            uc.mem_write(0x46C, (t & 0xFFFFFFFF).to_bytes(4, 'little'))
            self.ticks_done = t
            seg, off = self.vector(0x1C)
            if (seg, off) == BIOS_1C: continue
            ctx = uc.context_save()
            sp = uc.reg_read(UC_X86_REG_SP) - 6; ss = uc.reg_read(UC_X86_REG_SS)
            uc.mem_write((ss << 4) + sp, SENTINEL.to_bytes(2, 'little') + (0).to_bytes(2, 'little') + (0x202).to_bytes(2, 'little'))
            uc.reg_write(UC_X86_REG_SP, sp)
            uc.reg_write(UC_X86_REG_DS, 0x40); uc.reg_write(UC_X86_REG_AX, 0x1234); uc.reg_write(UC_X86_REG_DX, 0x5678)
            uc.reg_write(UC_X86_REG_CS, seg)
            before = {r: uc.reg_read(r) for r in (UC_X86_REG_BX, UC_X86_REG_CX, UC_X86_REG_SI, UC_X86_REG_DI, UC_X86_REG_BP, UC_X86_REG_ES, UC_X86_REG_FS, UC_X86_REG_GS)}
            uc.emu_start(off, 0xFFFFF, count=200_000)
            after = {r: uc.reg_read(r) for r in before}
            self.isr_clobbers = [r for r in before if before[r] != after[r]]
            self.isr_back = uc.reg_read(UC_X86_REG_IP) == SENTINEL + 2 and uc.reg_read(UC_X86_REG_SP) == sp + 6 \
                            and uc.reg_read(UC_X86_REG_DS) == 0x40
            uc.context_restore(ctx)
        return self
    def screen(self): return bytes(self.uc.mem_read(0xA0000, 0x10000))
    def dac(self): return [v for p, v in self.outs if p == 0x3C9]
    def note_ons(self):
        """Decode the captured MIDI stream (with running status) into (tick, channel, note, velocity) note-ons."""
        out, status, data = [], 0, []
        for t, b in self.midi:
            if b >= 0x80: status, data = b, []; continue
            data.append(b)
            need = 1 if status >> 4 in (0xC, 0xD) else 2
            if len(data) == need:
                if status >> 4 == 9 and data[1]: out.append((t, status & 15, data[0], data[1]))
                data = []
        return out
    def programs(self):
        out, status, data = [], 0, []
        for t, b in self.midi:
            if b >= 0x80: status, data = b, []; continue
            if status >> 4 == 0xC: out.append((status & 15, b))
        return out
