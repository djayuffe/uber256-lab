"""Run a real .COM in Unicorn and capture frames of its display (text mode, mode 13h or planar mode 0Dh).
The display is MODELLED: text memory + CRTC char height/stride, the DAC, or four VGA planes with latches
(write mode 3, set/reset, logical function). Frames are taken per vertical retrace, per timer tick (HLT) or
per N instructions. DOS screen and VGA font come from dumps made inside DOSBox."""
import random, sys
from unicorn import *
from unicorn.x86_const import *
from PIL import Image
sys.path.insert(0, '/tmp/render')
import vgatext

SEG = 0x1000; LIN = SEG << 4
EGA = vgatext.PAL

def dos_screen(name):
    m = bytearray(open('/tmp/fdump/SCREEN.BIN', 'rb').read())
    def put(row, text):
        for c in range(80):
            m[(row*80+c)*2] = ord(text[c]) if c < len(text) else 32
    rows = [''.join(chr(m[(r*80+c)*2]) for c in range(80)).rstrip() for r in range(25)]
    for r, t in enumerate(rows):
        if 'mount c' in t: put(r, 'Z:\\>mount c .')
        if 'Drive C is mounted' in t: put(r, 'Drive C is mounted as local directory ./')
        if t.startswith('C:\\>'): put(r, 'C:\\>' + name)
    last = max(r for r, t in enumerate(rows) if t.strip())
    return bytes(m), last + 1

class M:
    def __init__(s, com, name, rng=1, hlt=False):
        s.com = open(com, 'rb').read()
        uc = s.uc = Uc(UC_ARCH_X86, UC_MODE_16)
        uc.mem_map(0, 0x10000); uc.mem_map(LIN, 0x10000); uc.mem_map(0xA0000, 0x30000)
        uc.mem_write(LIN + 0x100, s.com); uc.mem_write(LIN, b'\xCD\x20\xFF\x9F')
        scr, s.cur_row = dos_screen(name); s.cur_col = 0
        uc.mem_write(0xB8000, scr)
        for r in (UC_X86_REG_CS, UC_X86_REG_DS, UC_X86_REG_ES, UC_X86_REG_SS): uc.reg_write(r, SEG)
        for r, v in ((UC_X86_REG_SP, 0xFFFE), (UC_X86_REG_FLAGS, 0x7202), (UC_X86_REG_CX, 0xFF), (UC_X86_REG_SI, 0x100),
                     (UC_X86_REG_DI, 0xFFFE), (UC_X86_REG_DX, 0x192), (UC_X86_REG_BP, 0x91C)): uc.reg_write(r, v)
        s.mode = 3; s.dac = [0] * 768; s.dac_i = 0; s.crtc = {0x09: 0x4F, 0x13: 40, 0x0C: 0, 0x0D: 0}; s.crtc_i = 0
        s.gr = [0, 0, 0, 0, 0, 0, 0, 0, 0xFF]; s.gr_i = 0; s.planes = [bytearray(65536) for _ in range(4)]; s.latch = [0]*4
        s.vs = 0; s.frame_due = False; s.exited = False; s.rng = random.Random(rng); s.ticks = 0
        uc.hook_add(UC_HOOK_INSN, s.on_in, None, 1, 0, UC_X86_INS_IN)
        uc.hook_add(UC_HOOK_INSN, s.on_out, None, 1, 0, UC_X86_INS_OUT)
        uc.hook_add(UC_HOOK_INTR, s.on_int)
        s.vhooks = None               # the planar-VGA memory hooks are added only when mode 0Dh is set
        s.hlt_at = None
        if hlt and 0xF4 in s.com:            # only for programs that really use HLT as a timer tick (an F4 byte can be data)
            off = s.com.index(0xF4); s.hlt_at = LIN + 0x100 + off; uc.mem_write(s.hlt_at, b'\x90')
            uc.hook_add(UC_HOOK_CODE, s.on_hlt, None, s.hlt_at, s.hlt_at)
    # ---- ports
    def on_in(s, uc, port, size, ud):
        if port == 0x3DA:
            s.vs += 1
            if s.vs % 2 == 0: s.frame_due = 'vsync'; uc.emu_stop()
            return 8 if s.vs % 2 else 0
        if port == 0x40: return s.rng.randrange(256)
        return 0
    def on_out(s, uc, port, size, v, ud):
        lo, hi = v & 255, (v >> 8) & 255
        if port == 0x3C8: s.dac_i = lo * 3
        elif port == 0x3C9: s.dac[s.dac_i % 768] = lo & 63; s.dac_i += 1
        elif port == 0x3D4:
            s.crtc_i = lo
            if size == 2: s.crtc[lo] = hi
        elif port == 0x3D5: s.crtc[s.crtc_i] = lo
        elif port == 0x3CE:
            s.gr_i = lo
            if size == 2 and lo < 9: s.gr[lo] = hi
        elif port == 0x3CF and s.gr_i < 9: s.gr[s.gr_i] = lo
    def on_int(s, uc, n, ud):
        ax = uc.reg_read(UC_X86_REG_AX)
        if n == 0x20: s.exited = True; uc.emu_stop()
        elif n == 0x10 and ax >> 8 == 0:
            s.mode = ax & 0x7F; s.dac_i = 0
            uc.mem_write(0xA0000, bytes(0x10000)); s.planes = [bytearray(65536) for _ in range(4)]
            s.gr = [0, 0, 0, 0, 0, 0, 0, 0, 0xFF]
            if s.mode == 0x13: s.dac = [0]*768
            if s.mode == 0x0D and s.vhooks is None:
                s.vhooks = (uc.hook_add(UC_HOOK_MEM_READ, s.on_vread, None, 0xA0000, 0xAFFFF),
                            uc.hook_add(UC_HOOK_MEM_WRITE, s.on_vwrite, None, 0xA0000, 0xAFFFF))
        elif n == 0x29: s.tty(ax & 255)
    def tty(s, ch):
        if ch == 13: s.cur_col = 0; return
        if ch == 7: return                                   # bell: no glyph
        if ch == 8: s.cur_col = max(0, s.cur_col - 1); return  # backspace
        if ch == 10: s.cur_row += 1
        else:
            s.uc.mem_write(0xB8000 + (s.cur_row*80 + s.cur_col)*2, bytes([ch])); s.cur_col += 1
            if s.cur_col == 80: s.cur_col = 0; s.cur_row += 1
        if s.cur_row == 25:
            t = bytes(s.uc.mem_read(0xB8000 + 160, 3840)); s.uc.mem_write(0xB8000, t + b'\x20\x07' * 80); s.cur_row = 24
    def on_hlt(s, uc, addr, size, ud):
        s.ticks += 1; s.frame_due = 'tick'; uc.emu_stop()
    # ---- planar VGA (mode 0Dh): latches, write mode 3, set/reset, logical function
    def on_vread(s, uc, access, addr, size, value, ud):
        if s.mode != 0x0D: return
        a = addr - 0xA0000
        s.latch = [p[a] for p in s.planes]
        uc.mem_write(addr, bytes([s.planes[s.gr[4] & 3][a]]))
    def on_vwrite(s, uc, access, addr, size, value, ud):
        if s.mode != 0x0D: return
        a = addr - 0xA0000; v = value & 255; wm = s.gr[5] & 3; rot = s.gr[3] & 7; fn = (s.gr[3] >> 3) & 3
        v = ((v >> rot) | (v << (8 - rot))) & 255
        for p in range(4):
            sr = 0xFF if (s.gr[0] >> p) & 1 else 0
            if wm == 3: mask = v & s.gr[8]; src = sr
            else:
                mask = s.gr[8]; src = sr if (s.gr[1] >> p) & 1 else v
            L = s.latch[p]
            val = src if fn == 0 else (src & L if fn == 1 else (src | L if fn == 2 else src ^ L))
            s.planes[p][a] = (val & mask) | (L & ~mask & 255)
    # ---- running
    def run(s, until='vsync', instr=0):
        s.frame_due = False
        start = s.uc.reg_read(UC_X86_REG_IP) if getattr(s, 'started', False) else 0x100
        s.started = True
        if until == 'instr':
            s.uc.emu_start(start, 0xFFFF0, count=instr)
        else:
            while not s.frame_due and not s.exited:
                if s.hlt_at is not None and LIN + start == s.hlt_at: start += 1   # step past the HLT (now a NOP) we stopped on
                s.uc.emu_start(start, 0xFFFF0, count=5_000_000)
                start = s.uc.reg_read(UC_X86_REG_IP)
                if until == 'tick' and s.frame_due != 'tick': s.frame_due = False
                if until == 'vsync' and s.frame_due != 'vsync': s.frame_due = False
        return s
    # ---- rendering
    def image(s):
        if s.mode == 0x13:
            px = bytes(s.uc.mem_read(0xA0000, 64000)); im = Image.frombytes('P', (320, 200), px)
            im.putpalette([c * 255 // 63 for c in s.dac]); return im.convert('RGB').resize((640, 400), Image.NEAREST)
        if s.mode == 0x0D:
            im = Image.new('P', (320, 200)); im.putpalette([c for p in EGA for c in p]); pxl = im.load()
            for y in range(200):
                for xb in range(40):
                    a = y*40 + xb; b0, b1, b2, b3 = (s.planes[q][a] for q in range(4))
                    for bit in range(8):
                        m = 0x80 >> bit
                        pxl[xb*8+bit, y] = (1 if b0 & m else 0) | (2 if b1 & m else 0) | (4 if b2 & m else 0) | (8 if b3 & m else 0)
            return im.convert('RGB').resize((640, 400), Image.NEAREST)
        mem = bytes(s.uc.mem_read(0xB8000, 0x8000))
        h = (s.crtc.get(0x09, 0x4F) & 31) + 1
        start = (s.crtc.get(0x0C, 0) << 8) | s.crtc.get(0x0D, 0)
        return vgatext.render(mem, height=h, stride=2 * s.crtc.get(0x13, 40), start=start).convert('RGB').resize((640, 400), Image.LANCZOS)
