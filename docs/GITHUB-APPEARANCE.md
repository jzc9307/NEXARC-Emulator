# NEXARC on GitHub

The README, repository About panel, owner avatar and social preview are separate settings. Putting a logo in README.md does not change the avatar beside a search-result repository name.

## Description and topics

On [jzc9307/NEXARC-Emulator](https://github.com/jzc9307/NEXARC-Emulator), use the gear beside **About** and set:

**Description**

> A multi-console game emulator for Apple Silicon Macs. Explore 21 console systems—from Game Boy and DS to PlayStation, PSP and Switch—with handheld skins, visual saves, fast-forward and controller support.

**Topics**

`macos` · `swift` · `swiftui` · `appkit` · `emulation` · `emulator-frontend` · `retro-gaming` · `apple-silicon` · `game-library` · `libretro`

These topics describe the frontend, not guaranteed compatibility with every title. The repository's primary language label and star count are calculated by GitHub; they are not README settings.

With an authenticated GitHub CLI, the equivalent explicit metadata update is:

```sh
gh repo edit jzc9307/NEXARC-Emulator \
  --description "A multi-console game emulator for Apple Silicon Macs. Explore 21 console systems—from Game Boy and DS to PlayStation, PSP and Switch—with handheld skins, visual saves, fast-forward and controller support." \
  --add-topic macos --add-topic swift --add-topic swiftui --add-topic appkit \
  --add-topic emulation --add-topic emulator-frontend --add-topic retro-gaming \
  --add-topic apple-silicon --add-topic game-library --add-topic libretro
```

This command changes the remote repository. It is not automatically run during local setup or releases. Existing topics are preserved when using `--add-topic`.

## The small logo beside the repository name

The Alacritty card uses its **owner's avatar**. A repository owned by `jzc9307` normally shows that profile avatar. There is no per-repository avatar setting equivalent to an app icon.

- To change your personal avatar, use GitHub profile Settings → Public profile → Profile picture. That changes your profile across GitHub, including other repositories.
- To give NEXARC a separate identity, create/use a NEXARC organization and set its organization avatar. Moving the repository to an organization is a separate ownership change; do not do it just to update the README.

A ready-to-upload copy of the approved app icon is [nexarc-avatar.png](assets/nexarc-avatar.png). This task does not change your personal avatar, create an organization or transfer a repository.

## Link and social preview

Use repository **Settings → General → Social preview → Edit → Upload an image** and select [social-preview.png](assets/social-preview.png). It is 1280 × 640 and uses the current NEXARC branding. Social/link previews are separate from the small owner avatar in the screenshot.

The [README banner](assets/readme-banner.svg) and [technology badges](assets/tech-badges.svg) are local repository assets, following the structure of the user's FootballManager-Simulation README. They are original NEXARC visuals and do not imply official manufacturer branding.

GitHub references: [repository appearance](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository), [topics/About guidance](https://docs.github.com/en/account-and-profile/tutorials/using-your-github-profile-to-enhance-your-resume), [organization profiles](https://docs.github.com/en/account-and-profile/concepts/organization-profile).
