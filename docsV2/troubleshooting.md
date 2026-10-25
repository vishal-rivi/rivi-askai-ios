---
title: Troubleshooting
sidebar_position: 6
slug: troubleshooting
---

# Troubleshooting

Symptoms, their causes and fixes, plus every error and log message the SDK produces. Turn on
`logLevel: .debug` before you start (see [Reference > Logging](reference.md#logging)).

---

## Symptom → Cause → Fix

| Symptom | Cause | Fix |
|---|---|---|
| No ranking arrives | `onEvent` was set after `search` | Set `onEvent` before you report `search` |
| | `searchId` isn't the id of the results on screen | Report the id your search returned for these results |
| | Smart Sort isn't available (multi-city, or the return leg) | Check `smartSort.isAvailable` |
| | You report `pool` and its `size` is 0 | Report `pool` with `size` above 0 once results load |
| The list doesn't reorder | You apply `ranking` on a tab other than Best | `ranking` is empty off Best; apply it on Best only |
| | You don't report `sort = .best` while the user is on Best | Report `sort` whenever the tab changes |
| The banner never shows | No query yet, or not on Best | The banner shows only after the user asks, on Best, while Smart Sort is available |
| | The banner and the sheet use different sessions | Pass the same `RiviSmartSort` to every view |
| No Explain AI text | It's Sort Best (no query) | Explain AI runs only for a query |
| | No preferences were extracted from the query | Expected: there is no explanation; the fallback line shows if some results only partly match |
| A filter notice shows when nothing is hidden | `visible` isn't reported | Report `visible` after your filters |
| Tags don't show | The id you pass to `tags(for:)` differs from the one you report | Use the same ids everywhere |
| | You expect the SDK to draw them | The SDK doesn't draw tags: render them on your result card |
| | You're off Best | Tags are empty off Best |
| Wrong language | `locale` not passed | Pass `locale: "ar"` when creating the session, or call `smartSort.setLocale("ar")` |
| The button or a prompt card stays left-to-right | Your screen isn't right-to-left | Apply `.environment(\.layoutDirection, .rightToLeft)` to the screen |
| Changing filters doesn't re-rank | Expected on iOS | Reporting filters never makes a request; the next ask, chip removal or new search carries them |
| Every request fails with `.auth` after a token rotation | The bundled token was rotated | Update to the rebuilt tenant package, or bridge with `auth:` |

---

## Error Kinds

Every failure reaches you as `.error(RiviError)`. The banner already shows it with **Try again**
when `retryable` is true.

| `kind` | `message` | Retryable | What to do |
|---|---|---|---|
| `.network` | Network request failed | Yes | Check connectivity; **Try again** |
| `.timeout` | No response within 30 s | Yes | A request or the Explain AI stream sent nothing for 30 s |
| `.timeout` | No ranking within 30 s | Yes | The round produced no ranking; check `searchId` |
| `.auth` | The gateway rejected the token twice (HTTP 401). Supply the new token through auth. | No | Update the tenant package, or pass `auth:` |
| `.auth` | auth() did not return a token | Yes | Your `auth:` closure threw or returned nothing |
| `.server` | HTTP *status* | For 5xx and 429 | A 4xx other than 429 means the request was rejected; check the search details and dates |
| `.server` | The ask response was not JSON | Yes | Report it to Rivi with the debug log |
| `.stream` | The ranking stream failed 5 times in a row | Yes | Connectivity; **Try again** reconnects |
| `.stream` | The ranking stream reported an error (or the gateway's message) | Yes | Report it to Rivi with the debug log |

---

## Log Messages

| Level | Message | Meaning |
|---|---|---|
| `.info` | A request block (`POST` or `GET`) and a response block per call | Normal traffic |
| `.warn` | `ranking stream for <searchId> dropped; reconnecting in <n> ms (failure <k> of 5)` | The stream reconnects on its own; the fifth failure becomes an error |
| `.warn` | `[smart-sort] dropped an entry without an id (scope …)` | Rivi sent a result without an id; it's skipped |
| `.warn` | `[smart-sort] dropped a duplicate entry <id> (scope …)` | Rivi sent the same id twice; the second is skipped |
| `.error` | `<endpoint> answered 200 with an error` | The gateway reported a failure inside a 200 response (for example a date it can't parse); use `RiviDate.string(from:)` |
| `.error` | `request failed` | An error block for every failure, with its `RiviError` |

Tokens and the stream URL never appear in logs or errors.

---

**Next:** [Migrate from V1](migrate_from_v1.md)
