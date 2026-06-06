#!/usr/bin/env bash
# Generates per-flavor iOS app-icon catalogs (AppIcon, AppIcon-dev,
# AppIcon-stg) so each flavor's home-screen icon carries its own
# DEV/STG badge overlay.
#
# flutter_launcher_icons can only write to
# `ios/Runner/Assets.xcassets/AppIcon.appiconset/` — the iconset
# directory name is not configurable. This script runs the three
# yaml configs in order, renames the resulting iconset after each
# non-prod run, then runs the prod config last so the unsuffixed
# `AppIcon.appiconset` carries the prod art.
#
# The per-flavor `ASSETCATALOG_COMPILER_APPICON_NAME` settings in
# `ios/{dev,stg}.xcconfig` reference the matching directory name.
#
# Source PNGs live in `assets/icons/launcher_icon{,_dev,_stg}.png` and
# are produced by `dart run scripts/generate_flavor_icons.dart` from
# `launcher_icon.png` (badged with orange DEV / blue STG ribbons).

set -euo pipefail

cd "$(dirname "$0")/.."

ASSETS_DIR="ios/Runner/Assets.xcassets"
ICONSET="$ASSETS_DIR/AppIcon.appiconset"

# Sanity check the source PNGs exist (run generate_flavor_icons.dart
# first if they don't).
for f in launcher_icon launcher_icon_dev launcher_icon_stg; do
  if [[ ! -f "assets/icons/$f.png" ]]; then
    echo "Error: assets/icons/$f.png is missing." >&2
    echo "Run: dart run scripts/generate_flavor_icons.dart" >&2
    exit 1
  fi
done

run_flavor() {
  local yaml="$1"
  local target="$2"

  echo "==> Generating from $yaml"
  dart run flutter_launcher_icons -f "$yaml"

  if [[ "$target" != "AppIcon" ]]; then
    local target_dir="$ASSETS_DIR/$target.appiconset"
    rm -rf "$target_dir"
    mv "$ICONSET" "$target_dir"
    echo "==> Renamed AppIcon.appiconset → $target.appiconset"
  fi
}

# Order matters: dev + stg get renamed; main runs last and keeps the
# default AppIcon.appiconset name.
run_flavor flutter_launcher_icons-dev.yaml  AppIcon-dev
run_flavor flutter_launcher_icons-stg.yaml  AppIcon-stg
run_flavor flutter_launcher_icons-main.yaml AppIcon

echo
echo "Done. iOS now has:"
echo "  $ASSETS_DIR/AppIcon.appiconset      (prod)"
echo "  $ASSETS_DIR/AppIcon-dev.appiconset  (dev — orange DEV badge)"
echo "  $ASSETS_DIR/AppIcon-stg.appiconset  (stg — blue STG badge)"
echo
echo "Rebuild dev/stg in Xcode (or via flutter run --flavor dev) to see"
echo "the badged icon on the home screen."
