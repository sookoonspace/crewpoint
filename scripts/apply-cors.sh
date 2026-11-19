#!/usr/bin/env bash
#
# Apply the Storage CORS allow-list (`infra/storage-cors.<flavor>.json`) to
# the CrewPoint Firebase Storage bucket for a given flavor. Each flavor
# allows its own web origins, so the web app can read receipts, profile
# pictures and event cover photos (Spec #186 Req 42).
#
# Idempotent: re-running with the same payload is safe and a no-op
# beyond an API call. Re-run after editing an `infra/storage-cors.*.json`
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

readonly INFRA_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/infra"

apply_one() {
  local flavor="$1"
  local config="$INFRA_DIR/storage-cors.${flavor}.json"
  local bucket="gs://crewpoint-${flavor}.firebasestorage.app"
  if [[ ! -f "$config" ]]; then
    echo "error: $config not found" >&2
    exit 1
  fi
  echo "==> applying $config to $bucket"
  gsutil cors set "$config" "$bucket"
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
