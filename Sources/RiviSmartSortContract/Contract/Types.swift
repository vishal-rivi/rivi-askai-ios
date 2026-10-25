// The contract's types (web: smart-sort-core/src/contract/types.ts, schema: data/cases.schema.json).
// Raw values are the wire / cases.json spellings.

/// `other` is any of the tenant's own sort tabs: the contract only needs Best or not.
public enum SortMode: String, Sendable, CaseIterable {
    case best, other
}

public enum Stage: String, Sendable {
    case onward, `return`
}

public enum BannerMode: String, Sendable {
    case hidden, loading, explanation, fallback
}

/// The one value the banner renders (`selectBanner`).
public enum BannerView: String, Sendable {
    case hidden, loading, refreshing, conflict, explanation, fallback
}

/// Named one-shot timers. (Not `Timer`, to stay clear of Foundation.)
public enum RiviTimer: String, Sendable, CaseIterable {
    case chunk, explain, settle
}

public enum TimerTarget: Sendable, Equatable {
    case one(RiviTimer)
    case all
}

public enum Product: String, Sendable {
    case flight, hotel
}

public enum TripType: String, Sendable {
    case oneway, round, multicity
}

public enum Cabin: String, Sendable {
    case economy, premium, business, first
}

public struct FlightSearch: Sendable, Equatable {
    public struct Pax: Sendable, Equatable {
        public var adults: Int
        public var children: Int
        public var infants: Int
        public init(adults: Int, children: Int = 0, infants: Int = 0) {
            self.adults = adults
            self.children = children
            self.infants = infants
        }
    }

    public var searchId: String
    public var tripType: TripType
    public var origin: String
    public var destination: String
    /// Passed through to the gateway exactly as the tenant supplies it.
    public var departureDate: String
    public var returnDate: String?
    public var cabin: Cabin?
    public var pax: Pax

    public init(searchId: String, tripType: TripType, origin: String, destination: String,
                departureDate: String, returnDate: String? = nil, cabin: Cabin? = nil, pax: Pax) {
        self.searchId = searchId
        self.tripType = tripType
        self.origin = origin
        self.destination = destination
        self.departureDate = departureDate
        self.returnDate = returnDate
        self.cabin = cabin
        self.pax = pax
    }
}

public struct HotelSearch: Sendable, Equatable {
    public struct Pax: Sendable, Equatable {
        public var adults: Int
        public var children: Int
        public init(adults: Int, children: Int = 0) {
            self.adults = adults
            self.children = children
        }
    }

    public var searchId: String
    public var destination: String
    public var checkin: String
    public var checkout: String
    public var rooms: Int
    public var pax: Pax

    public init(searchId: String, destination: String, checkin: String, checkout: String, rooms: Int, pax: Pax) {
        self.searchId = searchId
        self.destination = destination
        self.checkin = checkin
        self.checkout = checkout
        self.rooms = rooms
        self.pax = pax
    }
}

public enum RiviSearch: Sendable, Equatable {
    case flight(FlightSearch)
    case hotel(HotelSearch)

    public var product: Product {
        switch self {
        case .flight: return .flight
        case .hotel: return .hotel
        }
    }

    public var searchId: String {
        switch self {
        case .flight(let search): return search.searchId
        case .hotel(let search): return search.searchId
        }
    }

    /// Hotels are always one-way.
    public var tripType: TripType {
        switch self {
        case .flight(let search): return search.tripType
        case .hotel: return .oneway
        }
    }
}

public struct Chip: Sendable, Equatable, Hashable, Identifiable {
    public var id: String
    public var label: String
    public var group: String
    public init(id: String, label: String, group: String) {
        self.id = id
        self.label = label
        self.group = group
    }
}

/// The ask response's entity record. Opaque: `reconcile` never interprets it.
public typealias Entities = JSONObject

public enum Scope: String, Sendable {
    case itinerary, onward, `return`, hotel
}

public struct RankingEntry: Sendable, Equatable, Identifiable {
    /// Itinerary id, leg id or hotel id. Stable across frames.
    public var id: String
    /// A round-trip frame ranks both legs at once.
    public var scope: Scope
    /// 0-based position within its scope.
    public var rank: Int
    /// Wire: `allPreferencesMet`. Missing means true.
    public var matchesAllPreferences: Bool
    /// Wire: `recommendationTagList`, plus `recommendationTag`.
    public var tags: [String]
    /// The raw wire object, untouched, when the frame carries it.
    public var item: JSONValue?

    public init(id: String, scope: Scope, rank: Int, matchesAllPreferences: Bool, tags: [String], item: JSONValue? = nil) {
        self.id = id
        self.scope = scope
        self.rank = rank
        self.matchesAllPreferences = matchesAllPreferences
        self.tags = tags
        self.item = item
    }
}

public struct RiviError: Error, Sendable, Equatable {
    public enum Kind: String, Sendable {
        case network, auth, timeout, stream, server
    }

    public var kind: Kind
    public var message: String
    public var retryable: Bool

    public init(kind: Kind, message: String, retryable: Bool) {
        self.kind = kind
        self.message = message
        self.retryable = retryable
    }
}

public struct RiviConfig: Sendable, Equatable {
    public var chunkCoalesceMs: Int
    public var explainDebounceMs: Int
    public var settleMs: Int

    public static let `default` = RiviConfig(chunkCoalesceMs: 300, explainDebounceMs: 500, settleMs: 800)

    public init(chunkCoalesceMs: Int, explainDebounceMs: Int, settleMs: Int) {
        self.chunkCoalesceMs = chunkCoalesceMs
        self.explainDebounceMs = explainDebounceMs
        self.settleMs = settleMs
    }
}

public struct PoolFact: Sendable, Equatable {
    public var size: Int
    public var complete: Bool
    public init(size: Int, complete: Bool) {
        self.size = size
        self.complete = complete
    }
}

/// `.rivi` means the tenant never reported a pool: Rivi's list is the list.
public enum Pool: Sendable, Equatable {
    case rivi
    case fact(PoolFact)
}

public enum RankingStatus: String, Sendable {
    case none, provisional, final
}

public struct RiviState: Sendable, Equatable {
    /// nil until the first search.
    public var search: RiviSearch?
    public var config: RiviConfig
    public var available: Bool
    public var stage: Stage
    public var sort: SortMode
    public var pool: Pool
    public var query: String
    public var chips: [Chip]
    public var entities: Entities
    /// `parameter_change_notice` from the ask response.
    public var notice: String?
    public var ranking: [RankingEntry]
    public var rankingStatus: RankingStatus
    public var bannerMode: BannerMode
    public var explanation: String
    /// Epoch the current explanation text belongs to.
    public var explanationEpoch: Int?
    /// Optional tenant fact: ids actually rendered. nil means not reported.
    public var visible: [String]?
    /// The tenant's applied filters, any JSON value, sent as-is with every rank request. nil = none.
    public var filters: JSONValue?
    public var pendingAsk: String?
    public var pendingConfirm: SortMode?
    public var epoch: Int
    /// Epoch of the last accepted RankingFrame.
    public var rankedEpoch: Int?
    /// Epoch an explain was requested for.
    public var explainedEpoch: Int?
    public var error: RiviError?
}

public enum Input: Sendable, Equatable {
    // Tenant facts.
    case setSearch(RiviSearch)
    case setSort(SortMode)
    case setStage(Stage)
    /// nil (or JSON null) clears them.
    case setFilters(JSONValue?)
    case poolChanged(PoolFact)
    case setVisible([String]?)
    // User intents, from our UI.
    case ask(text: String)
    case removeChip(id: String)
    case clearAll
    case confirmResolved(accepted: Bool)
    case retry
    case dismissError
    // I/O results, each tagged with the epoch that started it.
    case askResponse(epoch: Int, entities: Entities, chips: [Chip], notice: String?)
    case rankingFrame(epoch: Int, ranking: [RankingEntry])
    case explainFrame(epoch: Int, text: String)
    case explainEnd(epoch: Int)
    case failed(epoch: Int, error: RiviError)
    case timerFired(timer: RiviTimer, epoch: Int)
}

/// The only three endpoints the SDK owns. The runtime opens the ranking stream for ask and sortBest.
/// `filters` is present only when the tenant reported filters (state.filters is not nil).
public enum FetchRequest: Sendable, Equatable {
    case ask(query: String, filters: JSONValue? = nil)
    case sortBest(filters: JSONValue? = nil)
    case explain(query: String, entities: Entities)
}

public enum CancelScope: String, Sendable {
    case all, explain
}

public enum Command: Sendable, Equatable {
    case fetch(epoch: Int, request: FetchRequest)
    case cancelInFlight(scope: CancelScope)
    case startTimer(timer: RiviTimer, ms: Int, epoch: Int)
    case cancelTimer(TimerTarget)
    case rankingCleared
    case confirmSortChange(sort: SortMode)
    case sortChanged(sort: SortMode)

    /// Commands the tenant hears about; the runtime executes the rest.
    public var isTenantCommand: Bool {
        switch self {
        case .rankingCleared, .confirmSortChange, .sortChanged: return true
        default: return false
        }
    }
}
