#!/bin/bash
set -euo pipefail
NEXARC_SOURCE="$(cd "$(dirname "$0")/.." && pwd)"
NEXARC_TEST_ROOT="$(mktemp -d /private/tmp/nexarc-tests.XXXXXX)"
trap 'rm -rf "$NEXARC_TEST_ROOT"' EXIT
mkdir -p "$NEXARC_TEST_ROOT/cache"
NEXARC_BASE=("$NEXARC_SOURCE/Sources/Models.swift" "$NEXARC_SOURCE/Sources/GameSystem.swift" "$NEXARC_SOURCE/Sources/PlayerPreferences.swift" "$NEXARC_SOURCE/Sources/ProgressStore.swift")
xcrun swiftc -module-cache-path "$NEXARC_TEST_ROOT/cache" "${NEXARC_BASE[@]}" "$NEXARC_SOURCE/Tests/ProgressTests.swift" -o "$NEXARC_TEST_ROOT/progress"
"$NEXARC_TEST_ROOT/progress"
xcrun swiftc -module-cache-path "$NEXARC_TEST_ROOT/cache" "${NEXARC_BASE[@]}" "$NEXARC_SOURCE/Sources/RetroRuntime.swift" "$NEXARC_SOURCE/Sources/ROMPatch.swift" "$NEXARC_SOURCE/Tests/SuiteTests.swift" -o "$NEXARC_TEST_ROOT/suite"
"$NEXARC_TEST_ROOT/suite"
xcrun swiftc -module-cache-path "$NEXARC_TEST_ROOT/cache" "${NEXARC_BASE[@]}" "$NEXARC_SOURCE/Sources/ControllerProfile.swift" "$NEXARC_SOURCE/Tests/ModelsTests.swift" -o "$NEXARC_TEST_ROOT/models"
"$NEXARC_TEST_ROOT/models"
clang -O2 "$NEXARC_SOURCE/Tests/PlayerRuntimeTests.c" -o "$NEXARC_TEST_ROOT/player"
"$NEXARC_TEST_ROOT/player"
