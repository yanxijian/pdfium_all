#!/usr/bin/env bash
# Fetch V8 pinned to pdfium/DEPS v8_revision into .tools/v8-workspace.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEPS="$ROOT/pdfium/DEPS"
REV="${1:-}"
if [[ -z "$REV" ]]; then
  REV="$(python3 - <<'PY' "$DEPS"
import re,sys
text=open(sys.argv[1],encoding="utf-8").read()
m=re.search(r"'v8_revision'\s*:\s*'([0-9a-fA-F]+)'", text)
assert m, "v8_revision not found"
print(m.group(1))
PY
)"
fi
echo "V8 revision: $REV"

DT="$ROOT/.tools/depot_tools"
if [[ ! -x "$DT/gclient" && ! -f "$DT/gclient" ]]; then
  mkdir -p "$ROOT/.tools"
  git clone --depth 1 https://chromium.googlesource.com/chromium/tools/depot_tools.git "$DT"
fi
export PATH="$DT:$PATH"

WS="$ROOT/.tools/v8-workspace"
mkdir -p "$WS"
cd "$WS"
cat > .gclient <<EOF
solutions = [
  {
    "name": "v8",
    "url": "https://chromium.googlesource.com/v8/v8.git@$REV",
    "deps_file": "DEPS",
    "managed": False,
    "custom_deps": {},
  },
]
EOF

gclient sync --with_branch_heads --revision "v8@$REV"
echo "$REV" > "$WS/V8_REVISION.txt"
echo "Fetched V8 into $WS/v8"
echo "Next: ./scripts/build_v8.sh"
