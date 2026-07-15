# 仓库布局与产物规范

## Meta 仓库布局

```
pdfium_all/
├── pdfium/          # submodule：PDFium 源码
├── thirdparty/      # 外部依赖源码或子仓库
├── docs/            # 文档
├── scripts/         # 工具脚本
└── output/          # 发布用产物（拷贝进入，不作为构建outdir）
    ├── include/     # 对外头文件
    ├── lib/         # 静态库 / 导入库（.a / .lib）
    └── bin/         # 动态库 / 可执行文件（.so / .dll / .dylib）
```

## output/ 约定

- **不要**把 CMake/`ninja` 的 `CMAKE_INSTALL_PREFIX` 或 `out/cmake` 直接指到 `output/`。
- 构建仍在 `pdfium/out/...`（或自选构建目录）完成。
- 成功后用 `scripts/stage_output.ps1`（或等价脚本）拷贝到 `output/`。
- `output/` 下二进制默认不纳入 git（见根目录 `.gitignore`），仅保留目录占位。

### 建议拷贝映射

| 来源 | 目标 |
|------|------|
| `public/*.h`、`public/cpp/*.h` | `output/include/pdfium/public/...` |
| `pdfium.lib` / `libpdfium.a` | `output/lib/` |
| `pdfium.dll` / `libpdfium.so` / `libpdfium.dylib`（若有） | `output/bin/` |

下游消费时增加 include：`output/include/pdfium`，链接：`output/lib`。
