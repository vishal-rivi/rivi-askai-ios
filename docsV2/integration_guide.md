---
title: Integration guide
sidebar_position: 3
slug: integration-guide
---

# Integration Guide

Wire Smart Sort into a results screen, step by step. [Install](install.md) the SDK and try the [Quickstart](quickstart.md) first. Every option is in the [Reference](reference.md), and everything the SDK decides on its own is in [Reference > Behaviour Rules](reference.md#behaviour-rules).

**Recommended Flow:**

1. Initialise the SDK: import your tenant package and create the session
2. Report the search: the SDK runs Sort Best and you apply the ranking
3. Set up the components: banner, button, sheet and prompt cards
4. Explain AI: shown by the banner, nothing to call
5. Result tags: show them on your result cards
6. Good to have: Hybrid Smart Sort and filter notices
7. Other optional features

**See it working:** build the [Quickstart](quickstart.md), or run the **Reference** tab of RiviSmartSortExample/RiviSmartSortExample.xcodeproj. It is wired as this guide describes.

---

## Complete Integration Example

### Step 1: Initialise the SDK

Smart Sort has no app-wide provider. Its root is one **`RiviSmartSort` session per results
screen**: it holds the state, makes every request, and every Smart Sort view on the screen reads
from it.

#### Import

```swift
import RiviSmartSortYourCompany   // your tenant package; it re-exports the whole SDK
```

#### Create the Session

Create it once and keep it for the life of the screen, with `@StateObject`:

**Example:**

```swift
@StateObject private var smartSort = RiviSmartSort(
    build: .bundled,            // required: your tenant package's configuration and tokens
    environment: .production,   // .production (default) or .staging
    locale: "en",               // "en" (default) or "ar"; drives wording and RTL
    currency: "USD"             // required: ISO currency code
)
```

**Parameters:**

* `build` (required): `.bundled`: the tenant, gateway and token from your tenant package
* `currency` (required): ISO code, e.g. `"USD"`
* `environment` (optional): `.production` (default) or `.staging`
* `locale` (optional): `"en"` (default) or `"ar"`

Optional parameters (`metadata`, `strings`, `auth`, `logLevel`, `logger`) are covered in Step 7.

#### Language and Layout

To show Smart Sort in Arabic, pass `locale: "ar"`. That's the only change you need:

```swift
@StateObject private var smartSort = RiviSmartSort(
    build: .bundled, locale: "ar", currency: "USD")
```

* All SDK wording switches to Arabic: the button, the sheet, the banner, chips, notices, errors and the confirmation
* The ask and Explain AI requests are sent in Arabic, so the explanation comes back in Arabic
* The SDK's views switch to right-to-left layout by themselves

To switch at runtime, call `smartSort.setLocale("ar")` (or `"en"`). The SDK's views and the chips switch straight away. An explanation already on screen stays in the old language until the user asks again.

**Note:** The Smart Sort button, the twinkle label and the prompt cards follow your screen's layout direction. In an app that's already right-to-left for Arabic there's nothing to do. Your own views (result cards, filter sheet) follow your app as usual.

#### Share It with Child Views

Pass the session to the views that need it. Because it's an `ObservableObject`, you can also put
it in the environment, which works like a context provider:

```swift
ResultsList()
    .environmentObject(smartSort)

// in a child view
@EnvironmentObject private var smartSort: RiviSmartSort
```

**Important Notes:**

* Don't create a second session for the same screen: each session opens its own ranking stream
* Call `destroy()` when the screen goes away

#### Listen to Events

Set `onEvent` before you report the search, so you don't miss the first ranking:

```swift
smartSort.onEvent = { event in
    switch event {
    case let .ranking(ranking, all, status): reorder(by: ranking.map(\.id))   // Step 2
    case .rankingCleared:                     useYourOwnOrder()
    case .sortChanged(.best):                 selectedTab = .best
    case .showHidden(let ids):                reveal(ids)                    // Step 6
    case .error(let error):                   log(error.message)             // the views already show it
    default:                                  break
    }
}
```

With Swift concurrency instead: `for await event in smartSort.events { … }`.

#### Add the Confirmation

Once, on the screen. When the user changes sort tab with an active query, it shows "Clear Ask AI
Query" ("Your active query will be cleared in order to change the sorting. Do you wish to
proceed?") with **Back** and **Proceed**:

```swift
.riviSmartSortConfirmation(smartSort)
```

#### Clean Up

Call `smartSort.destroy()` when the results screen is dismissed for good (for example when
the user leaves the search flow). Don't call it from a plain `.onDisappear`: that also fires when
you push a detail screen or switch tabs, and a destroyed session can't be restarted. Deinit also
calls it.

---

### Step 2: Sort Best

**Sort Best** is Rivi's default ranking of your results, before the user has typed anything. You
don't call it: the SDK sends it as soon as you report a search, and again whenever the user clears
their query. Your job is to pass the right parameters and apply the order you get back.

#### Pass the Search

Set `search` every time a new search runs. A new `searchId` resets Smart Sort and starts a new
Sort Best.

```swift
// Flights
smartSort.search = .flight(FlightSearch(
    searchId: searchId,                                // the id of the results on screen
    tripType: .oneway,                                 // .oneway, .round, .multicity
    origin: "JFK", destination: "LHR",
    departureDate: RiviDate.string(from: departure),   // "2026-10-14T09:31:18.000Z"
    returnDate: nil,                                   // set for .round
    cabin: .economy,
    pax: .init(adults: 1, children: 0, infants: 0)
))

// Hotels
smartSort.search = .hotel(HotelSearch(
    searchId: searchId,
    destination: "London",
    checkin: RiviDate.string(from: checkin),
    checkout: RiviDate.string(from: checkout),
    rooms: 1,
    pax: .init(adults: 2, children: 0)
))
```

**Flight Parameters:**

* `searchId` (required): The id Rivi's search returned for the results on screen
* `tripType` (required): `.oneway`, `.round` or `.multicity` (Smart Sort is off for multi-city)
* `origin`, `destination` (required): Airport or city codes, e.g. `"JFK"`
* `departureDate` (required): `RiviDate.string(from:)`
* `returnDate` (required for round trips): `RiviDate.string(from:)`
* `cabin` (optional): `.economy`, `.premium`, `.business`, `.first`
* `pax` (required): `.init(adults:children:infants:)`

**Hotel Parameters:**

* `searchId` (required): As above
* `destination` (required): The city
* `checkin`, `checkout` (required): `RiviDate.string(from:)`
* `rooms` (required): Number of rooms
* `pax` (required): `.init(adults:children:)`

Dates go to the gateway exactly as you pass them; always use `RiviDate.string(from:)`.

#### Report the Rest of the Screen

Set these whenever they change. Setting the same value again does nothing.

```swift
// Your sort tab. Only "Best" is Smart Sort's; report any other tab as .other.
smartSort.sort = selectedTab == .best ? .best : .other

// Round trips: which leg is showing. Smart Sort is off on the return leg.
smartSort.stage = .onward

// Your applied filters, as any JSON your backend understands. nil = none.
smartSort.filters = ["stops": [0, 1], "airlines": ["BA"]]

// Recommended: the ids you actually show after your filters, in order.
smartSort.visible = shownIds
```

To report several at once: `smartSort.update(sort: .best, filters: .some(nil), visible: shownIds)`.

Reporting filters never makes a request. Sort Best (and every later request) carries the filters
you last reported, as-is:

```json
{
  "search_id": "8f2c…",
  "query_type": "flight",
  "is_round": false,
  "filters": { "stops": [0], "airlines": ["BA"] },
  …
}
```

#### Apply the Ranking

The SDK never reorders your list. It sends `.ranking` and you apply it:

```swift
case let .ranking(ranking, all, status):
    reorder(by: ranking.map(\.id))
```

**Event Values:**

* `ranking`: Rivi's order while your Best tab is selected. **Empty on your other tabs**: use your own order there
* `all`: Every ranked result, whatever the tab. Use it if your items come only from Rivi
* `status`: `.provisional` while results are still arriving, `.final` once the ranking has settled

A simple way to apply it. `ResultItem` is your result model, `bestOrder` holds the ids from the
last `.ranking` event, and `yourOwnOrder` is your app's own sort:

```swift
func ordered(_ items: [ResultItem]) -> [ResultItem] {
    guard selectedTab == .best, !bestOrder.isEmpty else { return items.sorted(by: yourOwnOrder) }
    let rank = Dictionary(bestOrder.enumerated().map { ($1, $0) }, uniquingKeysWith: { a, _ in a })
    return items.sorted { (rank[$0.id] ?? .max) < (rank[$1.id] ?? .max) }   // unranked items go last
}
```

**Also Handle:**

* `.rankingCleared`: the user cleared their query. Go back to your own order until the next
  Sort Best ranking arrives.
* `.sortChanged(.best)`: the user kept their query in the confirmation, or asked from another tab.
  Move your tab to Best.

---

### Step 3: Set Up the Components

All the views are bound to the session: pass `smartSort` and they fill, show and hide themselves.

#### 1. RiviSmartSortV2Banner (Results Banner)

Above your results:

```swift
RiviSmartSortV2Banner(
    smartSort,
    onEdit: { openSmartSort() },                 // required: "Edit" reopens the sheet
    onClearFilters: { myFilters = .none }        // optional: "Clear Filters" in the filter notice; nil hides it
)
```

Hidden until the user asks. Then it shows the chips (removing one asks again without it), a
loading state, and the Explain AI text (Step 4). **✕** clears Smart Sort; a failed request
shows "Couldn't update results" with **Try again**.

#### 2. RiviSmartSortButton (Smart Sort Button)

```swift
RiviSmartSortButton(smartSort) { openSmartSort() }   // configuration: .rivi for the Rivi design
```

Shows the number of active preferences and disables itself where Smart Sort isn't available. For
the twinkle label instead, wrap `SmartSortTwinkleText(count: smartSort.chips.count)` in your own
`Button` and disable it with `!smartSort.isAvailable`.

#### 3. RiviSmartSortV2BottomSheet (Smart Sort Sheet)

```swift
.sheet(isPresented: $showSmartSort) {
    RiviSmartSortV2BottomSheet(
        smartSort,
        isPresented: $showSmartSort,             // required
        focusesInputOnAppear: focusInput,        // true when opened from a prompt card
        startingExample: startingExample,        // the result card's example, or nil
        filters: myFilters.json,                 // optional: sent with this ask
        filterLabels: myFilters.labels           // optional: words for the filters line (Step 7)
    )
}
```

It restores the current query, shows suggestions and an animated placeholder. **Improve Results**
sends the query and closes the sheet; progress and errors then show in the banner.

#### 4. SmartSortPromptResultCard (Result Prompt Card)

After the 4th result, **only while no query is active**. Remember if the user dismissed it:

```swift
if index == 3 && smartSort.state.query.isEmpty && !promptDismissed && results.count >= 6 {
    SmartSortPromptResultCard(
        queryType: smartSort.queryType,
        onTap: { example in openSmartSort(focusingInput: true, startingExample: example) },
        onDismiss: { promptDismissed = true }
    )
}
```

#### 5. SmartSortPromptFilterCard (Filter Sheet Prompt Card)

At the top of your own filter sheet:

```swift
SmartSortPromptFilterCard(queryType: smartSort.queryType,
                          isHighlighted: draftFilterCount >= 4) {
    applyDraftFilters()
    opensSmartSortAfterFilters = true
    showFilters = false                // open Smart Sort once this sheet is gone
}
```

Two sheets can't be up at once. Close the filter sheet first and open Smart Sort in its
`onDismiss`:

```swift
.sheet(isPresented: $showFilters, onDismiss: {
    if opensSmartSortAfterFilters {
        opensSmartSortAfterFilters = false
        openSmartSort(focusingInput: true)
    }
}) { YourFilterSheet(…) }
```

#### 6. Opening the Sheet

The button, **Edit** and both prompt cards open the same sheet:

```swift
func openSmartSort(focusingInput: Bool = false, startingExample: String? = nil) {
    guard smartSort.isAvailable else { return }
    focusInput = focusingInput
    self.startingExample = startingExample
    showSmartSort = true
}
```

---

### Step 4: Explain AI

After the user asks, Rivi explains why the top results were picked, and the trade-offs. The SDK
requests it, streams it, and shows it in the banner. **With `RiviSmartSortV2Banner` placed, there
is nothing to implement.**

#### How It Works

1. The user asks (or removes a chip). The SDK sends the ask, which returns the extracted
   preferences (shown as chips) and the ranking.
2. 0.5 s after the first ranking of that ask arrives, the SDK calls Explain AI once with the query
   and the extracted preferences.
3. The banner shows a loading state while the text streams in, then types the explanation out.
4. If Explain AI returns no text, the banner shows a fallback line when some results only partly
   match the request, and hides otherwise.
5. When the user asks again, the old explanation stays in place until the new one arrives.

Sort Best (no query) never calls Explain AI.

#### Customising How It Looks

```swift
var config = SmartSortV2DynamicBanner.Configuration.default
config.layout = .collapsible                // "Why these flights are recommended", collapsible
config.loadingStyle = .shimmerText          // "Explaining top picks…" with a shimmer
config.streamingUnit = .character           // how the text types out
config.streamingInterval = 0.02

RiviSmartSortV2Banner(smartSort, configuration: config, onEdit: { openSmartSort() })
```

To change the fallback wording, override `explain.fallback` in `strings:` (Step 7).

#### Showing It in Your Own UI

**Session Properties:**

* `explanation`: The text so far; grows while it streams
* `isExplanationComplete`: `false` while the stream is still sending text
* `banner`: `.hidden`, `.loading`, `.refreshing`, `.explanation`, `.fallback` or `.conflict`
* `text("explain.fallback")`: The fallback line

`SmartSortStreamingText` types text out the same way the banner does:

```swift
if smartSort.banner == .explanation {
    SmartSortStreamingText(smartSort.explanation, unit: .character, interval: 0.02)
        .font(.system(size: 14))
}
```

---

### Step 5: Result Tags

Rivi tags ranked results with short, localized labels that say why each one fits the request, and
says whether each result matches every preference. The tags arrive with the ranking
(`recommendationTagList` on the wire); the SDK doesn't draw them. You show them on your own result
card.

#### Read the Tags

Nothing extra to import: the tags come with your tenant package.

```swift
smartSort.tags(for: flight.id)                    // [String], empty if unranked or off Best
smartSort.matchesAllPreferences(id: flight.id)    // Bool?, nil if unranked or off Best
```

They're also on each `RankingEntry` in the `.ranking` event (`entry.tags`,
`entry.matchesAllPreferences`). The same works for hotels.

#### Show Them on Your Card

Show tags only while a query is active, so Sort Best results stay clean:

```swift
private var hasQuery: Bool { !smartSort.state.query.isEmpty }

private func tags(for id: String) -> [String] {
    hasQuery ? smartSort.tags(for: id) : []
}

// in your card
if !tags.isEmpty {
    HStack(spacing: 6) {
        ForEach(tags, id: \.self) { tag in
            Text(tag)
                .font(.system(size: 11, weight: .medium))
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.accentColor.opacity(0.12)))
        }
    }
}
```

#### Top Result Label (Optional)

Mark the first result on Best while a query is active. When your filters are on, the top match
may be hidden, so word it accordingly. These labels are your app's own text: localize them
yourself.

```swift
func topTag(at index: Int) -> String? {
    guard index == 0, hasQuery, selectedTab == .best else { return nil }
    return filterCount == 0 ? "BEST MATCH" : "BEST IN YOUR FILTERS"
}
```

Use `matchesAllPreferences(id:)` to flag partial matches on a card if your design needs it.

---

### Step 6: Good to Have

#### Hybrid Smart Sort (Your Own Results, Ranked by Rivi)

By default the SDK assumes Rivi has the whole result list. If your list is your own and loads in
pages or chunks, tell the SDK how far loading has got with `pool`. Smart Sort then works with your
loading:

```swift
// As results load
smartSort.pool = PoolFact(size: loadedCount, complete: false)

// When loading is done
smartSort.pool = PoolFact(size: loadedCount, complete: true)
```

**What Changes Once You Report pool:**

* Sort Best waits until `size` is above 0, so it doesn't rank an empty list.
* An ask made before any results arrive is held, and sent as soon as they do.
* When `size` grows, the SDK re-ranks (batched, 0.3 s after the last growth).
* The ranking turns `.final` only after `complete` is `true`.

Apply the ranking as usual: ranked ids first in Rivi's order, the rest after in your own order (the
`ordered` function in Step 2 already does this). Leave `pool` unset when the
list comes from Rivi.

#### Filters That Hide Results

Report `visible`, the ids you actually show after your filters, and the banner tells the user when
their filters hide what they asked for:

```swift
.onChange(of: shownIds) { ids in smartSort.visible = ids }
```

**Filter Notices:**

* Yellow ("Your filters are hiding the flights you asked for."): Every result you show only partly matches, while a full match in Rivi's top 10 is hidden
* Purple ("Your filters are hiding some recommended flights. Clear Filters"): Some of Rivi's top 10 full matches are hidden
* None: No top 10 full match is hidden

**Actions:**

* **Clear Filters** calls your `onClearFilters`: clear your filters and report `filters = nil`.
* `smartSort.hiddenMatches` lists the hidden full matches. `smartSort.showHiddenMatches()` sends
  `.showHidden(ids)`: reveal those results, or simply clear your filters.

Without `visible`, the SDK can't tell what is hidden: the purple notice then shows whenever filters
are on during a query, and the yellow one never shows.

---

### Step 7: Other Optional Features

**Features:**

* Filters line in the sheet: set `showsFiltersNote = true` on a `SmartSortV2BottomSheet.Configuration`, pass it as the sheet's `configuration:`, and pass `filterLabels: ["Nonstop", "Morning"]` to the sheet: *"Your filters (Nonstop, Morning) will now be used to rank flights."*
* "Clear All" in the sheet: `showsClearAllButton = true` on the same configuration, and pass `onClearAll:` to clear your filters; Smart Sort is cleared after
* Your own confirmation dialog: `smartSort.presentsSortConfirmation = false`, handle `.confirmSortChange`, call `resolveSortConfirmation(accepted:)`
* Switch language at runtime: `smartSort.setLocale("en")` (see Step 1 > Language and Layout)
* Change any wording: `strings: ["en": ["explain.fallback": "…"]]` when creating the session
* Extra request metadata: `metadata: ["channel": "ios"]`, sent with every request
* Bridge a rotated token: `auth: { await tokenStore.current() }`
* Logging: `logLevel: .debug`, or your own `logger:` (see [Reference > Logging](reference.md#logging))
* Round trips: Report `stage = .return` on the return leg; Smart Sort hides there and returns on the onward leg
* Restyle any view: Copy its `Configuration.default` and edit it (see [Reference > Elements](reference.md#elements))
* Build your own UI: Observe the session's state and call its actions (see [Reference > Custom UI](reference.md#custom-ui))

---

## Check It

Run these on a device before you go through the checklist:

1. A new search reorders your list on Best without any input.
2. Asking shows chips, a loading state, then the Explain AI text; the list reorders.
3. Removing one chip asks again without it; removing the last clears Smart Sort.
4. Changing sort tab with a query shows the confirmation; **Back** returns you to Best, **Proceed** clears the query.
5. With a filter that hides the top matches, the banner shows a filter notice.
6. On the return leg of a round trip, the banner and chips hide and come back on the onward leg.
7. In Arabic, the SDK's views are right-to-left and the explanation is in Arabic.

---

## Pre-ship Checklist

* Tenant package imported; one `RiviSmartSort` per results screen
* `onEvent` set before the search; handles `.ranking`, `.rankingCleared`, `.sortChanged(.best)`, `.showHidden`
* `.riviSmartSortConfirmation(smartSort)` added
* `search` set on every new search, with dates from `RiviDate.string(from:)`
* `sort` reported (`.best` or `.other`); `stage` for round trips
* `filters` reported whenever they change (`nil` when cleared)
* Ranking applied on Best only; your own order on other tabs
* `RiviSmartSortV2Banner`, `RiviSmartSortButton`, `RiviSmartSortV2BottomSheet` placed
* `SmartSortPromptResultCard` after the 4th result, only while no query is active
* `SmartSortPromptFilterCard` in your filter sheet; Smart Sort opens after it closes
* Tags shown on result cards while a query is active
* `visible` reported after your filters (recommended); `pool` if your list is your own
* `destroy()` when the results screen is dismissed for good
* Tested: flights and hotels, English and Arabic, filters on and off, sort tab changes, round trips, multi-city, background and foreground while ranking

---

## Best Practices

### 1. One Session per Screen

* Create the session with `@StateObject` so SwiftUI keeps it for the life of the screen
* Share it with `.environmentObject` instead of creating another one

### 2. Report Facts, Don't Call APIs

* Never call Sort Best, Ask or Explain AI yourself: report `search`, `sort`, `filters` and `visible`, and the SDK decides what to send
* Setting the same value again is free: it does nothing

### 3. Apply the Ranking on Best Only

* Use `ranking` on your Best tab and your own order on other tabs
* Keep unranked results after the ranked ones

### 4. Always Use RiviDate

* Build every date with `RiviDate.string(from:)`, so it reaches the gateway in the expected format

### 5. Keep Tokens in the Tenant Package

* Use `build: .bundled`; pass `auth:` only to bridge a rotated token until the rebuilt package ships

---

**Next:** [Reference](reference.md) · Something not working? [Troubleshooting](troubleshooting.md)
