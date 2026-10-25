---
title: Reference
sidebar_position: 4
slug: reference
---

# Reference

Every public type, property, event and view your app uses, and the rules the SDK follows on its own. For the step-by-step wiring, read the [Integration guide](integration_guide.md) first.

---

## Core API Reference

### RiviSmartSort Class

The main entry point. `RiviSmartSort` is a `@MainActor` `ObservableObject`: create one per results screen, report facts to it, and listen to its events.

**Recommended Flow:**

1. Create the session
2. Set `onEvent`
3. Report the search (the SDK runs Sort Best)
4. Report the sort tab, filters and visible results as they change
5. Call `destroy()` when the screen goes away

---

### 1. Creating a Session

**Basic Usage:**

```swift
RiviSmartSort(
    build: .bundled,
    environment: .production,
    locale: "en",
    currency: "USD",
    metadata: [:],
    strings: [:],
    auth: nil,
    logLevel: .info,
    logger: nil
)
```

**Parameters:**

* `build`: `.bundled`: your tenant package's configuration and tokens
* `environment`: `.production` or `.staging` (default: `.production`)
* `locale`: `"en"` or `"ar"`. Drives strings and RTL layout (default: `"en"`)
* `currency`: ISO code, e.g. `"USD"`
* `metadata`: `[String: String]` sent with each request (default: `[:]`)
* `strings`: Wording overrides, `[locale: [key: message]]` (ICU subset) (default: `[:]`)
* `auth`: Overrides the bundled token, resolved per request. A 401 resolves it once more (default: `nil`)
* `logLevel`: Minimum level the console logs. Ignored when `logger` is set (default: `.info`)
* `logger`: Your own `RiviLogger`. See [Logging](#logging) (default: `nil`)

**Note:** `destroy()` closes the ranking stream and cancels everything in flight. Call it when the screen goes away; deinit also does.

---

### 2. Facts You Report

Set these whenever they change. Setting the same value again does nothing.

**Properties:**

* `search` (`RiviSearch?`): The current search. A new `searchId` (or product) resets Smart Sort
* `sort` (`SortMode`): `.best` or `.other`. Leaving Best with an active query asks first
* `stage` (`Stage`): `.onward` or `.return`. Smart Sort is off on the return leg
* `filters` (`JSONValue?`): Your applied filters, any JSON. `nil` = none. Makes no request; the next request carries them
* `visible` (`[String]?`): The ids you actually show after your filters and paging, in order
* `pool` (`PoolFact?`): `PoolFact(size:complete:)`: how many results you've loaded, and whether loading finished. Leave unset when the list is Rivi's. See [Integration guide > Step 6](integration_guide.md#step-6-good-to-have)

**Reporting Several at Once** (dispatched in the contract's order):

```swift
smartSort.update(search: s, sort: .best, stage: .onward,
                 pool: PoolFact(size: 120, complete: true),
                 filters: .some(myFiltersJSON), visible: .some(shownIds))
```

`filters` and `visible` are double optionals in `update`: leave them out to keep the current value,
pass `.some(nil)` to clear.

---

### 3. Search Types

**Basic Usage:**

```swift
RiviSearch.flight(FlightSearch(
    searchId: String,
    tripType: TripType,          // .oneway, .round, .multicity
    origin: String,
    destination: String,
    departureDate: String,       // RiviDate.string(from:) → "2026-10-14T09:31:18.000Z"
    returnDate: String? = nil,
    cabin: Cabin? = nil,         // .economy, .premium, .business, .first
    pax: FlightSearch.Pax        // .init(adults:children: = 0, infants: = 0)
))

RiviSearch.hotel(HotelSearch(
    searchId: String,
    destination: String,
    checkin: String,
    checkout: String,
    rooms: Int,
    pax: HotelSearch.Pax         // .init(adults:children: = 0)
))
```

Dates are passed to the gateway exactly as you supply them. Use `RiviDate.string(from:)`.

---

### 4. Events

Receive them with `smartSort.onEvent = { event in … }` (on the main actor) or
`for await event in smartSort.events { … }` (each call returns an independent stream).

**Events:**

* `.ranking(ranking:all:status:)`: The order to apply. `ranking` is Rivi's order while Best is selected (empty on other tabs). `all` is every ranked result whatever the tab. `status` is `.provisional` or `.final`
* `.rankingCleared`: The query was cleared: go back to your own order
* `.sortChanged(SortMode)`: Set your sort tab to this (after an ask from another tab, or a declined confirmation)
* `.showHidden([String])`: "Show matches": the ids of full matches your filters hide
* `.confirmSortChange(SortMode)`: Leaving Best needs confirmation. Only handle it if `presentsSortConfirmation` is false
* `.error(RiviError)`: A request failed. The views already show it

**RankingEntry:**

* `id`: Your result id
* `rank`: 0-based position within its scope
* `scope`: `.itinerary`, `.onward`, `.return` or `.hotel`
* `matchesAllPreferences`: Whether it matches every preference in the query
* `tags`: Localized tags for the result card (see [Integration guide > Step 5](integration_guide.md#step-5-result-tags))
* `item`: The raw item, when Rivi supplies it

**RiviError:** `kind` (`.network`, `.auth`, `.timeout`, `.stream`, `.server`), `message`, `retryable`.
A `.timeout` is raised when a request or Explain AI stream sends nothing for 30 s, or when no
ranking arrives within 30 s.

---

### 5. Session State

Read-only, observable.

**Properties:**

* `isAvailable`: Whether Smart Sort can be used: a search is set, it is not multi-city, and this is the onward leg
* `queryType`: `.flight` or `.hotel`, from the search
* `chips`: The chips to show (`[Chip]`, empty when they should be hidden)
* `chipLabels`: The same chips' labels, as a `Set<String>`
* `banner`: `.hidden`, `.loading`, `.refreshing`, `.explanation`, `.fallback` or `.conflict`
* `explanation`: The Explain AI text; grows while it streams
* `isExplanationComplete`: `false` while the Explain AI stream is still sending text
* `notice`: The parameter-change notice, if any
* `inputValue`: The `text` and `chips` for the query input
* `ranking`, `rankingStatus`: The current ranking and its status (`.none`, `.provisional`, `.final`)
* `hiddenMatches`: Ids of full matches hidden by your filters
* `error`: The current `RiviError`, if any
* `state`: The full contract state (`state.query` is the active query, `""` when none)
* `matchesAllPreferences(id:)`: Whether a result matches every preference (`nil` if unranked, off Best, or not in the current leg)
* `tags(for:)`: Localized tags for a result (empty if unranked, off Best, or not in the current leg)
* `text(_:_:)`: A localized SDK string, e.g. `text("explain.fallback")`

---

### 6. Actions

The bound views call these; call them yourself for custom UI.

**Methods:**

* `ask(_:)`: Asks with a query
* `ask(_:filters:)`: Asks with these filters, replacing the reported ones. `nil` keeps them
* `removeChip(id:)`, `removeChip(label:)`: Removes a chip and asks again without it
* `clearAll()`: Clears Smart Sort
* `retry()`: Retries the failed request
* `dismissError()`: Dismisses the error
* `showHiddenMatches()`: Emits `.showHidden` with the hidden full matches
* `setLocale(_:strings:)`: Switches language at runtime
* `resolveSortConfirmation(accepted:)`: Answers `.confirmSortChange`

---

## UI Components

The bound views read everything from the session. Use these in your app. Each one takes a Configuration struct for customisation (see [Elements](#elements)).

---

### 1. RiviSmartSortV2Banner

The results banner: chips, the Explain AI text, loading, errors and filter notices.

**Basic Usage:**

```swift
RiviSmartSortV2Banner(smartSort,
                      configuration: .default,         // SmartSortV2DynamicBanner.Configuration
                      onEdit: { showSmartSort = true },
                      onClearFilters: { clearMyFilters() })   // nil hides "Clear Filters"
```

Shows itself while there are chips or an explanation, and picks the filter notice itself (see the
[Integration guide > Step 6](integration_guide.md#step-6-good-to-have)). Chips show in the order the query
produced them. For the collapsible "Why these flights are recommended" design, set
`configuration.layout = .collapsible` (see SmartSortV2DynamicBanner).

---

### 2. RiviSmartSortButton

The Smart Sort button.

**Basic Usage:**

```swift
RiviSmartSortButton(smartSort,
                    configuration: .default,         // SmartSortHaloButton.Configuration (.rivi for the Rivi design)
                    action: { showSmartSort = true })
```

The Smart Sort button with its halo (see SmartSortHaloButton). It shows the
number of active preferences and is disabled where Smart Sort isn't available.

---

### 3. RiviSmartSortV2BottomSheet

The Smart Sort sheet, where the user types their request.

**Basic Usage:**

```swift
RiviSmartSortV2BottomSheet(
    smartSort,
    isPresented: $showSmartSort,
    configuration: .default,         // SmartSortV2BottomSheet.Configuration
    focusesInputOnAppear: false,     // true when opened from a prompt card
    startingExample: nil,            // the placeholder example to start on
    filters: nil,                    // JSON sent with this ask; nil = the reported filters
    filterLabels: [],                // words for the filters line
    onClearAll: nil                  // "Clear All": clear your filters here; Smart Sort is cleared after
)
```

"Clear All" shows in the header with `configuration.showsClearAllButton = true` (off by default),
while the input has text or a query is active. It empties the input, calls `onClearAll`, then
clears Smart Sort; the sheet stays open.

---

### 4. riviSmartSortConfirmation

The "leave Best?" confirmation dialog. By default it shows "Clear Ask AI Query" ("Your active
query will be cleared in order to change the sorting. Do you wish to proceed?") with **Back**
and **Proceed**. Change the wording with `RiviConfirmationDialog.Configuration` (`titleText`,
`descriptionText`, `cancelButtonText`, `confirmButtonText`).

**Basic Usage:**

```swift
.riviSmartSortConfirmation(smartSort, configuration: .default)   // RiviConfirmationDialog.Configuration
```

Shows the "leave Best?" dialog. To show your own, set `smartSort.presentsSortConfirmation = false`,
handle `.confirmSortChange`, and call `resolveSortConfirmation(accepted:)`.

---

### 5. V1 Bound Views

Kept for apps on the previous design: `RiviSmartSortChips`, `RiviSmartSortBanner`,
`RiviSmartSortAskSheet`, `RiviSmartSortBottomSheet`, `RiviSmartSortAskButton`. New integrations
should use the V2 views.

---

## Elements

The plain SwiftUI views, in `RiviSmartSortElements`. All of them:

* support light and dark mode, English and Arabic (right-to-left)
* pick flight or hotel wording from `queryType`
* keep still when Reduce Motion is on

Every view takes a `configuration:` whose `.default` is the V2 design. To change a few things,
copy the default and edit it (the [Styling guide](styling.md) covers every property):

**Custom Configuration:**

```swift
var config = SmartSortV2BottomSheet.Configuration.default
config.submitButtonText = "Rank my flights"
config.submitButtonBackgroundColor = .indigo
```

**Available Elements:**

* SmartSortSparkle: The animated sparkle icon
* SmartSortTwinkleText: "✦ Smart Sort ②": the label for your Smart Sort button
* SmartSortHaloButton: The Smart Sort button with a halo circling its border
* SmartSortV2BottomSheet: The ask sheet
* SmartSortV2DynamicBanner: "Ranked by your preferences" (or the collapsible "Why these flights are recommended"): chips, explanation, notices
* SmartSortPromptResultCard: "Not sure which one to pick?" card for the results list
* SmartSortPromptFilterCard: "Describe what you want…" row for your filter sheet
* SmartSortStreamingText: Text that types itself out as it streams
* RiviChipsView: Chip row options added for V2
* SmartSortExampleAnimation: Timing for typed-out examples

**Note:** `RiviSmartSortElements` also contains `RiviSpotlightBanner` (the first-time spotlight).
It has no session-bound version in V2 and isn't part of the V2 integration.

---

### 1. SmartSortSparkle

The animated Smart Sort sparkle. `configuration: .rivi` draws the Rivi design.

<details>
<summary>Design spec</summary>

A four-point star with a small "+". On a 4.5 s loop the star wiggles and the "+" twinkles. With
`showsBurst`, four tiny stars pop out around it every 6 s.

`.rivi` draws the Rivi design instead (`style: .rivi`): a four-point star filled with a blue
gradient, a "+" top trailing and a smaller "+" bottom leading. Each pulses on its own loop: the
star 3.2 s (to 0.82×, 70% opacity), the "+" 2.4 s (to 0.45×, 25%), the small "+" 2.8 s (from 0.55×,
35% up to 1.1×).

</details>

**Basic Usage:**

```swift
SmartSortSparkle(size: 20)                                  // animated
SmartSortSparkle(size: 20, configuration: .rivi)            // the Rivi design
SmartSortSparkle(size: 20, configuration: .withBurst)       // with the burst
SmartSortSparkle(size: 16, configuration: .plain(.white), isAnimating: false)  // static, one color
SmartSortSparkle.image                                       // static template Image
```

* `size`: Width and height
* `isAnimating`: `false`: static
* `isBreathing`: `false`: pauses the wiggle and twinkle (e.g. while typing)
* `twinkleTrigger`: Change it to play one burst now

**Configuration Options (default values):**

* `primaryColor`: Purple `#7B3FE4`
* `burstColors`: Four lavender/purple tones
* `showsBurst`: `false` (`.withBurst`: `true`)
* `loopDuration`: 4.5 s
* `twinkleInterval`: 6 s between bursts (`nil`: only on `twinkleTrigger`)
* `initialDelay`: 0.9 s before the first burst
* `style`: `.classic` (`.rivi`: the Rivi design)
* `starGradient`, `plusColor`, `secondaryPlusColor`: `.rivi` only. `nil` uses `primaryColor`. `.rivi`: `#4B9CF0` → `#1D6FD1`, `#2F86E0`, `#5AA3EF`

---

### 2. SmartSortTwinkleText

Sparkle, "Smart Sort", and a count badge. Wrap it in your own `Button`.

<details>
<summary>Design spec</summary>

Sparkle, "Smart Sort", and a count badge. While the count is 0 it twinkles, bursts and a light
shimmer sweeps the text. With a count it turns lavender and shows the badge. Wrap it in your own
`Button`.

</details>

**Basic Usage:**

```swift
SmartSortTwinkleText(configuration: .default, count: smartSort.chips.count, isAnimating: true)
```

**Configuration Options (default values):**

* `text`: "Smart Sort" (localized)
* `font`, `textColor`: 15 pt semibold, purple
* `shimmerColor`: Pale lavender `#F8F4FF` (white in dark mode)
* `sparkleSize`, `sparkleConfiguration`: 18, `.default` (the burst is always on here)
* `twinkleInterval`, `initialDelay`: 6 s, 0.35 s
* `badgeFont`, `badgeBackgroundColor`, `badgeTextColor`, `badgeSize`: 11 pt bold, purple, white, 20
* `backgroundColor`, `activeBackgroundColor`: clear, lavender `#EFE9FD` (with a count)
* `spacing`, `padding`: 6, 10/14

---

### 3. SmartSortHaloButton

Sparkle and "Smart Sort" in a rounded button with a halo circling its border. With a count it
shows a badge; it dims while disabled. Use the bound version in your app.

<details>
<summary>Design spec</summary>

Sparkle and "Smart Sort" in a rounded button. A bright arc travels around its border, one turn
every 2 s: the ring is clear for most of the turn and brightens through `haloColors` (the Rivi
design's `conic-gradient`). With a count it shows a badge. It dims while disabled; with Reduce
Motion on only the resting border shows. Use the bound version in your app.

</details>

**Basic Usage:**

```swift
SmartSortHaloButton(configuration: .rivi, count: smartSort.chips.count) { showSmartSort = true }
```

**Configuration Options (default values, `.rivi` in parentheses):**

* `text`, `font`, `textColor`: "Smart Sort", 13.5 pt semibold, purple (blue `#017ACB`)
* `sparkleSize`, `sparkleConfiguration`: 17, `.default` (`.rivi`)
* `height`, `horizontalPadding`, `spacing`, `cornerRadius`: 38, 14, 8, 10
* `backgroundColor`, `borderColor`, `borderWidth`: background, lavender (`#D5E4F5`), 1
* `haloColors`, `haloDuration`, `haloWidth`, `showsHalo`: purple tones (blues ending in `#0186DF`), 2 s, 1, `true`
* `badgeFont`, `badgeBackgroundColor`, `badgeTextColor`, `badgeSize`: 11 pt bold, purple (`#0B7BD0`), white, 18

---

### 4. SmartSortV2BottomSheet

Sparkle + "Smart Sort", a description, an optional filters line, the query input with an
animated placeholder, suggestion chips, and **Improve Results**. Submitting calls `onSubmit` and
closes the sheet. Tapping a suggestion submits it: on its own when the input is empty, otherwise
added after the text already there ("Avoid long layovers. Depart after work"). Use the bound version
in your app.

**Basic Usage:**

```swift
SmartSortV2BottomSheet(isPresented: $show, queryType: .flight, userQuery: "",
                       startingExample: nil, filterLabels: [], isShowingError: false,
                       focusesInputOnAppear: false,
                       onSubmit: { query in … },
                       onRetry: nil, onQueryChange: nil)
```

**Configuration Options (default values):**

* `titleText`: "Smart Sort"
* `descriptionText`: "Share your preferences. AI will rank flights/hotels and explain the trade-offs."
* `showsFiltersNote`: `false`. With `filterLabels`: "Your filters (Nonstop, Morning) will now be used to rank flights."
* `animatesPlaceholder`: `true`: types out `placeholderExamples`, prefixed with `examplePrefix` ("e.g. ")
* `placeholderText`: Used when `animatesPlaceholder` is false
* `placeholderExamples`: 5 flight or hotel examples
* `exampleAnimation`: `SmartSortExampleAnimation.default`
* `suggestions`: 4 flight or hotel suggestions
* `submitButtonText`: "Improve Results"
* `showsSubmitButtonIcon`, `submitButtonCornerRadius`: `true` (sparkle before the text), `nil` (a capsule; e.g. 12 for rounded corners)
* `submitButtonDisabledTextColor`: `nil` (`submitButtonTextColor`). The text while the input is empty, e.g. grey on a light grey `submitButtonDisabledBackgroundColor`
* `showsClearAllButton`: `false`. "Clear All" in the header (with `onClearAll`)
* `clearAllButtonText`, `clearAllButtonFont`, `clearAllButtonColor`: "Clear all", 14 pt, purple
* `errorText`, `retryButtonText`: Shown when `isShowingError` (plain version only)
* `characterLimit`, `inputLineLimit`: 200, 3
* Fonts: `titleFont`, `descriptionFont`, `filtersNoteFont`, `inputFont`, `suggestionFont`, `submitButtonFont`, `errorFont`, `retryButtonFont`
* Layout: `padding`, `sparkleSize`, `sheetCornerRadius` (28), `inputCornerRadius`, `submitButtonHeight`
* Colors: `backgroundColor`, `titleColor`, `sparkleConfiguration`, `descriptionColor`, `filtersNoteColor`, `filtersNoteIconColor`, `closeButton…`, `input…`, `textColor`, `placeholderColor`, `suggestion…`, `submitButton…`, `error…`

---

### 5. SmartSortV2DynamicBanner

"Ranked by your preferences" with **Edit** and **✕**, the chips, then one of: a loading skeleton,
a filter notice, or the explanation streaming in. A failed request adds an inline error with
**Try again**. Use the bound version in your app.

With `layout: .collapsible` (the Rivi design):

* the header is one tappable row, the sparkle, "Why these flights are recommended" (or hotels) and a
  chevron, that collapses and expands the body;
* the chips share a row with **Edit**, and there is no ✕;
* the body (error, loading, notice or explanation) closes over its content when collapsed: nothing
  moves, and the explanation isn't typed out again when it reopens.

**Custom Configuration:**

```swift
var config = SmartSortV2DynamicBanner.Configuration.default
config.layout = .collapsible
config.loadingStyle = .shimmerText            // "Explaining top picks…" with a sweeping shimmer
config.clearFiltersPlacement = .trailing      // "Clear Filters" as a button after the notice
config.showsEditIcon = false
config.backgroundGradient = [Color(red: 0.89, green: 0.93, blue: 0.98), Color(red: 0.92, green: 0.91, blue: 0.97)]
```

**Basic Usage:**

```swift
SmartSortV2DynamicBanner(
    orderedChips: chips,                 // [String], in display order (or chips: Binding<Set<String>>)
    queryType: .flight,                  // picks the collapsible title's wording
    explanation: text,                   // may grow as it streams
    isLoading: false,
    isShowingError: false,
    filterNotice: .hidingRecommended(.flight),   // or .hidingMatches(.flight), or nil
    onEdit: { … }, onClear: { … }, onRemoveChip: { label in … },
    onRetry: { … }, onDismissError: { … }, onClearFilters: { … }
)
```

`FilterNotice(tone:text:)` builds a custom notice.

**Configuration Options (default values):**

* `titleText`, `editButtonText`: "Ranked by your preferences", "Edit"
* `errorText`, `retryButtonText`: "Couldn't update results. Your filters haven't changed.", "Try again"
* `clearFiltersText`: "Clear Filters"
* `chipsConfiguration`: Lavender pills, bold key ("**Departure:** after 5 PM"), edge fades, icon hidden
* `streamingUnit`, `streamingInterval`: `.character`, 0.02 s
* Notice colors: `notice…` (white, purple icon), `warning…` (yellow)
* Other: fonts, `padding`, `spacing`, `cornerRadius`, `sparkleSize`, `explanationLineSpacing`, `skeleton…`, `error…`, `retryButton…` colors
* `layout`: `.classic`. `.collapsible`: the Rivi design above
* `collapsibleTitleText`, `chevronColor`: `nil` ("Why these flights/hotels are recommended"), `nil` (`clearButtonColor`)
* `showsEditIcon`: `true`: the pencil before "Edit"
* `loadingStyle`: `.skeleton` (three pulsing bars). `.shimmerText`: `loadingText` with a band sweeping across it every 1.6 s
* `loadingText`, `loadingTextColor`, `loadingShimmerColor`: "Explaining top picks…", `#6A6D70`, `#C3CDD9`
* `clearFiltersPlacement`: `.inline` (a link after the text). `.trailing`: a button at the notice's end
* `noticeIconName`: `"info.circle"`
* `backgroundGradient`: `nil`. Colors fill the banner leading to trailing (the CSS `100deg`) instead of `backgroundColor`

---

### 6. SmartSortPromptResultCard

"Not sure which one to pick?" for your results list. Its fake input types out example queries in
quotes with a blinking cursor, only while it is on screen. A soft purple glow sits in the top
trailing corner.

**Basic Usage:**

```swift
SmartSortPromptResultCard(queryType: smartSort.queryType,
                          onTap: { example in /* open the sheet, startingExample: example */ },
                          onDismiss: { promptDismissed = true })
```

You decide where and when it shows: typically after the 4th result, only while no query is active.

**Configuration Options (default values):**

* `titleText`, `descriptionText`: "Not sure which one to pick?", "Describe what you want. AI will rank flights and explain the trade-offs."
* `examples`: 5 flight or hotel examples
* `quotesExample`, `cursorColor`: `true` ("“…|”"), purple. `false`: `examplePrefix` + example
* `exampleAnimation`: `SmartSortExampleAnimation.default` (`.streaming`: character by character, like the banner's explanation)
* `backgroundColor`, `glowColor`, `glowOpacity`, `borderColor`: `#FBF9FF`, `#9B6BF5`, 0.16, `#EBE6F5`
* `backgroundGradient`: `nil`. Colors fill the card instead of `backgroundColor`
* Layout: `padding`, `cornerRadius` (20), `sparkleSize`, `inputHeight`, `inputCornerRadius`, `sendButtonSize`
* Other colors: `titleColor`, `descriptionColor`, `dismissButtonColor`, `input…`, `exampleColor`, `sendButton…`

---

### 7. SmartSortPromptFilterCard

"Describe what you want and AI will rank flights for you. ›" for the top of your filter sheet.
The whole row is one tap target.

**Basic Usage:**

```swift
SmartSortPromptFilterCard(queryType: smartSort.queryType,
                          isHighlighted: draftFilterCount >= 4) {
    // apply the draft filters, close this sheet, then open Smart Sort
}
```

`isHighlighted` outlines the row in purple and makes its sparkle pop.

**Configuration Options (default values):**

* `text`: Flight or hotel text
* `buttonText`: "Try Smart Sort" (read by VoiceOver; the row shows a chevron)
* `arrowSize`, `arrowColor`: 15, purple
* `backgroundColor`, `borderColor`, `highlightedBorderColor`: `#F8F5FE`, `#E3D8FA`, purple
* `backgroundGradient`: `nil`. Colors fill the row instead of `backgroundColor`
* Other: `textFont`, `textColor`, `padding`, `cornerRadius`, `spacing`, `sparkleSize`, `sparkleConfiguration`

---

### 8. SmartSortStreamingText

Text that types itself out. A longer `text` continues from where it is; a shorter or equal one
(a new answer) appears at once. Style it like a `Text`.

It remembers how far each text got, so a rebuilt view (hidden behind another tab, or scrolled away
in a lazy list) never types the same text out again: a finished text shows at once, one still
streaming carries on from where it was.

**Basic Usage:**

```swift
SmartSortStreamingText(explanation, unit: .character, interval: 0.02)
    .font(.system(size: 14))
    .foregroundStyle(.secondary)
```

---

### 9. RiviChipsView (V2 Options)

Options added to `RiviChipsView.Configuration` for V2. Existing setups are unchanged.

* `icon`: Image before each chip's text, e.g. `SmartSortSparkle.image` (default: `nil`)
* `showsIcon`: Shows `icon` (default: `false`)
* `iconSize`, `iconColor`: default 14, chip text color
* `keyFont`: Bold key for "Key: Value" labels: "**Departure:** after 5 PM" (default: `nil`)
* `fadesEdges`, `edgeFadeWidth`: Fades an edge while chips are scrolled out past it (default: `false`, 28)
* `contentPadding`: Space before the first chip and after the last, inside the scrolling row (for an edge-to-edge row) (default: none)
* `removeButtonSize`: The ✕'s tap area (e.g. 22); `nil` sizes it to the icon (default: `nil`)

`RiviChipsView(configuration:orderedChips:onRemove:)` shows the chips in the order given (the set
initializer doesn't keep an order).

---

### 10. SmartSortExampleAnimation

Timing for the typed-out examples (the result card and the sheet's placeholder):

**Basic Usage:**

```swift
SmartSortExampleAnimation(wordInterval: 0.055, holdDuration: 2.5,
                          fadeDuration: 0.15, reducedMotionDuration: 3.5)   // .default, a word at a time
SmartSortExampleAnimation.streaming   // a character every 0.02 s, eased, as the banner's explanation
```

`unit` (`.word` or `.character`) sets what each step reveals; `wordInterval` is the time per step.

---

## Chip Labels

The SDK turns each preference the gateway extracts into chips (English shown; Arabic is bundled
too). List values get a chip each; times and airports are joined into one chip.

**Flight:**

* `preferred_airlines`: the airline
* `not_preferred_airlines`: Not preferred airline: …
* `trip_duration`: Trip duration: …
* `preferred_departure_time`: Departure: …
* `preferred_arrival_time`: Arrival: …
* `preferred_return_time`: Return: …
* `stops_preference`: Non-stop / 1 stop / n stops
* `preferred_flight_duration`: Flight duration: …
* `preferred_layover_airport_or_city`: Layover at …
* `not_preferred_layover_airport`: Not Preferred Layover: …
* `preferred_layover_duration`: Layover duration: …
* `checked_baggage_weight_preference`: Baggage weight: …
* `flight_budget`: Budget: … (+ `budget_currency`)
* `in_policy_only`: In policy only
* `avoid_overnight_layover`: Avoid overnight layover
* `flight_amenities`: the amenity
* `preferred_departure_airport`: Departure Airport: …
* `preferred_arrival_airport`: Arrival Airport: …
* `not_preferred_departure_airport`: Not Preferred Departure Airport: …
* `not_preferred_arrival_airport`: Not Preferred Arrival Airport: …
* `other_flight_preferences`: the preference

**Hotel:**

* `star_rating`: "4 star", or "No Rating" for 0
* `preferred_user_rating`: User Ratings: …
* `stay_budget`: Budget: … (+ `budget_currency`)
* `amenities`: the amenity
* `accommodation_type`: Accommodation Type: …
* `preferred_room_type`: the room type
* `preferred_hotel_names`: the hotel
* `preferred_stay_location`: Near … (one per location)
* `preferred_hotel_brand`: the brand
* `other_stay_preferences`: the preference
* `in_policy_only`: In policy only
* `not_preferred_hotel_names`: Not preferred hotel: …
* `not_preferred_stay_location`: Not preferred location: …
* `not_preferred_hotel_brand`: Not preferred brand: …
* `not_preferred_amenities`: Not preferred amenity: …
* `not_preferred_accommodation_type`: Not preferred accommodation type: …
* `not_preferred_room_type`: Not preferred room type: …
* `not_preferred_stay_preferences`: Not preferred: …

The budget's currency comes from the record's `budget_currency` when present ("Budget: 500 USD"),
and isn't added twice when the value already names it.

---

## Custom UI

To build your own views instead of the V2 views, observe the session (it's an
`ObservableObject`), render from Session State, and call
Actions. Keep `.riviSmartSortConfirmation`, or handle `.confirmSortChange` yourself.

---

## Localization

RiviSmartSort supports English and Arabic for every view and every SDK string.

### Supported Languages

* English ("en")
* Arabic ("ar")

### How It Works

Pass the locale when you create the session. It's the only setting you need:

```swift
RiviSmartSort(build: .bundled, locale: "ar", currency: "USD")
```

Everything then switches to that language automatically:

* The Smart Sort button and twinkle label
* The Smart Sort sheet: title, description, placeholder examples, suggestions, filters line
* The banner: title, chips, loading text, filter notices, errors
* The result and filter prompt cards
* The "leave Best?" confirmation
* The explanation (the ask and Explain AI requests carry the language)

### RTL Support

Arabic switches the SDK's views to right-to-left layout by themselves: the banner, the sheet, the chips and the confirmation. The Smart Sort button, twinkle label and prompt cards follow your screen's layout direction, which is already right-to-left in an Arabic app.

### Dynamic Language Switching

Change the language at runtime without creating a new session:

```swift
smartSort.setLocale("ar")   // or "en"
```

Chips are rebuilt in the new language, the SDK's views switch straight away, and later requests use it.

**Important Notes:**

* An explanation already on screen isn't fetched again: it stays in the old language until the user asks again
* Wording you set yourself in a configuration (for example `submitButtonText`) stays as you set it
* A configuration you store in a property keeps the language it was built with. Build it inside `body`, or rebuild it after `setLocale`

### Custom Wording

Override any SDK string per language with `strings:`, as `[locale: [key: message]]`:

```swift
RiviSmartSort(build: .bundled, locale: "ar", currency: "USD",
              strings: ["ar": ["explain.fallback": "…"]])
```

To pass new overrides at runtime: `smartSort.setLocale("ar", strings: [...])`.

---

## Logging

Logs go to the console at `.info` by default. Pass a `RiviLogLevel`, or your own `RiviLogger`
(which filters with its own `isEnabled(_:)`):

**Basic Usage:**

```swift
RiviSmartSort(build: .bundled, currency: "USD", logLevel: .debug)
RiviSmartSort(build: .bundled, currency: "USD", logger: MyLogger())
```

### Log Levels

* `.all`: Everything
* `.debug`: Request and response bodies, raw stream frames, every rule step
* `.info`: A request and response block for every call, and ranking sizes
* `.warn`: Ranking-stream reconnects, dropped entries
* `.error`: An error block for every failure
* `.none`: Nothing

**Note:** Tokens and the stream URL are never logged.

---

## Behaviour Rules

What the SDK decides on its own. You don't implement any of this. Read it to know what to expect when you test, and which facts and events drive each behaviour.

**Note:** Most rules come from the contract Smart Sort shares across platforms. One difference on iOS: reporting filters never makes a request ([8. Filters](#8-filters)), where the shared contract re-ranks on a filter change. The numbers in this section are for referring to rules within these iOS docs; they are not the contract's rule numbers.

---

### 1. Availability

1. Smart Sort is available only when a search is set, the search is not multi-city, and the onward leg is showing. `isAvailable` reports this.
2. On the return leg of a round trip, the banner and chips hide. Nothing is cleared: they come back on the onward leg.
3. While Smart Sort isn't available, asks are ignored and the Smart Sort button is disabled.

---

### 2. New Search

4. A new `searchId` (or a switch between flights and hotels) resets Smart Sort: the query, chips, ranking and explanation are cleared.
5. The sort tab, stage, filters and pool you reported are kept across a new search.
6. Setting the same `searchId` again only updates the search details. Nothing is reset or sent.

---

### 3. Sort Best

7. A new search starts Sort Best straight away: Rivi's default ranking with no query.
8. Clearing the query starts Sort Best again.
9. Sort Best never calls Explain AI and shows no banner.

---

### 4. Asking

10. Empty or whitespace-only text is ignored.
11. Asking replaces the previous query, chips and explanation, and the banner shows its loading state.
12. Asking from another sort tab moves Smart Sort to Best and sends `.sortChanged(.best)`.
13. The sheet restores the current query when it reopens.

---

### 5. Chips

14. Chips show only on the Best tab while Smart Sort is available.
15. Chips show in the order the query produced them.
16. Removing a chip asks again with the remaining chips.
17. Removing the last chip clears Smart Sort.

---

### 6. Clearing

18. Clearing (the banner's ✕, or removing the last chip) sends `.rankingCleared`, hides the banner, and starts Sort Best again.

---

### 7. Sort Tabs

19. Changing sort tab never makes a request.
20. Leaving Best while a query is active asks the user first ("Clear Ask AI Query"):
    * Proceed: the query is cleared and the new tab is kept.
    * Back: you receive `.sortChanged(.best)`; move your tab back.
21. Off Best, `ranking` is empty: use your own order. `all` still carries every ranked result.

---

### 8. Filters

22. Reporting filters never makes a request: no new ranking, and the query, chips and order stay.
23. The next request (Sort Best, an ask, a chip removal, a retry) carries your filters as-is.
24. Filters passed to the sheet or to `ask(_:filters:)` replace the reported ones.
25. `nil` or JSON `null` means no filters. Filters that differ only in key order count as the same.

---

### 9. Ranking

26. The SDK never reorders your list; it sends `.ranking` and you apply it.
27. Rankings are `.provisional` while results are arriving and turn `.final` 0.8 s after the last ranking update once results are complete.
28. The previous ranking stays on screen until the new one replaces it, so the list doesn't flicker.
29. A response for an older request (the user asked again, or a new search ran) is dropped.
30. Each ask, chip removal, retry or new search cancels the request in flight before sending its own.
31. On the return leg only return-leg entries are ranked; on the onward leg, itinerary, onward and hotel entries.
32. Results without an id, and duplicate ids, are dropped (logged at `.warn`).

---

### 10. Explain AI

33. Explain AI runs only for a query whose preferences were extracted. Chips alone never trigger it.
34. It's requested once per ask, 0.5 s after the first ranking of that ask arrives.
35. The text streams in; the banner shows its loading state until it's complete, then types it out.
36. If Explain AI ends with no text, the banner shows the fallback line when any ranked result only partly matches, and hides otherwise.
37. When the user asks again, the old explanation stays (shown as refreshing) until the new one arrives.

---

### 11. The Banner

38. The banner shows one state at a time: hidden, loading, refreshing, explanation, fallback, or conflict.
39. It shows only on the Best tab while Smart Sort is available.
40. **Conflict** comes first: every result you show only partly matches, while a full match in Rivi's top 10 is hidden by your filters (needs `visible`). The banner then shows the yellow notice.
41. With filters on during a query, the purple "hiding some recommended" notice shows unless you report `visible` and none of Rivi's top 10 full matches are hidden.
42. "Show matches" reveals only full matches from the top 10, so it always has something to show.

---

### 12. Errors and Connection

43. A failed request shows an error in the banner with **Try again**. Your filters and list are left as they were.
44. **Try again** repeats the last request. Dismissing the error keeps the current results.
45. A request, or an Explain AI stream, with no response for 30 s fails with a timeout. So does a round with no ranking within 30 s.
46. On a 401 the SDK asks for the token once more and retries.
47. The ranking stream reconnects on its own after 1 s, 2 s, 4 s, then 8 s (each ±20%, never more than 30 s). The fifth failure in a row shows a retryable error. A ranking update resets the count.
48. The ranking stream pauses while the app is in the background and reconnects when it returns.
49. Tokens and the stream URL never appear in logs or errors.

---

### 13. Your Own Result List (Pool)

These apply only when you report `pool` (see [Integration guide > Step 6](integration_guide.md#step-6-good-to-have)). Without it, Rivi's list is the list.

50. Sort Best waits until the pool size is above 0.
51. An ask made before any results have loaded is held, and sent as soon as they do.
52. When the pool grows, the SDK re-ranks 0.3 s after the last growth, so a burst of pages makes one request.
53. The ranking turns `.final` only once the pool is complete.

---

**Next:** [Styling guide](styling.md)
