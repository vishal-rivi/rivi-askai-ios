---
title: Quickstart
sidebar_position: 2
slug: quickstart
---

# Quickstart

A minimal results screen that shows a Smart Sort ranking. [Install](install.md) your tenant package
first. The [Integration guide](integration_guide.md) explains each line.

---

## The Screen

```swift
import SwiftUI
import RiviSmartSortYourCompany   // your tenant package

// searchId, departure and reorder(by:) are your app's: the id of the results on screen,
// the departure Date, and a function that reorders your list by these ids.
struct ResultsScreen: View {
    // 1. The session: the root of Smart Sort for this screen
    @StateObject private var smartSort = RiviSmartSort(
        build: .bundled, environment: .production, locale: "en", currency: "USD")
    @State private var showSmartSort = false

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                // 3 + 4. The banner: chips and the Explain AI text
                RiviSmartSortV2Banner(smartSort,
                                      onEdit: { showSmartSort = true },
                                      onClearFilters: { /* clear your filters */ })
                // your result cards, with their tags (5),
                // and SmartSortPromptResultCard after the 4th while no query is active
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
            // 2. Reporting the search starts Sort Best
            smartSort.search = .flight(FlightSearch(
                searchId: searchId, tripType: .oneway, origin: "JFK", destination: "LHR",
                departureDate: RiviDate.string(from: departure), pax: .init(adults: 1)))
        }
        // Also report: smartSort.sort, smartSort.filters, smartSort.visible
    }
}
```

The numbers match the steps of the [Integration guide](integration_guide.md).

---

## You Should Now See

1. Your results reorder by Rivi's Sort Best ranking shortly after the screen appears.
2. The Smart Sort button at the bottom. Tap it to open the sheet.
3. Type a request, such as "Direct flights that land before 4 PM", and tap **Improve Results**.
4. The banner appears above your results with chips for the request, a loading state, then the
   Explain AI text. Your results reorder again.
5. Tap **✕** on the banner: the chips go away and Sort Best runs again.

If the list doesn't reorder, see [Troubleshooting](troubleshooting.md).

---

## Next Steps

* Report your sort tab, filters and visible results: [Integration guide > Step 2](integration_guide.md#step-2-sort-best)
* Add the prompt cards and result tags: [Integration guide > Steps 3 and 5](integration_guide.md#step-3-set-up-the-components)
* Ranking your own, paged result list: [Integration guide > Step 6](integration_guide.md#step-6-good-to-have)

---

**Next:** [Integration guide](integration_guide.md)
