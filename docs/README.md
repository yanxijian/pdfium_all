# docs

本目录存放 pdfium_all / PDFium 相关文档（构建、集成、发布、设计笔记等）。

| 文档 | 内容 |
|------|------|
| [cmake-build.md](cmake-build.md) | CMake MVP 构建说明（默认无 V8；可选 EnableV8） |
| [deps-policy.md](deps-policy.md) | vcpkg vs thirdparty 子模块 vs V8 侧车策略 |
| [layout.md](layout.md) | 本 meta 仓库目录约定与产物规范 |
| [thirdparty.md](thirdparty.md) | 第三方依赖清单与引入方式 |
| [../deps.lock.md](../deps.lock.md) | 子模块 / V8 revision 锁定表 |

新增文档请保持 Markdown，文件名使用小写 + 连字符。文档中只写仓库相对路径或环境变量名，不要写某台机器的绝对路径。
