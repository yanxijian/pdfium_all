# 使用 CMake 构建 PDFium（MVP）

推荐使用仓库根目录脚本：

```powershell
.\scripts\bootstrap.ps1 -BootstrapVcpkg -InstallDeps
.\scripts\build.ps1
```

```bash
./scripts/bootstrap.sh
./scripts/build.sh
```

可选 V8（Acrobat JS，无 XFA）：

```powershell
.\scripts\fetch_v8.ps1
.\scripts\build_v8.ps1
.\scripts\build.ps1 -EnableV8
```

```bash
./scripts/fetch_v8.sh
./scripts/build_v8.sh
./scripts/build.sh --enable-v8
```

完整手工命令与系统包名见子模块：[`pdfium/docs/cmake-build.md`](../pdfium/docs/cmake-build.md)。

## 概要

| 项 | 值 |
|----|-----|
| 分支 | `chromium/7947_cmake` |
| 特性 | AGG；可选 V8；无 XFA / Skia / PartitionAlloc |
| 产物 | 动态库 `pdfium`（`pdfium.dll` / `.so`）+ `simple_no_v8`（V8 时另有 `simple_with_v8`） |
| Windows 编译器 | **MSVC `cl`**（产品路径；`-UseClangCl` / V8 仍可用 clang-cl） |
| C++ | **20**（与 VolitionToolchain 一致） |
| V8 侧车 | 默认 `.tools/v8-out`：**component/shared**（`bin/v8.dll` 等）+ Chromium libc++（**非**产品同进程路径） |

启用 V8 时请先 `fetch_v8` / `build_v8`，或设置环境变量 `PDFIUM_V8_ROOT` 指向已 stamp 的**共享**产物树。侧车钉死 `pdfium/DEPS` 的 `v8_revision`；不要用 stock vcpkg `v8`。

## 手工流程（Windows + vcpkg）

先保证环境变量 `VCPKG_ROOT` 已指向 vcpkg；在已加载 VS x64 开发环境的 shell 中执行（产品路径用 **MSVC `cl`**，不必装 LLVM）：

```bat
cmake -S pdfium -B pdfium/out/cmake-msvc -G Ninja -DCMAKE_BUILD_TYPE=Release ^
  -DCMAKE_C_COMPILER=cl -DCMAKE_CXX_COMPILER=cl ^
  -DCMAKE_TOOLCHAIN_FILE=%VCPKG_ROOT%/scripts/buildsystems/vcpkg.cmake ^
  -DVCPKG_TARGET_TRIPLET=x64-windows ^
  -DCMAKE_CXX_STANDARD=20 ^
  -DPDFIUM_ENABLE_V8=OFF
cmake --build pdfium/out/cmake-msvc --target pdfium simple_no_v8
powershell -File scripts\stage_output.ps1 -BuildDir pdfium\out\cmake-msvc
```

（推荐直接 `.\scripts\build.ps1`。旧 Clang-cl 路径：`.\scripts\build.ps1 -UseClangCl`。）

启用 V8 时另设 `-DPDFIUM_ENABLE_V8=ON` 与 `-DPDFIUM_V8_ROOT=...`（建议使用单独构建目录，例如 `pdfium/out/cmake-v8`）。

Linux / macOS 依赖包名见 `pdfium/docs/cmake-build.md`。
