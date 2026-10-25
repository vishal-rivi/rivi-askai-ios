#!/usr/bin/env python3 -I
"""Generates the sources of one Smart Sort tenant build (spec D10; web: scripts/gen-tenant.ts).

  gen_tenant.py secrets <tenant> <out.swift>        RiviTenantSecrets.swift (contains the tokens)
  gen_tenant.py package <tenant> <dist dir> <xcframework name>
                                                    Package.swift, the shim source and README.md
  gen_tenant.py verify <tenant> <dist dir>          the output holds this tenant's tokens and
                                                    staging URL, and no other tenant's token

Inputs: tenants/<tenant>.json (name, tier, environments.{staging,production}.baseUrl) and the
environment variables RIVI_TOKEN_<TENANT>_STAGING / _PRODUCTION. A missing or empty token fails.
RIVI_SDK_URL + RIVI_SDK_VERSION choose the shared package the tenant package depends on; without
them it points at this checkout (local verification only).

The checks mirror the web's (smart-sort-elements/scripts/gen-tenant.ts, build-tenant.ts).
"""
import json
import os
import re
import sys
from urllib.parse import urlsplit

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
# Overridable for the script's own tests.
TENANTS_DIR = os.environ.get("RIVI_TENANTS_DIR") or os.path.join(ROOT, "tenants")
TENANT_ID = re.compile(r"^[a-z0-9]+(-[a-z0-9]+)*$")
TOKEN_ENV = re.compile(r"^RIVI_TOKEN_([A-Z0-9_]+)_(STAGING|PRODUCTION)$")
# Swift stores strings of up to 15 UTF-8 bytes inline in code, not as contiguous bytes, so only
# longer values can be found in a binary. Real tokens are 64 characters.
INLINE_STRING_MAX = 15


def fail(message):
    sys.stderr.write(f"build-tenant: {message}\n")
    sys.exit(1)


def assert_tenant_id(tenant):
    if not TENANT_ID.match(tenant):
        fail(f'tenant "{tenant}" must be lowercase letters and digits, joined by single hyphens')


def env_key(tenant):
    return tenant.upper().replace("-", "_")


def module_name(tenant):
    return "RiviSmartSort" + "".join(part.capitalize() for part in re.split(r"[^A-Za-z0-9]+", tenant) if part)


def swift_string(value):
    out = []
    for ch in value:
        if ch in '"\\':
            out.append("\\" + ch)
        elif ch == "\n":
            out.append("\\n")
        elif ord(ch) < 0x20:
            out.append("\\u{%x}" % ord(ch))
        else:
            out.append(ch)
    return '"' + "".join(out) + '"'


def load_tenant(tenant):
    """Parses and checks tenants/<tenant>.json. It must never carry a token."""
    assert_tenant_id(tenant)
    path = os.path.join(TENANTS_DIR, f"{tenant}.json")
    if not os.path.isfile(path):
        known = sorted(f[:-5] for f in os.listdir(TENANTS_DIR) if f.endswith(".json"))
        fail(f"no tenants/{tenant}.json (known: {', '.join(known)})")
    with open(path, encoding="utf-8") as handle:
        try:
            raw = json.load(handle)
        except json.JSONDecodeError as error:
            fail(f"tenants/{tenant}.json is not JSON: {error}")
    if not isinstance(raw, dict):
        fail(f"tenants/{tenant}.json must be an object")
    problems = [f'unknown key "{key}"' for key in raw if key not in ("name", "tier", "environments")]
    if '"token"' in json.dumps(raw).lower():
        problems.append("tokens never go in tenants/*.json; they come from CI secrets")
    for key in ("name", "tier"):
        if not isinstance(raw.get(key), str) or not raw[key].strip():
            problems.append(f'"{key}" must be a non-empty string')
    envs = raw.get("environments") if isinstance(raw.get("environments"), dict) else {}
    base = {}
    for environment in ("staging", "production"):
        entry = envs.get(environment)
        url = entry.get("baseUrl") if isinstance(entry, dict) else None
        if not isinstance(url, str):
            problems.append(f"environments.{environment}.baseUrl is required")
            continue
        parts = urlsplit(url)
        if not parts.scheme or not parts.netloc:
            problems.append(f"environments.{environment}.baseUrl is not a URL")
            continue
        if parts.scheme != "https":
            problems.append(f"environments.{environment}.baseUrl must be https")
        if url.endswith("/") or parts.query or parts.fragment or "?" in url or "#" in url:
            problems.append(f"environments.{environment}.baseUrl must have no trailing slash, query or hash")
        base[environment] = url
    if problems:
        fail(f"tenants/{tenant}.json:\n  " + "\n  ".join(problems))
    return {"name": raw["name"], "tier": raw["tier"], "staging": base["staging"], "production": base["production"]}


def has_space_or_control(value):
    return any(ch.isspace() or ord(ch) < 0x20 or ord(ch) == 0x7F for ch in value)


def tokens(tenant):
    key = env_key(tenant)
    found = {}
    for environment in ("staging", "production"):
        name = f"RIVI_TOKEN_{key}_{environment.upper()}"
        value = os.environ.get(name, "").strip()
        if not value:
            fail(f"{name} is missing or empty; tenant builds need both tokens "
                 "(GitHub Actions secret, or a line in the gitignored .env)")
        if has_space_or_control(value):
            fail(f"{name} contains whitespace or control characters")
        found[environment] = value
    return found


def write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as handle:
        handle.write(text)


def secrets(tenant, out):
    config = load_tenant(tenant)
    secret = tokens(tenant)
    # Computed members, not stored constants: their bodies are not inlinable, so the values stay
    # in the binary and never reach the plain-text .swiftinterface.
    write(out, f"""// Generated by scripts/build-tenant.sh for "{tenant}". Contains tokens: never commit.

public enum RiviTenantSecrets {{
    public static var name: String {{ {swift_string(config['name'])} }}
    public static var tier: String {{ {swift_string(config['tier'])} }}

    public static func baseURL(production: Bool) -> String {{
        production ? {swift_string(config['production'])} : {swift_string(config['staging'])}
    }}

    public static func token(production: Bool) -> String {{
        production ? {swift_string(secret['production'])} : {swift_string(secret['staging'])}
    }}
}}
""")
    # The tokens, for the script's leak check over the generated interfaces.
    print(secret["staging"])
    print(secret["production"])


def sdk_dependency():
    url = os.environ.get("RIVI_SDK_URL", "").strip()
    version = os.environ.get("RIVI_SDK_VERSION", "").strip()
    if url:
        if not version:
            fail("RIVI_SDK_URL needs RIVI_SDK_VERSION (e.g. 2.0.0)")
        identity = re.sub(r"\.git$", "", url.rstrip("/").split("/")[-1]).lower()
        return f'.package(url: {swift_string(url)}, from: {swift_string(version)})', identity, False
    sys.stderr.write("build-tenant: RIVI_SDK_URL not set; the package depends on this checkout (local use only)\n")
    return f".package(path: {swift_string(ROOT)})", os.path.basename(ROOT).lower(), True


def package(tenant, dist, xcframework):
    config = load_tenant(tenant)
    module = module_name(tenant)
    dependency, identity, local = sdk_dependency()
    write(os.path.join(dist, "Package.swift"), f"""// swift-tools-version: 5.9
// Generated by scripts/build-tenant.sh for "{tenant}". Smart Sort for {config['name']} ({config['tier']}).

import PackageDescription

let package = Package(
    name: "{module}",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "{module}", targets: ["{module}"]),
    ],
    dependencies: [
        {dependency},
    ],
    targets: [
        // This tenant's name, tier, gateways and tokens. No other tenant's are in it.
        .binaryTarget(name: "RiviTenantSecrets", path: "{xcframework}"),
        .target(
            name: "{module}",
            dependencies: [
                "RiviTenantSecrets",
                .product(name: "RiviSmartSort", package: "{identity}"),
            ]
        ),
    ]
)
""")
    write(os.path.join(dist, "Sources", module, "Tenant.swift"), f"""// Generated by scripts/build-tenant.sh for "{tenant}". No secrets here: they live in RiviTenantSecrets.

@_exported import RiviSmartSortElements
@_exported import RiviSmartSortContract
@_exported import RiviSmartSortRuntime
@_exported import RiviSmartSortUI
import RiviTenantSecrets

extension RiviTenantBuild {{
    /// {config['name']}'s bundled configuration: tenant, gateways and tokens.
    public static let bundled = RiviTenantBuild(
        tenant: RiviTenant(name: RiviTenantSecrets.name, tier: RiviTenantSecrets.tier),
        stagingBaseURL: RiviTenantSecrets.baseURL(production: false),
        productionBaseURL: RiviTenantSecrets.baseURL(production: true),
        token: {{ RiviTenantSecrets.token(production: $0 == .production) }}
    )
}}
""")
    note = ("\n> Built against a local checkout (`RIVI_SDK_URL` was not set): for local verification only.\n"
            if local else "")
    write(os.path.join(dist, "README.md"), f"""# {module}

Smart Sort for **{config['name']}** (tier `{config['tier']}`). The tenant, the gateways and the
tokens are bundled: the app passes neither a token nor an endpoint.
{note}
## Install

Add this package (Swift Package Manager), then:

```swift
import {module}

@StateObject private var smartSort = RiviSmartSort(
    build: .bundled,
    environment: .production,   // or .staging
    locale: "ar",
    currency: "SAR"
)
```

Everything else is the shared Smart Sort API: see `docsV2/integration_guide.md` in the SDK.

A rotated token needs a rebuilt package. To bridge the gap, pass `auth:` to override the
bundled token.

**This package contains credentials.** Keep its repository private to {config['name']}.
""")


def files_under(directory):
    for base, _, names in os.walk(directory):
        for name in names:
            yield os.path.join(base, name)


def contains(paths, needle):
    data = needle.encode("utf-8")
    for path in paths:
        with open(path, "rb") as handle:
            if data in handle.read():
                return True
    return False


def verify(tenant, dist):
    """Fails if the output lacks its own tokens and staging URL (the generated config was not
    used), or any file contains a token of another tenant present in the environment. Prints
    variable names, never values."""
    config = load_tenant(tenant)
    own = tokens(tenant)
    paths = list(files_under(dist))
    if not paths:
        fail(f"{dist} is empty")
    binaries = [p for p in paths if os.path.basename(p) == "RiviTenantSecrets"]
    if not binaries:
        fail("the build has no RiviTenantSecrets binary")
    checks = [(f"RIVI_TOKEN_{env_key(tenant)}_{env.upper()}", own[env]) for env in ("staging", "production")]
    checks.append(("the staging base URL", config["staging"]))
    for label, value in checks:
        if len(value.encode("utf-8")) <= INLINE_STRING_MAX:
            continue
        for binary in binaries:
            if not contains([binary], value):
                fail(f"{os.path.relpath(binary, dist)} lacks {label}; the generated config was not used")
    key = env_key(tenant)
    for name, value in sorted(os.environ.items()):
        match = TOKEN_ENV.match(name)
        value = value.strip()
        if not match or match.group(1) == key or not value or value in own.values():
            continue
        if contains(paths, value):
            fail(f"the {tenant} build contains {name}; refusing to continue")


def main(argv):
    if len(argv) >= 4 and argv[1] == "secrets":
        secrets(argv[2], argv[3])
    elif len(argv) >= 5 and argv[1] == "package":
        package(argv[2], argv[3], argv[4])
    elif len(argv) >= 4 and argv[1] == "verify":
        verify(argv[2], argv[3])
    elif len(argv) >= 3 and argv[1] == "module":
        print(module_name(argv[2]))
    else:
        fail(__doc__)


if __name__ == "__main__":
    main(sys.argv)
