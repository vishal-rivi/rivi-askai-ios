#!/usr/bin/env bash
# Runs the package tests on an iOS simulator. (The elements import UIKit, so `swift test` on
# macOS cannot build the package.)
#
#   scripts/test.sh                         all tests
#   scripts/test.sh ConformanceTests        one test class (-only-testing)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEVICE="${RIVI_TEST_DEVICE:-$(xcrun simctl list devices available | grep -m1 -oE 'iPhone [^(]+' | sed 's/ *$//')}"
ONLY=()
[[ $# -gt 0 ]] && ONLY=(-only-testing:"RiviSmartSortTests/$1")

cd "$ROOT"
"$ROOT/scripts/sync-contract.sh" --check
xcodebuild test \
  -scheme RiviSmartSort \
  -destination "platform=iOS Simulator,name=$DEVICE" \
  ${RIVI_DERIVED_DATA:+-derivedDataPath "$RIVI_DERIVED_DATA"} \
  "${ONLY[@]+"${ONLY[@]}"}" \
  -collect-test-diagnostics never \
  -quiet
