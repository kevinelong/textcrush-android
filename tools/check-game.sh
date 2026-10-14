#!/bin/sh
# The game under game/ is the game in kevinelong/textcrush, byte for byte.
#
#   sh tools/check-game.sh
#   TC=/path/to/textcrush sh tools/check-game.sh
#
# The wrapper ships a vendored copy of the web game, and a vendored copy goes stale in silence: the
# fix lands upstream, this checkout keeps serving the old one, and nobody notices until the app
# behaves differently from the browser. game/UPSTREAM names the commit the copy came from, so this
# compares against that commit - not against whatever the tc working tree happens to hold, which may
# be a work in progress.
#
# A newer upstream build is picked up by refreshing game/ and the commit in game/UPSTREAM together:
#
#   rm -rf game/source && cp -r "$TC/source" game/source   # then update game/UPSTREAM
set -eu
export MSYS_NO_PATHCONV=1

ROOT=$(cd "$(dirname "$0")/.." && pwd)
TC=${TC:-$(cd "$ROOT/.." && pwd)/tc}
# git -C wants C:/..., not /c/... (the POSIX form is not a path its Windows build can change to).
TC=$(cygpath -m "$TC")

COMMIT=$(sed -n 's/^commit: *//p' "$ROOT/game/UPSTREAM")
[ -n "$COMMIT" ] || { echo "game/UPSTREAM names no commit"; exit 1; }

[ -d "$TC/.git" ] || { echo "no textcrush checkout at $TC - set TC=/path/to/textcrush"; exit 1; }
git -C "$TC" cat-file -e "$COMMIT^{commit}" 2>/dev/null \
    || { echo "$TC has no commit $COMMIT - fetch the upstream repository"; exit 1; }

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# The committed bytes, read one blob at a time. Not `git archive`: that exports through the checkout
# filters, and with core.autocrlf true it rewrites the line endings of the whole tree, which is not
# drift. cat-file returns what is in the repository.
git -C "$TC" ls-tree -r --name-only "$COMMIT" source > "$TMP/upstream-files"
mkdir -p "$TMP/upstream"
while IFS= read -r file; do
    # upstream keeps the game in source/{game,web}; the vendored copy is game/source/{game,web}, so the
    # leading source/ comes off and the two trees line up
    case $file in
        source/*) target=${file#source/} ;;
        *) continue ;;
    esac
    mkdir -p "$TMP/upstream/$(dirname "$target")"
    git -C "$TC" cat-file blob "$COMMIT:$file" > "$TMP/upstream/$target"
done < "$TMP/upstream-files"

# Line endings are compared away: the working copy on Windows is not a byte-for-byte mirror of the
# committed bytes, and which side has CR is an artifact of how the copy was made, not a difference in
# the game. Everything else here is compared exactly.
strip_cr() {
    from=$1
    to=$2
    mkdir -p "$to"
    (cd "$from" && find . -type f) | while IFS= read -r file; do
        mkdir -p "$to/$(dirname "$file")"
        tr -d '\r' < "$from/$file" > "$to/$file"
    done
}

strip_cr "$ROOT/game/source" "$TMP/vendored"
strip_cr "$TMP/upstream" "$TMP/upstream-plain"

vendored_count=$(find "$TMP/vendored" -type f | wc -l | tr -d ' ')
upstream_count=$(find "$TMP/upstream-plain" -type f | wc -l | tr -d ' ')

echo "vendored: game/source"
echo "upstream: $TC source/ at $COMMIT"
echo "files:    $vendored_count vendored, $upstream_count upstream"

if diff -r "$TMP/vendored" "$TMP/upstream-plain"; then
    echo "the vendored game matches upstream at $COMMIT"
else
    echo
    echo "the vendored game has drifted from upstream at $COMMIT, or is missing files it has (the"
    echo "differences are listed above). Re-vendor it, or say in game/UPSTREAM which commit it came"
    echo "from."
    exit 1
fi
