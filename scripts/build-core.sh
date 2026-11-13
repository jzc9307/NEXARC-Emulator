#!/bin/bash
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd -P)/layout.sh"
NEXARC_DOTNET="${NEXARC_DOTNET:-$NEXARC_WORK/toolchain/dotnet/dotnet}"
if [ ! -x "$NEXARC_DOTNET" ]; then NEXARC_DOTNET="$(command -v dotnet || true)"; fi
if [ -z "$NEXARC_DOTNET" ]; then echo "Install the .NET 10 SDK or set NEXARC_DOTNET to its executable." >&2; exit 1; fi
export DOTNET_CLI_HOME="$NEXARC_WORK/toolchain/cli"
export NUGET_PACKAGES="$NEXARC_WORK/toolchain/nuget"
export DOTNET_CLI_TELEMETRY_OPTOUT=1
export DOTNET_GENERATE_ASPNET_CERTIFICATE=false
cd "$NEXARC_SOURCE/EngineSource"
"$NEXARC_DOTNET" restore src/Ryujinx/Ryujinx.csproj -r osx-arm64 --disable-parallel
"$NEXARC_DOTNET" publish src/Ryujinx/Ryujinx.csproj -c Release -r osx-arm64 --self-contained true \
  --no-restore --disable-build-servers -m:1 -p:UseSharedCompilation=false -p:Version=1.3.335 \
  -p:PublishTrimmed=false -p:UsedAvaloniaProducts= -o "$NEXARC_WORK/engine-build"
