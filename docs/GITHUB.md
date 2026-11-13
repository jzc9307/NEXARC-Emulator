# GitHub and versioned releases

Open this inner **NEXARC** folder in VS Code with File → Open Folder. It is the Git root. The outer project folder still holds the current app, build caches and output ZIPs. A local `.nexarc-workspace` marker lets the build scripts reuse those files; a normal clone uses its own ignored `work/` and `dist/` folders.

## What “push to GitHub” means here

When you ask the coding agent to **push to GitHub**, `AGENTS.md` instructs it to create the next app version by default: `0.3.0 → 0.3.1 → 0.3.2`. Each version has its own changelog entry, Git tag and GitHub Release. The latest normal release receives GitHub's **Latest** label. Alpha/beta/rc builds are marked prerelease and keep the previous normal release as Latest.

A normal VS Code Git **Push/Sync** only pushes commits. It does not run the release workflow or bump the version. Use the release tasks below, the documented commands, or the phrase “push to GitHub” with the agent. Bumping on every low-level Git push would also bump retries and documentation-only syncs; the explicit release workflow avoids that.

`VERSION` is the single app release version; `BUILD_NUMBER` is the monotonically increasing macOS build number. `scripts/release.py` synchronizes the app plist, the app's displayed version, the README and [version history](RELEASES.md). The current `0.3.0` entry is a local baseline, not a claim that a GitHub release already exists.

## Connect a repository once

Create an empty repository in your GitHub account. Choose its visibility yourself. Do not initialize it with another README/license when connecting this existing project.

From this folder, add the URL GitHub gives you:

```bash
git remote add origin https://github.com/YOUR-ACCOUNT/NEXARC.git
```

Install GitHub CLI from https://cli.github.com/ and sign in with `gh auth login`. Tokens belong in the system credential store, never in source files. VS Code's GitHub sign-in can push source commits; the release script additionally needs `gh` for release assets and Latest labeling.

No remote URL, account login, public repository or GitHub Release has been created by the local setup.

## Prepare and publish a version

1. Write concrete release notes under `[Unreleased]` in `CHANGELOG.md`.
2. Preview with `python3 scripts/release.py plan`.
3. Run `python3 scripts/release.py prepare`. Use `--bump minor` or `--bump major` when intended. Use `--prerelease alpha`, `beta` or `rc` for prereleases. `--notes-file path/to/notes.md` can supply exact multiline notes without shell escaping.
4. Run `python3 scripts/release.py preflight`, the Python release tests, `bash scripts/test.sh`, and the checks appropriate to the actual product changes. Build with `bash scripts/build.sh` and verify the app. Do not replace the app during a live game; the build guard stops that replacement.
5. Review the diff and commit the intended source/version files on `main`. Build caches, compiled engine output, private content and release staging stay ignored. The existing configured Git identity is used; this setup does not invent one.
6. Run `python3 scripts/release.py package`. It requires a clean commit and matching versions in the built app and ZIP. It stages versioned app/source ZIPs, SHA256SUMS, release notes and a manifest in ignored `.release/current/`. Source packaging uses tracked files only.
7. Review `python3 scripts/release.py publish --dry-run` and finish the third-party distribution checks below.
8. Run `python3 scripts/release.py publish`. It pushes the branch/tag atomically without force, uploads assets into a draft, then publishes it with the correct Latest/prerelease status. Add `--draft` to stop at a draft intentionally.

The script never stages or commits changes for you. It refuses to package a dirty tree, move an existing tag to different code, republish a published version, or start a second version while one is pending. If a network step fails, rerun the same pending version after checking GitHub. Do not bump again merely to retry an upload.

VS Code's Terminal → Run Task includes build/test, release-plan, prepare-patch, package and publish tasks. **Publish current release** contacts GitHub and is meant to be invoked only when the release is ready.

## Public distribution checks

NEXARC is a frontend integrating upstream emulation code. Its project MIT license does not relicense the bundled engines, dependencies or artwork. Preserve [THIRD-PARTY.md](../THIRD-PARTY.md) and the original notices. Before shipping a binary, verify the exact core snapshots' corresponding source/build materials and the conditions on noncommercial/no-derivatives artwork. This setup does not certify that review as complete.

Local `Vendor/CoreArchives` are ignored so downloaded core binaries do not enter source history accidentally. Fetching uses pinned checksums; a changed/expired upstream nightly is rejected, rather than silently using a different core. Fresh-clone dependency restoration has not been established merely by reusing this Mac's build cache. Arrange durable matching dependency downloads/source materials before advertising reproducible public binaries.

Exclude personal ROMs, console keys, firmware, progress, session logs and downloaded covers. The preflight checks common paths/tokens and Git's 100 MiB regular-file limit, but a human/agent must still review the staged diff. The app ZIP belongs in Releases, not source history. Use bundled homebrew for portfolio screenshots and state compatibility and controller-testing limits accurately.

GitHub references: [release creation](https://cli.github.com/manual/gh_release_create), [release editing and Latest](https://cli.github.com/manual/gh_release_edit), [release management](https://docs.github.com/en/repositories/releasing-projects-on-github/managing-releases-in-a-repository).
