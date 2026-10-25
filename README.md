# RiviSmartSort

![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)
![iOS](https://img.shields.io/badge/iOS-16.0+-blue.svg)
![SPM](https://img.shields.io/badge/SPM-compatible-green.svg)

AI-powered sorting for flight and hotel search results on iOS. Users describe what they want in
plain language, and Smart Sort ranks your results by it.

Your app tells the SDK what's on screen and applies the ranking it gets back. The SDK handles
everything else: requests, live ranking updates, chips, the explanation banner, notices and
confirmations.

## Requirements

* iOS 16.0+
* Swift 5.9+

## Installation

Add your tenant package (`RiviSmartSort<YourCompany>`) with Swift Package Manager:
**File > Add Packages...**, then enter the package URL you were given.

The tenant package contains your configuration and tokens, and re-exports the whole SDK.

## Quick start

The Smart Sort design: a floating Smart Sort button, a results banner that streams its
explanation, prompt cards in the results list and the filter sheet, and an ask sheet. Start with
the [Quickstart](docsV2/quickstart.md).

```swift
import SwiftUI
import RiviSmartSortYourCompany   // your tenant package

struct ResultsScreen: View {
    @StateObject private var smartSort = RiviSmartSort(
        build: .bundled, environment: .production, locale: "en", currency: "USD")
    @State private var showSmartSort = false

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                RiviSmartSortV2Banner(smartSort,
                                      onEdit: { showSmartSort = true },
                                      onClearFilters: { /* clear your filters */ })
                // your results, with SmartSortPromptResultCard after the 4th while no query is active
            }
            RiviSmartSortButton(smartSort) { showSmartSort = true }
        }
        .sheet(isPresented: $showSmartSort) {
            RiviSmartSortV2BottomSheet(smartSort, isPresented: $showSmartSort)
        }
        .riviSmartSortConfirmation(smartSort)
        .onAppear {
            // Set onEvent before reporting the search, so you don't miss the first ranking
            smartSort.onEvent = { event in
                if case let .ranking(ranking, _, _) = event { reorder(by: ranking.map(\.id)) }
            }
            smartSort.search = .flight(FlightSearch(
                searchId: searchId, tripType: .oneway, origin: "JFK", destination: "LHR",
                departureDate: RiviDate.string(from: departure), pax: .init(adults: 1)))
        }
        // Also report: smartSort.sort, smartSort.filters, smartSort.visible (see the guide)
    }
}
```

The example project's **Reference** tab is a complete V2 results screen (flights and hotels) to
copy from.

## Documentation

Start with [Install](docsV2/install.md):

* [Install](docsV2/install.md): requirements, registry access, adding your tenant package, environments
* [Quickstart](docsV2/quickstart.md): a minimal results screen that shows a ranking
* [Integration guide](docsV2/integration_guide.md): every step, with a pre-ship checklist
* [Reference](docsV2/reference.md): the session API, events, views, behaviour rules, logging
* [Styling guide](docsV2/styling.md): match the views to your app: every configuration property, dark mode, RTL, reduced motion
* [Troubleshooting](docsV2/troubleshooting.md): symptoms and fixes, error kinds, log messages
* [Migrate from V1](docsV2/migrate_from_v1.md): from RiviAskAI to RiviSmartSort

## Features

* Natural-language ranking for flights and hotels
* Live ranking updates while results stream in
* Ready-made SwiftUI views: Smart Sort button, ask sheet, streaming results banner with filter
  notices, prompt cards for the results list and the filter sheet, sort confirmation
* Fully customizable views, or build your own from the session's state
* English and Arabic, with RTL layout
* Tokens bundled in your tenant package, never logged, rotated by a new package release

## Example project

`RiviSmartSortExample/RiviSmartSortExample.xcodeproj` has two tabs:

* **Reference integration:** a complete results screen for flights and hotels.
* **Demo:** every view on its own, with simulated states. Paste a `searchId` from a real search
  to see live rankings.

## Support

* Your Rivi integration contact (the team that sent you your package URL)
