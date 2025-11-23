import Foundation
import SwiftUI

/// Environment configuration for RiviAskAI
public enum RiviAskAIEnvironment {
    case staging
    case production
    case custom(baseURL: String)
    
    /// The base URL for the environment
    public var baseURL: String {
        switch self {
        case .staging:
            return "https://askai-gateway-staging.rivi.co/api/v1"
        case .production:
            return "https://askai-gateway.rivi.co/api/v1"
        case .custom(let baseURL):
            return baseURL
        }
    }
}

/// Global configuration for RiviAskAI package
public class RiviAskAIConfiguration {
    /// Shared instance
    public static let shared = RiviAskAIConfiguration()
    
    /// Current environment
    public var environment: RiviAskAIEnvironment = .staging
    
    /// Base URL for API requests (derived from environment)
    public var baseURL: String {
        return environment.baseURL
    }
    
    /// Authorization token for API requests
    public var authToken: String?
    
    /// Default language for API requests
    public var language: Language = .english
    
    private init() {}
}

/// Main entry point for RiviAskAI package
public class RiviAskAI {
    /// The API service for making AskAI requests
    private static var apiService: AskAIServiceProtocol = AskAIService()
    
    /// Initialize the RiviAskAI package with global configuration
    /// - Parameters:
    ///   - environment: The environment to use (.staging, .production, or .custom)
    ///   - authToken: The authorization token for API requests
    ///   - language: The default language for API requests
    public static func initialize(
        environment: RiviAskAIEnvironment,
        authToken: String,
        language: Language
    ) {
        RiviAskAIConfiguration.shared.environment = environment
        RiviAskAIConfiguration.shared.authToken = authToken
        RiviAskAIConfiguration.shared.language = language
        
        // Reinitialize the API service with new configuration
        apiService = AskAIService()
    }
    
    /// Perform an AskAI request with simplified parameters
    /// - Parameters:
    ///   - query: The user's query string
    ///   - searchId: The search ID to use
    ///   - isRound: Whether this is a round trip (default: false)
    ///   - queryType: The type of query (hotel or flight)
    ///   - currency: The currency code (e.g., SAR, AED, USD, INR)
    ///   - checkin: Check-in date (optional)
    ///   - checkout: Check-out date (optional)
    ///   - destination: Destination location
    ///   - origin: Origin location
    /// - Returns: AskAIResponse containing chips and parameter change notice
    /// - Throws: Error if the request fails
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
    ) async throws -> AskAIResponse {
        let request = AskAIRequest(
            filterQuery: query,
            searchId: searchId,
            isRound: isRound,
            queryType: queryType,
            currency: currency,
            checkin: checkin,
            checkout: checkout,
            destination: destination,
            origin: origin
        )
        
        return try await apiService.performAskAIRequest(request: request)
    }
    
    /// Subscribe to real-time updates for a search ID
    /// - Parameters:
    ///   - searchId: The search ID to subscribe to
    ///   - onEvent: Callback for received events
    ///   - onError: Callback for connection errors
    public static func subscribeToEvents(
        searchId: String,
        onEvent: @escaping (String) -> Void,
        onError: @escaping (Error) -> Void
    ) {
        apiService.subscribeToEvents(
            searchId: searchId,
            onEvent: onEvent,
            onError: onError
        )
    }
    
    /// Perform a sort-best request (without query, for automatic sorting)
    /// - Parameters:
    ///   - searchId: The search ID to use
    ///   - isRound: Whether this is a round trip (default: false)
    ///   - queryType: The type of query (hotel or flight)
    ///   - currency: The currency code (e.g., SAR, AED, USD, INR)
    ///   - checkin: Check-in date (optional)
    ///   - checkout: Check-out date (optional)
    ///   - destination: Destination location
    ///   - origin: Origin location
    /// - Returns: AskAIResponse containing chips and parameter change notice
    /// - Throws: Error if the request fails
    public static func performSortBestRequest(
        searchId: String,
        isRound: Bool = false,
        queryType: QueryType,
        currency: String,
        checkin: Date? = nil,
        checkout: Date? = nil,
        destination: String,
        origin: String
    ) async throws -> AskAIResponse {
        let request = AskAIRequest(
            filterQuery: "",  // Empty query for sort-best
            searchId: searchId,
            isRound: isRound,
            queryType: queryType,
            currency: currency,
            checkin: checkin,
            checkout: checkout,
            destination: destination,
            origin: origin
        )
        
        return try await apiService.performSortBestRequest(request: request)
    }
    
    /// Disconnect from any active SSE connection
    public static func disconnect() {
        apiService.disconnect()
    }
}
