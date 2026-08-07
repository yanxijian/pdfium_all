# pdfium_all

[![CI](https://github.com/yanxijian/pdfium_all/actions/workflows/ci.yml/badge.svg)](https://github.com/yanxijian/pdfium_all/actions/workflows/ci.yml)

PDFium 聚合 **meta** 仓库：源码 submodule、第三方镜像、文档与 stage 产物统一组织。

仓库：[yanxijian/pdfium_all](https://github.com/yanxijian/pdfium_all)  
English：[`docs/en/README.md`](docs/en/README.md)

> **VolitionToolchain（产品路径）**：Windows **MSVC `cl` + C++20 + `/MD`**，默认 **V8 OFF**，Abseil 优先 [AbseilPin](https://github.com/yanxijian/AbseilPin) `20260107.1`。产品消费方见 [Volition](https://github.com/yanxijian/Volition)。

## 目录

| 路径 | 说明 |
|------|------|
| [`pdfium/`](pdfium/) | PDFium（submodule → [yanxijian/pdfium](https://github.com/yanxijian/pdfium.git)；产品 tip 见 `deps.lock.md` / 当前 SHA） |
| [`thirdparty/`](thirdparty/) | 钉版本上游镜像（对照用；默认构建走 vcpkg / 系统包） |
| [`docs/`](docs/) | 文档（中文主文档 + [`docs/en/`](docs/en/)） |
| [`output/`](output/) | stage 产物目录（构建脚本拷贝；二进制默认不入库） |
| [`scripts/`](scripts/) | bootstrap / build / stage / 可选 V8 侧车 |

本地 `.tools/`（gitignore）可放 vcpkg / V8 侧车产物。

## 前置条件

| 平台 | 需要 |
|------|------|
| 通用 | Git、CMake、Ninja |
| Windows（产品） | Visual Studio C++ x64、[vcpkg](https://vcpkg.io)；可选 LLVM（仅 `-UseClangCl` / V8） |
| Linux / macOS | 系统开发包（见 [`docs/cmake-build.md`](docs/cmake-build.md)） |
| 可选 V8 | depot_tools；访问 chromium.googlesource.com（**非**同进程产品路径） |

Windows vcpkg：设 `VCPKG_ROOT`，或 `.\scripts\bootstrap.ps1 -BootstrapVcpkg -InstallDeps`。

## 快速开始

```bash
git clone --recurse-submodules https://github.com/yanxijian/pdfium_all.git
cd pdfium_all
# CI / 日常也可只拉 pdfium： git submodule update --init pdfium
```

Windows（默认 MSVC `cl`）：

```powershell
.\scripts\bootstrap.ps1 -BootstrapVcpkg -InstallDeps
.\scripts\build.ps1
```

可选 Acrobat JS（V8，无 XFA；强制 clang-cl + libc++ ABI）：

```powershell
.\scripts\fetch_v8.ps1
.\scripts\build_v8.ps1
.\scripts\build.ps1 -EnableV8
```

Linux / macOS：

```bash
./scripts/bootstrap.sh
./scripts/build.sh
```

钉扎：[`deps.lock.md`](deps.lock.md)。策略：[`docs/deps-policy.md`](docs/deps-policy.md)。构建细节：[`docs/cmake-build.md`](docs/cmake-build.md)。

## 依赖与构建（概要）

- **构建用 vcpkg / 系统包**；`thirdparty/` 为源码镜像。
- AGG / lcms2 / OpenJPEG：在 `pdfium/third_party` 内置。
- CMake MVP：默认 **共享库** `pdfium`、**无 V8**；无 XFA / Skia。
- V8 **不是** submodule；由 `fetch_v8` / `build_v8` 按 `pdfium/DEPS` 拉齐。

## 产出

```powershell
.\scripts\stage_output.ps1 -BuildDir .\pdfium\out\cmake-msvc
```

`output/include/pdfium/public/`、`output/lib/`、`output/bin/`。

## CI

GitHub Actions：Windows MSVC 产品路径 + Ubuntu 无 V8 编通（见 [Actions](https://github.com/yanxijian/pdfium_all/actions/workflows/ci.yml)）。
