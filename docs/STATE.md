# State

Where this repository is right now: what the last change was, what the release is, what is checked,
what is next, and what is waiting on Kevin. The README says what the app is; this says where it
stands.

## Now (2026-10-14)

- Branch `main`. The commit before this note is `8cb327a` — "tools: check the APK's version and the
  vendored game, from the artifact".
- **Published release:** `v1.9`, no longer a draft, tag `v1.9` on `6f14000`. Its asset
  `textcrush-release.apk` is 210,269 bytes, sha256
  `b12ae94c1b53ab72a6ac897d5bf4f001c98e31fe183ed7ab7b6740c72e8b4a87`, and `aapt2 dump badging` on the
  downloaded file reports `versionCode='10' versionName='1.9'` with no permissions. `/releases/latest`
  resolves to it; `v1.8` is unchanged (asset `a8c47cc3…`) and no longer carries the Latest marker.
- **The version is checked from the artifact.** `sh tools/check-version.sh` reads the version out of
  `app/AndroidManifest.xml` and back out of the built APK's own badging, and fails if they disagree;
  `sh build.sh` runs it at the end of every build. This exists because the first 1.9 release shipped
  a binary that called itself 1.8 while the release notes said otherwise, and nothing looked at the
  artifact.
- **The vendored game is checked.** `sh tools/check-game.sh` → 75 files match `kevinelong/textcrush`
  at `b8d04bc0`, the commit named in `game/UPSTREAM`.
- **Both digests reproduce from this checkout**, from the committed bytes:
  `SIGN=release sh build.sh` → `b12ae94c…` and `sh build.sh` → `e431f3c1…`.

## What changed last

`8cb327a`: `tools/check-version.sh` and `tools/check-game.sh`, wired into `build.sh`, plus the
README's account of where the version identity lives and how to check the vendored game.

## Next

1. Nothing is pending in this repository's code.
2. **Back up the signing identity.** `tools/release.keystore` and `tools/release-credentials.txt` are
   git-ignored and exist only on this machine. Losing them means never being able to update an
   installed copy of the app. Copy both somewhere off this machine.
3. The `.gitattributes` decision below, if the digests should be reproducible from a fresh clone.
4. A newer upstream game is picked up by re-vendoring `game/` and updating the commit in
   `game/UPSTREAM` together, then trusting `tools/check-game.sh` to say whether it was done right.

## Awaiting Kevin's approval to push

**Nothing here has been pushed.** As of this note the branch is **2 commits ahead of `origin/main`**:

```
git log --oneline origin/main..HEAD

8cb327a  tools: check the APK's version and the vendored game, from the artifact
         (this note's own commit, on top of it)
```

Neither commit changes the published release: `v1.9` and its asset were published earlier with
Kevin's approval and are untouched by these two.

## Open decisions (Kevin's)

- **`.gitattributes` with `* text=auto eol=lf` — and this is the repository that needs it.**
  `core.autocrlf=true` means a fresh clone or a plain `git checkout` materialises text files as CRLF,
  and the same commit then builds to `8b3ae0d9…` instead of the published `b12ae94c…`: a functionally
  identical APK (same version stamp, same code) whose only differences are the line endings of
  `Board.js` and of the compiled manifest, with `git status` still reporting clean. So the digests in
  the README and in the release notes cannot be reproduced from a fresh clone today. One line in
  `.gitattributes` fixes it; it is a repo-wide end-of-line policy, so it is not mine to set. If it is
  added, add it to `tc` and `textcrush-ios` in the same session and re-verify these digests.
- **No CI in this repository.** A real job needs the Android SDK and an emulator; only the static half
  of `tools/check-version.sh` (that `build.sh` passes no `--version-*` flag) runs without them. Left
  out deliberately rather than added as a job that verifies almost nothing.
