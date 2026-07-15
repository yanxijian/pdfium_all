# output

构建产物归档目录（**不作为** CMake 直接输出目录）。

```
output/
├── include/   # 头文件，如 include/pdfium/public/...
├── lib/       # .lib / .a
└── bin/       # .dll / .so / .dylib / 可选可执行文件
```

使用仓库根目录 `scripts/stage_output.ps1` 或 `scripts/stage_output.sh`，从构建树拷贝到此处。
