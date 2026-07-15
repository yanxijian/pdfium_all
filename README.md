# pdfium_all

PDFium 聚合 meta 仓库：源码、第三方依赖、文档与发布产出统一组织。

## 目录结构

| 路径 | 说明 |
|------|------|
| [`pdfium/`](pdfium/) | PDFium 源码（git submodule → [yanxijian/pdfium](https://github.com/yanxijian/pdfium.git)，默认分支 `chromium/7947_cmake`） |
| [`thirdparty/`](thirdparty/) | 构建所需外部依赖（多为 submodule；ICU 见目录说明） |
| [`docs/`](docs/) | 设计、构建、集成等文档 |
| [`output/`](output/) | 构建产物暂存区（头文件 / 库 / 动态库），由脚本从构建目录**拷贝**而来 |
| [`scripts/`](scripts/) | 辅助脚本（如产物归档） |

## 初次获取

```bash
git clone --recurse-submodules <本仓库 URL> pdfium_all
# 或已克隆后：
git submodule update --init --recursive
```

子模块 `pdfium` 跟踪分支 `chromium/7947_cmake`（见 `.gitmodules`）。

## 依赖与构建（概要）

- AGG / lcms2 / OpenJPEG：在 `pdfium/third_party` 内置。
- zlib / libjpeg-turbo / FreeType / HarfBuzz / Abseil / fast_float：见 [`thirdparty/`](thirdparty/) 子模块；ICU 可用 vcpkg/系统包或按 `thirdparty/icu/README.md` 引入。
- CMake MVP：无 V8 / 无 XFA / AGG，产物为静态库；说明见 [`docs/cmake-build.md`](docs/cmake-build.md) 与 `pdfium/docs/cmake-build.md`。
- Windows 必须使用 **Clang-cl**。

## 产出归档

构建（例如到 `pdfium/out/cmake`）完成后：

```powershell
.\scripts\stage_output.ps1 -BuildDir .\pdfium\out\cmake
```

```bash
./scripts/stage_output.sh ./pdfium/out/cmake
```

产物进入 [`output/`](output/)：`include/pdfium/public/`、`lib/`、`bin/`（二进制默认不入库）。
