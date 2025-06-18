// The Swift Programming Language
// https://docs.swift.org/swift-book

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
    ///   - authToken: Optional authorization token
    /// - Returns: Set of chip strings extracted from the response
    /// - Throws: Error if the request fails
    public static func performAskAIRequest(
        query: String,
        searchId: String,
        isRound: Bool = false,
        authToken: String? = nil
    ) async throws -> Set<String> {
        let request = AskAIRequest(
            filterQuery: query,
            searchId: searchId,
            isRound: isRound,
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
    
    /// Disconnect from any active SSE connection
    public static func disconnect() {
        apiService.disconnect()
    }
}
