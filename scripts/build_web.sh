#!/usr/bin/env bash
# Builds the web app for one flavor, with that flavor's .env file, into
# build/web. Firebase Hosting runs it before every deploy (firebase.json
# predeploy). It is a script because the Firebase CLI does not run a
# predeploy command that contains '=', and silently deploys whatever is
# already in build/web instead.
#
#   scripts/build_web.sh dev|stg|prod
set -euo pipefail

flavor="${1:?usage: scripts/build_web.sh dev|stg|prod}"
case "$flavor" in
  dev | stg | prod) ;;
  *) echo "Unknown flavor: $flavor" >&2; exit 1 ;;
esac

cd "$(dirname "$0")/.."
env_file=".env.$flavor"
if [ ! -f "$env_file" ]; then
  echo "Missing $env_file. See ai_specs/setup-guide.md." >&2
  exit 1
fi

flutter build web --release \
  "--dart-define-from-file=$env_file" \
  "--dart-define=FLAVOR=$flavor"

# The web engine downloads every declared font before the first frame, so
# drop the icon weights the app never uses (tool/trim_web_fonts.dart).
dart run tool/trim_web_fonts.dart build/web
