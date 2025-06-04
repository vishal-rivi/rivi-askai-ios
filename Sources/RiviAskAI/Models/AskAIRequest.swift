import Foundation

/// Request parameters for the AskAI API
public struct AskAIRequest {
    /// The filter query string
    public let filterQuery: String
    
    /// The search ID
    public let searchId: String
    
    /// Whether this is a round trip flight
    public let isRound: Bool
    
    /// Authorization token for API requests
    public let authToken: String?
    
    /// Initialize a new AskAI request
    /// - Parameters:
    ///   - filterQuery: The filter query string
    ///   - searchId: The search ID
    ///   - isRound: Whether this is a round trip flight
    ///   - authToken: Authorization token for API requests
    public init(
        filterQuery: String,
        searchId: String,
        isRound: Bool = false,
        authToken: String? = nil
    ) {
        self.filterQuery = filterQuery
        self.searchId = searchId
        self.isRound = isRound
        self.authToken = authToken
    }
} 