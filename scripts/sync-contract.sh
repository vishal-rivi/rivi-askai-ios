#!/usr/bin/env bash
# Syncs the shared Smart Sort contract from the web repo and pins it in contract.lock.json.
#
#   scripts/sync-contract.sh            copy the files and rewrite the lock
#   scripts/sync-contract.sh --check    fail if the bundled files differ from the lock
#
# Also syncs the non-secret tenant configs (tenants/<tenant>.json) used by scripts/build-tenant.sh.
# WEB_REPO defaults to ../rivi-client-react. The contract (cases.json) is normative and is the
# same file on every platform: never edit the copies here; change cases.json on the web first.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WEB_REPO="${WEB_REPO:-$ROOT/../rivi-client-react}"
LOCK="$ROOT/contract.lock.json"
RES="$ROOT/Sources/RiviSmartSortContract/Resources/smart-sort"
TEST_RES="$ROOT/Tests/RiviSmartSortTests/TestData"

# destination|source (source relative to WEB_REPO)
FILES=(
  "$RES/rules.json|packages/smart-sort-core/data/rules.json"
  "$RES/tokens.json|packages/smart-sort-core/data/tokens.json"
  "$RES/i18n/en.json|apps/sandbox/public/i18n/smart-sort/v1/en.json"
  "$RES/i18n/ar.json|apps/sandbox/public/i18n/smart-sort/v1/ar.json"
  "$TEST_RES/contract/cases.json|packages/smart-sort-core/data/cases.json"
  "$TEST_RES/contract/cases.schema.json|packages/smart-sort-core/data/cases.schema.json"
  "$ROOT/tenants/almatar.json|packages/smart-sort-elements/tenants/almatar.json"
  "$ROOT/tenants/sandbox.json|packages/smart-sort-elements/tenants/sandbox.json"
)
FIXTURE_DIRS=(entities frames sse)

sha() { shasum -a 256 "$1" | cut -d' ' -f1; }
rel() { echo "${1#"$ROOT"/}"; }

if [[ "${1:-}" == "--check" ]]; then
  status=0
  for entry in "${FILES[@]}"; do
    dest="${entry%%|*}"
    want="$(/usr/bin/python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["files"].get(sys.argv[2], ""))' "$LOCK" "$(rel "$dest")")"
    have="$(sha "$dest")"
    if [[ "$want" != "$have" ]]; then
      echo "MISMATCH $(rel "$dest")"
      status=1
    fi
  done
  [[ $status -eq 0 ]] && echo "contract files match contract.lock.json"
  exit $status
fi

[[ -d "$WEB_REPO/packages/smart-sort-core" ]] || { echo "web repo not found at $WEB_REPO (set WEB_REPO)"; exit 1; }

for entry in "${FILES[@]}"; do
  dest="${entry%%|*}"; src="$WEB_REPO/${entry#*|}"
  mkdir -p "$(dirname "$dest")"
  cp "$src" "$dest"
done
for dir in "${FIXTURE_DIRS[@]}"; do
  rm -rf "$TEST_RES/fixtures/$dir"
  mkdir -p "$TEST_RES/fixtures"
  cp -R "$WEB_REPO/packages/smart-sort-core/test/fixtures/$dir" "$TEST_RES/fixtures/$dir"
done

web_commit="$(git -C "$WEB_REPO" rev-parse HEAD 2>/dev/null || echo unknown)"
{
  echo "{"
  echo "  \"source\": \"rivi-client-react@$web_commit\","
  echo "  \"files\": {"
  last=$((${#FILES[@]} - 1))
  for i in "${!FILES[@]}"; do
    dest="${FILES[$i]%%|*}"
    sep=","; [[ $i -eq $last ]] && sep=""
    echo "    \"$(rel "$dest")\": \"$(sha "$dest")\"$sep"
  done
  echo "  }"
  echo "}"
} > "$LOCK"
echo "synced from rivi-client-react@$web_commit; wrote $(rel "$LOCK")"
