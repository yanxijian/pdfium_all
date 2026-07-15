#!/usr/bin/env bash
# Configure + build PDFium CMake MVP and stage output/ (Linux/macOS).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENABLE_V8=0
BUILD_DIR=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --enable-v8) ENABLE_V8=1; shift ;;
    --build-dir) BUILD_DIR="$2"; shift 2 ;;
    *)
      if [[ -z "$BUILD_DIR" ]]; then BUILD_DIR="$1"; shift; else echo "unknown arg: $1" >&2; exit 1; fi
      ;;
  esac
done

if [[ -z "$BUILD_DIR" ]]; then
  if [[ "$ENABLE_V8" -eq 1 ]]; then
    BUILD_DIR="$ROOT/pdfium/out/cmake-v8"
  else
    BUILD_DIR="$ROOT/pdfium/out/cmake"
  fi
fi

CMAKE_ARGS=(
  -S "$ROOT/pdfium"
  -B "$BUILD_DIR"
  -G Ninja
  -DCMAKE_BUILD_TYPE=Release
)

TARGETS=(pdfium simple_no_v8)
if [[ "$ENABLE_V8" -eq 1 ]]; then
  V8_ROOT="${PDFIUM_V8_ROOT:-${V8_ROOT:-$ROOT/.tools/v8-out}}"
  if [[ ! -f "$V8_ROOT/v8/include/v8.h" ]]; then
    echo "V8 tree missing at $V8_ROOT (run ./scripts/fetch_v8.sh && ./scripts/build_v8.sh)" >&2
    exit 1
  fi
  CMAKE_ARGS+=(-DPDFIUM_ENABLE_V8=ON "-DPDFIUM_V8_ROOT=$V8_ROOT")
  TARGETS+=(simple_with_v8)
else
  CMAKE_ARGS+=(-DPDFIUM_ENABLE_V8=OFF)
fi

cmake "${CMAKE_ARGS[@]}"
cmake --build "$BUILD_DIR" --target "${TARGETS[@]}"
"$ROOT/scripts/stage_output.sh" "$BUILD_DIR"

if [[ -x "$ROOT/output/bin/simple_no_v8" ]]; then
  (cd "$ROOT/output/bin" && ./simple_no_v8)
fi
if [[ "$ENABLE_V8" -eq 1 && -x "$ROOT/output/bin/simple_with_v8" ]]; then
  (cd "$ROOT/output/bin" && ./simple_with_v8)
fi
echo "Build pipeline done."
