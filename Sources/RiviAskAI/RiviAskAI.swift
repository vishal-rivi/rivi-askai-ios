import Foundation
import SwiftUI

/// RiviAskAI SDK provides components for flight filtering with natural language
public struct RiviAskAI {
    /// SDK version number
    public static let version = "1.0.0"
    
    /// Base URL for API requests
    public static var baseURL = "http://34.48.22.18:9000/api/v1"
    
    /// Configure the SDK with custom settings
    public static func configure(baseURL: String? = nil) {
        if let baseURL = baseURL {
            self.baseURL = baseURL
        }
    }
    
    /// Set the global log level for the SDK
    /// - Parameter logLevel: The desired log level
    public static func setLogLevel(_ logLevel: RiviAskAILogger.LogLevel) {
        RiviAskAILogger.logLevel = logLevel
    }
}

// Export public components
@available(iOS 14.0, *)
public struct RiviAskAISwiftUI {
    /// Example view showing how to use the RiviAskAI API
    public static func createExampleView() -> some View {
        FlightFilterExampleView()
    }
} 