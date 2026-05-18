# Basic Setup

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
                    destination: "Dubai"
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
                destination: "Dubai"
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

**Location:** RiviAskAIExample/RiviAskAIExample/

### What's Included

The example app demonstrates:

1. Package UI Flow: Using all pre-built views with customization
2. Custom UI Flow: Using package logic with custom views
3. SSE Subscription: Real-time event streaming
4. Error Handling: Parameter change warnings and alerts
5. Multi-language: English and Arabic support
6. Both Query Types: Hotel and Flight examples

### Running the Example

1. Open RiviAskAIExample.xcodeproj
2. Update the constants in ContentView.swift:

```swift
private let searchId = "YOUR_SEARCH_ID"
private let authToken = "YOUR_AUTH_TOKEN"
```

3. Run the app and explore different scenarios

The example app covers all possible use cases and edge cases, providing a complete reference implementation.

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

#### 1. Package Not Initialized

* Problem: API calls fail or UI components show default English text
* Solution: Ensure RiviAskAI.initialize() is called before any API calls or UI components are used
* Best Practice: Call it in your App struct's init() method

#### 2. No Chips Returned

* Verify searchId and authToken are correct
* Ensure query is relevant to the query type (hotel/flight)
* Check network connectivity
* Confirm RiviAskAI.initialize() was called with valid token

#### 3. SSE Connection Fails

* Verify authToken is valid
* Check network stability
* Ensure you're not blocking the connection with firewalls
* Confirm initialization was completed before subscribing

#### 4. UI Not Updating

* Ensure state updates are on main thread
* Check bindings are properly set up
* Verify @state variables are correctly declared

#### 5. Parameter Change Warning Not Showing

* Check if parameterChangeNotice is nil
* Verify you're displaying the warning in UI
* Ensure alert/banner is properly configured

#### 6. Chips Not Removing

* Verify onRemove callback is implemented
* Check that you're updating the chips Set
* Ensure you're re-processing the query after removal

#### 7. Wrong Language Displayed

* Problem: UI components show wrong language
* Solution: Verify you're passing the correct language to initialize()
* Check: Use RiviAskAIConfiguration.shared.language to verify current language

#### 8. RTL Layout Not Working

* Problem: Arabic text displays but layout is still LTR
* Solution: Apply .environment(\.layoutDirection, RiviAskAIConfiguration.shared.language.layoutDirection) to your view
* Note: The package views handle this automatically, but your custom views need this modifier
