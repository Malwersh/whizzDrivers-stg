#!/usr/bin/env bash
# Explicit staging trial only. Identity gating remains enforced by DriverLocationMode.
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
mode="${1:-release}"
trial_build="${2:-$(sed -n 's/^version:.*+\([0-9][0-9]*\).*$/\1/p' "$repo_root/frontend/pubspec.yaml")}"
[[ "$trial_build" =~ ^[0-9]+$ ]] || { echo 'Build number must be numeric' >&2; exit 2; }
case "$mode" in
 release) target=(--release) ;;
 profile) target=(--profile) ;;
 simulator) target=(--simulator --debug) ;;
 *) echo 'Use release, profile or simulator' >&2; exit 2 ;;
esac
cd "$repo_root/frontend"
"${FLUTTER_BIN:-flutter}" build ios "${target[@]}" --no-pub --build-number="$trial_build" \
 --dart-define-from-file=config/staging-test-driver.json
