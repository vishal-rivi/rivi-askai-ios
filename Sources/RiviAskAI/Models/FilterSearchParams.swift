import Foundation

/// Filter search request parameters
public struct FilterSearchParams {
    /// The filter query string
    public let filterQuery: String?
    /// The search ID
    public let searchId: String?
    /// Whether this is a round trip flight
    public let isRound: Bool?
    /// Authorization token for API requests
    public let authToken: String?
    
    /// Initialize with required parameters for the filter search API
    public init(
        searchId: String?,
        isRound: Bool? = false,
        filterQuery: String? = "",
        authToken: String?
    ) {
        self.filterQuery = filterQuery
        self.searchId = searchId
        self.isRound = isRound
        self.authToken = authToken
    }
    
    private enum CodingKeys: String, CodingKey {
        case filterQuery = "filter_query"
        case searchId = "search_id"
        case isRound = "is_round"
        case authToken = "authorization"
    }
}
