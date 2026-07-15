# thirdparty

构建 PDFium 所需的**外部**第三方库（源码或 git 子仓库）。

内置在 PDFium 树内、无需放在此处的组件：

- `pdfium/third_party/agg23`（AGG）
- `pdfium/third_party/lcms`（Little CMS）
- `pdfium/third_party/libopenjpeg`

清单与上游地址见 [`docs/thirdparty.md`](../docs/thirdparty.md)。

每个子目录若尚未检出 submodule，会有简短 `README.md` 说明如何获取。
