# Changelog

Pushing a `vX.Y.Z` tag runs `.github/workflows/release.yml`, which builds, tests and attaches
`UBER256.COM` to a GitHub release using that version's section below.

## [1.0.0] - 2026-10-10

First release as its own repository (it started life in
[uber-tiny-demos](https://github.com/djayuffe/uber-tiny-demos), where it went 237 -> 171 bytes).

- **UBER256.COM**, 171 bytes: an XOR rotozoomer rotating about the screen centre.
- `build.sh` enforces the 256-byte class and the 171-byte budget; `tests/run_tests.sh` runs it in an
  emulated 16-bit CPU and checks the rotation maths; CI and tag-driven releases on GitHub Actions.
