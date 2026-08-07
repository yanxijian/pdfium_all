# pdfium_all

[![CI](https://github.com/yanxijian/pdfium_all/actions/workflows/ci.yml/badge.svg)](https://github.com/yanxijian/pdfium_all/actions/workflows/ci.yml)

Meta-repo that aggregates **PDFium** sources, third-party mirrors, docs, and staged build output.

Repo: [yanxijian/pdfium_all](https://github.com/yanxijian/pdfium_all)

> Canonical docs are Chinese — start at the [root README](../../README.md).

**VolitionToolchain (product path):** Windows **MSVC `cl` + C++20 + `/MD`**, default **V8 OFF**, Abseil prefers [AbseilPin](https://github.com/yanxijian/AbseilPin) `20260107.1`. Product consumer: [Volition](https://github.com/yanxijian/Volition).

## Layout

| Path | Role |
|------|------|
| [`pdfium/`](../../pdfium/) | PDFium submodule → [yanxijian/pdfium](https://github.com/yanxijian/pdfium.git) |
| [`thirdparty/`](../../thirdparty/) | Version-locked upstream mirrors (build uses vcpkg / system packages) |
| [`docs/`](../) | Docs (`zh` via root / this tree; English here) |
| [`output/`](../../output/) | Staged artifacts (copied by scripts; binaries not committed) |
| [`scripts/`](../../scripts/) | bootstrap / build / stage / optional V8 sidecar |

## Requirements

| Platform | Needs |
|----------|--------|
| Common | Git, CMake, Ninja |
| Windows (product) | VS C++ x64, [vcpkg](https://vcpkg.io); LLVM only for `-UseClangCl` / V8 |
| Linux / macOS | Distro packages (see [cmake-build.md](../cmake-build.md)) |
| Optional V8 | depot_tools + Chromium sources (**not** the in-process product path) |

## Quick start

```bash
git clone --recurse-submodules https://github.com/yanxijian/pdfium_all.git
cd pdfium_all
```

Windows (default MSVC `cl`):

```powershell
.\scripts\bootstrap.ps1 -BootstrapVcpkg -InstallDeps
.\scripts\build.ps1
```

Optional Acrobat JS (V8; clang-cl + libc++):

```powershell
.\scripts\fetch_v8.ps1
.\scripts\build_v8.ps1
.\scripts\build.ps1 -EnableV8
```

Linux / macOS:

```bash
./scripts/bootstrap.sh
./scripts/build.sh
```

Pins: [`deps.lock.md`](../../deps.lock.md). Policy: [`deps-policy.md`](../deps-policy.md). Build notes: [`cmake-build.md`](../cmake-build.md).

## CI

[GitHub Actions](https://github.com/yanxijian/pdfium_all/actions/workflows/ci.yml): Windows MSVC product path + Ubuntu V8-off build.
