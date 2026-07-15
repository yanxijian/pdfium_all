# pdfium_all

PDFium 聚合 meta 仓库：源码、第三方依赖、文档与发布产物统一组织。

仓库地址：https://github.com/yanxijian/pdfium_all

## 目录结构

| 路径 | 说明 |
|------|------|
| [`pdfium/`](pdfium/) | PDFium 源码（submodule → [yanxijian/pdfium](https://github.com/yanxijian/pdfium.git)，分支 `chromium/7947_cmake`） |
| [`thirdparty/`](thirdparty/) | 钉版本的上游源码镜像（对照用；默认不直接参与链接） |
| [`docs/`](docs/) | 文档 |
| [`output/`](output/) | 构建产物暂存（由脚本从构建目录**拷贝**） |
| [`scripts/`](scripts/) | bootstrap / build / stage / V8 侧车脚本 |

仓库内 `.tools/`（已 gitignore）可存放本地工具与 V8 侧车产物，请勿提交。

## 前置条件

| 平台 | 需要 |
|------|------|
| 通用 | Git、CMake、Ninja |
| Windows | **Clang-cl**（LLVM）、Visual Studio C++ 工具集、[vcpkg](https://vcpkg.io) |
| Linux / macOS | 系统开发包（见 `pdfium/docs/cmake-build.md`） |
| 可选 V8 | depot_tools（脚本可自动准备）、能访问 chromium.googlesource.com |

Windows 上请任选其一提供 vcpkg：

1. 设置环境变量 `VCPKG_ROOT` 指向已有 vcpkg 检出；或  
2. 首次执行 `.\scripts\bootstrap.ps1 -BootstrapVcpkg`（克隆到仓库内 `.tools/vcpkg`）。

访问 Google 源站若需要代理，请设置标准的 `HTTP_PROXY` / `HTTPS_PROXY`。若只有 SOCKS5，可用 `scripts/socks_http_bridge.py`（依赖 `PySocks`）桥接为 HTTP 代理后再跑 `fetch_v8`。

## 快速开始

```bash
git clone --recurse-submodules https://github.com/yanxijian/pdfium_all.git
cd pdfium_all
```

Windows：

```powershell
# 若尚无 VCPKG_ROOT，可加 -BootstrapVcpkg；需要装端口时加 -InstallDeps
.\scripts\bootstrap.ps1 -BootstrapVcpkg -InstallDeps
.\scripts\build.ps1
```

可选 Acrobat JS（V8，无 XFA；首次较慢）：

```powershell
.\scripts\fetch_v8.ps1
.\scripts\build_v8.ps1
.\scripts\build.ps1 -EnableV8
```

Linux / macOS（系统依赖需自行装好）：

```bash
./scripts/bootstrap.sh
./scripts/build.sh
# optional:
# ./scripts/fetch_v8.sh && ./scripts/build_v8.sh && ./scripts/build.sh --enable-v8
```

版本钉扎见 [`deps.lock.md`](deps.lock.md)；依赖策略见 [`docs/deps-policy.md`](docs/deps-policy.md)。

## 依赖与构建（概要）

- **构建用 vcpkg / 系统包**；`thirdparty/` 是钉版本源码镜像（见策略文档）。
- AGG / lcms2 / OpenJPEG：在 `pdfium/third_party` 内置。
- CMake MVP：**默认无 V8**；可用侧车脚本启用 V8。默认产出 **共享库** `pdfium`（`PDFIUM_BUILD_SHARED=ON`）。无 XFA / Skia。见 [`docs/cmake-build.md`](docs/cmake-build.md)。
- V8 **不是** submodule；按 `pdfium/DEPS` 的 `v8_revision` 由 `fetch_v8` / `build_v8` 拉齐，默认产出 **component/shared** 到 `.tools/v8-out`（`bin/v8.dll` 等；也可用 `PDFIUM_V8_ROOT`）。
- Windows 必须使用 **Clang-cl**。

## 产出归档

`build` 脚本默认会 stage；也可单独执行：

```powershell
.\scripts\stage_output.ps1 -BuildDir .\pdfium\out\cmake
```

```bash
./scripts/stage_output.sh ./pdfium/out/cmake
```

产物目录：`output/include/pdfium/public/`、`output/lib/`、`output/bin/`（二进制默认不入库）。
