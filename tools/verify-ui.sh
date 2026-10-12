#!/bin/sh
# Install the APK on a running emulator or device, play the game, and prove it behaves.
#
#   sh tools/verify-ui.sh [apk] [serial]
#
# Defaults: out/textcrush-release.apk if it exists, else out/textcrush.apk; the only attached device.
#
# The app draws its score line natively now (the page is loaded with hud=off), so:
#   - the board is the whole play square, eight rows of `width / 8` rather than nine of `width / 9`;
#   - the square is centred on the display, and the header sits above it, out of the web view's reach;
#   - a tap in the header cannot reach the game at all, and a tap on the board must move both the board
#     and the header's score.
# This script derives those positions from the display size instead of hardcoding them, and reports
# what it measured rather than what it hoped.
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

# The web view is a square of the display width, centred; the board fills it, eight rows.
STEP=$((W / 8))
TOP=$(( (H - W) / 2 ))
TAP_X=$((2 * STEP + STEP / 2))
TAP_Y=$((TOP + 4 * STEP + STEP / 2))
HEADER_Y=$((W / 40))                 # inside the native header, above the square
echo "tile step ${STEP}px, board from y=${TOP}; board tap ${TAP_X},${TAP_Y}; header tap ${TAP_X},${HEADER_Y}"

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

# A fresh install shows the rules once, and the tap that closes them is not a move: dismiss them
# before taking the reference shot, or the first board tap below would only dismiss them again.
$ADBS shell input tap "$TAP_X" "$TAP_Y"
sleep 2
shoot 01-board

echo
echo "== the header is native text, and a screen reader can read it =="
$ADBS shell uiautomator dump /sdcard/verify-ui.xml >/dev/null
$ADBS pull /sdcard/verify-ui.xml "$OUT/ui.xml" >/dev/null
python - "$OUT/ui.xml" <<'PY'
import re, sys
xml = open(sys.argv[1], encoding="utf-8", errors="ignore").read()
texts = [t for t in re.findall(r'text="([^"]*)"', xml) if t.strip()]
print("widget text on screen:", texts[:8])
print("grid cells exposed to accessibility:", len(re.findall(r'gridcell', xml)))
PY

echo
echo "== taps in the header must not reach the game =="
for i in 1 2 3; do $ADBS shell input tap "$TAP_X" "$HEADER_Y"; sleep 0.4; done
sleep 1
shoot 02-header-taps

echo
echo "== a board tap must move the board and the header =="
$ADBS shell input tap "$TAP_X" "$TAP_Y"
sleep 2
shoot 03-after-tap

echo
echo "== cold restart =="
$ADBS shell am force-stop $APP
sleep 1
$ADBS shell am start -W -n $APP/.MainActivity | grep -E "LaunchState"
sleep 4
shoot 04-relaunch

echo
echo "== measurements =="
python - "$OUT" "$STEP" "$TOP" "$W" <<'PY'
import os, sys
from PIL import Image, ImageChops

out = sys.argv[1]
step, top, width = int(sys.argv[2]), int(sys.argv[3]), int(sys.argv[4])
NAMES = ["01-board.png", "02-header-taps.png", "03-after-tap.png", "04-relaunch.png"]

def load(name):
    image = Image.open(os.path.join(out, name)).convert("RGB")
    px = image.load()
    w, h = image.size
    drawn = sum(1 for y in range(0, h, 4) for x in range(0, w, 4) if px[x, y] != (34, 17, 0))
    return image, drawn, w, h

images, drawn = {}, {}
for name in NAMES:
    image, count, w, h = load(name)
    images[name], drawn[name] = image, count
    print(f"{name}: {count} non-background samples, {os.path.getsize(os.path.join(out, name))} bytes")

def board(name):
    """just the play square, so the header's own text cannot mask a board change"""
    return images[name].crop((0, top, width, top + width))

def header(name):
    return images[name].crop((0, 0, width, top))

print("board unchanged by 3 header taps:", ImageChops.difference(board("01-board.png"), board("02-header-taps.png")).getbbox() is None)
print("board changed by a board tap:   ", ImageChops.difference(board("02-header-taps.png"), board("03-after-tap.png")).getbbox() is not None)
print("header changed by a board tap:  ", ImageChops.difference(header("02-header-taps.png"), header("03-after-tap.png")).getbbox() is not None)
print("board differs after relaunch:   ", ImageChops.difference(board("01-board.png"), board("04-relaunch.png")).getbbox() is not None)
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
