// JSON mapping for the contract types, in the spellings of data/cases.schema.json. Used to load the
// conformance corpus and to compare results with it ("Deep equality is JSON equality").

public struct ContractDecodingError: Error, Sendable, CustomStringConvertible {
    public let description: String
    init(_ description: String) { self.description = description }
}

private func field(_ object: JSONObject, _ key: String) throws -> JSONValue {
    guard let value = object[key] else { throw ContractDecodingError("missing \"\(key)\"") }
    return value
}

private func string(_ object: JSONObject, _ key: String) throws -> String {
    guard let value = try field(object, key).stringValue else { throw ContractDecodingError("\"\(key)\" is not a string") }
    return value
}

private func optionalString(_ object: JSONObject, _ key: String) throws -> String? {
    guard let value = object[key], !value.isNull else { return nil }
    guard let text = value.stringValue else { throw ContractDecodingError("\"\(key)\" is not a string") }
    return text
}

private func int(_ object: JSONObject, _ key: String) throws -> Int {
    guard let value = try field(object, key).numberValue, value.rounded() == value else {
        throw ContractDecodingError("\"\(key)\" is not an integer")
    }
    return Int(value)
}

private func optionalInt(_ object: JSONObject, _ key: String) throws -> Int? {
    guard let value = object[key], !value.isNull else { return nil }
    return try int(object, key)
}

private func bool(_ object: JSONObject, _ key: String) throws -> Bool {
    guard let value = try field(object, key).boolValue else { throw ContractDecodingError("\"\(key)\" is not a boolean") }
    return value
}

private func object(_ value: JSONValue, _ what: String) throws -> JSONObject {
    guard let object = value.objectValue else { throw ContractDecodingError("\(what) is not an object") }
    return object
}

private func array(_ object: JSONObject, _ key: String) throws -> [JSONValue] {
    guard let value = try field(object, key).arrayValue else { throw ContractDecodingError("\"\(key)\" is not an array") }
    return value
}

private func enumValue<T: RawRepresentable>(_ object: JSONObject, _ key: String) throws -> T where T.RawValue == String {
    let raw = try string(object, key)
    guard let value = T(rawValue: raw) else { throw ContractDecodingError("\"\(key)\": unknown value \"\(raw)\"") }
    return value
}

private func optional(_ value: Int?) -> JSONValue { value.map { .number(Double($0)) } ?? .null }
private func optional(_ value: String?) -> JSONValue { value.map { .string($0) } ?? .null }
private func number(_ value: Int) -> JSONValue { .number(Double(value)) }

// MARK: - Values

extension RiviSearch {
    public init(json: JSONValue) throws {
        let o = try object(json, "search")
        let product: Product = try enumValue(o, "product")
        let pax = try object(try field(o, "pax"), "pax")
        switch product {
        case .flight:
            let cabin: Cabin? = o["cabin"].flatMap { $0.isNull ? nil : $0.stringValue }.flatMap(Cabin.init(rawValue:))
            self = .flight(FlightSearch(
                searchId: try string(o, "searchId"),
                tripType: try enumValue(o, "tripType"),
                origin: try string(o, "origin"),
                destination: try string(o, "destination"),
                departureDate: try string(o, "departureDate"),
                returnDate: try optionalString(o, "returnDate"),
                cabin: cabin,
                pax: .init(adults: try int(pax, "adults"), children: try int(pax, "children"), infants: try int(pax, "infants"))
            ))
        case .hotel:
            self = .hotel(HotelSearch(
                searchId: try string(o, "searchId"),
                destination: try string(o, "destination"),
                checkin: try string(o, "checkin"),
                checkout: try string(o, "checkout"),
                rooms: try int(o, "rooms"),
                pax: .init(adults: try int(pax, "adults"), children: try int(pax, "children"))
            ))
        }
    }

    public var json: JSONValue {
        switch self {
        case .flight(let s):
            var o: JSONObject = JSONObject([
                ("product", "flight"), ("searchId", .string(s.searchId)), ("tripType", .string(s.tripType.rawValue)),
                ("origin", .string(s.origin)), ("destination", .string(s.destination)),
                ("departureDate", .string(s.departureDate)),
            ])
            if let returnDate = s.returnDate { o["returnDate"] = .string(returnDate) }
            if let cabin = s.cabin { o["cabin"] = .string(cabin.rawValue) }
            o["pax"] = ["adults": number(s.pax.adults), "children": number(s.pax.children), "infants": number(s.pax.infants)]
            return .object(o)
        case .hotel(let s):
            return .object(JSONObject([
                ("product", "hotel"), ("searchId", .string(s.searchId)), ("tripType", "oneway"),
                ("destination", .string(s.destination)), ("checkin", .string(s.checkin)),
                ("checkout", .string(s.checkout)), ("rooms", number(s.rooms)),
                ("pax", ["adults": number(s.pax.adults), "children": number(s.pax.children)]),
            ]))
        }
    }
}

extension Chip {
    public init(json: JSONValue) throws {
        let o = try object(json, "chip")
        self.init(id: try string(o, "id"), label: try string(o, "label"), group: try string(o, "group"))
    }

    public var json: JSONValue {
        .object(JSONObject([("id", .string(id)), ("label", .string(label)), ("group", .string(group))]))
    }
}

extension RankingEntry {
    public init(json: JSONValue) throws {
        let o = try object(json, "ranking entry")
        self.init(
            id: try string(o, "id"),
            scope: try enumValue(o, "scope"),
            rank: try int(o, "rank"),
            matchesAllPreferences: try bool(o, "matchesAllPreferences"),
            tags: try array(o, "tags").map { value in
                guard let tag = value.stringValue else { throw ContractDecodingError("tag is not a string") }
                return tag
            },
            item: o["item"]
        )
    }

    public var json: JSONValue {
        var o = JSONObject([
            ("id", .string(id)), ("scope", .string(scope.rawValue)), ("rank", number(rank)),
            ("matchesAllPreferences", .bool(matchesAllPreferences)), ("tags", .array(tags.map { .string($0) })),
        ])
        if let item { o["item"] = item }
        return .object(o)
    }
}

extension RiviError {
    public init(json: JSONValue) throws {
        let o = try object(json, "error")
        self.init(kind: try enumValue(o, "kind"), message: try string(o, "message"), retryable: try bool(o, "retryable"))
    }

    public var json: JSONValue {
        .object(JSONObject([("kind", .string(kind.rawValue)), ("message", .string(message)), ("retryable", .bool(retryable))]))
    }
}

extension RiviConfig {
    /// A partial config over the defaults, as `initialState(config)` takes it.
    public init(partialJSON json: JSONValue?) throws {
        self = .default
        guard let json, !json.isNull else { return }
        let o = try object(json, "config")
        if o["chunkCoalesceMs"] != nil { chunkCoalesceMs = try int(o, "chunkCoalesceMs") }
        if o["explainDebounceMs"] != nil { explainDebounceMs = try int(o, "explainDebounceMs") }
        if o["settleMs"] != nil { settleMs = try int(o, "settleMs") }
    }

    public var json: JSONValue {
        .object(JSONObject([
            ("chunkCoalesceMs", number(chunkCoalesceMs)), ("explainDebounceMs", number(explainDebounceMs)),
            ("settleMs", number(settleMs)),
        ]))
    }
}

extension PoolFact {
    public init(json: JSONValue) throws {
        let o = try object(json, "pool")
        self.init(size: try int(o, "size"), complete: try bool(o, "complete"))
    }

    public var json: JSONValue {
        .object(JSONObject([("size", number(size)), ("complete", .bool(complete))]))
    }
}

extension Pool {
    public var json: JSONValue {
        switch self {
        case .rivi: return "rivi"
        case .fact(let fact): return fact.json
        }
    }
}

extension RiviState {
    /// Every field, keyed as `cases.json` names them.
    public var json: JSONObject {
        JSONObject([
            ("search", search?.json ?? .null),
            ("config", config.json),
            ("available", .bool(available)),
            ("stage", .string(stage.rawValue)),
            ("sort", .string(sort.rawValue)),
            ("pool", pool.json),
            ("query", .string(query)),
            ("chips", .array(chips.map(\.json))),
            ("entities", .object(entities)),
            ("notice", optional(notice)),
            ("ranking", .array(ranking.map(\.json))),
            ("rankingStatus", .string(rankingStatus.rawValue)),
            ("bannerMode", .string(bannerMode.rawValue)),
            ("explanation", .string(explanation)),
            ("explanationEpoch", optional(explanationEpoch)),
            ("visible", visible.map { .array($0.map { .string($0) }) } ?? .null),
            ("filters", filters ?? .null),
            ("pendingAsk", optional(pendingAsk)),
            ("pendingConfirm", optional(pendingConfirm?.rawValue)),
            ("epoch", number(epoch)),
            ("rankedEpoch", optional(rankedEpoch)),
            ("explainedEpoch", optional(explainedEpoch)),
            ("error", error?.json ?? .null),
        ])
    }
}

// MARK: - Inputs and commands

private func entities(_ o: JSONObject, _ key: String) throws -> Entities {
    try object(try field(o, key), "\"\(key)\"")
}

extension Input {
    public init(json: JSONValue) throws {
        let o = try object(json, "input")
        let kind = try string(o, "kind")
        switch kind {
        case "SetSearch": self = .setSearch(try RiviSearch(json: try field(o, "search")))
        case "SetSort": self = .setSort(try enumValue(o, "sort"))
        case "SetStage": self = .setStage(try enumValue(o, "stage"))
        case "SetFilters": self = .setFilters(o["filters"])
        case "PoolChanged": self = .poolChanged(try PoolFact(json: try field(o, "pool")))
        case "SetVisible":
            let ids = try field(o, "ids")
            self = .setVisible(ids.isNull ? nil : try (ids.arrayValue ?? []).map { value in
                guard let id = value.stringValue else { throw ContractDecodingError("visible id is not a string") }
                return id
            })
        case "Ask": self = .ask(text: try string(o, "text"))
        case "RemoveChip": self = .removeChip(id: try string(o, "id"))
        case "ClearAll": self = .clearAll
        case "ConfirmResolved": self = .confirmResolved(accepted: try bool(o, "accepted"))
        case "Retry": self = .retry
        case "DismissError": self = .dismissError
        case "AskResponse":
            self = .askResponse(
                epoch: try int(o, "epoch"),
                entities: try entities(o, "entities"),
                chips: try array(o, "chips").map(Chip.init(json:)),
                notice: try optionalString(o, "notice")
            )
        case "RankingFrame":
            self = .rankingFrame(epoch: try int(o, "epoch"), ranking: try array(o, "ranking").map(RankingEntry.init(json:)))
        case "ExplainFrame": self = .explainFrame(epoch: try int(o, "epoch"), text: try string(o, "text"))
        case "ExplainEnd": self = .explainEnd(epoch: try int(o, "epoch"))
        case "Failed": self = .failed(epoch: try int(o, "epoch"), error: try RiviError(json: try field(o, "error")))
        case "TimerFired": self = .timerFired(timer: try enumValue(o, "timer"), epoch: try int(o, "epoch"))
        default: throw ContractDecodingError("unknown input kind \"\(kind)\"")
        }
    }
}

extension FetchRequest {
    public init(json: JSONValue) throws {
        let o = try object(json, "request")
        switch try string(o, "kind") {
        case "ask": self = .ask(query: try string(o, "query"), filters: o["filters"])
        case "sortBest": self = .sortBest(filters: o["filters"])
        case "explain": self = .explain(query: try string(o, "query"), entities: try entities(o, "entities"))
        case let kind: throw ContractDecodingError("unknown request kind \"\(kind)\"")
        }
    }

    public var kindName: String {
        switch self {
        case .ask: return "ask"
        case .sortBest: return "sortBest"
        case .explain: return "explain"
        }
    }

    public var json: JSONValue {
        switch self {
        case let .ask(query, filters):
            var o = JSONObject([("kind", "ask"), ("query", .string(query))])
            if let filters { o["filters"] = filters }
            return .object(o)
        case .sortBest(let filters):
            var o = JSONObject([("kind", "sortBest")])
            if let filters { o["filters"] = filters }
            return .object(o)
        case let .explain(query, entities): return ["kind": "explain", "query": .string(query), "entities": .object(entities)]
        }
    }
}

extension Command {
    public init(json: JSONValue) throws {
        let o = try object(json, "command")
        switch try string(o, "kind") {
        case "Fetch": self = .fetch(epoch: try int(o, "epoch"), request: try FetchRequest(json: try field(o, "request")))
        case "CancelInFlight": self = .cancelInFlight(scope: try enumValue(o, "scope"))
        case "StartTimer":
            self = .startTimer(timer: try enumValue(o, "timer"), ms: try int(o, "ms"), epoch: try int(o, "epoch"))
        case "CancelTimer":
            let timer = try string(o, "timer")
            if timer == "all" {
                self = .cancelTimer(.all)
            } else if let one = RiviTimer(rawValue: timer) {
                self = .cancelTimer(.one(one))
            } else {
                throw ContractDecodingError("unknown timer \"\(timer)\"")
            }
        case "RankingCleared": self = .rankingCleared
        case "ConfirmSortChange": self = .confirmSortChange(sort: try enumValue(o, "sort"))
        case "SortChanged": self = .sortChanged(sort: try enumValue(o, "sort"))
        case let kind: throw ContractDecodingError("unknown command kind \"\(kind)\"")
        }
    }

    public var json: JSONValue {
        switch self {
        case let .fetch(epoch, request): return ["kind": "Fetch", "epoch": number(epoch), "request": request.json]
        case .cancelInFlight(let scope): return ["kind": "CancelInFlight", "scope": .string(scope.rawValue)]
        case let .startTimer(timer, ms, epoch):
            return ["kind": "StartTimer", "timer": .string(timer.rawValue), "ms": number(ms), "epoch": number(epoch)]
        case .cancelTimer(.all): return ["kind": "CancelTimer", "timer": "all"]
        case .cancelTimer(.one(let timer)): return ["kind": "CancelTimer", "timer": .string(timer.rawValue)]
        case .rankingCleared: return ["kind": "RankingCleared"]
        case .confirmSortChange(let sort): return ["kind": "ConfirmSortChange", "sort": .string(sort.rawValue)]
        case .sortChanged(let sort): return ["kind": "SortChanged", "sort": .string(sort.rawValue)]
        }
    }
}
