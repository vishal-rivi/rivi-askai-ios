# Core API Reference

### RiviAskAI Class

The main entry point for all package functionality.

**Recommended Flow:**

1. Get searchId from your search API
2. Subscribe to SSE events (to receive sorted results)
3. Call Sort Best API (for automatic sorting)
4. Call Ask AI API (when user enters a query)

---

### 1. Subscribe to Events (SSE)

Subscribe to real-time sorted results via Server-Sent Events. Call this immediately after receiving your search ID to start receiving sorted results.

```swift
public static func subscribeToEvents(
    searchId: String,
    config: SSEConfig = .default,
    onState: ((SSEConnectionState) -> Void)? = nil,
    onEvent: @escaping (String) -> Void,
    onError: @escaping (Error) -> Void
)
```

**Parameters:**

* searchId: Your application's search identifier.
* config: (Optional) Connection configuration. Defaults to .default. You can also use .aggressive or .conservative.
* onState: (Optional) Callback for connection lifecycle changes (e.g., to show a "Reconnecting..." banner).
* onEvent: Callback for received data events.
* onError: Callback for unrecoverable errors.

**Returns:** Nothing (void). Results are delivered via the onEvent callback.

**Note:** Auth token is automatically used from the global configuration set during initialization.

**Example:**

```swift
// Step 1: Get searchId from your search API
let searchResponse = try await yourSearchAPI.search(...)
let searchId = searchResponse.searchId

RiviAskAI.subscribeToEvents(
    searchId: searchId,
    config: .aggressive,
    onState: { state in
        print("State is \(state)")
    },
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
    }
)
```

**Important Notes:**

* Subscribe to SSE before calling Sort Best or Ask AI APIs
* The SSE connection will deliver sorted results whenever you call Sort Best or Ask AI
* Keep the connection active while displaying results
* Call disconnect() when leaving the results screen

---

### 2. Sort Best API (Initial Sorting)

Automatically sorts search results without a user query. Call this after subscribing to SSE to get initial sorted results.

```swift
public static func performSortBestRequest(
    searchId: String,
    isRound: Bool = false,
    queryType: QueryType,
    currency: String,
    checkin: Date? = nil,
    checkout: Date? = nil,
    departureDate: Date? = nil,
    returnDate: Date? = nil,
    adults: Int = 1,
    children: Int = 0,
    childAges: [Int]? = nil,
    infant: Int = 0,
    rooms: Int = 1,
    cabinType: String = "Economy",
    destination: String,
    origin: String = ""
) async throws -> AskAIResponse
```

**Parameters:**

* searchId: The search identifier from your initial search
* isRound: Whether this is a round trip flight (default: false)
* queryType: `.hotel` or `.flight`
* currency: Currency code (e.g., "SAR", "AED", "USD", "INR")
* checkin: For hotels, the check-in date (also used as departure date for flights internally)
* checkout: For hotels, the check-out date
* departureDate: For flights, optional departure date context
* returnDate: For flights, optional return date context (round-trips)
* adults: Number of adults (default: 1)
* children: Number of children (default: 0)
* childAges: Ages for each child (optional)
* infant: Number of infants (flights) (default: 0)
* rooms: Number of rooms (hotels) (default: 1)
* cabinType: Flight cabin class (default: "Economy")
* destination: Destination location
* origin: Origin location (flights only; omit for hotels)

**Returns:** AskAIResponse containing:
* chips: Set of filter chips to display
* parameterChangeNotice: Warning message if applicable
* rawResponse: Complete API response
* entity: First entity from response for custom processing

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
            departureDate: nil,
            returnDate: nil,
            adults: 2,
            children: 0,
            childAges: nil,
            infant: 0,
            rooms: 1,
            cabinType: "Economy",
            destination: "Singapore"
        )
        
        // Display chips returned from API
        filterChips = response.chips
        
        // Sorted results will be delivered via SSE onEvent callback
    } catch {
        print("Error: \(error)")
    }
}
```

---

### 3. Ask AI API (User Query)

Process a natural language query from the user to refine sorting. Call this when user enters a query to get refined sorted results.

```swift
public static func performAskAIRequest(
    query: String,
    searchId: String,
    isRound: Bool = false,
    queryType: QueryType,
    currency: String,
    checkin: Date? = nil,
    checkout: Date? = nil,
    departureDate: Date? = nil,
    returnDate: Date? = nil,
    adults: Int = 1,
    children: Int = 0,
    childAges: [Int]? = nil,
    infant: Int = 0,
    rooms: Int = 1,
    cabinType: String = "Economy",
    destination: String,
    origin: String = "",
    onPartialContent: (@MainActor (String) -> Void)? = nil
) async throws -> AskAIResponse
```

**Parameters:** Same as Sort Best API, plus:
* query: User's natural language query (e.g., "4 star hotels near airport")

* onPartialContent (optional): Receives cumulative explain-ai `content` snapshots while the server streams explanation (only used for explain-ai if you call it manually). Auto-fired explain-ai after `performAskAIRequest` when `RiviAskAIConfiguration.shared.onExplainContent` / `onExplainError` are set.

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
            departureDate: nil,
            returnDate: nil,
            adults: 2,
            children: 0,
            childAges: nil,
            infant: 0,
            rooms: 1,
            cabinType: "Economy",
            destination: "Dubai"
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

---

### 4. Disconnect

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

RiviAskAI provides six customizable SwiftUI views. Each view has a Configuration struct for complete customization.

---

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

* text: Button text (default: "Ask AI")
* font: Text font
* showIcon: Show/hide sparkle icon
* spacing: Icon-text spacing
* cornerRadius: Button corner radius
* padding: Internal padding
* iconSize: Icon size
* backgroundColor: Button background color
* textColor: Text color
* iconColor: Icon color
* disabledBackgroundColor: Disabled state background
* disabledTextColor: Disabled state text color

---

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

* titleText: Sheet title
* placeholderText: Input placeholder (auto-set based on queryType)
* submitButtonText: Submit button text
* infoTooltipText: Tooltip text (auto-set based on queryType)
* titleFont, inputFont, submitButtonFont: Font customization
* padding: Internal padding
* lineLimit: Text input line limit
* spacing: Element spacing
* headerIconSize: Header icon size
* showHeaderIcon: Show/hide header icon
* headerSpacing: Header element spacing
* showInfoButton: Show/hide info button
* infoButtonSize: Info button size
* Color customization for all elements

---

### 3. RiviChipsView

Displays filter chips with removal capability.

**Basic Usage:**

```swift
RiviChipsView(chips: $filterChips) { removedChip in
    print("Removed: \(removedChip)")
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

* font: Chip text font
* cornerRadius: Chip corner radius
* chipPadding: Internal chip padding
* spacing: Spacing between chips
* removeIconSize: X icon size
* textIconSpacing: Text-icon spacing
* chipBackgroundColor: Chip background
* chipBorderColor: Chip border
* chipTextColor: Chip text color
* removeIconColor: X icon color

---

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

* iconName: Icon asset name
* titleText: Banner title
* descriptionText: Banner description
* titleFont, descriptionFont: Font customization
* cornerRadius: Banner corner radius
* padding: Internal padding
* iconSpacing: Icon-text spacing
* textSpacing: Title-description spacing
* showIcon: Show/hide icon
* iconSize: Icon size
* Color customization for all elements

---

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

* iconName: Icon asset name
* titleText: Alert title
* descriptionText: Alert description
* buttonText: Button text
* titleFont, descriptionFont, buttonFont: Font customization
* cornerRadius: Dialog corner radius
* padding: Internal padding
* spacing: Element spacing
* iconSize: Icon size
* Color customization for all elements

---

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

* titleText: Dialog title
* descriptionText: Dialog description
* cancelButtonText: Cancel button text
* confirmButtonText: Confirm button text
* titleFont, descriptionFont, buttonFont: Font customization
* cornerRadius: Dialog corner radius
* padding: Internal padding
* spacing: Element spacing
* buttonSpacing: Spacing between buttons
* buttonHeight: Button height
* Color customization for all elements (background, buttons, text, borders, overlay)

---

## Advanced Features

### Clear All Button (RiviAskAISheet)

The **Clear All** button is part of the `RiviAskAISheet` bottom sheet, allowing users to quickly clear their input query.

**Location**: `RiviAskAISheet.Configuration`

**Key Properties**:
* `clearButtonText`: Localizable button text (default: system localized "Clear All")
* `clearButtonFont`: Button font (customizable)

**Basic Usage** (enabled by default in sheet):

```swift
RiviAskAISheet(
    isPresented: $showSheet,
    queryType: .hotel,
    onSubmit: { query in processQuery(query) },
    onClear: { /* Optional: Handle clear action */
        print("Query cleared")
    }
)
```

**Custom Configuration**:

```swift
var config = RiviAskAISheet.Configuration.default
config.clearButtonText = "Reset Query"
config.clearButtonFont = .system(size: 16, weight: .medium)
config.clearButtonBackgroundColor = Color.red.opacity(0.1)
config.clearButtonTextColor = Color.red

RiviAskAISheet(
    configuration: config,
    isPresented: $showSheet,
    onSubmit: { processQuery($0) }
)
```

The button clears the text field and resets any parameter change notices.

---

### Dynamic First-Time Banner (RiviAskAIFirstTimeBanner)

A **one-time onboarding banner** that appears above the Ask AI button on first use. Features a purple card with sparkle icon, notch pointing at the button, and "Let's Go!" CTA.

**Key Features**:
* One-time display (UserDefaults tracking)
* Customizable notch position (`notchOffsetFromLeading`)
* 30+ configuration options
* RTL support
* Default purple theme (#9D7BFA)

**Storage API**:
```swift
// Check if shown
if !RiviAskAIFirstTimeBannerStorage.hasBeenShown {
    // Show banner
}

// Mark as shown
RiviAskAIFirstTimeBannerStorage.markAsShown()

// Reset for testing
RiviAskAIFirstTimeBannerStorage.reset()
```

**Basic Usage**:

```swift
if !RiviAskAIFirstTimeBannerStorage.hasBeenShown {
    RiviAskAIFirstTimeBanner { 
        RiviAskAIFirstTimeBannerStorage.markAsShown()
        // Optional: Track analytics
    }
    .frame(maxWidth: 320)
}
```

**Advanced Usage** (custom notch position for button alignment):

```swift
RiviAskAIFirstTimeBanner(
    width: 300,
    notchOffsetFromLeading: 150,  // Aligns notch with button
    onCTATapped: {
        RiviAskAIFirstTimeBannerStorage.markAsShown()
    }
)
.padding(.top)
```

**Configuration Highlights**:
* `iconName`: "ic_sparkle" (template)
* `notchWidth: 18`, `notchHeight: 9`
* `maxWidth: 320`
* Colors: `backgroundColor` (#9D7BFA), `ctaBackgroundColor` (white), `ctaTextColor` (#7B3AEC)
* Fonts: `titleFont` (.semibold 18), `ctaFont` (.semibold 14)

Full config in `Configuration.default`.

---

### Explain-AI Endpoint

Provides **natural-language explanations** for AI sorting decisions via `performExplainAIRequest`.

**Endpoint**: `POST /askai/explain-ai` (SSE stream)

**Streams** cumulative `content` via `@MainActor onPartialContent` callback. Auto-fires after `performAskAIRequest` if handlers set.

**Manual Call**:

```swift
let service = AskAIService()
try await service.performExplainAIRequest(
    request: askAIRequest,
    extractedEntities: response.entity!,
    departureDate: departureDate,
    returnDate: returnDate,
    rooms: 1,
    cabinType: "Economy",
    onPartialContent: { partialContent in
        // Update explanation UI live
        explanationText = partialContent
    }
)
```

**Auto-fire Setup** (global callbacks):

```swift
// In App init after RiviAskAI.initialize()
RiviAskAIConfiguration.shared.onExplainContent = { content in
    // Show in info banner/toast
    showExplanation(content)
}
RiviAskAIConfiguration.shared.onExplainError = { error in
    hideExplanation()
    showError("Explanation unavailable")
}
```

**Response**: `ExplainAIResponse(content: String, rawResponse: [String: Any])`

**Parameters**:
* `request`: Original `AskAIRequest`
* `extractedEntities`: From prior AskAI response (sanitizes `parameter_change_notice`)
* Dates/rooms/cabin: Contextual (flight/hotel-specific)
* ISO 8601 dates with ms (e.g., "2026-05-06T04:50:57.755Z")

**Auto-triggers** on "Improve Results"/"Sort Best" → seamless UX.

---

## Localization

RiviAskAI supports English and Arabic localization for all UI components.

### Supported Languages

* English (.english or "en")
* Arabic (.arabic or "ar")

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

* Button text
* Sheet titles and placeholders
* Tooltips
* Info banners
* Alert dialogs
* Confirmation dialogs

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

* RiviAskAIButton
* RiviAskAISheet
* RiviInfoBanner
* RiviAlertDialog
* RiviConfirmationDialog

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

* .staging: Staging environment (https://askai-gateway-staging.rivi.co/api/v1)
* .production: Production environment (https://askai-gateway.rivi.co/api/v1)
* .custom(baseURL:): Custom environment with your own base URL

---

### QueryType

```swift
public enum QueryType: String {
    case hotel = "hotel"
    case flight = "flight"
}
```

---

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

---

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

### SSEConfig

Controls timeouts and retry policies for Server-Sent Events streams

```swift
public struct SSEConfig {
    public let connectTimeout: TimeInterval
    public let maxReconnectAttempts: Int
    public let initialReconnectDelay: TimeInterval
    public let maxReconnectDelay: TimeInterval
    public let reconnectBackoffMultiplier: Double

    public static let `default`: SSEConfig
    public static let aggressive: SSEConfig
    public static let conservative: SSEConfig
}
```

---

## State Management

Monitor the detailed lifecycle of the connection using these types.

### SSEConnectionState

Represents the current state of the connection.

```swift
public enum SSEConnectionState {
    case connecting
    case connected
    /// The connection was lost and is attempting to reconnect.
    /// - attempt: The current retry attempt number
    /// - maxAttempts: The maximum allowed retries
    /// - nextRetryIn: Seconds remaining until the next retry
    case reconnecting(attempt: Int, maxAttempts: Int, nextRetryIn: TimeInterval)
    case disconnected(reason: DisconnectReason)
}
```

---

### DisconnectReason

Explains why a connection was terminated.

```swift
public enum DisconnectReason {
    case timeout
    case serverClosed
    case cancelled
    case maxRetriesExceeded
    case networkError(message: String?)
    case unknown(cause: Error)
}
```

---

## Logging

RiviAskAI includes a flexible logging system to help you debug integration issues and monitor SDK activity. It supports configurable log levels, custom logging destinations, and automatic debug-only network logging.

### Log Levels

The AskAILogLevel enum defines the verbosity of the logs. You can filter logs by setting a specific level.

```swift
public enum AskAILogLevel: Int, Comparable {
    case all = 0
    case debug = 1
    case info = 2
    case warn = 3
    case error = 4
    case none = 5
}
```

**Default Implementation:** The SDK comes with ConsoleAskAILogger, which simply prints formatted logs to the Xcode console based on the configured log level.

### Custom Logging

If you use a centralized logging framework (like os_log, CocoaLumberjack, or Crashlytics), you can route AskAI logs to it by implementing the AskAILogger protocol.

```swift
public protocol AskAILogger {
    /// Logs a debug message.
    func debug(_ message: String)
    /// Logs an informational message.
    func info(_ message: String)
    /// Logs a warning message.
    func warn(_ message: String)
    /// Logs an error message.
    func error(_ message: String)
    /// Logs an error with an Error object.
    func error(_ error: Error)
}
```

### Network Debugging

The Logger utility provides specialized formatting for network requests and responses.

* Automatic Safety: All methods in Logger are wrapped in #if DEBUG, ensuring that verbose network logs (which might contain sensitive query data) are never included in your Release builds.
* Pretty Printing: JSON responses are automatically formatted with indentation for easier reading in the console.

**Example Console Output:**

```
================================================================================
ASK AI REQUEST
================================================================================
URL: https://askai-gateway.rivi.co/api/v1/ask-ai
Params:
  query: 5 star hotels in Dubai
  currency: AED
================================================================================

================================================================================
ASK AI RESPONSE
================================================================================
URL: https://askai-gateway.rivi.co/api/v1/ask-ai
Status Code: 200
Response:
  {
    "chips" : [
      "5 Star",
      "Dubai"
    ],
    "status" : "success"
  }
================================================================================
```
