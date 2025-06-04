# RiviAskAI Package Documentation

## Overview

RiviAskAI is a Swift package that provides AI-powered search and filtering capabilities for iOS applications. The package offers both pre-built UI components and core functionality that can be integrated with custom UI implementations.

## Key Features

- **AI-Powered Query Processing**: Convert natural language queries into structured filter parameters
- **Real-time Updates**: Subscribe to server-sent events (SSE) for live updates
- **Pre-built UI Components**: Ready-to-use UI elements including:
  - Ask AI Button
  - Filter Chips View
  - Query Input Sheet
- **Custom UI Support**: Core functionality can be used with custom UI implementations

## Installation

### Swift Package Manager

Add RiviAskAI to your project using Swift Package Manager:

1. In Xcode, select **File > Add Packages...**
2. Enter the package repository URL: `https://github.com/yourusername/RiviAskAI.git`
3. Select the desired version or branch
4. Click **Add Package**

## Quick Start

### Basic Implementation

```swift
import SwiftUI
import RiviAskAI

struct ContentView: View {
    @State private var filterChips: Set<String> = []
    @State private var showAskAISheet = false
    
    // Your search ID and auth token
    private let searchId = "YOUR_SEARCH_ID"
    private let authToken = "YOUR_AUTH_TOKEN"
    
    var body: some View {
        VStack {
            // Display filter chips
            RiviChipsView(chips: $filterChips) { removedChip in
                // Handle chip removal
                Task {
                    do {
                        filterChips = try await RiviAskAI.askAI(
                            query: filterChips.joined(separator: ", "),
                            searchId: searchId,
                            isRound: false,
                            authToken: authToken
                        )
                    } catch {
                        print("Error: \(error)")
                    }
                }
            }
            
            // Ask AI button
            RiviAskAIButton(isEnabled: .constant(true)) {
                showAskAISheet = true
            }
        }
        .sheet(isPresented: $showAskAISheet) {
            RiviAskAISheet(isPresented: $showAskAISheet) { query in
                processQuery(query)
            }
        }
    }
    
    private func processQuery(_ query: String) {
        Task {
            do {
                filterChips = try await RiviAskAI.askAI(
                    query: query,
                    searchId: searchId,
                    isRound: false,
                    authToken: authToken
                )
            } catch {
                print("Error: \(error)")
            }
        }
    }
}
```

## Core API Reference

### RiviAskAI Class

The main entry point for the package functionality.

#### Methods

##### `askAI(query:searchId:isRound:authToken:)`

Process a natural language query and return filter chips.

```swift
public static func askAI(
    query: String,
    searchId: String,
    isRound: Bool = false,
    authToken: String? = nil
) async throws -> Set<String>
```

**Parameters**:
- `query`: The user's natural language query
- `searchId`: Your application's search identifier
- `isRound`: Whether this is for a round trip (default: false)
- `authToken`: Optional authorization token

**Returns**: A set of strings representing filter chips

**Example**:
```swift
let filterChips = try await RiviAskAI.askAI(
    query: "I want a flight to New York next week with Delta",
    searchId: "YOUR_SEARCH_ID",
    authToken: "YOUR_AUTH_TOKEN"
)
```

##### `subscribeToUpdates(searchId:authToken:onEvent:onError:)`

Subscribe to real-time updates using Server-Sent Events (SSE).

```swift
public static func subscribeToUpdates(
    searchId: String,
    authToken: String,
    onEvent: @escaping (String) -> Void,
    onError: @escaping (Error) -> Void
)
```

**Parameters**:
- `searchId`: Your application's search identifier
- `authToken`: Authorization token
- `onEvent`: Callback for received events
- `onError`: Callback for connection errors

**Example**:
```swift
RiviAskAI.subscribeToUpdates(
    searchId: "YOUR_SEARCH_ID",
    authToken: "YOUR_AUTH_TOKEN",
    onEvent: { eventData in
        print("Received event: \(eventData)")
    },
    onError: { error in
        print("Error: \(error)")
    }
)
```

##### `disconnect()`

Disconnect from any active SSE connection.

```swift
public static func disconnect()
```

**Example**:
```swift
RiviAskAI.disconnect()
```

## UI Components

### RiviAskAIButton

A customizable button that triggers the Ask AI functionality.

```swift
RiviAskAIButton(isEnabled: $isEnabled) {
    // Action when button is tapped
}
```

**Parameters**:
- `isEnabled`: Binding to control button enabled state
- `action`: Closure to execute when button is tapped

### RiviChipsView

A view that displays and manages filter chips.

```swift
RiviChipsView(chips: $filterChips) { removedChip in
    // Handle chip removal
}
```

**Parameters**:
- `chips`: Binding to a set of strings representing the chips
- `onChipRemoved`: Closure called when a chip is removed

### RiviAskAISheet

A sheet that allows users to input their queries.

```swift
RiviAskAISheet(isPresented: $isPresented) { query in
    // Handle submitted query
}
```

**Parameters**:
- `isPresented`: Binding to control sheet presentation
- `onSubmit`: Closure called when a query is submitted

## Advanced Usage

### Custom UI Implementation

You can use the core RiviAskAI functionality with your own custom UI:

```swift
struct CustomAskAIView: View {
    @State private var filterChips: Set<String> = []
    @State private var userQuery: String = ""
    
    private let searchId = "YOUR_SEARCH_ID"
    private let authToken = "YOUR_AUTH_TOKEN"
    
    var body: some View {
        VStack {
            // Custom query input
            TextField("Enter your query", text: $userQuery)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            Button("Process Query") {
                processQuery(userQuery)
            }
            
            // Custom chips display
            ScrollView(.horizontal) {
                HStack {
                    ForEach(Array(filterChips), id: \.self) { chip in
                        Text(chip)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(15)
                    }
                }
            }
        }
        .padding()
    }
    
    private func processQuery(_ query: String) {
        Task {
            do {
                filterChips = try await RiviAskAI.askAI(
                    query: query,
                    searchId: searchId,
                    authToken: authToken
                )
            } catch {
                print("Error: \(error)")
            }
        }
    }
}
```

### Real-time Updates with SSE

Monitor real-time updates from the server:

```swift
struct SSEMonitorView: View {
    @State private var events: [String] = []
    @State private var isSubscribed = false
    
    private let searchId = "YOUR_SEARCH_ID"
    private let authToken = "YOUR_AUTH_TOKEN"
    
    var body: some View {
        VStack {
            Button(isSubscribed ? "Unsubscribe" : "Subscribe") {
                if isSubscribed {
                    RiviAskAI.disconnect()
                    isSubscribed = false
                } else {
                    subscribeToEvents()
                }
            }
            
            List(events, id: \.self) { event in
                Text(event)
            }
        }
    }
    
    private func subscribeToEvents() {
        RiviAskAI.subscribeToUpdates(
            searchId: searchId,
            authToken: authToken,
            onEvent: { eventData in
                events.append(eventData)
            },
            onError: { error in
                events.append("Error: \(error.localizedDescription)")
            }
        )
        isSubscribed = true
    }
}
```

## Best Practices

1. **Error Handling**: Always implement proper error handling for network requests.

2. **Memory Management**: Disconnect from SSE connections when they are no longer needed to prevent memory leaks.

3. **UI Responsiveness**: Use async/await to keep your UI responsive during network operations.

4. **Authorization**: Securely store and manage your authentication tokens.

5. **Testing**: Test with various query patterns to ensure your application handles all responses correctly.

## Troubleshooting

### Common Issues

1. **No Chips Returned**:
   - Verify your search ID and auth token
   - Check that your query is relevant to the configured domain

2. **SSE Connection Issues**:
   - Ensure you have a stable network connection
   - Verify your authentication token is valid

3. **UI Not Updating**:
   - Make sure state updates are performed on the main thread
   - Check that your bindings are properly set up

## Support and Contact

For additional support or questions about the RiviAskAI package, please contact:

- Email: support@rivi.com
- Website: https://rivi.com/support 