# Changelog

Pushing a `vX.Y.Z` tag runs `.github/workflows/release.yml`, which builds, tests and attaches
`UBER128.COM` to a GitHub release using that version's section below.

## [1.0.0] - 2026-10-10

First release as its own repository (it started life in
[uber-tiny-demos](https://github.com/djayuffe/uber-tiny-demos), where it went 118 -> 77 bytes).

- **UBER128.COM**, 77 bytes: rainbow rings flowing out of the screen centre.
- `build.sh` enforces the 128-byte class and the 77-byte budget; `tests/run_tests.sh` runs it in an
  emulated 16-bit CPU; CI and tag-driven releases on GitHub Actions.
