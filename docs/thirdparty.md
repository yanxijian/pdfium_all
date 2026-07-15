# 第三方依赖清单

CMake MVP（无 V8 / 无 XFA / AGG）所需外部依赖如下。AGG、lcms2、OpenJPEG 已内置在 `pdfium/third_party`，**不**放入本目录。

| 依赖 | 本目录建议路径 | 上游 | 用途 |
|------|----------------|------|------|
| zlib | `thirdparty/zlib` | https://github.com/madler/zlib.git | 压缩 |
| libjpeg-turbo | `thirdparty/libjpeg-turbo` | https://github.com/libjpeg-turbo/libjpeg-turbo.git | JPEG |
| FreeType | `thirdparty/freetype` | https://github.com/freetype/freetype.git | 字体 |
| ICU | `thirdparty/icu` | https://github.com/unicode-org/icu.git | Unicode |
| HarfBuzz | `thirdparty/harfbuzz` | https://github.com/harfbuzz/harfbuzz.git | 字体子集（edit） |
| Abseil | `thirdparty/abseil-cpp` | https://github.com/abseil/abseil-cpp.git | 容器等 |
| fast_float | `thirdparty/fast_float` | https://github.com/fastfloat/fast_float.git | 浮点解析 |

Linux 另需系统 **Fontconfig**；macOS 链接 AppKit / CoreFoundation / CoreGraphics。

## 引入方式

可任选：

1. **子仓库（推荐）**：在 `thirdparty/` 下以 git submodule 引入上表仓库。
2. **源码解压**：将发行包解压到对应目录（勿提交巨型历史时可用 `.gitignore` 排除内容、仅留 README）。
3. **包管理器**：Windows 可用 vcpkg（见 [cmake-build.md](cmake-build.md)），此时本目录可作为对照版本钉扎，不必重复编译。

## 本仓库当前状态

已通过 **git submodule**（`--depth 1`）引入：

- `thirdparty/zlib`
- `thirdparty/libjpeg-turbo`
- `thirdparty/freetype`
- `thirdparty/harfbuzz`
- `thirdparty/abseil-cpp`
- `thirdparty/fast_float`

`thirdparty/icu` 仅保留说明（仓库过大）；需要时按该目录 README 自行添加 submodule，或继续用 vcpkg / 系统 ICU。