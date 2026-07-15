# 依赖策略（MVP）

## 结论（先读这个）

| 用途 | 用什么 |
|------|--------|
| **日常 / CI 构建 PDFium（当前）** | **vcpkg**（Windows）或系统包（Linux/macOS） |
| **`thirdparty/` 子模块** | **版本钉扎的源码镜像**（对照、审计、日后源码联编） |
| **`pdfium/third_party` 内置** | AGG、lcms2、OpenJPEG（不放在本仓库 `thirdparty/`） |
| **可选 V8** | GN 侧车：`fetch_v8` / `build_v8` → `.tools/v8-out`（钉 `pdfium/DEPS` `v8_revision`） |

**不要**指望仅 `git submodule update` 后不加 vcpkg/系统包就能编过：CMake MVP 通过 `find_package` 找已安装的库，默认不 `add_subdirectory(thirdparty/...)`。

## 为什么这样分

1. ICU / FreeType / HarfBuzz 等在 Windows 上用 vcpkg 安装最省事（端口版本见 [`deps.lock.md`](../deps.lock.md)）。
2. 子模块把「用过哪几个上游 tag」写进 git history，避免 tip 漂移。
3. 将来若要纯源码构建，可在 CMake 中增加开关再接线；**当前非目标**。

## 操作约定

- 不要在文档 / 脚本里硬编码某台机器的绝对路径；使用 `VCPKG_ROOT`、`PDFIUM_V8_ROOT`，或 `bootstrap.ps1 -BootstrapVcpkg` / `build_v8`（落到仓库相对路径 `.tools/...`）。
- 可选 V8：通过 `fetch_v8` / `build_v8` 侧车按 `pdfium/DEPS` 的 `v8_revision` 提供引擎；不要用 stock vcpkg `v8` 端口。
- 升级依赖：先在 vcpkg（或系统包）验证能编过 → 再把对应 `thirdparty/*` checkout 到同名 tag → 更新 `deps.lock.md` → 提交 meta 仓库的 gitlink。
- ICU：体积大，不设 submodule；始终用 vcpkg/系统包，版本记在 `deps.lock.md` 的 vcpkg 表中。
