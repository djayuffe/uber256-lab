"""Render VGA text mode (80 columns, 9x16 cells, blink-mode attributes) from text memory, with the CRTC
character height (CR09) and row stride (CR13) honoured, using the ROM font dumped from DOSBox."""
from PIL import Image
FONT = open('/tmp/fdump/FONT.BIN', 'rb').read()
PAL = [(0,0,0),(0,0,170),(0,170,0),(0,170,170),(170,0,0),(170,0,170),(170,85,0),(170,170,170),
       (85,85,85),(85,85,255),(85,255,85),(85,255,255),(255,85,85),(255,85,255),(255,255,85),(255,255,255)]
def render(mem, height=16, stride=80, start=0, rows400=400):
    """mem: bytes of text memory from B8000h (at least 32 KB recommended). height: scan lines per row."""
    im = Image.new('P', (720, rows400)); im.putpalette([c for p in PAL for c in p])
    px = im.load()
    n = len(mem) // 2
    for y in range(rows400):
        row, line = divmod(y, height)
        base = start + row * stride
        for col in range(80):
            i = (base + col) % n
            ch, at = mem[2*i], mem[2*i+1]
            fg, bg = at & 15, (at >> 4) & 7
            bits = FONT[ch*16 + line] if line < 16 else 0
            x0 = col * 9
            for b in range(8):
                px[x0+b, y] = fg if bits & (0x80 >> b) else bg
            px[x0+8, y] = (fg if bits & 1 else bg) if 0xC0 <= ch <= 0xDF else bg
    return im
