#!/usr/bin/env bash
# Build shared (component) V8 and stamp into .tools/v8-out for CMake.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WS="$ROOT/.tools/v8-workspace"
V8="$WS/v8"
CONFIG="${1:-x64.release}"
if [[ ! -f "$V8/include/v8.h" ]]; then
  "$ROOT/scripts/fetch_v8.sh"
fi

OUT="$V8/out.gn/$CONFIG"
mkdir -p "$OUT"
cat > "$OUT/args.gn" <<'EOF'
is_debug = false
target_cpu = "x64"
is_component_build = true
is_clang = true
clang_use_chrome_plugins = false
use_lld = true
v8_monolithic = false
v8_use_external_startup_data = false
v8_enable_webassembly = false
v8_enable_temporal_support = false
v8_imminent_deprecation_warnings = false
v8_enable_sandbox = false
v8_enable_i18n_support = false
use_allocator_shim = false
use_partition_alloc_as_malloc = false
treat_warnings_as_errors = false
v8_generate_external_defines_header = true
use_custom_libcxx = true
EOF

DT="$ROOT/.tools/depot_tools"
export PATH="$DT:$PATH"
cd "$V8"
gn gen "$OUT"
ninja -C "$OUT" v8 v8_libbase v8_libplatform

STAMP="$ROOT/.tools/v8-out"
rm -rf "$STAMP/lib" "$STAMP/bin"
mkdir -p "$STAMP/lib" "$STAMP/bin"
rm -f "$STAMP/v8"
ln -sfn "$V8" "$STAMP/v8"

# Shared libraries + import/link names.
shopt -s nullglob
for f in \
  "$OUT"/libv8.so "$OUT"/libv8.dylib "$OUT"/v8.dll \
  "$OUT"/libv8_libbase.so "$OUT"/libv8_libbase.dylib "$OUT"/v8_libbase.dll \
  "$OUT"/libv8_libplatform.so "$OUT"/libv8_libplatform.dylib "$OUT"/v8_libplatform.dll \
  "$OUT"/libc++.so "$OUT"/libc++.dylib "$OUT"/libc++.dll
do
  [[ -f "$f" ]] && cp -f "$f" "$STAMP/bin/"
done
for f in \
  "$OUT"/v8.dll.lib "$OUT"/v8_libbase.dll.lib "$OUT"/v8_libplatform.dll.lib \
  "$OUT"/libc++.dll.lib \
  "$OUT"/libv8.so "$OUT"/libv8.dylib \
  "$OUT"/libv8_libbase.so "$OUT"/libv8_libplatform.so
do
  [[ -f "$f" ]] || continue
  case "$f" in
    *.dll) cp -f "$f" "$STAMP/bin/" ;;
    *) cp -f "$f" "$STAMP/lib/" ;;
  esac
done
# Copy remaining out-root shared libs that may be transitive.
for f in "$OUT"/*.so "$OUT"/*.dylib "$OUT"/*.dll; do
  [[ -f "$f" ]] || continue
  base="$(basename "$f")"
  [[ -f "$STAMP/bin/$base" ]] || cp -f "$f" "$STAMP/bin/"
done

if [[ ! -f "$STAMP/bin/v8.dll" && ! -f "$STAMP/bin/libv8.so" && ! -f "$STAMP/bin/libv8.dylib" ]]; then
  # Recursive fallback
  found="$(find "$OUT" -name 'v8.dll' -o -name 'libv8.so' -o -name 'libv8.dylib' | head -n1 || true)"
  [[ -n "$found" ]] || { echo "shared V8 library not found" >&2; exit 1; }
  cp -f "$found" "$STAMP/bin/"
fi

mkdir -p "$STAMP/include"
LIBCXX_INC="$V8/third_party/libc++/src/include"
LIBCXX_CFG="$V8/buildtools/third_party/libc++"
LIBCXX_CFG_GEN="$OUT/gen/third_party/libc++/src/include"
rm -f "$STAMP/include/c++" "$STAMP/include/c++config" 2>/dev/null || true
rmdir "$STAMP/include/c++" "$STAMP/include/c++config" 2>/dev/null || true
[[ -d "$LIBCXX_INC" ]] && ln -sfn "$LIBCXX_INC" "$STAMP/include/c++"
if [[ -f "$LIBCXX_CFG_GEN/__config_site" ]]; then
  ln -sfn "$LIBCXX_CFG_GEN" "$STAMP/include/c++config"
elif [[ -f "$LIBCXX_CFG/__config_site" ]]; then
  mkdir -p "$STAMP/include/c++config"
  cp -f "$LIBCXX_CFG/__config_site" "$STAMP/include/c++config/__config_site"
else
  echo "libc++ __config_site not found" >&2
  exit 1
fi

for c in "$OUT/gen/include/v8-gn.h" "$OUT/gen/v8/include/v8-gn.h"; do
  if [[ -f "$c" ]]; then
    cp -f "$c" "$STAMP/include/v8-gn.h"
    cp -f "$c" "$V8/include/v8-gn.h"
    break
  fi
done

for blob in snapshot_blob.bin icudtl.dat; do
  if [[ -f "$OUT/$blob" ]]; then cp -f "$OUT/$blob" "$STAMP/bin/"; fi
done

echo "component" > "$STAMP/V8_SHARED.txt"
if [[ -f "$WS/V8_REVISION.txt" ]]; then
  cp -f "$WS/V8_REVISION.txt" "$STAMP/V8_REVISION.txt"
fi

export PDFIUM_V8_ROOT="$STAMP"
echo "Stamped shared V8 product tree: $STAMP"
echo "Next: ./scripts/build.sh --enable-v8"
