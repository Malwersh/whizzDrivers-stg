#!/usr/bin/env bash
# Explicit staging trial only. Identity gating remains enforced by DriverLocationMode.
set -euo pipefail
mode="${1:-profile}"
trial_build="${2:-260}"
[[ "$trial_build" =~ ^[0-9]+$ ]] || { echo 'Build number must be numeric' >&2; exit 2; }
case "$mode" in
 profile) target=(--profile) ;;
 simulator) target=(--simulator --debug) ;;
 *) echo 'Use profile or simulator' >&2; exit 2 ;;
esac
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root/frontend"
"${FLUTTER_BIN:-flutter}" build ios "${target[@]}" --no-pub --build-number="$trial_build" \
 --dart-define=ENVIRONMENT=staging \
 --dart-define=IS_PRODUCTION=false \
 --dart-define=USE_TEST_LOCATION=true \
 --dart-define=TEST_LOCATION_DRIVER_ID=34d8e408-1021-7076-6055-7325644f97cb \
 --dart-define=TEST_LATITUDE=31.913292 \
 --dart-define=TEST_LONGITUDE=44.476014
