import Foundation

/// Parameters for flight search using the RiviAskAI API
public struct FlightSearchParams {
    /// The search ID
    public let searchId: String
    /// Whether this is a round trip flight
    public let isRound: Bool
    /// Authorization token for API requests
    public let authToken: String
    /// The filter query string
    public let filterQuery: String?
    
    /// Initialize with required parameters for flight search
    /// - Parameters:
    ///   - searchId: The search ID
    ///   - isRound: Whether this is a round trip
    ///   - authToken: Authorization token
    ///   - filterQuery: Optional filter query text
    public init(
        searchId: String,
        isRound: Bool,
        authToken: String,
        filterQuery: String? = ""
    ) {
        self.searchId = searchId
        self.isRound = isRound
        self.authToken = authToken
        self.filterQuery = filterQuery
    }
    
    /// Convert to FilterSearchParams for internal use
    public func toFilterSearchParams() -> FilterSearchParams {
        return FilterSearchParams(
            searchId: searchId,
            isRound: isRound,
            filterQuery: filterQuery,
            authToken: authToken
        )
    }
} 
