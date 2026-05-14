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
    
    /// The currency code (e.g., SAR, AED, USD, INR)
    public let currency: String
    
    /// Check-in date
    public let checkin: Date?
    
    /// Check-out date
    public let checkout: Date?
    
     /// Adults
    public let adults: Int?
    
    // Children
   public let children: Int?
    
    // Child ages
    public let childAges: [Int]?

    /// Number of infants (flight)
    public let infant: Int?

    /// Number of rooms (hotel)
    public let rooms: Int?

    /// Cabin class (flight) — e.g. "Economy", "Business"
    public let cabinType: String?

    /// Departure date (flight) — sent as ISO 8601 to sort-best
    public let departureDate: Date?

    /// Return date for round-trip flights — sent as ISO 8601 when present
    public let returnDate: Date?

    /// Destination location
    public let destination: String

    /// Origin location
    public let origin: String

    /// Initialize a new AskAI request
    public init(
        filterQuery: String,
        searchId: String,
        isRound: Bool = false,
        queryType: QueryType,
        currency: String,
        checkin: Date? = nil,
        checkout: Date? = nil,
        adults: Int? = nil,
        children: Int? = nil,
        childAges: [Int]? = nil,
        infant: Int? = nil,
        rooms: Int? = nil,
        cabinType: String? = nil,
        departureDate: Date? = nil,
        returnDate: Date? = nil,
        destination: String,
        origin: String
    ) {
        self.filterQuery = filterQuery
        self.searchId = searchId
        self.isRound = isRound
        self.queryType = queryType
        self.currency = currency
        self.checkin = checkin
        self.checkout = checkout
        self.adults = adults
        self.children = children
        self.childAges = childAges
        self.infant = infant
        self.rooms = rooms
        self.cabinType = cabinType
        self.departureDate = departureDate
        self.returnDate = returnDate
        self.destination = destination
        self.origin = origin
    }
}
