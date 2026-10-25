import XCTest
@testable import RiviSmartSortContract

/// Request bodies, byte for byte as the web builds them (test/adapters/wire.test.ts).
final class WireTests: XCTestCase {
    private let oneWay = RiviSearch.flight(FlightSearch(
        searchId: "s-flight", tripType: .oneway, origin: "RUH", destination: "DXB",
        departureDate: "2026-10-10T00:00:00.000Z", cabin: .economy, pax: .init(adults: 2, children: 1, infants: 0)
    ))
    private let round = RiviSearch.flight(FlightSearch(
        searchId: "s-round", tripType: .round, origin: "RUH", destination: "DXB",
        departureDate: "2026-10-10T00:00:00.000Z", returnDate: "2026-10-17T00:00:00.000Z", cabin: .first,
        pax: .init(adults: 2, children: 1, infants: 0)
    ))
    private let hotel = RiviSearch.hotel(HotelSearch(
        searchId: "s-hotel", destination: "Dubai", checkin: "10/10/2026", checkout: "10/14/2026", rooms: 2,
        pax: .init(adults: 3, children: 1)
    ))
    private let ctx = WireContext(locale: "ar", currency: "SAR")

    func testFlightAskBodyIsExactlyWhatAlmatarSends() {
        XCTAssertEqual(
            toAskBody(oneWay, query: "non-stop please", context: ctx).serialized(),
            #"{"search_id":"s-flight","filter_query":"non-stop please","query_type":"flight","is_round":false,"# +
            #""currency":"SAR","language":"ar","origin":"RUH","destination":"DXB","departure_date":"2026-10-10T00:00:00.000Z","# +
            #""adults":2,"children":1,"infant":0,"cabin_type":"Economy"}"#
        )
    }

    func testRoundTripAddsReturnDateAndIsRound() {
        let body = toAskBody(round, query: "q", context: ctx)
        XCTAssertEqual(body["is_round"], true)
        XCTAssertEqual(body["return_date"], "2026-10-17T00:00:00.000Z")
        XCTAssertEqual(body["cabin_type"], "FirstClass")
    }

    func testEmptyReturnDateIsOneWayAndNoCabinOmitsCabinType() {
        guard case .flight(var flight) = round else { return XCTFail() }
        flight.returnDate = ""
        flight.cabin = nil
        let body = toAskBody(.flight(flight), query: "q", context: ctx)
        XCTAssertEqual(body["is_round"], false)
        XCTAssertNil(body["return_date"])
        XCTAssertNil(body["cabin_type"])
    }

    func testFiltersAreSentAsIsAndOmittedWhenNone() {
        let filters: JSONValue = ["stops": [0], "maxPrice": 500]
        XCTAssertEqual(toAskBody(oneWay, query: "q", context: ctx, filters: filters)["filters"], filters)
        XCTAssertEqual(toSortBestBody(oneWay, filters: filters)["filters"], filters)
        XCTAssertNil(toAskBody(oneWay, query: "q", context: ctx)["filters"])
        XCTAssertNil(toSortBestBody(oneWay, filters: .null)["filters"])
        XCTAssertNil(toExplainBody(oneWay, query: "q", entities: JSONObject(), context: ctx)["filters"], "explain never carries filters")
        XCTAssertTrue(toSortBestBody(oneWay, filters: filters).serialized().hasSuffix(#""filters":{"stops":[0],"maxPrice":500}}"#), "filters come last")
    }

    func testHotelAskBodySendsUSDates() {
        let iso = RiviSearch.hotel(HotelSearch(
            searchId: "s-hotel", destination: "Dubai", checkin: "2026-10-19T08:25:49.771Z",
            checkout: "2026-10-23T08:25:49.771Z", rooms: 1, pax: .init(adults: 2)
        ))
        let ask = toAskBody(iso, query: "q", context: ctx)
        XCTAssertEqual(ask["checkin"], "10/19/2026")
        XCTAssertEqual(ask["checkout"], "10/23/2026")
        // Sort-best and explain-ai keep the dates as supplied.
        XCTAssertEqual(toSortBestBody(iso)["checkin"], "2026-10-19T08:25:49.771Z")
        XCTAssertEqual(toExplainBody(iso, query: "q", entities: JSONObject(), context: ctx)["checkin"], "2026-10-19T08:25:49.771Z")
    }

    func testUSDatePassesThroughNonISO() {
        XCTAssertEqual(usDate("10/19/2026"), "10/19/2026")
        XCTAssertEqual(usDate(""), "")
        XCTAssertEqual(usDate("2026-10-19"), "10/19/2026")
    }

    func testHotelAskBodyUsesSingularPax() {
        XCTAssertEqual(
            toAskBody(hotel, query: "near the beach", context: ctx).serialized(),
            #"{"search_id":"s-hotel","filter_query":"near the beach","query_type":"hotel","is_round":false,"# +
            #""currency":"SAR","language":"ar","destination":"Dubai","checkin":"10/10/2026","checkout":"10/14/2026","# +
            #""rooms":2,"adult":3,"child":1}"#
        )
    }

    func testSendsABareLanguageCode() {
        XCTAssertEqual(toAskBody(hotel, query: "q", context: .init(locale: "ar-SA", currency: "SAR"))["language"], "ar")
        XCTAssertEqual(toAskBody(hotel, query: "q", context: .init(locale: "EN_us", currency: "USD"))["language"], "en")
        XCTAssertEqual(toAskBody(hotel, query: "q", context: .init(locale: "ar-u-nu-arab", currency: "SAR"))["language"], "ar")
    }

    func testSortBestBodyHasNoCurrencyOrLanguage() {
        XCTAssertEqual(
            toSortBestBody(round).serialized(),
            #"{"search_id":"s-round","filled_slots":{},"query_type":"flight","is_round":true,"origin":"RUH","# +
            #""destination":"DXB","departure_date":"2026-10-10T00:00:00.000Z","return_date":"2026-10-17T00:00:00.000Z","# +
            #""adults":2,"children":1,"infant":0,"cabin_type":"FirstClass"}"#
        )
        XCTAssertEqual(toSortBestBody(hotel)["is_round"], false)
    }

    func testExplainBodyUsesPluralPaxAndNoInfants() {
        let body = toExplainBody(hotel, query: "q", entities: JSONObject([("star_rating", [5])]), context: ctx)
        XCTAssertEqual(body["adults"], 3)
        XCTAssertEqual(body["children"], 1)
        XCTAssertNil(body["adult"])
        XCTAssertEqual(body["extracted_entities"], ["star_rating": [5]])
        let flight = toExplainBody(oneWay, query: "q", entities: JSONObject(), context: ctx)
        XCTAssertNil(flight["infant"])
        XCTAssertEqual(flight["search_type"], "flight")
    }
}
