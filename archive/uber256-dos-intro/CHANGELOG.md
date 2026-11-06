# Changelog

Pushing a `vX.Y.Z` tag runs `.github/workflows/release.yml`, which builds, tests and attaches
`MOIRE.COM` to a GitHub release using that version's section below.

## [1.1.0] - 2026-10-10

### Changed
- **Shrunk from 196 to 131 bytes** and renamed `UBER256.COM` -> `MOIRE.COM` (the 256-byte class
  now also has a rotozoomer: [uber256-rotozoomer](https://github.com/djayuffe/uber256-rotozoomer)).
  - The 43-byte triangle-wave palette became a 12-byte streamed one (`R = i, G = 2i, B = 4i`).
  - No loop nest: `DI` wraps over the 64 KB segment and one `DIV` gives x and y.
  - The ring families are XORed instead of folded and added, and the orbit uses `|signed byte|`
    triangle waves: no fold routine at all.
- Now paced to vertical retrace. The source moved to `moire.asm`; the test checks the palette exactly.

## [1.0.0] - 2026-10-07

First standalone release (split out of [uber40k-dos-demo](https://github.com/djayuffe/uber40k-dos-demo)).

- 196-byte intro: a seamless rainbow palette built
  from three phase-shifted triangle waves, and two ring families whose centres orbit
  each other, folded into a moire.
- Clean exit: Esc restores text mode and the keyboard interrupt mask.
- `build.sh` enforces the 256-byte limit; `tests/run_tests.sh` runs the real binary in an
  emulated 16-bit CPU; CI and tag-driven releases on GitHub Actions.
