#!/usr/bin/env bash
# Configure + build PDFium CMake MVP and stage output/ (Linux/macOS).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="${1:-$ROOT/pdfium/out/cmake}"

cmake -S "$ROOT/pdfium" -B "$BUILD_DIR" -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build "$BUILD_DIR" --target pdfium simple_no_v8
"$ROOT/scripts/stage_output.sh" "$BUILD_DIR"
if [[ -x "$ROOT/output/bin/simple_no_v8" ]]; then
  "$ROOT/output/bin/simple_no_v8"
fi
echo "Build pipeline done."
