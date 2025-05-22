import Foundation

/// Filter search request parameters
public struct FilterSearchParams {
    /// The filter query string
    public let filterQuery: String?
    /// The itinerary Id
    public let itineraryId: String?
    /// The destination city
    public let destination: String?
    /// Check-in date (format: YYYY-MM-DD)
    public let checkin: String?
    /// Check-out date (format: YYYY-MM-DD)
    public let checkout: String?
    /// Number of adults
    public let adult: Int?
    /// Number of rooms
    public let rooms: Int?
    /// Type of query (e.g., "hotel")
    public let queryType: String?
    
    public let cabinType: String?
    public let origin: String?
    public let depDate: String?
    public let isRound: String?
    
    /// Initialize with all required parameters for a filter search (Hotel)
    public init(
        itineraryId: String?,
        destination: String?,
        checkin: String?,
        checkout: String?,
        adult: Int?,
        rooms: Int?,
        queryType: String?
    ) {
        self.filterQuery = ""
        self.itineraryId = itineraryId
        self.destination = destination
        self.checkin = checkin
        self.checkout = checkout
        self.adult = adult
        self.rooms = rooms
        self.queryType = queryType
        
        self.cabinType = nil
        self.origin = nil
        self.depDate = nil
        self.isRound = nil
    }
    
    /// Initialize with all required parameters for a filter search (Flight)
    public init(
        adult: Int?,
        cabinType: String?,
        origin: String?,
        destination: String?,
        depDate: String?,
        itineraryId: String?,
        isRound: String?,
        queryType: String?
    ) {
        self.filterQuery = ""
        self.itineraryId = itineraryId
        self.destination = destination
        self.adult = adult
        self.queryType = queryType
        self.cabinType = cabinType
        self.origin = origin
        self.depDate = depDate
        self.isRound = isRound
        
        self.checkin = nil
        self.checkout = nil
        self.rooms = nil
    }
    
    private enum CodingKeys: String, CodingKey {
        case filterQuery = "filter_query"
        case itineraryId = "itinerary_id"
        case destination = "destination"
        case checkin = "checkin"
        case checkout = "checkout"
        case adult = "adult"
        case rooms = "rooms"
        case queryType = "query_type"
        case cabinType = "cabin_type"
        case origin = "origin"
        case depDate = "dep_date"
        case isRound = "is_round"
    }
}
