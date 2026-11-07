# Rendering animations without a screen recorder

The GIFs marked "rendered" in the demo READMEs come from these scripts: each frame is produced by running the
**real `.COM` binary** in the Unicorn CPU emulator and drawing its display from a **model** of the hardware.

- `vgatext.py`: VGA text mode, 80 x 25 cells of 9 x 16 pixels, blink-mode attributes, the 9th-column rule for
  characters C0h-DFh, and the CRTC character height (CR09) and row stride (CR13).
- `emu.py`: the machine. DOS entry registers as DOSBox sets them; a text screen and ROM font dumped from DOSBox;
  a minimal `int 29h` teletype; the DAC for mode 13h; and for mode 0Dh four VGA planes with latches, set/reset,
  write modes 0 and 3 and the logical function. Frames are taken per vertical retrace, per timer tick (`HLT`) or
  per N instructions (DOSBox `cycles=3000` is modelled as about 3 million instructions a second).
- `batch.py`: the list of demos, frame counts and GIF settings used for the READMEs.
- `fontdump.asm`: assemble with NASM and run inside DOSBox; it writes `FONT.BIN` (the 8 x 16 ROM font from
  `int 10h` AX = 1130h) and `SCREEN.BIN` (the text screen at the moment it ran). The scripts expect both in
  `/tmp/fdump/` and write frames to `/tmp/render/`; change the paths at the top if you keep them elsewhere.

These are models, so a render can only be as right as the model. Every rendered GIF was compared with a real
DOSBox screenshot of the same program before it was published.
