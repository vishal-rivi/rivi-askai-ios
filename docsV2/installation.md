---
title: Install
sidebar_position: 1
slug: install
---

# Installation

Add Smart Sort to your iOS app. Start here; next, build the [Quickstart](quickstart.md).

RiviSmartSort (Smart Sort 2.0) is a Swift package that ranks flight and hotel search results by
what the user asks for in plain language ("leave after work and land before midnight", "4 stars or
more with a pool"). Your app reports facts to the SDK (the search, the sort tab, the filters and the
results it shows), orders its list by the ranking it gets back, and places the views. The SDK
handles everything else. Moving from RiviAskAI? See [Migrate from V1](migrate_from_v1.md).

---

## Requirements

| Requirement | Version |
|---|---|
| iOS | 16.0+ |
| Swift | 5.9+ |
| Xcode | 15.0+ |
| UI framework | SwiftUI. From UIKit, host the views with `UIHostingController` |
| Network | Access to the Rivi gateway (`askai-gateway.rivi.co`, and `askai-gateway-staging.rivi.co` for staging) |

The gateway hosts keep the product's former name, Ask AI.

---

## Registry Access

You integrate through a tenant package named `RiviSmartSort<YourCompany>`, not the bare SDK. Rivi
gives you its package URL and access to the repository it lives in. The examples in these docs use
`RiviSmartSortYourCompany`: replace it with your package's name.

---

## Add the Dependency

### Swift Package Manager (SPM)

1. In Xcode, select File > Add Packages...
2. Enter the package repository URL you were given
3. Select the latest version
4. Click Add Package

Then import it where you build your results screen:

```swift
import RiviSmartSortYourCompany   // your tenant package
```

### What the Tenant Package Contains

* Configuration: Your tenant's name and tier, and the staging and production gateways
* Tokens: Bundled in, so you never pass a token or an endpoint in code
* The Whole SDK: Re-exported, so the tenant package is the only import you need
* Isolation: No tenant package contains another tenant's configuration or token

**Note:** When a token is rotated, Rivi ships a rebuilt package. To bridge the gap before you update, pass `auth:` when creating the session (see [Reference > Creating a Session](reference.md#1-creating-a-session)).

### Modules

Your tenant package re-exports all of these:

* RiviSmartSortUI: `RiviSmartSort`, the session object, and the views bound to it
* RiviSmartSortElements: The underlying SwiftUI views and their configuration
* RiviSmartSortRuntime: Networking, the ranking stream, timers, logging
* RiviSmartSortContract: Types and the Smart Sort rules

---

## Environments

* `.staging`: Development and QA
* `.production`: Release builds (the default)

You choose the environment when you create the session (see [Integration guide > Step 1](integration_guide.md#step-1-initialise-the-sdk)).

---

## Verify It Works

Create a session with debug logging and report a search with a real `searchId`:

```swift
let smartSort = RiviSmartSort(build: .bundled, environment: .staging,
                              currency: "USD", logLevel: .debug)
smartSort.onEvent = { event in print(event) }
smartSort.search = .flight(FlightSearch(
    searchId: searchId, tripType: .oneway, origin: "JFK", destination: "LHR",
    departureDate: RiviDate.string(from: departure), pax: .init(adults: 1)))
```

You should see a POST and a GET request block in the console, then a `.ranking` event. If not, see
[Troubleshooting](troubleshooting.md).

---

## Example Project

`RiviSmartSortExample/RiviSmartSortExample.xcodeproj` has two tabs:

* Reference: A complete results screen for flights and hotels that follows the [Integration guide](integration_guide.md)
* Demo: Every view on its own, with simulated states. Paste a `searchId` from a real search to see live rankings

---

## Support

Your Rivi integration contact (the team that sent you your package URL).

---

**Next:** [Quickstart](quickstart.md)
