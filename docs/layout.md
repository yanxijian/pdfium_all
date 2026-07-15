# 仓库布局与产物规范

## Meta 仓库布局

```
pdfium_all/
├── pdfium/          # submodule：PDFium 源码
├── thirdparty/      # 钉版本上游源码镜像
├── docs/            # 文档
├── scripts/         # 工具脚本
├── .tools/          # 本地工具 / V8 侧车（gitignore，勿提交）
└── output/          # 发布用产物（拷贝进入，不作为构建 outdir）
    ├── include/     # 对外头文件
    ├── lib/         # 静态库 / 导入库（.a / .lib）
    └── bin/         # 动态库 / 可执行文件（.so / .dll / .dylib）
```

## .tools/ 约定

- 默认路径约定：`.tools/vcpkg`、`.tools/depot_tools`、`.tools/v8-workspace`、`.tools/v8-out`。
- 可用 `VCPKG_ROOT` / `PDFIUM_V8_ROOT` 指向仓库外的已有目录；不要在文档或脚本里写盘符绝对路径。

## output/ 约定

- **不要**把 CMake/`ninja` 的 `CMAKE_INSTALL_PREFIX` 或构建 out 目录直接指到 `output/`。
- 构建仍在 `pdfium/out/...`（或自选构建目录）完成。
- 成功后用 `scripts/stage_output.ps1`（或 `.sh`）拷贝到 `output/`。
- `output/` 下二进制默认不纳入 git（见根目录 `.gitignore`），仅保留目录占位。

### 建议拷贝映射

| 来源 | 目标 |
|------|------|
| `public/*.h`、`public/cpp/*.h` | `output/include/pdfium/public/...` |
| `pdfium.lib` / `libpdfium.a`（导入库） | `output/lib/` |
| `pdfium.dll` / `.so` / `.dylib` | `output/bin/` |
| `v8.dll` 等及导入库（EnableV8 时） | `output/bin/` + `output/lib/` |
| 样本 exe 及 `snapshot_blob.bin`（若启用） | `output/bin/` |

下游消费时增加 include：`output/include/pdfium`，链接：`output/lib`。
