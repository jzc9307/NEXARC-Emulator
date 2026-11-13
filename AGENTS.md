# NEXARC project instructions

## Workspace

This folder is the canonical editable source and Git repository. Work here for all future NEXARC changes. In Jason's local workspace it lives at `Project/NEXARC/NEXARC`; the parent contains the one current `NEXARC.app`, `work` cache and `outputs` archives. `outputs/NEXARC` is a compatibility symlink, not another source copy. Do not create duplicate projects or versioned local app folders.

Read the user's current instructions first. Preserve imported games, saves, settings and controller profiles. Never reset user data for testing. Use isolated copies for runtime checks.

## Product standard

Keep the existing NEXARC branding, dark mint/lilac styling, aligned responsive layouts, readable text and compact desktop controls with press feedback. App-owned popups support outside-click and Escape dismissal. Handheld hardware skins remain distinct from optional stylized shells. Do not describe community artwork as official. Keep upstream engine credits and state tested capabilities honestly. Physical controllers and most console titles have not been validated.

## When the user says “push to GitHub”

Treat that phrase as a request to publish the next app release, including its version history, unless the user explicitly requests a code-only push. Ordinary Git pushes and commits do not automatically change the app version.

1. Inspect the current diff, `VERSION`, `BUILD_NUMBER`, Git status, origin, pending release state and remote branches/tags. If origin is missing, finish local preparation before requesting the intended repository URL. Do not create a public repository or change its visibility without the user's chosen destination/visibility.
2. Default to a patch increase: `0.3.0 → 0.3.1 → 0.3.2`. Use a minor/major increase or alpha/beta/rc only when requested or agreed. App versioning does not alter game saves or upstream core versions. If `.release/prepared.json` already names the current version, finish/retry it; do not bump twice for one request.
3. Add real user-facing notes to `CHANGELOG.md` under `[Unreleased]`. Run `python3 scripts/release.py prepare` (or the requested bump). It updates VERSION, BUILD_NUMBER, the app plist, main README’s **All versions** DMG table, `release-history.json` and `docs/RELEASES.md`; local/prepared versions are marked **Newest** without fake public download links. Do not invent published historical versions.
4. Run `python3 scripts/release.py preflight`, `python3 -m unittest discover -s Tests -p 'test_release.py'`, `bash scripts/test.sh` and appropriate app/runtime checks. Review all staged changes for personal data, credentials, unintended vendored changes and large/generated files. Build and verify the current app with `bash scripts/build.sh`; do not replace resources while a real game is running.
5. Commit the reviewed source/version changes on main. Do not stage work you do not understand. Use the user's configured Git identity; do not invent their identity. Then run `python3 scripts/release.py package` so the assets identify that exact clean commit. Each release must include `NEXARC-X.Y.Z-macOS-arm64.dmg`, with a verified app and an Applications shortcut, plus the ZIP/source/checksums. Validate the DMG by mounting it read-only and checking its contents/signature before publishing. The one locally launchable app keeps the same filename. Historical downloads belong in GitHub Releases.
6. Before distributing third-party binaries/assets, check the release-specific licenses, corresponding source and notices in `THIRD-PARTY.md` and `docs/GITHUB.md`. A source-credit list alone does not prove binary redistribution requirements have been met. Do not claim a review was completed if it was not. Do not include ROMs, console keys, firmware, saves or cached covers. Do not silently make private repositories public.
7. Inspect `python3 scripts/release.py publish --dry-run`, then publish with `python3 scripts/release.py publish` when the requested release is ready. This creates an annotated `vX.Y.Z` tag, pushes main plus that tag without force, uploads versioned assets to a draft, and then publishes it. Normal releases get GitHub's **Latest** marker. Alpha/beta/rc are prereleases and never replace the latest normal release. After publication, the script verifies real assets and the remote tag, then commits/pushes only the generated main README table, mirror and publication catalog. Every published version must keep its own DMG link in the main README, with the newest normal one marked **Latest**. Do not move version history out of the main README. `--draft` intentionally leaves a draft if the user requests one.
8. Preserve all prior release tags, release notes and downloads. Never overwrite a published tag/release to reuse a version number. If an upload fails, retain the prepared version and resume the draft rather than producing a second version. If a publish response was lost, inspect the remote tag and release before clearing local pending state.
9. Report the actual version, commit, release URL, validation and any remaining limitation. Never claim a GitHub push, release or upload happened unless the service confirmed it.

## Local commands

- `python3 scripts/release.py plan`: read-only next-version preview.
- `python3 scripts/release.py check`: validate version metadata.
- `python3 scripts/release.py preflight`: check candidate source paths and common secret patterns; still review the diff.
- `bash scripts/test.sh`: core model/configuration/save/input regression tests.
- `bash scripts/build.sh`: overwrite the current local app and archive.
- `python3 scripts/release.py dmg`: create a local installer without changing versions or publishing.
- `python3 scripts/release.py package`: stage downloads from a clean committed tree.

GitHub CLI (`gh`) and a signed-in account are required only for publication. They are not currently installed/configured by this setup. Never store GitHub tokens in the repository.
