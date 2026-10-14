#!/bin/sh
# The version an APK reports is the version in app/AndroidManifest.xml. Nothing else.
#
#   sh tools/check-version.sh [apk]
#
# The first 1.9 release shipped an APK whose own manifest said versionCode 9 / versionName 1.8.
# build.sh passed --version-code 10 --version-name 1.9 to aapt2 link, aapt2 does not override a
# manifest that declares both, and the flags were discarded in silence - so the release notes
# described a binary that identified itself as the previous version, and every release from 1.0 to
# 1.8 had been correct because those releases bumped the manifest. Nothing looked at the artifact.
# This reads the version back out of the built APK, where it cannot be aspirational.
#
# Default APK: out/textcrush-release.apk if it exists, else out/textcrush.apk.
set -eu
export MSYS_NO_PATHCONV=1

ROOT=$(cd "$(dirname "$0")/.." && pwd)
MANIFEST="$ROOT/app/AndroidManifest.xml"
BT="$ROOT/toolchain/sdk/build-tools/34.0.0"

APK=${1:-}
if [ -z "$APK" ]; then
    if [ -f "$ROOT/out/textcrush-release.apk" ]; then
        APK="$ROOT/out/textcrush-release.apk"
    else
        APK="$ROOT/out/textcrush.apk"
    fi
fi

[ -f "$APK" ] || { echo "no APK at $APK - build it first: sh build.sh"; exit 1; }
[ -x "$BT/aapt2.exe" ] || { echo "missing build-tools - run: sh tools/bootstrap.sh"; exit 1; }

WANT_CODE=$(sed -n 's/.*android:versionCode="\([^"]*\)".*/\1/p' "$MANIFEST")
WANT_NAME=$(sed -n 's/.*android:versionName="\([^"]*\)".*/\1/p' "$MANIFEST")

[ -n "$WANT_CODE" ] || { echo "$MANIFEST declares no versionCode"; exit 1; }
[ -n "$WANT_NAME" ] || { echo "$MANIFEST declares no versionName"; exit 1; }

echo "app/AndroidManifest.xml: versionCode $WANT_CODE, versionName $WANT_NAME"

# One version truth. A version flag passed to aapt2 is not an override - it is ignored when the
# manifest declares both - so a second source of the version is how 1.9 shipped as 1.8. Matched as
# an argument (a line of its own inside the aapt2 link command), not as a mention in a comment.
if grep -qE '^[[:space:]]*--version-(code|name)' "$ROOT/build.sh"; then
    echo "build.sh still passes a --version flag to aapt2; it would be ignored, and a reader would"
    echo "believe it. The manifest is the one version truth."
    exit 1
fi

BADGING=$("$BT/aapt2.exe" dump badging "$(cygpath -m "$APK")")
GOT_CODE=$(printf '%s\n' "$BADGING" | sed -n "s/^package:.*versionCode='\([^']*\)'.*/\1/p")
GOT_NAME=$(printf '%s\n' "$BADGING" | sed -n "s/^package:.*versionName='\([^']*\)'.*/\1/p")

echo "the built APK reports:   versionCode $GOT_CODE, versionName $GOT_NAME"

if [ "$GOT_CODE" != "$WANT_CODE" ] || [ "$GOT_NAME" != "$WANT_NAME" ]; then
    echo
    echo "the built APK does not carry the version the manifest declares"
    exit 1
fi

echo "the APK carries the version in the manifest"
