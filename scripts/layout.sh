#!/bin/bash
# Resolve this shared layout from any working directory, including a legacy link.
NEXARC_SOURCE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
NEXARC_PARENT="$(dirname "$NEXARC_SOURCE")"
if [ -f "$NEXARC_PARENT/.nexarc-workspace" ]; then
  NEXARC_PROJECT="$NEXARC_PARENT"
  NEXARC_OUTPUT="$NEXARC_PARENT/outputs"
else
  NEXARC_PROJECT="$NEXARC_SOURCE"
  NEXARC_OUTPUT="$NEXARC_SOURCE/dist"
fi
NEXARC_WORK="$NEXARC_PROJECT/work"
