import Foundation
import SwiftUI

/// Main entry point for RiviAskAI package
public class RiviAskAI {
    /// The API service for making AskAI requests
    private static var apiService: AskAIServiceProtocol = AskAIService()
    
    /// Perform an AskAI request with simplified parameters
    /// - Parameters:
    ///   - query: The user's query string
    ///   - searchId: The search ID to use
    ///   - isRound: Whether this is a round trip (default: false)
    ///   - queryType: The type of query (hotel or flight)
    ///   - language: The language for the request (default: .english)
    ///   - currency: The currency code (e.g., SAR, AED, USD, INR)
    ///   - checkin: Check-in date (optional)
    ///   - checkout: Check-out date (optional)
    ///   - destination: Destination location
    ///   - origin: Origin location
    ///   - authToken: Optional authorization token
    /// - Returns: AskAIResponse containing chips and parameter change notice
    /// - Throws: Error if the request fails
    public static func performAskAIRequest(
        query: String,
        searchId: String,
        isRound: Bool = false,
        queryType: QueryType,
        language: Language = .english,
        currency: String,
        checkin: Date? = nil,
        checkout: Date? = nil,
        destination: String,
        origin: String,
        authToken: String? = nil
    ) async throws -> AskAIResponse {
        let request = AskAIRequest(
            filterQuery: query,
            searchId: searchId,
            isRound: isRound,
            queryType: queryType,
            language: language,
            currency: currency,
            checkin: checkin,
            checkout: checkout,
            destination: destination,
            origin: origin,
            authToken: authToken
        )
        
        return try await apiService.performAskAIRequest(request: request)
    }
    
    /// Subscribe to real-time updates for a search ID
    /// - Parameters:
    ///   - searchId: The search ID to subscribe to
    ///   - authToken: The authorization token
    ///   - onEvent: Callback for received events
    ///   - onError: Callback for connection errors
    public static func subscribeToEvents(
        searchId: String,
        authToken: String,
        onEvent: @escaping (String) -> Void,
        onError: @escaping (Error) -> Void
    ) {
        apiService.subscribeToEvents(
            searchId: searchId,
            authToken: authToken,
            onEvent: onEvent,
            onError: onError
        )
    }
    
    /// Perform a sort-best request (without query, for automatic sorting)
    /// - Parameters:
    ///   - searchId: The search ID to use
    ///   - isRound: Whether this is a round trip (default: false)
    ///   - queryType: The type of query (hotel or flight)
    ///   - language: The language for the request (default: .english)
    ///   - currency: The currency code (e.g., SAR, AED, USD, INR)
    ///   - checkin: Check-in date (optional)
    ///   - checkout: Check-out date (optional)
    ///   - destination: Destination location
    ///   - origin: Origin location
    ///   - authToken: Optional authorization token
    /// - Returns: AskAIResponse containing chips and parameter change notice
    /// - Throws: Error if the request fails
    public static func performSortBestRequest(
        searchId: String,
        isRound: Bool = false,
        queryType: QueryType,
        language: Language = .english,
        currency: String,
        checkin: Date? = nil,
        checkout: Date? = nil,
        destination: String,
        origin: String,
        authToken: String? = nil
    ) async throws -> AskAIResponse {
        let request = AskAIRequest(
            filterQuery: "",  // Empty query for sort-best
            searchId: searchId,
            isRound: isRound,
            queryType: queryType,
            language: language,
            currency: currency,
            checkin: checkin,
            checkout: checkout,
            destination: destination,
            origin: origin,
            authToken: authToken
        )
        
        return try await apiService.performSortBestRequest(request: request)
    }
    
    /// Disconnect from any active SSE connection
    public static func disconnect() {
        apiService.disconnect()
    }
}
