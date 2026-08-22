#!/bin/sh
# Standalone checks for the macOS chart-pane geometry.
#
# ChartPaneLayout.swift is pure maths with no app dependencies, so it can be
# verified without building the Mac app — useful while the macOS target still has
# outstanding compile errors elsewhere. Fold these into a real macOS test target
# once one exists.
set -e
cd "$(dirname "$0")/.."
OUT=$(mktemp -d)
swiftc -target arm64-apple-macos14.0 -sdk "$(xcrun --sdk macosx --show-sdk-path)" \
    traders_guild_macOS/ChartPaneLayout.swift \
    scripts/panelayout-checks/main.swift \
    -o "$OUT/run"
"$OUT/run"
