# 使用 CMake 构建 PDFium（MVP）

推荐使用仓库根目录脚本（跨机器、不绑定具体盘符路径）：

```powershell
.\scripts\bootstrap.ps1 -BootstrapVcpkg -InstallDeps
.\scripts\build.ps1
```

完整手工命令与系统包名见子模块：[`pdfium/docs/cmake-build.md`](../pdfium/docs/cmake-build.md)。

## 概要

| 项 | 值 |
|----|-----|
| 分支 | `chromium/7947_cmake` |
| 特性 | AGG，无 V8，无 XFA，无 Skia，无 PartitionAlloc |
| 产物 | 静态库 `pdfium` + 示例 `simple_no_v8` |
| Windows 编译器 | Clang-cl（必需） |

## 手工流程（Windows + vcpkg）

先保证 `VCPKG_ROOT` 已设置，且 LLVM / Ninja 在 `PATH` 中：

```bat
call "%VSINSTALLDIR%\VC\Auxiliary\Build\vcvars64.bat"
cmake -S pdfium -B pdfium/out/cmake -G Ninja -DCMAKE_BUILD_TYPE=Release ^
  -DCMAKE_C_COMPILER=clang-cl -DCMAKE_CXX_COMPILER=clang-cl ^
  -DCMAKE_TOOLCHAIN_FILE=%VCPKG_ROOT%/scripts/buildsystems/vcpkg.cmake ^
  -DVCPKG_TARGET_TRIPLET=x64-windows
cmake --build pdfium/out/cmake --target pdfium simple_no_v8
powershell -File scripts\stage_output.ps1 -BuildDir pdfium\out\cmake
```

Linux / macOS 依赖包名见 `pdfium/docs/cmake-build.md`。
