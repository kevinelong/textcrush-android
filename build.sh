#!/bin/sh
# Assemble the Text Crush APK with the Android SDK tools directly.
# No Gradle, no Android Studio, no AndroidX, no third-party dependencies.
#
#   sh build.sh                 -> out/textcrush.apk          debug-signed, for the dev loop
#   SIGN=release sh build.sh    -> out/textcrush-release.apk  signed with the project's release key
#
# Run with Git's shell:  sh build.sh
set -eu

ROOT=$(cd "$(dirname "$0")" && pwd)
WIN=$(cygpath -m "$ROOT")          # C:/... form for the native Windows tools (javac, aapt2, d8, ...)
TB="$ROOT/toolchain"
BT="$TB/sdk/build-tools/34.0.0"
AAR="$WIN/toolchain/sdk/platforms/android-34/android.jar"

JAVA_HOME=$(cygpath -w "$TB/jdk")
export JAVA_HOME
PATH="$TB/jdk/bin:$PATH"
export PATH

APP="$ROOT/app"
B="$ROOT/build"
OUT="$ROOT/out"
MODE=${SIGN:-debug}

[ -x "$TB/jdk/bin/javac.exe" ] || { echo "missing JDK - run: sh tools/bootstrap.sh"; exit 1; }
[ -f "$BT/aapt2.exe" ]        || { echo "missing build-tools - run: sh tools/bootstrap.sh"; exit 1; }

rm -rf "$B"
mkdir -p "$B/gen" "$B/classes" "$B/dex" "$B/assets" "$OUT"

echo "== launcher icons =="
[ -f "$APP/res/mipmap-xxhdpi/ic_launcher.png" ] || python "$WIN/tools/make_icons.py"

echo "== stage the web build =="
# game/ is the vendored upstream source (see UPSTREAM). Only what the page loads at runtime is
# staged, so the TypeScript sources and the IDE files stay out of the APK.
mkdir -p "$B/assets/www"
cp -r "$ROOT/game/source/web"  "$B/assets/www/web"
cp -r "$ROOT/game/source/game" "$B/assets/www/game"
find "$B/assets" -name '*.ts' -delete
find "$B/assets" -name '*.iml' -delete
# The web build can also be installed in a browser, and that is what the manifest, the icon set and
# the service worker are for. Inside the APK they are dead weight: the assets are already local, the
# launcher icon is the native one, and a worker would only fail to register (it is staged out).
rm -rf "$B/assets/www/web/icons" "$B/assets/www/web/manifest.webmanifest" "$B/assets/www/web/sw.js"
[ -f "$B/assets/www/web/index.html" ] || { echo "game/ is not vendored - see UPSTREAM"; exit 1; }
find "$B/assets" -type f | wc -l | tr -d ' ' | sed 's/^/staged files: /'

echo "== aapt2 compile =="
"$BT/aapt2.exe" compile --dir "$WIN/app/res" -o "$WIN/build/res.zip"

DEBUG_FLAG=""
if [ "$MODE" = debug ]; then
  # --debug-mode sets android:debuggable in the built manifest. It is what lets the dev loop attach
  # WebView devtools to the running app; the release APK must not carry it, and the check below
  # proves it does not.
  DEBUG_FLAG="--debug-mode"
fi

echo "== aapt2 link =="
"$BT/aapt2.exe" link \
  -o "$WIN/build/base.apk" \
  -I "$AAR" \
  --manifest "$WIN/app/AndroidManifest.xml" \
  -A "$WIN/build/assets" \
  --java "$WIN/build/gen" \
  --min-sdk-version 21 \
  --target-sdk-version 34 \
  --version-code 8 \
  --version-name 1.7 \
  $DEBUG_FLAG \
  "$WIN/build/res.zip"

echo "== javac =="
: > "$B/sources.txt"
for f in "$APP"/java/com/kevin/textcrush/*.java "$B"/gen/com/kevin/textcrush/*.java; do
  [ -f "$f" ] || continue
  cygpath -m "$f" >> "$B/sources.txt"
done
wc -l < "$B/sources.txt" | tr -d ' ' | sed 's/^/source files: /'
javac -source 8 -target 8 \
  -bootclasspath "$AAR" -classpath "$AAR" \
  -encoding UTF-8 -Xlint:-options \
  -d "$WIN/build/classes" \
  @"$WIN/build/sources.txt"

echo "== d8 =="
"$TB/jdk/bin/jar.exe" cf "$WIN/build/classes.jar" -C "$WIN/build/classes" .
"$BT/d8.bat" --lib "$AAR" --min-api 21 --output "$WIN/build/dex" "$WIN/build/classes.jar"
ls -l "$B/dex"

echo "== package =="
python "$WIN/tools/add_dex.py" "$WIN/build/base.apk" "$WIN/build/unsigned.apk" "$WIN/build/dex/classes.dex"
"$BT/zipalign.exe" -p -f 4 "$WIN/build/unsigned.apk" "$WIN/build/aligned.apk"

echo "== sign =="
if [ "$MODE" = release ]; then
  KS="$ROOT/tools/release.keystore"
  CRED="$ROOT/tools/release-credentials.txt"
  [ -f "$KS" ]   || { echo "no release keystore - run: sh tools/make-release-key.sh"; exit 1; }
  [ -f "$CRED" ] || { echo "no $CRED - run: sh tools/make-release-key.sh"; exit 1; }
  STOREPASS=$(sed -n 's/^storepass=//p' "$CRED")
  KEYALIAS=$(sed -n 's/^alias=//p' "$CRED")
  APK=textcrush-release.apk
  echo "signing with the release key (alias $KEYALIAS)"
else
  KS="$ROOT/tools/debug.keystore"
  STOREPASS=android
  KEYALIAS=androiddebugkey
  APK=textcrush.apk
  if [ ! -f "$KS" ]; then
    "$TB/jdk/bin/keytool.exe" -genkeypair \
      -keystore "$(cygpath -w "$KS")" \
      -storepass android -keypass android \
      -alias androiddebugkey -keyalg RSA -keysize 2048 -validity 10000 \
      -dname "CN=Android Debug,O=Android,C=US"
  fi
fi

"$BT/apksigner.bat" sign \
  --ks "$(cygpath -w "$KS")" \
  --ks-pass "pass:$STOREPASS" --key-pass "pass:$STOREPASS" \
  --ks-key-alias "$KEYALIAS" \
  --v1-signing-enabled true --v2-signing-enabled true --v3-signing-enabled true \
  --v4-signing-enabled false \
  --out "$WIN/out/$APK" \
  "$WIN/build/aligned.apk"

echo "== verify =="
"$BT/apksigner.bat" verify --print-certs "$WIN/out/$APK" | head -4
echo "-- debuggable / testOnly in the manifest (both must be absent from a release build) --"
"$BT/aapt2.exe" dump xmltree --file AndroidManifest.xml "$WIN/out/$APK" | grep -iE "debuggable|testOnly" || echo "  neither present"
echo "-- permissions requested --"
"$BT/aapt2.exe" dump badging "$WIN/out/$APK" | grep -E "^uses-permission" || echo "  none"
"$BT/aapt2.exe" dump badging "$WIN/out/$APK" | grep -E "^package|^application-label:|^sdkVersion|^targetSdkVersion" | head -5
echo "-- size and digest --"
ls -l "$OUT/$APK" | awk '{print $5" bytes"}'
sha256sum "$OUT/$APK"
echo "== built: $WIN/out/$APK =="
