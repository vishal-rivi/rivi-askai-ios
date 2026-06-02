
# RiviAskAI Package Documentation

## Overview
![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)
![iOS](https://img.shields.io/badge/iOS-16.0+-blue.svg)
![macOS](https://img.shields.io/badge/macOS-12.0+-blue.svg)
![SPM](https://img.shields.io/badge/SPM-compatible-green.svg)

RiviAskAI is a Swift package that provides AI-powered sorting and filtering capabilities for flight and hotel search results in iOS applications. The package enables travel booking apps to offer intelligent, natural language-based search refinement to their users.

## Key Features

* AI-Powered Sorting: Automatically sort search results based on user preferences
* Natural Language Queries: Process user queries like "4 star hotels near airport with free breakfast" or "Direct flights that reach before 4PM"
* Real-time Updates: Subscribe to server-sent events (SSE) with built-in auto-reconnection, exponential backoff, and configurable timeouts.
* Granular State Management: Receive detailed connection states (Connecting, Reconnecting, Disconnected) to build responsive UIs.
* Pre-built UI Components: Ready-to-use, fully customizable SwiftUI views
* Custom UI Support: Use package logic with your own UI implementation
* Dual Query Types: Support for both hotel and flight searches
* Parameter Change Detection: Warns users when queries attempt to modify trip details

## Installation

### Swift Package Manager (SPM)

Add RiviAskAI to your project using Swift Package Manager:

1. In Xcode, select File > Add Packages...
2. Enter the package repository URL: "https://gitlab.com/riviai/ios/rivi_ask_ai.git"
3. Select the latest version
4. Click Add Package

---

## Support

For questions, issues, or feature requests:

* Email: shubhamnanda@rivi.co
* Example App: Included in package

---

## Changelog

### Version 1.3.0

* New UI Component — AlmatarSmartSortBottomSheet: Alternative bottom sheet with Almatar-styled visuals. Functionally equivalent to RiviAskAISheet (same callbacks, parameter change notice, clear-all confirmation, info tooltip) but renders a centered "Smart Sort" title, white prompt card with the sparkle prompt, in-card "Clear all" action, live `count/limit` counter on the text field, and a pill-shaped "Improve results" CTA. Close (X) and info (i) live in the navigation toolbar so they pick up the system Liquid Glass treatment on iOS 26+ automatically.
* RiviChipsView — Clear All: Added a trailing "Clear all" button that appears above the chip row whenever there are chips to clear. New `Configuration` fields (`showClearAllButton`, `clearAllText`, `clearAllFont`, `clearAllSpacing`, `clearAllColor`) and a new optional `onClearAll` callback on the initializer. Tapping "Clear all" empties the chips set and fires `onClearAll`.
* Optional `origin` parameter: `performSortBestRequest`, `performAskAIRequest`, and `performExplainAIRequest` now default `origin` to `""`. Hotel call-sites can omit it; flight call-sites should keep passing it.

### Breaking Changes

* RiviChipsView.Configuration: The public `init(...)` signature gained new required parameters (`showClearAllButton`, `clearAllText`, `clearAllFont`, `clearAllSpacing`, `clearAllColor`). Callers that build configurations via `Configuration.default` and mutate properties are unaffected.

### Version 1.2.0

* Robust SSE Connectivity: Completely refactored SSEClient to support automatic reconnection and exponential backoff strategies.
* Connection Configuration: Introduced SSEConfig to control timeouts, max retry attempts, and backoff multipliers. Includes presets: .default, .aggressive, and .conservative.
* Granular State Management: Exposed detailed connection states (Reconnecting, Disconnected with specific reasons) via the new onState callback to enable better UI feedback (e.g., "Retrying in 3s...").
* Model Updates: Update AskAIFilterRequest (Flights) and AskAIHotelFilterRequest (Hotels) to include missing passenger/guest parameters (adults, children, infant, childAges).

### Improvements

* Smart Error Handling: Added DisconnectReason to distinguish between recoverable errors (Network, Timeout) and permanent failures (Server Closed, Auth Failed).
* Explain Ai added along with new clear all button in Ask AI sheet
* Logging: Core logging infrastructure for the AskAI SDK. This includes the AskAILogLevel enum for defining log severity and the AskAILogger protocol (interface) to allow the SDK to log messages abstractly.

### Breaking Changes

* API Update: RiviAskAI.subscribeToEvents now accepts an optional SSEConfig parameter and an optional onState callback. Existing implementations will need to be updated.
