#!/usr/bin/env bash
# Builds the Smart Sort package for one tenant (spec D10), into dist/<tenant>/:
#
#   RiviTenantSecrets.xcframework   the tenant's name, tier, gateways and tokens (iOS + simulator)
#   RiviTenantSecrets.xcframework.zip + .checksum   for hosting it behind a URL instead
#   Package.swift, Sources/RiviSmartSort<Tenant>/   the package the tenant adds
#
# Usage:
#   RIVI_TOKEN_ALMATAR_STAGING=… RIVI_TOKEN_ALMATAR_PRODUCTION=… scripts/build-tenant.sh almatar
#   RIVI_SDK_URL=https://github.com/vishal-rivi/rivi-askai-ios.git RIVI_SDK_VERSION=2.0.0 scripts/build-tenant.sh almatar
#
# Tokens come from the environment (GitHub Actions secrets) or a dotenv file: RIVI_ENV_FILE=<path>,
# else the gitignored .env at the repo root. Only RIVI_TOKEN_* lines are read from the file, and a
# variable already defined (even empty) is never overridden, so a CI secret always wins. A missing
# token fails the build. dist/ holds credentials: it is gitignored, and each tenant's package goes
# only to that tenant's private repository. The checks mirror the web's tenant build.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TENANT="${1:?usage: scripts/build-tenant.sh <tenant>  (tenants: $(ls "$ROOT/tenants" | sed 's/\.json$//' | tr '\n' ' '))}"
GEN=(/usr/bin/python3 -I "$ROOT/scripts/lib/gen_tenant.py")
MIN_IOS=16.0
FRAMEWORK=RiviTenantSecrets

# A dotenv file supplies the tokens locally (web: scripts/lib/env-file.ts). Only RIVI_TOKEN_* names
# are read, and a name already defined, even as an empty string, is left alone.
ENV_FILE="${RIVI_ENV_FILE:-$ROOT/.env}"
if [[ -n "${RIVI_ENV_FILE:-}" && ! -f "$ENV_FILE" ]]; then
  echo "build-tenant: RIVI_ENV_FILE=$RIVI_ENV_FILE does not exist" >&2
  exit 1
fi
if [[ -f "$ENV_FILE" ]]; then
  loaded=()
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line#export }"
    [[ "$line" =~ ^[[:space:]]*(RIVI_TOKEN_[A-Z0-9_]+)[[:space:]]*=(.*)$ ]] || continue
    key="${BASH_REMATCH[1]}"
    value="${BASH_REMATCH[2]}"
    value="${value#"${value%%[![:space:]]*}"}"   # trim leading spaces
    value="${value%"${value##*[![:space:]]}"}"   # trim trailing spaces
    if [[ "$value" =~ ^\"(.*)\"$ || "$value" =~ ^\'(.*)\'$ ]]; then value="${BASH_REMATCH[1]}"; fi
    [[ -n "${!key+x}" ]] && continue
    export "$key=$value"
    loaded+=("$key")
  done < "$ENV_FILE"
  [[ ${#loaded[@]} -gt 0 ]] && echo "build-tenant: loaded ${loaded[*]} from ${ENV_FILE#"$ROOT"/}"
fi

WORK="$ROOT/.tenant-build/$TENANT"
DIST="$ROOT/dist/$TENANT"
rm -rf "$WORK" && mkdir -p "$WORK"
# The generated secrets source holds the tokens in plain text: never leave it behind.
trap 'rm -rf "$WORK"' EXIT

"${GEN[@]}" secrets "$TENANT" "$WORK/$FRAMEWORK.swift" > "$WORK/tokens"

# One slice per target triple, compiled for library evolution so any later Swift compiler can use it.
compile() { # <triple> <sdk> <out dir>
  mkdir -p "$3"
  xcrun --sdk "$2" swiftc "$WORK/$FRAMEWORK.swift" \
    -parse-as-library -module-name "$FRAMEWORK" -target "$1" -swift-version 5 \
    -sdk "$(xcrun --sdk "$2" --show-sdk-path)" \
    -enable-library-evolution -O -whole-module-optimization \
    -emit-library -static -o "$3/lib$FRAMEWORK.a" \
    -emit-module -emit-module-path "$3/$FRAMEWORK.swiftmodule" \
    -emit-module-interface-path "$3/$FRAMEWORK.swiftinterface"
}

# <dir> <platform name> <arch triple prefixes…>: a static framework bundle.
assemble() {
  local dir="$1" platform="$2"; shift 2
  local fw="$dir/$FRAMEWORK.framework"
  mkdir -p "$fw/Modules/$FRAMEWORK.swiftmodule"
  local libs=()
  for slice in "$@"; do
    local name="${slice%%|*}" out="${slice#*|}"
    libs+=("$out/lib$FRAMEWORK.a")
    cp "$out/$FRAMEWORK.swiftinterface" "$fw/Modules/$FRAMEWORK.swiftmodule/$name.swiftinterface"
    cp "$out/$FRAMEWORK.swiftmodule" "$fw/Modules/$FRAMEWORK.swiftmodule/$name.swiftmodule"
  done
  xcrun lipo -create "${libs[@]}" -output "$fw/$FRAMEWORK"
  cat > "$fw/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key><string>$FRAMEWORK</string>
  <key>CFBundleIdentifier</key><string>co.rivi.smartsort.tenant.$TENANT</string>
  <key>CFBundleName</key><string>$FRAMEWORK</string>
  <key>CFBundlePackageType</key><string>FMWK</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>CFBundleSupportedPlatforms</key><array><string>$platform</string></array>
  <key>MinimumOSVersion</key><string>$MIN_IOS</string>
</dict>
</plist>
PLIST
}

echo "build-tenant: compiling $FRAMEWORK for $TENANT"
compile "arm64-apple-ios$MIN_IOS" iphoneos "$WORK/ios-arm64"
compile "arm64-apple-ios$MIN_IOS-simulator" iphonesimulator "$WORK/sim-arm64"
compile "x86_64-apple-ios$MIN_IOS-simulator" iphonesimulator "$WORK/sim-x86_64"
assemble "$WORK/fw/ios" iPhoneOS "arm64-apple-ios|$WORK/ios-arm64"
assemble "$WORK/fw/sim" iPhoneSimulator \
  "arm64-apple-ios-simulator|$WORK/sim-arm64" "x86_64-apple-ios-simulator|$WORK/sim-x86_64"

# The interfaces are plain text that ships with the framework: no token may be in them. grep exits 1
# for "not found"; anything else (an error) also stops the build.
interfaces=()
while IFS= read -r -d '' file; do interfaces+=("$file"); done < <(find "$WORK/fw" -name '*.swiftinterface' -print0)
[[ ${#interfaces[@]} -gt 0 ]] || { echo "build-tenant: no .swiftinterface was produced" >&2; exit 1; }
while IFS= read -r token; do
  set +e
  grep -qF -e "$token" "${interfaces[@]}"
  found=$?
  set -e
  if [[ $found -eq 0 ]]; then
    echo "build-tenant: a token leaked into a .swiftinterface; aborting" >&2
    exit 1
  elif [[ $found -ne 1 ]]; then
    echo "build-tenant: could not check the interfaces for tokens; aborting" >&2
    exit 1
  fi
done < "$WORK/tokens"

rm -rf "$DIST" && mkdir -p "$DIST"
xcodebuild -create-xcframework \
  -framework "$WORK/fw/ios/$FRAMEWORK.framework" \
  -framework "$WORK/fw/sim/$FRAMEWORK.framework" \
  -output "$DIST/$FRAMEWORK.xcframework" > /dev/null

"${GEN[@]}" package "$TENANT" "$DIST" "$FRAMEWORK.xcframework"
"${GEN[@]}" verify "$TENANT" "$DIST"

(cd "$DIST" && zip -qry "$FRAMEWORK.xcframework.zip" "$FRAMEWORK.xcframework" \
  && swift package compute-checksum "$FRAMEWORK.xcframework.zip" > "$FRAMEWORK.xcframework.checksum" \
  && rm -rf .build)

MODULE="$("${GEN[@]}" module "$TENANT")"
echo "build-tenant: wrote dist/$TENANT ($MODULE)"
echo "  checksum $(cat "$DIST/$FRAMEWORK.xcframework.checksum")"
