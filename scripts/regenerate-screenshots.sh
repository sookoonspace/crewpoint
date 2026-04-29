#!/usr/bin/env bash
#
# (Re)generate the placeholder screenshots committed under `screenshots/`
# from the golden-style tests in `test/screenshots/`.
#
# The screenshots are tagged `screenshots`, which `dart_test.yaml` skips
# by default. This script runs them with `--update-goldens` so the PNGs
# at `screenshots/*` get rewritten.
#
# Usage:
#   scripts/regenerate-screenshots.sh
#
# After running, review the diff:
#   git diff screenshots/
# and commit if the new artifacts look right (each must carry the
# "PLACEHOLDER - replace before public launch" overlay).

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

flutter test \
  --tags screenshots \
  --run-skipped \
  --update-goldens \
  test/screenshots/

echo
echo "==> regenerated placeholder screenshots in screenshots/"
ls screenshots/ 2>/dev/null || echo "(no PNGs yet — check test output above)"
