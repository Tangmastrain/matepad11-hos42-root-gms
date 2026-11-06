#!/usr/bin/env bash
# Build debloat_stub3 Magisk module zip (run on PC, requires python 3).
# Usage: ./build.sh   -> writes debloat_stub3.zip next to this script.
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
OUT="$DIR/debloat_stub3.zip"

# Module tree: APK paths are stubbed by a directory containing a ".replace"
# marker file. NOTE: Magisk magic mount ignores EMPTY directories without
# ".replace" -- this is the #1 pitfall of this approach.
mkdir -p "$DIR/system/app/HwNearby" \
         "$DIR/system/app/HwAirlink" \
         "$DIR/system/app/iConnect" \
         "$DIR/system/priv-app/HiAction" \
         "$DIR/system/system_ext/app/QCC"
touch "$DIR/system/app/HwNearby/.replace" \
      "$DIR/system/app/HwAirlink/.replace" \
      "$DIR/system/app/iConnect/.replace" \
      "$DIR/system/priv-app/HiAction/.replace" \
      "$DIR/system/system_ext/app/QCC/.replace"

python - "$DIR" "$OUT" <<'PY'
import os, sys, zipfile
src, out = sys.argv[1], sys.argv[2]
if os.path.exists(out):
    os.remove(out)
with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
    for root, dirs, files in os.walk(src):
        if os.path.abspath(root) == os.path.abspath(src):
            continue  # module.prop is added explicitly first
        for f in dirs + files:
            p = os.path.join(root, f)
            z.write(p, os.path.relpath(p, src).replace("\\", "/"))
    z.write(os.path.join(src, "module.prop"), "module.prop")
print("built:", out)
PY

echo "Install with:"
echo "  adb push $OUT /data/local/tmp/debloat_stub3.zip"
echo "  adb shell 'su -c \"magisk --install-module /data/local/tmp/debloat_stub3.zip\"'"
