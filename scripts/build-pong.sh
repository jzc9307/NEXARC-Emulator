#!/bin/bash
set -euo pipefail
NEXARC_SOURCE="$(cd "$(dirname "$0")/.." && pwd)"
# Pinned official devkitPro image. It is a build tool, not a runtime dependency.
docker run --rm --network none -v "$NEXARC_SOURCE/Homebrew/OrbitPong:/project" -w /project \
  devkitpro/devkita64@sha256:1fc388c3a0d34bd2045a6dadcb1020e069d5f876a187fd705de14b4440c00282 make -j2
cp "$NEXARC_SOURCE/Homebrew/OrbitPong/orbit-pong.nro" "$NEXARC_SOURCE/Resources/Homebrew/orbit-pong.nro"
