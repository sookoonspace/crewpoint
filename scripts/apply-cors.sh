#!/usr/bin/env bash
#
# Apply the Storage CORS allow-list (`infra/storage-cors.json`) to the
# CrewPoint Firebase Storage bucket for a given flavor.
#
# Idempotent: re-running with the same payload is safe and a no-op
# beyond an API call. Re-run after editing `infra/storage-cors.json`
# (e.g., when adding a new allowed subdomain) or after rotating a
# bucket.
#
# Usage:
#   scripts/apply-cors.sh dev          # apply to crewpoint-dev
#   scripts/apply-cors.sh stg          # apply to crewpoint-stg
#   scripts/apply-cors.sh prod         # apply to crewpoint-prod
#   scripts/apply-cors.sh all          # apply to dev + stg + prod
#
# Prerequisites:
#   - `gsutil` installed (ships with Google Cloud SDK).
#   - Authenticated against Google Cloud:
#       gcloud auth login
#       gcloud config set project crewpoint-<flavor>
#   - Editor / Storage Admin on the target Firebase project.
#
# Verification:
#   gsutil cors get gs://<bucket>      # shows the active rules

set -euo pipefail

readonly CONFIG_FILE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/infra/storage-cors.json"

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "error: $CONFIG_FILE not found" >&2
  exit 1
fi

apply_one() {
  local flavor="$1"
  local bucket="gs://crewpoint-${flavor}.firebasestorage.app"
  echo "==> applying CORS to $bucket"
  gsutil cors set "$CONFIG_FILE" "$bucket"
}

case "${1:-}" in
  dev|stg|prod)
    apply_one "$1"
    ;;
  all)
    apply_one dev
    apply_one stg
    apply_one prod
    ;;
  *)
    echo "usage: $0 {dev|stg|prod|all}" >&2
    exit 64
    ;;
esac
