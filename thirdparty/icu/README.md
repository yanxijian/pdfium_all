# icu

上游仓库：https://github.com/unicode-org/icu.git

ICU 体积较大，默认**不**自动作为 submodule 拉全历史。需要时：

```bash
cd pdfium_all
git submodule add --depth 1 https://github.com/unicode-org/icu.git thirdparty/icu
```

或继续使用 vcpkg / 系统包安装 ICU，本目录仅作版本对照。
