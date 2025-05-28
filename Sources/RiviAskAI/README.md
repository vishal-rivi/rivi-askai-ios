# RiviAskAI

A Swift library for integrating flight filter functionality with natural language processing.

## API Usage

### Initialize the RiviAskAI Service

```swift
import RiviAskAI

// Initialize with default base URL
let service = RiviAskAIService()

// Or with custom base URL
let service = RiviAskAIService(baseURL: "http://your-api-url.com/api/v1")
```

### Filter Search API

Use the filter search API to improve flight search results based on natural language queries:

```swift
// Create filter search parameters
let params = FilterSearchParams(
    searchId: "682c4f4e8b9a1305495cb861",
    isRound: false,
    filterQuery: "under 400 reach before morning",
    authToken: "99d477cbcb65dcf06a992bb808061362ba2f2050c217ee488acbd708610b4012"
)

// Call the API
service.filterSearch(query: "under 400 reach before morning", params: params) { result in
    switch result {
    case .success:
        print("Filter search successful")
    case .failure(let error):
        print("Filter search failed: \(error)")
    }
}
```

### Subscribe to Server-Sent Events (SSE)

Subscribe to real-time updates via SSE:

```swift
// Connect to SSE
service.subscribeToEvents(
    searchId: "682c4f4e8b9a1305495cb861",
    authToken: "99d477cbcb65dcf06a992bb808061362ba2f2050c217ee488acbd708610b4012",
    onEvent: { eventData in
        // Process event data
        print("Received event: \(eventData)")
        
        // Extract chips from event data
        let chips = SSEDataProcessor.extractChipsFromSSEData(eventData)
        print("Extracted chips: \(chips)")
    },
    onError: { error in
        print("SSE connection error: \(error)")
    }
)

// Disconnect when done
service.disconnect()
```

### Using the ViewModel

For SwiftUI integration, use the RiviAskAIViewModel:

```swift
let params = FilterSearchParams(
    searchId: "682c4f4e8b9a1305495cb861",
    isRound: false,
    authToken: "99d477cbcb65dcf06a992bb808061362ba2f2050c217ee488acbd708610b4012"
)

let viewModel = RiviAskAIViewModel(
    filterSearchParams: params,
    onEvent: { event in
        switch event {
        case .data(let data):
            print("Received data: \(data)")
        case .error(let error):
            print("Error: \(error)")
        case .disconnected:
            print("SSE disconnected")
        case .filterSearchCompleted:
            print("Filter search completed")
        case .chipsExtracted(let chips):
            print("Extracted chips: \(chips)")
        }
    }
)
```

## API Endpoints

- **Filter Search API**: `POST /api/v1/askai`
  - Request body:
    ```json
    {
      "filter_query": "under 400 reach before morning",
      "search_id": "682c4f4e8b9a1305495cb861",
      "is_round": false
    }
    ```
  - Required Header: `authorization: YOUR_AUTH_TOKEN`

- **SSE Subscription**: `GET /api/v1/askai/subscribe?searchId=YOUR_SEARCH_ID`
  - Required Header: `authorization: YOUR_AUTH_TOKEN` 