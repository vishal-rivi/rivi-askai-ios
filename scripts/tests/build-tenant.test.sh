#!/usr/bin/env bash
# Tests scripts/build-tenant.sh: every check that must stop a tenant build does, and a good build
# passes. Uses throwaway tenants in a temp dir (RIVI_TENANTS_DIR) and cleans up dist/ after itself.
#
#   scripts/tests/build-tenant.test.sh
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="$ROOT/scripts/build-tenant.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP" "$ROOT/dist/zz-test" "$ROOT/dist/zz-other"' EXIT
export RIVI_TENANTS_DIR="$TMP/tenants"
mkdir -p "$RIVI_TENANTS_DIR"
# The repo's own .env must not leak into these tests.
export RIVI_ENV_FILE="$TMP/empty.env"
: > "$RIVI_ENV_FILE"

GOOD_STAGING="stg-0123456789abcdef0123456789abcdef"
GOOD_PRODUCTION="prd-0123456789abcdef0123456789abcdef"
passed=0
failed=0

tenant() { # <id> <json>
  printf '%s\n' "$2" > "$RIVI_TENANTS_DIR/$1.json"
}

valid_json='{"name":"zz","tier":"basic","environments":{"staging":{"baseUrl":"https://staging.rivi.test"},"production":{"baseUrl":"https://production.rivi.test"}}}'

# <name> <expected exit: 0|fail> <expected output fragment> <env assignments…> -- <tenant>
check() {
  local name="$1" expect="$2" fragment="$3"; shift 3
  local assignments=()
  while [[ "$1" != "--" ]]; do assignments+=("$1"); shift; done
  shift
  local output status
  output="$(env -u RIVI_TOKEN_ZZ_TEST_STAGING -u RIVI_TOKEN_ZZ_TEST_PRODUCTION "${assignments[@]}" "$BUILD" "$@" 2>&1)"
  status=$?
  local ok=1
  if [[ "$expect" == 0 && $status -ne 0 ]] || [[ "$expect" == fail && $status -eq 0 ]]; then ok=0; fi
  if [[ -n "$fragment" && "$output" != *"$fragment"* ]]; then ok=0; fi
  if [[ "$output" == *"$GOOD_STAGING"* || "$output" == *"$GOOD_PRODUCTION"* ]]; then
    ok=0
    output="$output
(a token value was printed)"
  fi
  if [[ $ok -eq 1 ]]; then
    passed=$((passed + 1))
    echo "ok   $name"
  else
    failed=$((failed + 1))
    echo "FAIL $name (exit $status)"
    echo "$output" | sed 's/^/     /' | tail -6
  fi
}

TOKENS=(RIVI_TOKEN_ZZ_TEST_STAGING=$GOOD_STAGING RIVI_TOKEN_ZZ_TEST_PRODUCTION=$GOOD_PRODUCTION)

tenant zz-test "$valid_json"
check "rejects an invalid tenant id" fail "must be lowercase letters and digits" "${TOKENS[@]}" -- ZZ_Test
check "rejects a missing token" fail "RIVI_TOKEN_ZZ_TEST_PRODUCTION is missing or empty" \
  RIVI_TOKEN_ZZ_TEST_STAGING=$GOOD_STAGING -- zz-test
check "rejects a token with whitespace" fail "contains whitespace or control characters" \
  "RIVI_TOKEN_ZZ_TEST_STAGING=has space" RIVI_TOKEN_ZZ_TEST_PRODUCTION=$GOOD_PRODUCTION -- zz-test

tenant zz-test '{"name":"zz","tier":"basic","token":"x","environments":{"staging":{"baseUrl":"https://s.rivi.test"},"production":{"baseUrl":"https://p.rivi.test"}}}'
check "rejects a token in the tenant file" fail "tokens never go in tenants/*.json" "${TOKENS[@]}" -- zz-test
tenant zz-test '{"name":"zz","tier":"basic","colour":"red","environments":{"staging":{"baseUrl":"https://s.rivi.test"},"production":{"baseUrl":"https://p.rivi.test"}}}'
check "rejects an unknown key" fail 'unknown key "colour"' "${TOKENS[@]}" -- zz-test
tenant zz-test '{"name":"zz","tier":"basic","environments":{"staging":{"baseUrl":"http://s.rivi.test"},"production":{"baseUrl":"https://p.rivi.test"}}}'
check "rejects a non-https base URL" fail "staging.baseUrl must be https" "${TOKENS[@]}" -- zz-test
tenant zz-test '{"name":"zz","tier":"basic","environments":{"staging":{"baseUrl":"https://s.rivi.test/"},"production":{"baseUrl":"https://p.rivi.test?x=1"}}}'
check "rejects a trailing slash or query" fail "must have no trailing slash, query or hash" "${TOKENS[@]}" -- zz-test
tenant zz-test '{"name":"zz","tier":"basic","environments":{"staging":{"baseUrl":"https://s.rivi.test"}}}'
check "rejects a missing environment" fail "environments.production.baseUrl is required" "${TOKENS[@]}" -- zz-test

tenant zz-test "$valid_json"
check "rejects a RIVI_ENV_FILE that does not exist" fail "does not exist" \
  RIVI_ENV_FILE="$TMP/missing.env" -- zz-test

printf 'RIVI_TOKEN_ZZ_TEST_STAGING="%s"\nexport RIVI_TOKEN_ZZ_TEST_PRODUCTION=%s\nOTHER_SECRET=nope\n' \
  "$GOOD_STAGING" "$GOOD_PRODUCTION" > "$TMP/tokens.env"
check "an environment variable wins over the file, even when empty" fail \
  "RIVI_TOKEN_ZZ_TEST_STAGING is missing or empty" \
  RIVI_ENV_FILE="$TMP/tokens.env" RIVI_TOKEN_ZZ_TEST_STAGING= -- zz-test

# A token of another tenant that ends up in this build: the staging URL is in every build, so use it.
check "refuses a build that contains another tenant's token" fail \
  "contains RIVI_TOKEN_ZZ_OTHER_STAGING" \
  "${TOKENS[@]}" RIVI_TOKEN_ZZ_OTHER_STAGING=https://staging.rivi.test -- zz-test

check "builds from a dotenv file (quotes, export) and verifies its own tokens" 0 \
  "loaded RIVI_TOKEN_ZZ_TEST_STAGING RIVI_TOKEN_ZZ_TEST_PRODUCTION" \
  RIVI_ENV_FILE="$TMP/tokens.env" -- zz-test
if [[ -f "$ROOT/dist/zz-test/Package.swift" ]] && ! grep -rqF "$GOOD_STAGING" "$ROOT/dist/zz-test/Sources" "$ROOT/dist/zz-test/Package.swift"; then
  passed=$((passed + 1)); echo "ok   the generated sources carry no token"
else
  failed=$((failed + 1)); echo "FAIL the generated sources carry no token"
fi
if [[ ! -d "$ROOT/.tenant-build/zz-test" ]]; then
  passed=$((passed + 1)); echo "ok   the token-bearing work folder is gone"
else
  failed=$((failed + 1)); echo "FAIL the token-bearing work folder is gone"
fi

echo "$passed passed, $failed failed"
[[ $failed -eq 0 ]]
