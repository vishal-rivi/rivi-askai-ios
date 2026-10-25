---
title: Migrate from V1
sidebar_position: 7
slug: migrate-from-v1
---

# Migrate from V1

Move an app from RiviAskAI (V1) to RiviSmartSort (V2). Read the [Integration guide](integration_guide.md)
alongside this page: it covers every V2 step in full.

Smart Sort was called Ask AI in V1, which is why V1 APIs are named `AskAI…` and the gateway is
still `askai-gateway`.

---

## What Changes

In V1 your app called the APIs and decided when: subscribe to the stream, call Sort Best, call
Ask AI, call Explain AI, keep the chips, clear on a tab change. In V2 your app **reports facts**
(the search, the sort tab, the filters, the results it shows) and the SDK decides what to send and
when. You no longer call any endpoint.

| | V1 (RiviAskAI) | V2 (RiviSmartSort) |
|---|---|---|
| Package | `RiviAskAI`, from the shared repository | Your tenant package, `RiviSmartSort<YourCompany>` |
| Setup | `RiviAskAI.initialize(environment:authToken:language:…)`, once per app | One `RiviSmartSort(build: .bundled, …)` per results screen |
| Token | Passed in code (`authToken:`) | Bundled in the tenant package; `auth:` only to bridge a rotation |
| Language | `language: .english` / `.arabic` | `locale: "en"` / `"ar"`; `setLocale(_:)` at runtime |
| Currency | Passed on each request | `currency:` once, on the session |
| Ranking stream | `subscribeToEvents(searchId:config:onState:onEvent:onError:)`; you parse JSON | Opened for you when you report `search`; `.ranking` events with typed `RankingEntry` values |
| Reconnects | `SSEConfig` (`.default`, `.aggressive`, `.conservative`) | Built in: 1, 2, 4, 8 s backoff, 5 failures. No configuration |
| Sort Best | `performSortBestRequest(…)` | Automatic on every new `search`, and after the query is cleared |
| Asking | `performAskAIRequest(query:…)`; you keep `response.chips` | The sheet calls `smartSort.ask(_:)`; read `smartSort.chips` |
| Explain AI | `performExplainAIRequest(…, onPartialContent:)` | Automatic 0.5 s after the first ranking; shown by the banner |
| Chip removal | You rebuild the query and ask again | `smartSort.removeChip(label:)` (the banner does it) |
| Sort tab change | You present `RiviConfirmationDialog` and clear | Report `sort`; `.riviSmartSortConfirmation(smartSort)` asks |
| Tear down | `RiviAskAI.disconnect()` | `smartSort.destroy()` |
| Dates | `Date` values | `String`s from `RiviDate.string(from:)` |
| Trip type | `isRound: Bool` | `tripType: .oneway`, `.round` or `.multicity` |
| Cabin | `cabinType: "Economy"` | `cabin: .economy`, `.premium`, `.business`, `.first` |
| Logging | `AskAILogLevel`, `AskAILogger` (`debug`/`info`/`warn`/`error`) | `RiviLogLevel`, `RiviLogger` (`isEnabled(_:)` and `log(_:_:)`) |
| Connection state | `onState` with `SSEConnectionState`, `DisconnectReason` | `.error(RiviError)` with `kind` and `retryable`; the banner shows it |

---

## Views

| V1 | V2 |
|---|---|
| `RiviAskAIButton` | `RiviSmartSortButton(smartSort)` |
| `RiviAskAISheet` | `RiviSmartSortV2BottomSheet(smartSort, isPresented:)` |
| `RiviChipsView` + `RiviInfoBanner` | `RiviSmartSortV2Banner(smartSort, onEdit:)` (chips and Explain AI together) |
| `RiviConfirmationDialog` (you present it) | `.riviSmartSortConfirmation(smartSort)` |
| `RiviAlertDialog` | No bound equivalent: request errors show inline in the banner with **Try again** |
| `RiviAskAIFirstTimeBanner` | Not part of V2 |
| None | `SmartSortPromptResultCard`, `SmartSortPromptFilterCard` (new) |

To keep the V1 look while moving to the V2 session, use the V1-design bound views:
`RiviSmartSortChips`, `RiviSmartSortBanner`, `RiviSmartSortAskSheet`, `RiviSmartSortBottomSheet`,
`RiviSmartSortAskButton` (see [Reference > V1 Bound Views](reference.md#5-v1-bound-views)).

---

## Behaviour That Differs

* **Filters and the query co-exist.** Reporting filters never clears the query or makes a request; the next request carries them.
* **A new search** (a new `searchId`) resets the query, chips and explanation, and keeps your sort tab, filters and pool.
* **The return leg** of a round trip hides the banner and chips without clearing them; they come back on the onward leg.
* **Explain AI** is requested by the SDK 0.5 s after the first ranking of each ask.
* **The query** is limited to 200 characters in the sheet.

The full list is in [Reference > Behaviour Rules](reference.md#behaviour-rules).

---

## Steps

1. Remove the `RiviAskAI` package and add your tenant package ([Install](install.md)).
2. Delete `RiviAskAI.initialize(…)`. Create one `RiviSmartSort` per results screen with `@StateObject`.
3. Delete your `subscribeToEvents`, `performSortBestRequest`, `performAskAIRequest` and `performExplainAIRequest` calls, and the state that held their results.
4. Set `onEvent` and apply `.ranking` to your list ([Integration guide > Step 2](integration_guide.md#step-2-sort-best)).
5. Report `search` on every new search, with dates from `RiviDate.string(from:)`. Report `sort`, `stage`, `filters` and `visible` as they change.
6. Replace the V1 views with the V2 views above, and add `.riviSmartSortConfirmation(smartSort)`.
7. Replace `RiviAskAI.disconnect()` with `smartSort.destroy()` when the results screen is dismissed for good.
8. Move a custom `AskAILogger` to `RiviLogger`.
9. Run the [Integration guide's Check It list](integration_guide.md#check-it) and pre-ship checklist.
