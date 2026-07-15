# 使用 CMake 构建 PDFium（MVP）

完整平台命令见子模块：[`pdfium/docs/cmake-build.md`](../pdfium/docs/cmake-build.md)。

## 概要

| 项 | 值 |
|----|-----|
| 分支 | `chromium/7947_cmake` |
| 特性 | AGG，无 V8，无 XFA，无 Skia，无 PartitionAlloc |
| 产物 | 静态库 `pdfium` + 示例 `simple_no_v8` |
| Windows 编译器 | Clang-cl（必需） |

## 典型流程（Windows + vcpkg）

```bat
call "%VSINSTALLDIR%\VC\Auxiliary\Build\vcvars64.bat"
set PATH=C:\Program Files\LLVM\bin;%PATH%
cmake -S pdfium -B pdfium/out/cmake -G Ninja -DCMAKE_BUILD_TYPE=Release ^
  -DCMAKE_C_COMPILER=clang-cl -DCMAKE_CXX_COMPILER=clang-cl ^
  -DCMAKE_TOOLCHAIN_FILE=%VCPKG_ROOT%/scripts/buildsystems/vcpkg.cmake
cmake --build pdfium/out/cmake --target pdfium simple_no_v8
powershell -File scripts\stage_output.ps1 -BuildDir pdfium\out\cmake
```

Linux / macOS 依赖包名见 `pdfium/docs/cmake-build.md`。
