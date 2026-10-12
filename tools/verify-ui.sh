#!/bin/sh
# Install the APK on a running emulator or device, play the game, and prove it behaves.
#
#   sh tools/verify-ui.sh [apk] [serial]
#
# Defaults: out/textcrush-release.apk if it exists, else out/textcrush.apk; the only attached device.
#
# The board is square and centred, so where the tiles are follows from the display size - this
# script derives the tap targets instead of hardcoding them, and reports what it measured:
#   - the board paints (sampled pixel count, not an eyeball)
#   - a tap changes the score line and the board
#   - a cold restart paints the same board again
#   - no crash, and no permissions requested
set -eu
export MSYS_NO_PATHCONV=1

ROOT=$(cygpath -m "$(cd "$(dirname "$0")/.." && pwd)")
ADB="$ROOT/toolchain/sdk/platform-tools/adb.exe"
APP=com.kevin.textcrush
OUT="$ROOT/build/verify"

APK=${1:-}
if [ -z "$APK" ]; then
  if [ -f "$ROOT/out/textcrush-release.apk" ]; then APK="$ROOT/out/textcrush-release.apk"; else APK="$ROOT/out/textcrush.apk"; fi
fi
SERIAL=${2:-}
if [ -n "$SERIAL" ]; then ADBS="$ADB -s $SERIAL"; else ADBS="$ADB"; fi

# Screenshots must land somewhere the build does not wipe.
mkdir -p "$OUT"

echo "== device =="
SIZE=$($ADBS shell wm size | tr -d '\r' | sed -n 's/.*: \([0-9]*x[0-9]*\).*/\1/p')
W=${SIZE%x*}
H=${SIZE#*x}
echo "display $SIZE"
# Board geometry: the web view is a square of the display width, centred vertically. Inside it the
# game reserves width/9 for the score line and gives each of the 8 rows width/9.
STEP=$((W / 9))
TOP=$(( (H - W) / 2 + STEP ))
echo "tile step ${STEP}px, first row centre y=${TOP}"
TAP_X=$((2 * STEP + STEP / 2))
TAP_Y=$((TOP + 4 * STEP + STEP / 2))
echo "tap target: ${TAP_X},${TAP_Y}"

shoot() { $ADBS exec-out screencap -p > "$OUT/$1.png"; }

echo
echo "== install =="
$ADBS shell am force-stop $APP 2>/dev/null || true
$ADBS uninstall $APP >/dev/null 2>&1 || true
$ADBS install "$APK" | tail -1
$ADBS logcat -c

echo
echo "== cold start and deal-in =="
$ADBS shell am start -W -n $APP/.MainActivity | grep -E "LaunchState|Status"
sleep 4
shoot 01-board

echo
echo "== tap a tile =="
$ADBS shell input tap "$TAP_X" "$TAP_Y"
sleep 2
shoot 02-after-tap

echo
echo "== cold restart (same install, so the stored high score must survive) =="
$ADBS shell am force-stop $APP
sleep 1
$ADBS shell am start -W -n $APP/.MainActivity | grep -E "LaunchState"
sleep 4
shoot 03-relaunch

echo
echo "== measurements =="
python - "$OUT" <<'PY'
import os, sys
from PIL import Image, ImageChops

out = sys.argv[1]
NAMES = ["01-board.png", "02-after-tap.png", "03-relaunch.png"]

def load(name):
    image = Image.open(os.path.join(out, name)).convert("RGB")
    px = image.load()
    w, h = image.size
    # sample every 4th pixel: the board colour is 34,17,0, everything else is a tile or text
    drawn = sum(1 for y in range(0, h, 4) for x in range(0, w, 4) if px[x, y] != (34, 17, 0))
    return image, drawn, w, h

images = {}
for name in NAMES:
    image, drawn, w, h = load(name)
    images[name] = image
    print(f"{name}: {drawn} non-background samples of {(w // 4) * (h // 4)} ({100 * drawn / ((w // 4) * (h // 4)):.0f}%), {os.path.getsize(os.path.join(out, name))} bytes")

board = images["01-board.png"]
print("board vs after-tap differs:", ImageChops.difference(board, images["02-after-tap.png"]).getbbox() is not None)
print("board vs relaunch differs: ", ImageChops.difference(board, images["03-relaunch.png"]).getbbox() is not None)
PY

echo
echo "== permissions requested (expect a label, no permissions) =="
$ADBS shell dumpsys package $APP | grep -A4 "requested permissions" || echo "  none requested"
echo
echo "== crash log (expect nothing) =="
$ADBS logcat -d -s AndroidRuntime:E | grep -v "^---" | tail -3 || true
echo
echo "== screenshots =="
ls -l "$OUT"/*.png
