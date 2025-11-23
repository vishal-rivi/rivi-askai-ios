# RiviAskAI Package Documentation

## Overview

**RiviAskAI** is a Swift package that provides AI-powered sorting and filtering capabilities for flight and hotel search results in iOS applications. The package enables travel booking apps to offer intelligent, natural language-based search refinement to their users.

### Key Features

- **AI-Powered Sorting**: Automatically sort search results based on user preferences
- **Natural Language Queries**: Process user queries like "4 star hotels near airport with free breakfast" or "Direct flights that reach before 4PM"
- **Real-time Updates**: Subscribe to Server-Sent Events (SSE) for live sorted results
- **Pre-built UI Components**: Ready-to-use, fully customizable SwiftUI views
- **Custom UI Support**: Use package logic with your own UI implementation
- **Dual Query Types**: Support for both hotel and flight searches
- **Parameter Change Detection**: Warns users when queries attempt to modify trip details

---

## Installation

### Swift Package Manager

Add RiviAskAI to your project using Swift Package Manager:

1. In Xcode, select **File > Add Packages...**
2. Enter the package repository URL: https://github.com/vishal-rivi/rivi-askai-ios.git
3. Select the latest version
4. Click **Add Package**

### Requirements

- iOS 16.0+ / macOS 12.0+
- Swift 5.9+
- Xcode 14.0+

---

## Getting Started

### Prerequisites

Before using RiviAskAI, you need:

1. **Search ID**: Obtained from your initial search API call
2. **Authorization Token**: Your API authentication token
3. **Trip Details**: Origin, destination, dates (for hotels), and other search parameters

### Initialization

Initialize the package once at app startup to configure the environment, auth token, and language:

```swift
import SwiftUI
import RiviAskAI

@main
struct YourApp: App {
    init() {
        // Initialize RiviAskAI with environment, auth token, and language
        RiviAskAI.initialize(
            environment: .staging,  // or .production or .custom(baseURL:)
            authToken: "YOUR_AUTH_TOKEN",
            language: .english  // or .arabic
        )
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

**Parameters:**
- `environment`: `.staging`, `.production`, or `.custom(baseURL: "...")`
- `authToken`: Your authorization token (required)
- `language`: `.english` or `.arabic`

**Environments:**
- `.staging`: Uses `https://askai-gateway-staging.rivi.co/api/v1`
- `.production`: Uses `https://askai-gateway.rivi.co/api/v1`
- `.custom(baseURL:)`: Uses your custom base URL

After initialization, the auth token and language are used globally for all API calls.

### Basic Setup

```swift
import SwiftUI
import RiviAskAI

struct ContentView: View {
    @State private var filterChips: Set<String> = []
    @State private var showAskAISheet = false
    @State private var isButtonEnabled = false
    
    private let searchId = "YOUR_SEARCH_ID"
    private let authToken = "YOUR_AUTH_TOKEN"
    
    var body: some View {
        VStack {
            // Display filter chips
            if !filterChips.isEmpty {
                RiviChipsView(chips: $filterChips) { removedChip in
                    handleChipRemoval(removedChip)
                }
            }
            
            // Ask AI button
            RiviAskAIButton(isEnabled: $isButtonEnabled) {
                showAskAISheet = true
            }
        }
        .sheet(isPresented: $showAskAISheet) {
            RiviAskAISheet(
                isPresented: $showAskAISheet,
                queryType: .hotel,
                onSubmit: { query in
                    processUserQuery(query)
                }
            )
        }
    }
}
```

---

## Core API Reference

### RiviAskAI Class

The main entry point for all package functionality.

**Recommended Flow:**
1. Get searchId from your search API
2. Subscribe to SSE events (to receive sorted results)
3. Call Sort Best API (for automatic sorting)
4. Call Ask AI API (when user enters a query)

#### 1. Subscribe to Events (SSE)

Subscribe to real-time sorted results via Server-Sent Events. **Call this immediately after receiving your search ID** to start receiving sorted results.





```swift
public static func subscribeToEvents(
    searchId: String,
    onEvent: @escaping (String) -> Void,
    onError: @escaping (Error) -> Void
)
```

**Parameters:**
- `searchId`: The search identifier from your initial search
- `onEvent`: Callback receiving JSON event data as string
- `onError`: Callback for connection errors

**Returns:** Nothing (void). Results are delivered via the `onEvent` callback.

**Note:** Auth token is automatically used from global configuration set during initialization.

**Example:**

```swift
// Step 1: Get searchId from your search API
let searchResponse = try await yourSearchAPI.search(...)
let searchId = searchResponse.searchId

// Step 2: Subscribe to SSE immediately
RiviAskAI.subscribeToEvents(
    searchId: searchId,
    onEvent: { jsonData in
        // Parse and display sorted results
        print("Received sorted results: \(jsonData)")
        
        // Parse JSON and update UI
        if let data = jsonData.data(using: .utf8),
           let results = try? JSONDecoder().decode([YourResultModel].self, from: data) {
            DispatchQueue.main.async {
                self.displayResults(results)
            }
        }
    },
    onError: { error in
        print("SSE Error: \(error)")
        // Handle connection errors
    }
)

// Step 3: Now call Sort Best or Ask AI APIs
// The sorted results will be delivered via the onEvent callback above
```

**Important Notes:**
- Subscribe to SSE **before** calling Sort Best or Ask AI APIs
- The SSE connection will deliver sorted results whenever you call Sort Best or Ask AI
- Keep the connection active while displaying results
- Call `disconnect()` when leaving the results screen

#### 2. Sort Best API (Initial Sorting)

Automatically sorts search results without a user query. **Call this after subscribing to SSE** to get initial sorted results.

```swift
public static func performSortBestRequest(
    searchId: String,
    isRound: Bool = false,
    queryType: QueryType,
    currency: String,
    checkin: Date? = nil,
    checkout: Date? = nil,
    destination: String,
    origin: String
) async throws -> AskAIResponse
```

**Parameters:**
- `searchId`: The search identifier from your initial search
- `isRound`: Whether this is a round trip flight (default: false)
- `queryType`: `.hotel` or `.flight`
- `currency`: Currency code (e.g., "SAR", "AED", "USD", "INR")
- `checkin`: Check-in date (required for hotels)
- `checkout`: Check-out date (required for hotels)
- `destination`: Destination location
- `origin`: Origin location

**Returns:** `AskAIResponse` containing:
- `chips`: Set of filter chips to display
- `parameterChangeNotice`: Warning message if applicable
- `rawResponse`: Complete API response
- `entity`: First entity from response for custom processing

**Example:**

```swift
Task {
    do {
        let response = try await RiviAskAI.performSortBestRequest(
            searchId: searchId,
            isRound: false,
            queryType: .hotel,
            currency: "SAR",
            checkin: checkinDate,
            checkout: checkoutDate,
            destination: "Singapore",
            origin: "Riyadh"
        )
        
        // Display chips returned from API
        filterChips = response.chips
        
        // Sorted results will be delivered via SSE onEvent callback
    } catch {
        print("Error: \(error)")
    }
}
```

#### 3. Ask AI API (User Query)

Process a natural language query from the user to refine sorting. **Call this when user enters a query** to get refined sorted results.

```swift
public static func performAskAIRequest(
    query: String,
    searchId: String,
    isRound: Bool = false,
    queryType: QueryType,
    currency: String,
    checkin: Date? = nil,
    checkout: Date? = nil,
    destination: String,
    origin: String
) async throws -> AskAIResponse
```

**Parameters:** Same as Sort Best API, plus:
- `query`: User's natural language query (e.g., "4 star hotels near airport")

**Example:**

```swift
Task {
    do {
        let response = try await RiviAskAI.performAskAIRequest(
            query: "Show me 5 star hotels with pool and gym",
            searchId: searchId,
            isRound: false,
            queryType: .hotel,
            currency: "SAR",
            checkin: checkinDate,
            checkout: checkoutDate,
            destination: "Dubai",
            origin: "Riyadh"
        )
        
        // Display chips returned from API
        filterChips = response.chips
        
        // Check for parameter change warning
        if let notice = response.parameterChangeNotice {
            showWarning(notice)
        }
        
        // Sorted results will be delivered via SSE onEvent callback
    } catch {
        print("Error: \(error)")
    }
}
```

#### 4. Disconnect

Disconnect from active SSE connection.

```swift
public static func disconnect()
```

**Example:**

```swift
// Call when leaving the results screen
override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    RiviAskAI.disconnect()
}
```

---

## UI Components

RiviAskAI provides six customizable SwiftUI views. Each view has a `Configuration` struct for complete customization.

### 1. RiviAskAIButton

A button that triggers the Ask AI sheet.

**Basic Usage:**

```swift
RiviAskAIButton(isEnabled: $isButtonEnabled) {
    showAskAISheet = true
}
```

**Custom Configuration:**

```swift
var customConfig = RiviAskAIButton.Configuration.default
customConfig.text = "Refine Search"
customConfig.backgroundColor = Color.blue
customConfig.textColor = Color.white
customConfig.cornerRadius = 12

RiviAskAIButton(
    configuration: customConfig,
    isEnabled: $isButtonEnabled
) {
    showAskAISheet = true
}
```

**Configuration Options:**
- `text`: Button text (default: "Ask AI")
- `font`: Text font
- `showIcon`: Show/hide sparkle icon
- `spacing`: Icon-text spacing
- `cornerRadius`: Button corner radius
- `padding`: Internal padding
- `iconSize`: Icon size
- `backgroundColor`: Button background color
- `textColor`: Text color
- `iconColor`: Icon color
- `disabledBackgroundColor`: Disabled state background
- `disabledTextColor`: Disabled state text color

### 2. RiviAskAISheet

A bottom sheet for user query input.

**Basic Usage:**

```swift
RiviAskAISheet(
    isPresented: $showSheet,
    queryType: .hotel,
    onSubmit: { query in
        processQuery(query)
    }
)
```

**With Pre-filled Query and Warning:**

```swift
RiviAskAISheet(
    isPresented: $showSheet,
    queryType: .flight,
    userQuery: "Direct flights",
    parameterChangeNotice: "Your prompt includes changes to trip details",
    onSubmit: { query in
        processQuery(query)
    }
)
```

**Custom Configuration:**

```swift
var customConfig = RiviAskAISheet.Configuration.default
customConfig.titleText = "Refine Your Search"
customConfig.submitButtonText = "Apply Filters"
customConfig.backgroundColor = Color.white
customConfig.submitButtonBackgroundColor = Color.blue

RiviAskAISheet(
    configuration: customConfig,
    isPresented: $showSheet,
    queryType: .hotel,
    onSubmit: { query in
        processQuery(query)
    }
)
```

**Configuration Options:**
- `titleText`: Sheet title
- `placeholderText`: Input placeholder (auto-set based on queryType)
- `submitButtonText`: Submit button text
- `infoTooltipText`: Tooltip text (auto-set based on queryType)
- `titleFont`, `inputFont`, `submitButtonFont`: Font customization
- `padding`: Internal padding
- `lineLimit`: Text input line limit
- `spacing`: Element spacing
- `headerIconSize`: Header icon size
- `showHeaderIcon`: Show/hide header icon
- `headerSpacing`: Header element spacing
- `showInfoButton`: Show/hide info button
- `infoButtonSize`: Info button size
- Color customization for all elements

### 3. RiviChipsView

Displays filter chips with removal capability.

**Basic Usage:**

```swift
RiviChipsView(chips: $filterChips) { removedChip in
    print("Removed: \(removedChip)")
    // Re-process query without this chip
    processUpdatedChips()
}
```

**Custom Configuration:**

```swift
var customConfig = RiviChipsView.Configuration.default
customConfig.chipBackgroundColor = Color.blue.opacity(0.1)
customConfig.chipBorderColor = Color.blue
customConfig.chipTextColor = Color.blue
customConfig.cornerRadius = 16

RiviChipsView(
    configuration: customConfig,
    chips: $filterChips,
    onRemove: { removedChip in
        handleChipRemoval(removedChip)
    }
)
```

**Configuration Options:**
- `font`: Chip text font
- `cornerRadius`: Chip corner radius
- `chipPadding`: Internal chip padding
- `spacing`: Spacing between chips
- `removeIconSize`: X icon size
- `textIconSpacing`: Text-icon spacing
- `chipBackgroundColor`: Chip background
- `chipBorderColor`: Chip border
- `chipTextColor`: Chip text color
- `removeIconColor`: X icon color

### 4. RiviInfoBanner

Displays informational messages.

**Basic Usage:**

```swift
if !filterChips.isEmpty {
    RiviInfoBanner()
}
```

**Custom Configuration:**

```swift
var customConfig = RiviInfoBanner.Configuration.default
customConfig.titleText = "Custom Title"
customConfig.descriptionText = "Custom description text"
customConfig.backgroundColor = Color.yellow.opacity(0.1)
customConfig.borderColor = Color.yellow

RiviInfoBanner(configuration: customConfig)
```

**Configuration Options:**
- `iconName`: Icon asset name
- `titleText`: Banner title
- `descriptionText`: Banner description
- `titleFont`, `descriptionFont`: Font customization
- `cornerRadius`: Banner corner radius
- `padding`: Internal padding
- `iconSpacing`: Icon-text spacing
- `textSpacing`: Title-description spacing
- `showIcon`: Show/hide icon
- `iconSize`: Icon size
- Color customization for all elements

### 5. RiviAlertDialog

Displays alert dialogs for warnings.

**Basic Usage:**

```swift
if showAlert {
    RiviAlertDialog(isPresented: $showAlert) {
        print("Alert dismissed")
    }
}
```

**Custom Configuration:**

```swift
var customConfig = RiviAlertDialog.Configuration.default
customConfig.titleText = "Warning!"
customConfig.descriptionText = "Please review your changes"
customConfig.buttonText = "Understood"

RiviAlertDialog(
    configuration: customConfig,
    isPresented: $showAlert,
    onDismiss: {
        handleAlertDismissal()
    }
)
```

**Configuration Options:**
- `iconName`: Icon asset name
- `titleText`: Alert title
- `descriptionText`: Alert description
- `buttonText`: Button text
- `titleFont`, `descriptionFont`, `buttonFont`: Font customization
- `cornerRadius`: Dialog corner radius
- `padding`: Internal padding
- `spacing`: Element spacing
- `iconSize`: Icon size
- Color customization for all elements

### 6. RiviConfirmationDialog

Displays confirmation dialogs with two action buttons (Cancel and Confirm).

**Basic Usage:**

```swift
if showConfirmationDialog {
    RiviConfirmationDialog(
        isPresented: $showConfirmationDialog,
        onConfirm: {
            // Handle confirmation
            clearQuery()
        }
    )
}
```

**With Cancel Callback:**

```swift
RiviConfirmationDialog(
    isPresented: $showConfirmationDialog,
    onCancel: {
        print("User cancelled")
    },
    onConfirm: {
        print("User confirmed")
        clearQuery()
    }
)
```

**Custom Configuration:**

```swift
var customConfig = RiviConfirmationDialog.Configuration.default
customConfig.titleText = "Custom Title"
customConfig.descriptionText = "Custom description"
customConfig.cancelButtonText = "Cancel"
customConfig.confirmButtonText = "Confirm"

RiviConfirmationDialog(
    configuration: customConfig,
    isPresented: $showConfirmationDialog,
    onConfirm: { /* ... */ }
)
```

**Configuration Options:**
- `titleText`: Dialog title
- `descriptionText`: Dialog description
- `cancelButtonText`: Cancel button text
- `confirmButtonText`: Confirm button text
- `titleFont`, `descriptionFont`, `buttonFont`: Font customization
- `cornerRadius`: Dialog corner radius
- `padding`: Internal padding
- `spacing`: Element spacing
- `buttonSpacing`: Spacing between buttons
- `buttonHeight`: Button height
- Color customization for all elements (background, buttons, text, borders, overlay)

---

## Using Custom UI

You can use RiviAskAI's backend logic with completely custom UI:

```swift
struct CustomAskAIView: View {
    @State private var filterChips: Set<String> = []
    @State private var userQuery: String = ""
    @State private var showCustomSheet = false
    
    var body: some View {
        VStack {
            // Custom chips display
            ScrollView(.horizontal) {
                HStack {
                    ForEach(Array(filterChips), id: \.self) { chip in
                        CustomChipView(text: chip) {
                            removeChip(chip)
                        }
                    }
                }
            }
            
            // Custom button
            Button("Ask AI") {
                showCustomSheet = true
            }
            .buttonStyle(CustomButtonStyle())
        }
        .sheet(isPresented: $showCustomSheet) {
            CustomQuerySheet(
                query: $userQuery,
                onSubmit: { query in
                    processQuery(query)
                }
            )
        }
    }
    
    private func processQuery(_ query: String) {
        Task {
            do {
                let response = try await RiviAskAI.performAskAIRequest(
                    query: query,
                    searchId: searchId,
                    queryType: .hotel,
                    currency: "SAR",
                    checkin: checkinDate,
                    checkout: checkoutDate,
                    destination: "Dubai",
                    origin: "Riyadh"
                )
                
                filterChips = response.chips
                
                // Handle raw response for custom processing
                if let entity = response.entity {
                    // Access specific fields
                    if let starRating = entity["star_rating"] as? [String] {
                        // Custom handling
                    }
                }
            } catch {
                print("Error: \(error)")
            }
        }
    }
}
```

---

## Complete Integration Example

### Step 1: Initialize Package

```swift
// In your App struct
@main
struct YourApp: App {
    init() {
        RiviAskAI.initialize(
            environment: .production,
            authToken: "YOUR_AUTH_TOKEN",
            language: .english
        )
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

### Step 2: Perform Initial Search

```swift
// User performs search in your app
let searchResponse = try await yourSearchAPI.search(
    origin: "Riyadh",
    destination: "Dubai",
    checkin: checkinDate,
    checkout: checkoutDate
)

let searchId = searchResponse.searchId
```

### Step 3: Subscribe to SSE (Immediately)

```swift
// Subscribe to SSE immediately after getting searchId
func subscribeToSortedResults() {
    RiviAskAI.subscribeToEvents(
        searchId: searchId,
        onEvent: { jsonData in
            // Parse and display sorted results
            DispatchQueue.main.async {
                self.parseAndDisplayResults(jsonData)
            }
        },
        onError: { error in
            print("SSE Error: \(error)")
            // Handle connection errors
        }
    )
}
```

### Step 4: Sort Best (Automatic Sorting)

```swift
// Immediately call sort-best
Task {
    do {
        let response = try await RiviAskAI.performSortBestRequest(
            searchId: searchId,
            queryType: .hotel,
            currency: "SAR",
            checkin: checkinDate,
            checkout: checkoutDate,
            destination: "Dubai",
            origin: "Riyadh"
        )
        
        filterChips = response.chips
        isAskAIButtonEnabled = true
        
    } catch {
        handleError(error)
    }
}
```

### Step 5: User Refines Search

```swift
// User clicks Ask AI button and enters query
func handleUserQuery(_ query: String) {
    Task {
        do {
            let response = try await RiviAskAI.performAskAIRequest(
                query: query,
                searchId: searchId,
                queryType: .hotel,
                currency: "SAR",
                checkin: checkinDate,
                checkout: checkoutDate,
                destination: "Dubai",
                origin: "Riyadh"
            )
            
            filterChips = response.chips
            
            // Show warning if user tried to change trip details
            if let notice = response.parameterChangeNotice {
                showParameterChangeAlert(notice)
            }
            
            // SSE will automatically send updated sorted results
        } catch {
            handleError(error)
        }
    }
}
```

### Step 6: Handle Chip Removal

```swift
func handleChipRemoval(_ removedChip: String) {
    // Re-process with remaining chips
    let remainingQuery = filterChips.joined(separator: ", ")
    
    Task {
        do {
            let response = try await RiviAskAI.performAskAIRequest(
                query: remainingQuery,
                searchId: searchId,
                queryType: .hotel,
                currency: "SAR",
                checkin: checkinDate,
                checkout: checkoutDate,
                destination: "Dubai",
                origin: "Riyadh"
            )
            
            filterChips = response.chips
        } catch {
            handleError(error)
        }
    }
}
```

### Step 7: Cleanup

```swift
deinit {
    RiviAskAI.disconnect()
}
```

---

## Example Project

The package includes a comprehensive example app demonstrating all features:

**Location:** `RiviAskAIExample/RiviAskAIExample/`

### What's Included

The example app demonstrates:

1. **Package UI Flow**: Using all pre-built views with customization
2. **Custom UI Flow**: Using package logic with custom views
3. **SSE Subscription**: Real-time event streaming
4. **Error Handling**: Parameter change warnings and alerts
5. **Multi-language**: English and Arabic support
6. **Both Query Types**: Hotel and Flight examples

### Running the Example

1. Open `RiviAskAIExample.xcodeproj`
2. Update the constants in `ContentView.swift`:
   ```swift
   private let searchId = "YOUR_SEARCH_ID"
   private let authToken = "YOUR_AUTH_TOKEN"
   ```
3. Run the app and explore different scenarios

The example app covers all possible use cases and edge cases, providing a complete reference implementation.

---

## Localization

RiviAskAI supports English and Arabic localization for all UI components.

### Supported Languages

- **English** (`.english` or `"en"`)
- **Arabic** (`.arabic` or `"ar"`)

### How It Works

When you initialize with a language:

```swift
RiviAskAI.initialize(
    environment: .staging,
    authToken: "YOUR_AUTH_TOKEN",
    language: .arabic
)
```

All UI components automatically display in the selected language:
- Button text
- Sheet titles and placeholders
- Tooltips
- Info banners
- Alert dialogs
- Confirmation dialogs

### RTL Support

Arabic language automatically enables Right-to-Left (RTL) layout direction for all views.

### Dynamic Language Switching

You can change the language at runtime by reinitializing:

```swift
// Switch to Arabic
RiviAskAI.initialize(
    environment: .staging,
    authToken: "YOUR_AUTH_TOKEN",
    language: .arabic
)

// Update layout direction in your view
.environment(\.layoutDirection, RiviAskAIConfiguration.shared.language.layoutDirection)
```

### Localized Components

All package UI components are fully localized:
- `RiviAskAIButton`
- `RiviAskAISheet`
- `RiviInfoBanner`
- `RiviAlertDialog`
- `RiviConfirmationDialog`

---

## Models Reference

### RiviAskAIEnvironment

```swift
public enum RiviAskAIEnvironment {
    case staging
    case production
    case custom(baseURL: String)
}
```

**Values:**
- `.staging`: Staging environment (`https://askai-gateway-staging.rivi.co/api/v1`)
- `.production`: Production environment (`https://askai-gateway.rivi.co/api/v1`)
- `.custom(baseURL:)`: Custom environment with your own base URL

### QueryType

```swift
public enum QueryType: String {
    case hotel = "hotel"
    case flight = "flight"
}
```

### Language

```swift
public enum Language: String {
    case english = "en"
    case arabic = "ar"
    
    public var layoutDirection: LayoutDirection {
        switch self {
        case .english: return .leftToRight
        case .arabic: return .rightToLeft
        }
    }
}
```

### AskAIResponse

```swift
public struct AskAIResponse {
    public let chips: Set<String>
    public let parameterChangeNotice: String?
    public let rawResponse: [String: Any]
    public let entity: [String: Any]?
}
```

---

## Best Practices

### 1. Error Handling

Always implement proper error handling:

```swift
Task {
    do {
        let response = try await RiviAskAI.performAskAIRequest(...)
        // Handle success
    } catch {
        // Show user-friendly error message
        showError("Unable to process your request. Please try again.")
    }
}
```

### 2. Memory Management

Disconnect from SSE when leaving the screen:

```swift
override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    RiviAskAI.disconnect()
}
```

### 3. UI Responsiveness

Use async/await to keep UI responsive:

```swift
Task {
    let response = try await RiviAskAI.performAskAIRequest(...)
    await MainActor.run {
        updateUI(with: response)
    }
}
```

### 4. Parameter Change Warnings

Always check and display parameter change notices:

```swift
if let notice = response.parameterChangeNotice {
    // Show warning banner or alert
    showWarning(notice)
}
```

### 5. Secure Token Storage

Never hardcode tokens in production:

```swift
// Use Keychain or secure storage
let authToken = KeychainManager.shared.getAuthToken()

// Initialize with secure token
RiviAskAI.initialize(
    environment: .production,
    authToken: authToken,
    language: .english
)
```

---

## Troubleshooting

### Common Issues

**1. Package Not Initialized**
- **Problem**: API calls fail or UI components show default English text
- **Solution**: Ensure `RiviAskAI.initialize()` is called before any API calls or UI components are used
- **Best Practice**: Call it in your App struct's `init()` method

**2. No Chips Returned**
- Verify searchId and authToken are correct
- Ensure query is relevant to the query type (hotel/flight)
- Check network connectivity
- Confirm `RiviAskAI.initialize()` was called with valid token

**3. SSE Connection Fails**
- Verify authToken is valid
- Check network stability
- Ensure you're not blocking the connection with firewalls
- Confirm initialization was completed before subscribing

**4. UI Not Updating**
- Ensure state updates are on main thread
- Check bindings are properly set up
- Verify @State variables are correctly declared

**5. Parameter Change Warning Not Showing**
- Check if `parameterChangeNotice` is nil
- Verify you're displaying the warning in UI
- Ensure alert/banner is properly configured

**6. Chips Not Removing**
- Verify onRemove callback is implemented
- Check that you're updating the chips Set
- Ensure you're re-processing the query after removal

**7. Wrong Language Displayed**
- **Problem**: UI components show wrong language
- **Solution**: Verify you're passing the correct language to `initialize()`
- **Check**: Use `RiviAskAIConfiguration.shared.language` to verify current language

**8. RTL Layout Not Working**
- **Problem**: Arabic text displays but layout is still LTR
- **Solution**: Apply `.environment(\.layoutDirection, RiviAskAIConfiguration.shared.language.layoutDirection)` to your view
- **Note**: The package views handle this automatically, but your custom views need this modifier

---

## Support

For questions, issues, or feature requests:

- **Email**: mayank@rivi.co
- **Example App**: Included in package

---

## Changelog

### Version 1.0.0
- Initial release
- Support for hotel and flight queries
- Pre-built UI components (6 customizable views)
- SSE real-time updates
- Multi-language support (English and Arabic)
- RTL layout support for Arabic
- Parameter change detection
- Environment configuration (staging, production, custom)
- Global initialization with auth token and language
- Confirmation dialog component
