---
title: Styling guide
sidebar_position: 5
slug: styling
---

# Styling Guide

Make the Smart Sort views match your app. Read the [Integration guide](integration_guide.md) first:
this page assumes the views are already on your screen.

The views ship with the Smart Sort V2 design, in light and dark mode, English and Arabic. Change
only what still differs from your app. There are no CSS-style tokens on iOS: every view takes a
**`Configuration`** struct, and that is the one place its text, fonts, sizes and colours come from.

* **Presets:** `.default` (the V2 design) and, for some views, `.rivi` (the Rivi design).
* **Your own configuration:** copy a preset, change the properties you need, pass it to the view.
* **Your own views:** for anything a configuration can't express, build the UI yourself from the
  session's state (see [Reference > Custom UI](reference.md#custom-ui)).

---

## How It Works

Every bound view takes `configuration:`. Copy the default, edit it, pass it in:

```swift
var sheet = SmartSortV2BottomSheet.Configuration.default
sheet.submitButtonBackgroundColor = Color("BrandAccent")
sheet.inputFocusedBorderColor = Color("BrandAccent")
sheet.sheetCornerRadius = 20

RiviSmartSortV2BottomSheet(smartSort, isPresented: $showSmartSort, configuration: sheet)
```

* A property you set replaces the default; everything you leave alone keeps the V2 design.
* Build configurations inside `body` (or a computed property). `.default` reads the current
  language, so a configuration stored once keeps the language it was built in after `setLocale`.
* Text you set yourself (for example `submitButtonText`) is used in every language. Leave text
  properties alone to keep the SDK's English and Arabic.
* `Color(hex:)` inside the SDK isn't public. Use colours from your asset catalog, or
  `Color(red:green:blue:)`.

### Which Configuration Each View Takes

| View in your app | `configuration:` type | Presets |
|---|---|---|
| `RiviSmartSortButton` | `SmartSortHaloButton.Configuration` | `.default`, `.rivi` |
| `RiviSmartSortV2BottomSheet` | `SmartSortV2BottomSheet.Configuration` | `.default` |
| `RiviSmartSortV2Banner` | `SmartSortV2DynamicBanner.Configuration` | `.default` |
| `.riviSmartSortConfirmation` | `RiviConfirmationDialog.Configuration` | `.default` |
| `SmartSortPromptResultCard` | `SmartSortPromptResultCard.Configuration` | `.default` |
| `SmartSortPromptFilterCard` | `SmartSortPromptFilterCard.Configuration` | `.default` |
| `SmartSortTwinkleText` | `SmartSortTwinkleText.Configuration` | `.default` |
| Chips inside the banner | `RiviChipsView.Configuration`, via the banner's `chipsConfiguration` | `SmartSortV2DynamicBanner.Configuration.defaultChips` |
| The sparkle inside any view | `SmartSortSparkle.Configuration`, via that view's `sparkleConfiguration` | `.default`, `.rivi`, `.withBurst`, `.plain(_:)` |

---

## Your Brand Across Every View

The views don't share a theme, so set your accent on each one. Keep it in one place:

```swift
import SwiftUI
import RiviSmartSortYourCompany

/// Your brand, applied to the Smart Sort views. Colours come from your asset catalog,
/// with Any and Dark appearances, so dark mode keeps working.
enum SmartSortStyle {
    static let accent = Color("BrandAccent")
    static let tint = Color("BrandTint")          // light fill behind chips and labels
    static let font = "YourFont-Regular"

    static var sparkle: SmartSortSparkle.Configuration { .plain(accent) }

    static var button: SmartSortHaloButton.Configuration {
        var c = SmartSortHaloButton.Configuration.default
        c.textColor = accent
        c.badgeBackgroundColor = accent
        c.haloColors = [accent.opacity(0), accent]
        c.sparkleConfiguration = sparkle
        return c
    }

    static var sheet: SmartSortV2BottomSheet.Configuration {
        var c = SmartSortV2BottomSheet.Configuration.default
        c.sparkleConfiguration = sparkle
        c.inputFocusedBorderColor = accent
        c.suggestionSelectedColor = accent
        c.submitButtonBackgroundColor = accent
        c.inputFont = .custom(font, size: 15)
        return c
    }

    static var banner: SmartSortV2DynamicBanner.Configuration {
        var c = SmartSortV2DynamicBanner.Configuration.default
        c.sparkleConfiguration = sparkle
        c.editButtonColor = accent
        c.backgroundColor = tint
        var chips = c.chipsConfiguration
        chips.chipTextColor = accent
        c.chipsConfiguration = chips
        return c
    }
}

// On the screen
RiviSmartSortButton(smartSort, configuration: SmartSortStyle.button) { showSmartSort = true }
RiviSmartSortV2Banner(smartSort, configuration: SmartSortStyle.banner, onEdit: { showSmartSort = true })
```

The prompt cards and the confirmation take the same treatment: `sparkleConfiguration`,
`backgroundColor` / `backgroundGradient` and their text colours.

---

## What You Can Style

Every property, by view. Defaults are in the [Reference](reference.md#elements).

### RiviSmartSortV2BottomSheet

`SmartSortV2BottomSheet.Configuration`

| Group | Properties | What they are |
|---|---|---|
| Text | `titleText`, `descriptionText` | The heading and the line under it. Empty description uses the flight or hotel default |
| | `placeholderText`, `animatesPlaceholder`, `placeholderExamples`, `examplePrefix`, `exampleAnimation` | The empty input: typed-out examples ("e.g. …"), or a static placeholder when `animatesPlaceholder` is false |
| | `suggestions` | The suggestion chips. Empty uses the flight or hotel defaults |
| | `submitButtonText`, `showsSubmitButtonIcon` | **Improve Results**, with the sparkle before it |
| | `showsFiltersNote` | "Your filters (…) will now be used to rank flights." with `filterLabels` |
| | `showsClearAllButton`, `clearAllButtonText` | "Clear All" in the header (also needs `onClearAll`) |
| | `errorText`, `retryButtonText` | The inline error (plain version only) |
| Limits | `characterLimit`, `inputLineLimit` | Longest query; lines shown before the input scrolls |
| Fonts | `titleFont`, `descriptionFont`, `filtersNoteFont`, `inputFont`, `suggestionFont`, `submitButtonFont`, `clearAllButtonFont`, `errorFont`, `retryButtonFont` | |
| Layout | `padding`, `sparkleSize`, `sheetCornerRadius` (iOS 16.4+), `inputCornerRadius`, `submitButtonHeight`, `submitButtonCornerRadius` | `submitButtonCornerRadius` nil is a capsule |
| Colours | `backgroundColor`, `titleColor`, `descriptionColor`, `sparkleConfiguration` | The sheet and its header |
| | `filtersNoteColor`, `filtersNoteIconColor` | The filters line |
| | `closeButtonBackgroundColor`, `closeButtonColor`, `clearAllButtonColor` | Header buttons |
| | `inputBackgroundColor`, `inputBorderColor`, `inputFocusedBorderColor`, `textColor`, `placeholderColor` | The input; the focused border also draws a soft ring |
| | `suggestionBorderColor`, `suggestionTextColor`, `suggestionSelectedColor`, `suggestionSelectedBackgroundColor` | Suggestions; "selected" is one already in the query |
| | `submitButtonBackgroundColor`, `submitButtonTextColor`, `submitButtonDisabledBackgroundColor`, `submitButtonDisabledTextColor` | The submit button, enabled and with an empty input |
| | `errorBackgroundColor`, `errorBorderColor`, `errorTextColor`, `retryButtonBackgroundColor` | The inline error |

### RiviSmartSortV2Banner

`SmartSortV2DynamicBanner.Configuration`

| Group | Properties | What they are |
|---|---|---|
| Design | `layout` | `.classic` ("Ranked by your preferences", Edit and ✕) or `.collapsible` ("Why these flights are recommended", a chevron, no ✕) |
| | `loadingStyle` | `.skeleton` (pulsing bars) or `.shimmerText` (`loadingText` with a sweeping band) |
| | `clearFiltersPlacement` | `.inline` (a link after the notice) or `.trailing` (a button at its end) |
| | `showsEditIcon`, `noticeIconName` | The pencil before Edit; the notice's SF Symbol |
| | `animatesChipEntrance` | Chips fade and scale in one after another |
| Text | `titleText`, `collapsibleTitleText`, `editButtonText`, `loadingText`, `errorText`, `retryButtonText`, `clearFiltersText` | |
| Streaming | `streamingUnit`, `streamingInterval` | How the explanation types out |
| Fonts | `titleFont`, `editButtonFont`, `explanationFont`, `filterNoticeFont`, `clearFiltersFont`, `errorFont`, `retryButtonFont` | |
| Layout | `padding`, `spacing`, `cornerRadius`, `sparkleSize`, `explanationLineSpacing` | |
| Chips | `chipsConfiguration` | The chip row (see [Chips](#chips-in-the-banner)) |
| Colours | `backgroundColor`, `backgroundGradient`, `borderColor` | The card; a gradient replaces the background colour |
| | `titleColor`, `sparkleConfiguration`, `editButtonColor`, `clearButtonColor`, `chevronColor` | The header |
| | `explanationColor` | The explanation text |
| | `skeletonColor`, `skeletonSecondaryColor`, `loadingTextColor`, `loadingShimmerColor` | Loading |
| | `noticeBackgroundColor`, `noticeBorderColor`, `noticeTextColor`, `noticeIconColor` | The purple notice ("hiding some recommended …") |
| | `warningBackgroundColor`, `warningBorderColor`, `warningTextColor` | The yellow notice ("hiding the flights you asked for") |
| | `clearFiltersColor` | The Clear Filters link or button |
| | `errorBackgroundColor`, `errorBorderColor`, `errorTextColor`, `retryButtonBackgroundColor`, `retryButtonBorderColor` | The inline error |

### Chips in the Banner

`RiviChipsView.Configuration`, set through the banner's `chipsConfiguration`. Start from
`SmartSortV2DynamicBanner.Configuration.defaultChips`.

| Group | Properties | What they are |
|---|---|---|
| Content | `icon`, `showsIcon`, `iconSize`, `iconColor` | An image before each chip's text, e.g. `SmartSortSparkle.image` |
| | `keyFont` | Bold key in "**Departure:** after 5 PM" |
| | `showClearAllButton`, `clearAllText`, `clearAllFont`, `clearAllColor`, `clearAllSpacing` | A "Clear all" row above the chips (off in the banner) |
| Layout | `font`, `cornerRadius`, `chipPadding`, `spacing`, `textIconSpacing` | |
| | `removeIconSize`, `removeButtonSize` | The ✕ and its tap area |
| | `fadesEdges`, `edgeFadeWidth`, `contentPadding` | Edge fades while chips scroll sideways |
| Motion | `animatesEntrance` | Fade and scale in |
| Colours | `chipBackgroundColor`, `chipBorderColor`, `chipTextColor`, `removeIconColor` | |

### RiviSmartSortButton

`SmartSortHaloButton.Configuration` (`.rivi` for the Rivi design)

| Group | Properties | What they are |
|---|---|---|
| Content | `text`, `font`, `textColor`, `sparkleSize`, `sparkleConfiguration` | "Smart Sort" and the sparkle |
| Layout | `height`, `horizontalPadding`, `spacing`, `cornerRadius` | |
| Border | `backgroundColor`, `borderColor`, `borderWidth` | The resting button |
| Halo | `showsHalo`, `haloColors`, `haloDuration`, `haloWidth` | The arc that circles the border, from faint tail to bright head |
| Badge | `badgeFont`, `badgeBackgroundColor`, `badgeTextColor`, `badgeSize` | The number of active preferences |

### SmartSortTwinkleText

For your own Smart Sort button: `SmartSortTwinkleText.Configuration`.

| Group | Properties | What they are |
|---|---|---|
| Content | `text`, `font`, `textColor`, `sparkleSize`, `sparkleConfiguration` | |
| Motion | `shimmerColor`, `twinkleInterval`, `initialDelay` | The twinkle and the band that sweeps the text after it |
| Pill | `backgroundColor`, `activeBackgroundColor`, `spacing`, `padding` | Inactive and active (with a count) |
| Badge | `badgeFont`, `badgeBackgroundColor`, `badgeTextColor`, `badgeSize` | |

### SmartSortPromptResultCard

`SmartSortPromptResultCard.Configuration`

| Group | Properties | What they are |
|---|---|---|
| Text | `titleText`, `descriptionText`, `examples`, `examplePrefix`, `quotesExample`, `exampleAnimation` | "Not sure which one to pick?" and the typed-out examples |
| Fonts | `titleFont`, `descriptionFont`, `exampleFont` | |
| Layout | `padding`, `cornerRadius`, `sparkleSize`, `inputHeight`, `inputCornerRadius`, `sendButtonSize` | |
| Colours | `backgroundColor`, `backgroundGradient`, `borderColor`, `glowColor`, `glowOpacity` | The card and its corner glow |
| | `titleColor`, `descriptionColor`, `dismissButtonColor`, `sparkleConfiguration` | |
| | `inputBackgroundColor`, `inputBorderColor`, `exampleColor`, `cursorColor`, `sendButtonBackgroundColor`, `sendButtonIconColor` | The fake input |

### SmartSortPromptFilterCard

`SmartSortPromptFilterCard.Configuration`

| Group | Properties | What they are |
|---|---|---|
| Text | `text`, `buttonText` | The row's text; `buttonText` is what VoiceOver reads |
| Layout | `textFont`, `padding`, `cornerRadius`, `spacing`, `sparkleSize`, `arrowSize` | |
| Colours | `backgroundColor`, `backgroundGradient`, `borderColor`, `highlightedBorderColor`, `textColor`, `arrowColor`, `sparkleConfiguration` | `highlightedBorderColor` is used with `isHighlighted` |

### The Confirmation

`RiviConfirmationDialog.Configuration`, passed to `.riviSmartSortConfirmation(smartSort, configuration:)`.

| Group | Properties | What they are |
|---|---|---|
| Text | `titleText`, `descriptionText`, `cancelButtonText`, `confirmButtonText` | Defaults: "Clear Ask AI Query", **Back**, **Proceed** |
| Fonts | `titleFont`, `descriptionFont`, `buttonFont` | |
| Layout | `cornerRadius`, `padding`, `spacing`, `buttonSpacing`, `buttonHeight` | |
| Colours | `backgroundColor`, `overlayBackgroundColor`, `titleColor`, `descriptionColor` | |
| | `cancelButtonBackgroundColor`, `cancelButtonTextColor`, `cancelButtonBorderColor`, `confirmButtonBackgroundColor`, `confirmButtonTextColor` | |

To show your own dialog instead, set `smartSort.presentsSortConfirmation = false`, handle
`.confirmSortChange`, and call `resolveSortConfirmation(accepted:)`.

### The Sparkle

`SmartSortSparkle.Configuration`, inside every view's `sparkleConfiguration`.

| Property | What it is |
|---|---|
| `style` | `.classic` or `.rivi` |
| `primaryColor` | The star and "+" colour |
| `starGradient`, `plusColor`, `secondaryPlusColor` | `.rivi` only. nil uses `primaryColor` |
| `showsBurst`, `burstColors`, `twinkleInterval`, `initialDelay` | The burst of tiny stars |
| `loopDuration` | Seconds per wiggle and twinkle |

`.plain(color)` draws it in one colour; `SmartSortSparkle.image` is a static template image for
your own views.

---

## Language and Direction

```swift
RiviSmartSort(build: .bundled, locale: "ar", currency: "USD")
```

* `locale`: `"en"` (default) or `"ar"`. It sets the views' text and the language of Rivi's
  explanation. `smartSort.setLocale("ar")` switches at runtime and keeps the query.
* Direction: the banner, sheet, chips and confirmation switch to right-to-left by themselves. The
  button, twinkle label and prompt cards follow your screen's layout direction.
* Your own wording has two places:
  * **On a view** (titles, button text, placeholders, suggestions): set its configuration's text
    properties. They're used in every language, so set them per locale yourself.
  * **Smart Sort's messages** (chip labels, the fallback line, the conflict line): override them
    with `strings:`, per locale, in ICU syntax:

```swift
RiviSmartSort(build: .bundled, locale: "ar", currency: "USD",
              strings: ["en": ["explain.fallback": "Some results only partly match"],
                        "ar": ["explain.fallback": "بعض النتائج تطابق جزئياً"]])
```

Keep the placeholders (`{query}`, `{n}`), and write plurals with every form your language has
(Arabic adds `zero`, `two`, `few`, `many`).

---

## Layout Notes

* Hidden views take no space: the banner draws nothing until the user asks, and nothing on other
  sort tabs or the return leg.
* `RiviSmartSortButton` dims and disables itself while Smart Sort isn't available. Don't add your
  own `.disabled` on top.
* `sheetCornerRadius` needs iOS 16.4; earlier versions use the system sheet corners.
* From UIKit, host each view in a `UIHostingController` and give it the same session.

## Dark Mode

The defaults adapt to light and dark mode. Colours you pass replace both, so use asset-catalog
colours with an Any and a Dark appearance, or the system colours (`.primary`, `.secondary`,
`Color(.systemBackground)`).

## Reduced Motion

With Reduce Motion on, the sparkle, halo, twinkle, chip entrance, example typing and the
explanation's typing keep still or appear at once. You don't need to do anything. To turn motion
off for everyone:

```swift
var button = SmartSortHaloButton.Configuration.default
button.showsHalo = false

var sheet = SmartSortV2BottomSheet.Configuration.default
sheet.animatesPlaceholder = false

var banner = SmartSortV2DynamicBanner.Configuration.default
banner.animatesChipEntrance = false
```

---

**Next:** [Troubleshooting](troubleshooting.md)
