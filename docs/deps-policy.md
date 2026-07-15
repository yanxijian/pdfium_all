# 依赖策略（MVP）

## 结论（先读这个）

| 用途 | 用什么 |
|------|--------|
| **日常 / CI 构建 PDFium（当前）** | **vcpkg**（Windows）或系统包（Linux/macOS） |
| **`thirdparty/` 子模块** | **版本钉扎的源码镜像**（对照、审计、日后源码联编） |
| **`pdfium/third_party` 内置** | AGG、lcms2、OpenJPEG（不放在本仓库 `thirdparty/`） |

**不要**指望仅 `git submodule update` 后不加 vcpkg 就能编过：CMake MVP 通过 `find_package` 找已安装的库，默认不 `add_subdirectory(thirdparty/...)`。

## 为什么这样分

1. ICU / FreeType / HarfBuzz 等二进制部署在 Windows 上用 vcpkg 最省事，且已在本仓库验证路径上跑通。
2. 子模块把「用过哪几个上游 tag」写进 git history（见 [`deps.lock.md`](../deps.lock.md)），避免 tip 漂移。
3. 将来若要纯源码构建，可在 CMake 中增加 `PDFIUM_USE_BUNDLED_THIRDPARTY=ON` 一类开关再接线；**当前非目标**。

## 操作约定

- 升级依赖：先在 vcpkg（或系统包）验证能编过 → 再把对应 `thirdparty/*` checkout 到同名 tag → 更新 `deps.lock.md` → 提交 meta 仓库的 gitlink。
- ICU：体积大，不设 submodule；始终用 vcpkg/系统包，版本记在 `deps.lock.md` 的 vcpkg 表中。
