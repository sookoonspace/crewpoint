#!/usr/bin/env bash
# Generates per-flavor iOS app-icon catalogs so each flavor's home-screen
# icon carries its own DEV/STG badge overlay.
#
# flutter_launcher_icons 0.14+ auto-derives the iOS iconset directory
# name from the yaml's filename suffix:
#
#   flutter_launcher_icons-dev.yaml  → AppIcon-dev.appiconset
#   flutter_launcher_icons-stg.yaml  → AppIcon-stg.appiconset
#   flutter_launcher_icons-main.yaml → AppIcon-main.appiconset
#
# So no renames are needed — this script just runs the three yamls
# in order. The per-flavor xcconfigs at ios/{dev,stg,prod}.xcconfig
# point ASSETCATALOG_COMPILER_APPICON_NAME at the matching name.
#
# Source PNGs (`assets/icons/launcher_icon{,_dev,_stg}.png`) are
# produced by `dart run scripts/generate_flavor_icons.dart` from the
# unbadged base icon.

set -euo pipefail

cd "$(dirname "$0")/.."

# Sanity check the source PNGs.
for f in launcher_icon launcher_icon_dev launcher_icon_stg; do
  if [[ ! -f "assets/icons/$f.png" ]]; then
    echo "Error: assets/icons/$f.png is missing." >&2
    echo "Run: dart run scripts/generate_flavor_icons.dart" >&2
    exit 1
  fi
done

run_flavor() {
  local yaml="$1"
  echo "==> Generating from $yaml"
  dart run flutter_launcher_icons -f "$yaml"
}

run_flavor flutter_launcher_icons-dev.yaml
run_flavor flutter_launcher_icons-stg.yaml
run_flavor flutter_launcher_icons-main.yaml

echo
echo "Done. iOS now has:"
echo "  ios/Runner/Assets.xcassets/AppIcon-dev.appiconset   (dev — orange DEV badge)"
echo "  ios/Runner/Assets.xcassets/AppIcon-stg.appiconset   (stg — blue STG badge)"
echo "  ios/Runner/Assets.xcassets/AppIcon-main.appiconset  (prod / App Store art)"
echo
echo "Rebuild dev/stg/prod in Xcode (or via flutter run --flavor X) to"
echo "see the matching icon on the home screen."
