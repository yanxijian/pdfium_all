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

stage_sample() {
  local name="$1"
  local bin
  bin="$(find_art "${name}" || true)"
  if [[ -z "${bin}" ]]; then
    bin="$(find_art "${name}.exe" || true)"
  fi
  if [[ -z "${bin}" ]]; then
    return 0
  fi
  cp -a "${bin}" "${OUT_ROOT}/bin/"
  echo "Staged bin: ${bin}"
  local dir
  dir="$(dirname "${bin}")"
  for blob in snapshot_blob.bin icudtl.dat; do
    if [[ -f "${dir}/${blob}" ]]; then
      cp -a "${dir}/${blob}" "${OUT_ROOT}/bin/"
      echo "Staged bin: ${blob}"
    fi
  done
}

stage_sample simple_no_v8
stage_sample simple_with_v8

V8_ROOT="${PDFIUM_V8_ROOT:-${REPO_ROOT}/.tools/v8-out}"
if [[ -d "${V8_ROOT}/bin" ]]; then
  shopt -s nullglob
  for f in "${V8_ROOT}/bin"/*.{dll,so,dylib} "${V8_ROOT}/bin"/snapshot_blob.bin "${V8_ROOT}/bin"/icudtl.dat; do
    [[ -f "$f" ]] || continue
    cp -a "$f" "${OUT_ROOT}/bin/"
    echo "Staged V8 runtime: $(basename "$f")"
  done
fi
if [[ -d "${V8_ROOT}/lib" ]]; then
  for f in "${V8_ROOT}/lib"/*.{lib,a,dll.lib}; do
    [[ -f "$f" ]] || continue
    cp -a "$f" "${OUT_ROOT}/lib/"
    echo "Staged V8 lib: $(basename "$f")"
  done
fi

echo "Done. Output root: ${OUT_ROOT}"
