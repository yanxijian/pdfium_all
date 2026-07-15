# Dependency lock file

Pinned git commits for meta-repo submodules. Update this file whenever submodule
pointers change. **Build (MVP) uses vcpkg / system packages**; submodule trees
are the version-locked source mirror for review and future source-builds.

| Path | Role | Pin (tag) | Commit |
|------|------|-----------|--------|
| `pdfium` | PDFium | branch `chromium/7947_cmake` | `d82939c9f3da4f58cfc100d23f6a2bd214d02295` |
| `thirdparty/zlib` | source mirror | `v1.3.2` | `da607da739fa6047df13e66a2af6b8bec7c2a498` |
| `thirdparty/libjpeg-turbo` | source mirror | `3.2.0` | `c85e6b905bf237038faa936dab160ebfc5da0344` |
| `thirdparty/freetype` | source mirror | `VER-2-14-3` | `0a0221a1347e2f1e07c395263540026e9a0aa7c7` |
| `thirdparty/harfbuzz` | source mirror | `14.2.1` | `56feae4035bdd48f62ba2b8d8c16232d4d89b3a4` |
| `thirdparty/abseil-cpp` | source mirror | `20260107.1` | `255c84dadd029fd8ad25c5efb5933e47beaa00c7` |
| `thirdparty/fast_float` | source mirror | `v8.0.2` | `50a80a73ab2ab256ba1c3bf86923ddd8b4202bc7` |
| `thirdparty/icu` | not vendored | use vcpkg / system | — |

## Reference Windows build packages (vcpkg `x64-windows`)

Versions that successfully built the CMake MVP (for reference; pin via your own vcpkg baseline if needed):

| Port | Version |
|------|---------|
| zlib | 1.3.2#1 |
| libjpeg-turbo | 3.2.0 |
| freetype | 2.14.3 |
| harfbuzz | 14.2.1#1 |
| abseil | 20260107.1#3 |
| icu | 78.3#1 |

Install:

```bat
vcpkg install zlib libjpeg-turbo freetype icu harfbuzz abseil --triplet x64-windows
```
