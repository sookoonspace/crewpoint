#!/usr/bin/env bash
#
# Run CrewPoint with a flavor, passing every flag the app actually needs.
#
# `flutter run --flavor stg` on its own is NOT enough and fails in a
# confusing way. `--flavor` only selects the *native* build (Android
# product flavor, iOS scheme, and therefore which google-services.json /
# GoogleService-Info.plist ships). The Dart side picks its Firebase
# project from `--dart-define=FLAVOR=`, which defaults to `dev` when
# absent. Mismatch them and Android's Firebase SDK auto-initializes
# `[DEFAULT]` from the native stg/prod config, then `initializeApp` is
# called again with dev options and throws `[core/duplicate-app]` — an
# unhandled exception in `main()`, so you get a blank screen rather than
# an error. `main.dart` now guards against this explicitly; this script
# stops you tripping it in the first place.
#
# Usage:
#   scripts/run.sh <dev|stg|prod> [extra flutter run args...]
#
# Examples:
#   scripts/run.sh dev
#   scripts/run.sh stg -d emulator-5554
#   scripts/run.sh prod --release
#   scripts/run.sh dev -d chrome        # web: --flavor is omitted for you
#
# VS Code users: .vscode/launch.json already carries the equivalent
# configurations for all three flavors. This script is the terminal
# counterpart — launch.json has no effect on `flutter run`.

set -euo pipefail

FLAVOR="${1:-}"
shift || true

case "$FLAVOR" in
  dev | stg | prod) ;;
  *)
    echo "Usage: scripts/run.sh <dev|stg|prod> [extra flutter run args...]" >&2
    [ -n "$FLAVOR" ] && echo "Unknown flavor: '$FLAVOR'" >&2
    exit 64
    ;;
esac

ENV_FILE=".env.$FLAVOR"
if [ ! -f "$ENV_FILE" ]; then
  echo "Missing $ENV_FILE. It supplies non-Firebase secrets and is gitignored;" >&2
  echo "see ai_specs/setup-guide.md for how to create it." >&2
  exit 66
fi

# Web takes no --flavor (there is no native build to select), so FLAVOR
# is the only selector there. Detect an explicit web device and drop the
# flag rather than letting Flutter reject it.
FLAVOR_ARGS=("--flavor" "$FLAVOR")
for arg in "$@"; do
  case "$arg" in
    chrome | web-server | edge)
      FLAVOR_ARGS=()
      break
      ;;
  esac
done

set -x
exec flutter run \
  "${FLAVOR_ARGS[@]}" \
  -t lib/main.dart \
  "--dart-define-from-file=$ENV_FILE" \
  "--dart-define=FLAVOR=$FLAVOR" \
  "$@"
