// Request bodies (web: src/adapters/wire.ts), field for field and in the same key order.
// Dates pass through as the tenant supplied them, except the hotel ask's (MM/dd/yyyy).

public struct WireContext: Sendable, Equatable {
    public var locale: String
    public var currency: String
    public init(locale: String, currency: String) {
        self.locale = locale
        self.currency = currency
    }
}

/// `cabin_type` values as production integrations send them.
private func cabinType(_ cabin: Cabin) -> String {
    switch cabin {
    case .economy: return "Economy"
    case .premium: return "PremiumEconomy"
    case .business: return "Business"
    case .first: return "FirstClass"
    }
}

/// A bare language code (`en`, `ar`), never a region or extension.
func wireLanguage(_ locale: String) -> String {
    let base = locale.split(whereSeparator: { $0 == "-" || $0 == "_" }).first.map(String.init)?.lowercased() ?? ""
    return base.isEmpty ? "en" : base
}

private func isRound(_ search: RiviSearch) -> Bool {
    if case .flight(let flight) = search, let returnDate = flight.returnDate, returnDate != "" { return true }
    return false
}

private func int(_ value: Int) -> JSONValue { .number(Double(value)) }

private func flightTrip(_ search: FlightSearch) -> JSONObject {
    var trip = JSONObject([
        ("origin", .string(search.origin)),
        ("destination", .string(search.destination)),
        ("departure_date", .string(search.departureDate)),
    ])
    if isRound(.flight(search)), let returnDate = search.returnDate { trip["return_date"] = .string(returnDate) }
    trip["adults"] = int(search.pax.adults)
    trip["children"] = int(search.pax.children)
    trip["infant"] = int(search.pax.infants)
    if let cabin = search.cabin { trip["cabin_type"] = .string(cabinType(cabin)) }
    return trip
}

/// `2026-10-19T08:25:49.771Z` → `10/19/2026`. Anything that doesn't start with `yyyy-MM-dd` passes
/// through unchanged.
func usDate(_ date: String) -> String {
    let parts = date.prefix(10).split(separator: "-", omittingEmptySubsequences: false)
    guard parts.count == 3, parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
          parts.allSatisfy({ $0.allSatisfy(\.isASCII) && $0.allSatisfy(\.isNumber) }) else { return date }
    return "\(parts[1])/\(parts[2])/\(parts[0])"
}

/// `usDates`: the hotel ask endpoint only accepts `MM/dd/yyyy` (it rejects ISO 8601 with
/// "does not match format '%m/%d/%Y'"); sort-best and explain-ai take the dates as supplied.
private func hotelTrip(_ search: HotelSearch, usDates: Bool = false) -> JSONObject {
    JSONObject([
        ("destination", .string(search.destination)),
        ("checkin", .string(usDates ? usDate(search.checkin) : search.checkin)),
        ("checkout", .string(usDates ? usDate(search.checkout) : search.checkout)),
        ("rooms", int(search.rooms)),
        ("adult", int(search.pax.adults)),
        ("child", int(search.pax.children)),
    ])
}

private func trip(_ search: RiviSearch, usHotelDates: Bool = false) -> JSONObject {
    switch search {
    case .flight(let flight): return flightTrip(flight)
    case .hotel(let hotel): return hotelTrip(hotel, usDates: usHotelDates)
    }
}

/// The tenant's filters, exactly as reported. Omitted when there are none.
private func filtersField(_ filters: JSONValue?) -> JSONObject {
    guard let filters, !filters.isNull else { return JSONObject() }
    return JSONObject([("filters", filters)])
}

/// `POST /api/v1/askai`.
public func toAskBody(_ search: RiviSearch, query: String, context: WireContext, filters: JSONValue? = nil) -> JSONValue {
    let body = JSONObject([
        ("search_id", .string(search.searchId)),
        ("filter_query", .string(query)),
        ("query_type", .string(search.product.rawValue)),
        ("is_round", .bool(isRound(search))),
        ("currency", .string(context.currency)),
        ("language", .string(wireLanguage(context.locale))),
    ])
    return .object(body.merging(trip(search, usHotelDates: true)).merging(filtersField(filters)))
}

/// `POST /api/v1/askai/sort-best`. No currency or language here, as on the web.
public func toSortBestBody(_ search: RiviSearch, filters: JSONValue? = nil) -> JSONValue {
    let body = JSONObject([
        ("search_id", .string(search.searchId)),
        ("filled_slots", .object(JSONObject())),
        ("query_type", .string(search.product.rawValue)),
        ("is_round", .bool(isRound(search))),
    ])
    return .object(body.merging(trip(search)).merging(filtersField(filters)))
}

/// `POST /api/v1/askai/explain-ai`. Plural pax only, and no infants.
public func toExplainBody(_ search: RiviSearch, query: String, entities: Entities, context: WireContext) -> JSONValue {
    var body = JSONObject([
        ("search_type", .string(search.product.rawValue)),
        ("filter_query", .string(query)),
        ("extracted_entities", .object(entities)),
        ("language", .string(wireLanguage(context.locale))),
        ("currency", .string(context.currency)),
        ("search_id", .string(search.searchId)),
    ])
    switch search {
    case .flight(let s):
        body["origin"] = .string(s.origin)
        body["destination"] = .string(s.destination)
        body["departure_date"] = .string(s.departureDate)
        if isRound(search), let returnDate = s.returnDate { body["return_date"] = .string(returnDate) }
        body["adults"] = int(s.pax.adults)
        body["children"] = int(s.pax.children)
        if let cabin = s.cabin { body["cabin_type"] = .string(cabinType(cabin)) }
    case .hotel(let s):
        body["destination"] = .string(s.destination)
        body["checkin"] = .string(s.checkin)
        body["checkout"] = .string(s.checkout)
        body["rooms"] = int(s.rooms)
        body["adults"] = int(s.pax.adults)
        body["children"] = int(s.pax.children)
    }
    return .object(body)
}
