#!/usr/bin/env bash
#
# Regenerate the Design gallery goldens in test/design/golden/goldens/
# (Spec #186, ledger L15). Goldens are made on Linux only, so CI compares
# like with like:
#
#   - On Linux this runs the tests with --update-goldens here.
#   - Anywhere else it asks GitHub Actions to do it on the current branch
#     (the "Design goldens" workflow), which commits the images back.
#     Pull afterwards. If the workflow is not on main yet, push a commit
#     whose message contains [update-goldens] instead.
#
# Usage: scripts/update-design-goldens.sh

set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

if [[ "$(uname -s)" == "Linux" ]]; then
  flutter test --tags design --run-skipped --update-goldens test/design/golden
  echo
  echo "==> regenerated goldens; review with: git diff --stat test/design/golden/goldens"
  exit 0
fi

branch="$(git branch --show-current)"
if [[ "$branch" == "main" ]]; then
  echo "Refusing to regenerate goldens on main; use a branch." >&2
  exit 1
fi
echo "Not on Linux: asking GitHub Actions to regenerate goldens on '$branch'."
git push --quiet origin "$branch"
gh workflow run design-goldens.yml --ref "$branch"
echo "==> started; when it finishes, run: git pull"
