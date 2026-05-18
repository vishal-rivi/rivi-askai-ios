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
        environment.baseURL
    }

    /// Authorization token for API requests
    public var authToken: String?

    /// Default language for API requests
    public var language: Language = .english

    /// Minimum log level for SDK logs (e.g. request/response flow). Default: `.info`.
    public var logLevel: AskAILogLevel = .info

    /// Custom logger for SDK logs. If `nil`, a default console logger is used with `logLevel`.
    public var logger: AskAILogger?

    /// Optional handler invoked with cumulative explain-ai content as it streams from the SSE endpoint.
    /// When set, the SDK automatically fires `performExplainAIRequest` after every successful
    /// `performAskAIRequest` with a non-empty query, and forwards each snapshot to this handler on the main actor.
    public var onExplainContent: (@MainActor (String) -> Void)?

    /// Optional handler invoked on the main actor when the auto-fired explain-ai request fails.
    public var onExplainError: (@MainActor (Error) -> Void)?

    /// Resolved logger used internally: custom logger if set, otherwise `ConsoleAskAILogger(logLevel: logLevel)`.
    internal var resolvedLogger: AskAILogger {
        logger ?? ConsoleAskAILogger(logLevel: logLevel)
    }

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
    ///   - logLevel: Minimum level for SDK logs (default: `.info`)
    ///   - logger: Optional custom logger; if `nil`, a default console logger is used
    public static func initialize(
        environment: RiviAskAIEnvironment,
        authToken: String,
        language: Language,
        logLevel: AskAILogLevel = .info,
        logger: AskAILogger? = nil
    ) {
        RiviAskAIConfiguration.shared.environment = environment
        RiviAskAIConfiguration.shared.authToken = authToken
        RiviAskAIConfiguration.shared.language = language
        RiviAskAIConfiguration.shared.logLevel = logLevel
        RiviAskAIConfiguration.shared.logger = logger

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
    /// Perform an AskAI filter request. The body shape varies by `queryType`:
    ///   - **flight**: `filter_query`, `search_id`, `origin`, `destination`, `departure_date`
    ///     (ISO 8601), `return_date`, `adults`, `children`, `infant`, `is_round`, `cabin_type`,
    ///     `language`, `currency`, plus `query_type`.
    ///   - **hotel**: `filter_query`, `search_id`, `destination`, `checkin` / `checkout`
    ///     (ISO 8601), `rooms`, `adults`, `children`, `child_ages`, `language`, `currency`,
    ///     plus `query_type`.
    public static func performAskAIRequest(
        query: String,
        searchId: String,
        isRound: Bool = false,
        queryType: QueryType,
        currency: String,
        checkin: Date? = nil,
        checkout: Date? = nil,
        departureDate: Date? = nil,
        returnDate: Date? = nil,
        adults: Int = 1,
        children: Int = 0,
        childAges: [Int]? = nil,
        infant: Int = 0,
        rooms: Int = 1,
        cabinType: String = "Economy",
        destination: String,
        origin: String = ""
    ) async throws -> AskAIResponse {
        let request = AskAIRequest(
            filterQuery: query,
            searchId: searchId,
            isRound: isRound,
            queryType: queryType,
            currency: currency,
            checkin: checkin,
            checkout: checkout,
            adults: adults,
            children: children,
            childAges: childAges,
            infant: infant,
            rooms: rooms,
            cabinType: cabinType,
            departureDate: departureDate,
            returnDate: returnDate,
            destination: destination,
            origin: origin
        )

        return try await apiService.performAskAIRequest(request: request)
    }
    
    /// Request a natural-language explanation for the current AskAI ranking.
    /// Call this after `performAskAIRequest` using `response.entity` as `extractedEntities`.
    /// - Parameters:
    ///   - query: The user's query string (same as the prior AskAI call)
    ///   - extractedEntities: The `entity` dictionary returned from the prior `AskAIResponse`
    ///   - searchId: The search ID to use
    ///   - isRound: Whether this is a round trip (default: false)
    ///   - queryType: The type of query (hotel or flight)
    ///   - currency: The currency code (e.g., SAR, AED, USD, INR)
    ///   - checkin: Hotel check-in date (optional)
    ///   - checkout: Hotel check-out date (optional)
    ///   - departureDate: Flight departure date (optional)
    ///   - returnDate: Flight return date for round-trips (optional)
    ///   - adults: Number of adults (default: 1)
    ///   - children: Number of children (default: 0)
    ///   - childAges: Ages for each child (optional)
    ///   - rooms: Number of rooms for hotel queries (default: 1)
    ///   - cabinType: Cabin class for flight queries (default: "Economy")
    ///   - destination: Destination location
    ///   - origin: Origin location
    /// - Returns: ExplainAIResponse containing the explanation text
    /// - Throws: Error if the request fails
    public static func performExplainAIRequest(
        query: String,
        extractedEntities: [String: Any],
        searchId: String,
        isRound: Bool = false,
        queryType: QueryType,
        currency: String = "",
        checkin: Date? = nil,
        checkout: Date? = nil,
        departureDate: Date? = nil,
        returnDate: Date? = nil,
        adults: Int = 1,
        children: Int = 0,
        childAges: [Int]? = nil,
        rooms: Int = 1,
        cabinType: String = "Economy",
        destination: String,
        origin: String = "",
        onPartialContent: (@MainActor (String) -> Void)? = nil
    ) async throws -> ExplainAIResponse {
        let request = AskAIRequest(
            filterQuery: query,
            searchId: searchId,
            isRound: isRound,
            queryType: queryType,
            currency: currency,
            checkin: checkin,
            checkout: checkout,
            adults: adults,
            children: children,
            childAges: childAges,
            destination: destination,
            origin: origin
        )

        return try await apiService.performExplainAIRequest(
            request: request,
            extractedEntities: extractedEntities,
            departureDate: departureDate,
            returnDate: returnDate,
            rooms: rooms,
            cabinType: cabinType,
            onPartialContent: onPartialContent
        )
    }

    /// Subscribe to real-time updates for a search ID
    /// - Parameters:
    ///   - searchId: The search ID to subscribe to
    ///   - onEvent: Callback for received events
    ///   - onError: Callback for connection errors
    public static func subscribeToEvents(
        searchId: String,
        config: SSEConfig = .default,
        onState: ((SSEConnectionState) -> Void)? = nil,
        onEvent: @escaping (String) -> Void,
        onError: @escaping (Error) -> Void
    ) {
        apiService.subscribeToEvents(
            searchId: searchId,
            config: config,
            onState: onState,
            onEvent: onEvent,
            onError: onError
        )
    }
    
    /// Perform a sort-best request (no user query — used for the initial ranked search).
    /// Body shape varies by `queryType`:
    ///   - **flight**: `search_id`, `is_round`, `origin`, `destination`, `departure_date` (ISO 8601),
    ///     `return_date`, `adults`, `children`, `infant`, `cabin_type`, `language`, `currency`.
    ///   - **hotel**: `search_id`, `is_round`, `query_type`, `context`, `origin`, `destination`,
    ///     `checkin` / `checkout` (MM/dd/yyyy), `adults`, `children`, `rooms`, `language`, `currency`.
    public static func performSortBestRequest(
        searchId: String,
        isRound: Bool = false,
        queryType: QueryType,
        currency: String,
        checkin: Date? = nil,
        checkout: Date? = nil,
        departureDate: Date? = nil,
        returnDate: Date? = nil,
        adults: Int = 1,
        children: Int = 0,
        childAges: [Int]? = nil,
        infant: Int = 0,
        rooms: Int = 1,
        cabinType: String = "Economy",
        destination: String,
        origin: String = ""
    ) async throws -> AskAIResponse {
        let request = AskAIRequest(
            filterQuery: "",
            searchId: searchId,
            isRound: isRound,
            queryType: queryType,
            currency: currency,
            checkin: checkin,
            checkout: checkout,
            adults: adults,
            children: children,
            childAges: childAges,
            infant: infant,
            rooms: rooms,
            cabinType: cabinType,
            departureDate: departureDate,
            returnDate: returnDate,
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
