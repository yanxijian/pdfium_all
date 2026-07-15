#!/usr/bin/env bash
# 将 PDFium CMake 构建产物拷贝到 pdfium_all/output/
set -euo pipefail

BUILD_DIR="${1:?Usage: $0 <cmake-build-dir>}"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT_ROOT="${REPO_ROOT}/output"
PDIUM_ROOT="${REPO_ROOT}/pdfium"

if [[ ! -d "${BUILD_DIR}" ]]; then
  echo "Build dir not found: ${BUILD_DIR}" >&2
  exit 1
fi

mkdir -p "${OUT_ROOT}/include/pdfium/public" "${OUT_ROOT}/lib" "${OUT_ROOT}/bin"
cp -a "${PDIUM_ROOT}/public/." "${OUT_ROOT}/include/pdfium/public/"

find_art() {
  local name="$1"
  find "${BUILD_DIR}" -type f -name "${name}" 2>/dev/null | head -n 1
}

LIB="$(find_art 'libpdfium.a' || true)"
if [[ -z "${LIB}" ]]; then
  LIB="$(find_art 'pdfium.lib' || true)"
fi
if [[ -n "${LIB}" ]]; then
  cp -a "${LIB}" "${OUT_ROOT}/lib/"
  echo "Staged lib: ${LIB}"
else
  echo "WARNING: no pdfium library found under ${BUILD_DIR}" >&2
fi

for name in libpdfium.so libpdfium.dylib pdfium.dll; do
  BIN="$(find_art "${name}" || true)"
  if [[ -n "${BIN}" ]]; then
    cp -a "${BIN}" "${OUT_ROOT}/bin/"
    echo "Staged bin: ${BIN}"
  fi
done

echo "Done. Output root: ${OUT_ROOT}"
