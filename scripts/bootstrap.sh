#!/usr/bin/env bash
# Initialize submodules and check toolchain (Linux/macOS).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "== git submodule update --init --recursive =="
git submodule update --init --recursive

need() { command -v "$1" >/dev/null || { echo "missing: $1" >&2; exit 1; }; }
need cmake
need ninja
need git
need c++
echo "Bootstrap done. Install system deps per docs/cmake-build.md / pdfium/docs/cmake-build.md"
