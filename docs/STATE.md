# State

Where this repository is right now: what the last change was, what the release is, what is checked,
what is next, and what is waiting on Kevin. The README says what the app is; this says where it
stands.

## Now (2026-10-15)

- Branch `main`. The commit before this note is `8cb327a` — "tools: check the APK's version and the
  vendored game, from the artifact".
- **Both checks were re-run on 2026-10-15, from the existing artifact, with no build.** `sh
  tools/check-version.sh` → `app/AndroidManifest.xml: versionCode 10, versionName 1.9`, `the built APK
  reports: versionCode 10, versionName 1.9`, `the APK carries the version in the manifest`, exit 0;
  `sh tools/check-game.sh` → `files: 75 vendored, 75 upstream`, `the vendored game matches upstream at
  b8d04bc0`, exit 0. Both are green, and neither needed an emulator.
- The APK the version check read is `out/textcrush-release.apk`, 210,269 bytes, sha256 `b12ae94c…` —
  the same digest the published release asset reports, read again today.
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

**2026-10-15: `docs/STATE.md` and the README's description of it, nothing else.** Twice in one day:
first the push record was wrong in the direction that matters — it said nothing had been pushed when the
branch had been pushed the day before — so it now carries the reflog line, the `ls-remote` answer and
the release's own digest; then Kevin's call ("push textcrush-android and textcrush-ios; keep tc held")
was recorded, which makes this a commit-and-push repository and makes the 2026-10-14 push something he
has now confirmed he wants. Both checks were re-run and are still green; no build was run.

## Next

1. Nothing is pending in this repository's code.
2. **Back up the signing identity.** `tools/release.keystore` and `tools/release-credentials.txt` are
   git-ignored and exist only on this machine. Losing them means never being able to update an
   installed copy of the app. Copy both somewhere off this machine.
3. The `.gitattributes` decision below, if the digests should be reproducible from a fresh clone.
4. A newer upstream game is picked up by re-vendoring `game/` and updating the commit in
   `game/UPSTREAM` together, then trusting `tools/check-game.sh` to say whether it was done right.
   No re-vendoring is due: no commit in `tc` after `b8d04bc0` touches `source/` (`git -C ../tc diff
   --stat b8d04bc0..HEAD -- source/` is empty as of 2026-10-15), so the pin names an older commit
   but the copy is content-current.
5. **Nothing here is waiting on a decision.** Kevin's call of 2026-10-15 makes this a commit-and-push
   repository (see Push status), so each turn ends with the branch level with `origin/main`. The
   signing-identity backup above needs no decision and should happen first.

## Push status and Kevin's decision (2026-10-15)

**The branch is level with the remote: 0 ahead, 0 behind.** `git status -sb` prints
`## main...origin/main` with no `[ahead]`, and the remote agrees — see the push record below. Not the
2 ahead the 2026-10-14 note claimed: those two commits went out on 2026-10-14 13:52:15 -0700, and this
note's own commit went out with this turn's push.

**The push happened at 2026-10-14 13:52:15 -0700**, an hour and twenty-three minutes after the two
commits were written and after the earlier version of this note said nothing had been pushed:

```
$ git reflog show origin/main
10117f0 refs/remotes/origin/main@{2026-10-14 13:52:15 -0700}: update by push

$ git ls-remote origin
10117f0b5330cdb34202ed4a7594225c4da864ab        HEAD
10117f0b5330cdb34202ed4a7594225c4da864ab        refs/heads/main

$ gh repo view kevinelong/textcrush-android --json visibility,pushedAt --template '{{.visibility}} pushedAt={{.pushedAt}}'
PUBLIC pushedAt=2026-10-14T20:52:15Z
```

`ls-remote` asks the remote rather than a local tracking ref, so `refs/heads/main` at `10117f0` is the
published state of the public repository and not a stale local ref.

**What that push published, and what it did not.** There is no `.github` directory in this repository,
so no workflow ran on it — `gh run list` returns nothing. A branch push does not move tags, and the
tags and the release are untouched (fields read out of the JSON, one per line):

```
$ git ls-remote --tags origin          (last line)
6f14000a11fca0012cd0e06d5ab713a98b4da471        v1.9

$ gh release view v1.9 --repo kevinelong/textcrush-android --json isDraft,publishedAt,assets
isDraft              false
publishedAt          2026-10-14T17:10:22Z
assets[0].name       textcrush-release.apk
assets[0].size       210269
assets[0].digest     sha256:b12ae94c1b53ab72a6ac897d5bf4f001c98e31fe183ed7ab7b6740c72e8b4a87
```

So the push published **the branch's commits only** — `app/`, `game/`, `tools/` and `docs/` sources in
a repository that was already public. It did not touch `v1.9` (still Latest, published with Kevin's
approval at 2026-10-14T17:10:22Z, three hours before this push), did not create a tag, and published
no new APK. The published asset's digest still equals the APK in this checkout to the byte.

**Kevin's decision, received this turn, verbatim: "push textcrush-android and textcrush-ios; keep tc
held."** This repository is a **commit-and-push** repository: each turn commits its work and pushes it,
and ends level with `origin/main`. That is his standing instruction, not a question waiting on him — and
it settles the 2026-10-14 push above too, which was this repository being used the way he now says he
wants it used. `textcrush` (tc) is the exception, held locally because a push there deploys the live
site.

**This turn's push**, confirmed from the remote rather than from a local ref:

```
$ git push origin main
   10117f0..c880869  main -> main

$ git ls-remote origin refs/heads/main
c88086922cd1b67cc1353a67d14e52e7c64f782d        refs/heads/main
```

`c88086922cd1b67cc1353a67d14e52e7c64f782d` was this branch's local head when it was pushed, so the
branch came out 0 ahead / 0 behind. The commit carrying the note you are reading was pushed the same
way, straight after it was written, so this file is on the remote too.

**What this repository's pushes publish, and what they cannot publish:** the branch's commits and
nothing else. No workflow reacts to a push — there is no `.github` directory — a tag moves only when it
is pushed explicitly, and publishing a release is a separate act from pushing a branch. No push here has
ever created an APK, and none can.

## Open decisions (Kevin's)

Still his after the push call of 2026-10-15: that call was only about where the commits go, not about
any of these.

- **`.gitattributes` with `* text=auto eol=lf` — and this is the repository that needs it.**
  A `.gitattributes` does exist here, committed as `7c5ddd3`, but it carries one rule that is not this
  one — `game/** linguist-vendored` — so the end-of-line policy is still unset. `core.autocrlf=true`
  means a fresh clone or a plain `git checkout` materialises text files as CRLF, and the same commit
  then builds to `8b3ae0d9…` instead of the published `b12ae94c…`: a functionally identical APK (same
  version stamp, same code) whose only differences are the line endings of `Board.js` and of the
  compiled manifest, with `git status` still reporting clean. So the digests in the README and in the
  release notes cannot be reproduced from a fresh clone today. One line in `.gitattributes` fixes it;
  it is a repo-wide end-of-line policy, so it is not mine to set, and it is not set. If it is added,
  add it to `tc` and `textcrush-ios` in the same session and re-verify these digests.
- **No CI in this repository.** A real job needs the Android SDK and an emulator; only the static half
  of `tools/check-version.sh` (that `build.sh` passes no `--version-*` flag) runs without them. Left
  out deliberately rather than added as a job that verifies almost nothing. Checked 2026-10-15: there
  is no `.github` directory here at all, so this is still the case.
