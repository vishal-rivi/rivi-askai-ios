## Requirements

* iOS 16.0+ / macOS 12.0+
* Swift 5.9+
* Xcode 14.0+

## Getting Started

### Prerequisites

Before using RiviAskAI, you need:

1. Search ID: Obtained from your initial search API call
2. Authorization Token: Your API authentication token
3. Trip Details: Origin, destination, dates (for hotels), and other search parameters

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

* environment: .staging, .production, or .custom(baseURL: "...")
* authToken: Your authorization token (required)
* language: .english or .arabic

**Environments:**

* .staging: Uses https://askai-gateway-staging.rivi.co/api/v1
* .production: Uses https://askai-gateway.rivi.co/api/v1
* .custom(baseURL:): Uses your custom base URL

After initialization, the auth token and language are used globally for all API calls.
