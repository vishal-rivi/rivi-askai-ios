import Foundation

/// Request parameters for the AskAI API
public struct AskAIRequest {
    /// The filter query string
    public let filterQuery: String
    
    /// The search ID
    public let searchId: String
    
    /// Whether this is a round trip flight
    public let isRound: Bool
    
    /// The type of query (hotel or flight)
    public let queryType: QueryType
    
    /// The language for the request
    public let language: Language
    
    /// The currency code (e.g., SAR, AED, USD, INR)
    public let currency: String
    
    /// Check-in date
    public let checkin: Date?
    
    /// Check-out date
    public let checkout: Date?
    
    /// Destination location
    public let destination: String
    
    /// Origin location
    public let origin: String
    
    /// Authorization token for API requests
    public let authToken: String?
    
    /// Initialize a new AskAI request
    /// - Parameters:
    ///   - filterQuery: The filter query string
    ///   - searchId: The search ID
    ///   - isRound: Whether this is a round trip flight
    ///   - queryType: The type of query (hotel or flight)
    ///   - language: The language for the request
    ///   - currency: The currency code
    ///   - checkin: Check-in date (optional)
    ///   - checkout: Check-out date (optional)
    ///   - destination: Destination location
    ///   - origin: Origin location
    ///   - authToken: Authorization token for API requests
    public init(
        filterQuery: String,
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
    ) {
        self.filterQuery = filterQuery
        self.searchId = searchId
        self.isRound = isRound
        self.queryType = queryType
        self.language = language
        self.currency = currency
        self.checkin = checkin
        self.checkout = checkout
        self.destination = destination
        self.origin = origin
        self.authToken = authToken
    }
}
