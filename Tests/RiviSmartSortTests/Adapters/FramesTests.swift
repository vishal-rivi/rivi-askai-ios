import XCTest
@testable import RiviSmartSortContract

/// Frame shapes, from the web suite (test/adapters/frames.test.ts) and its fixtures.
final class FramesTests: XCTestCase {
    private final class Warnings: @unchecked Sendable {
        var messages: [String] = []
        var warn: Warn { { [self] in self.messages.append($0) } }
    }

    private func ranking(_ result: FrameResult, file: StaticString = #filePath, line: UInt = #line) -> [RankingEntry] {
        guard case .ranking(let entries) = result else {
            XCTFail("expected a ranking, got \(result)", file: file, line: line)
            return []
        }
        return entries
    }

    func testRanksItinerariesByKeyWithTagsAndPartialMatches() throws {
        let entries = ranking(fromFrame(try TestResources.json("fixtures/frames/itineraries.json"), product: .flight))
        XCTAssertEqual(entries, [
            RankingEntry(id: "026ea155-4bf8-498a-96f5-cd0b83e482d7~FCAI", scope: .itinerary, rank: 0,
                         matchesAllPreferences: true, tags: ["Recommended", "Non stop"]),
            RankingEntry(id: "6b18d609-4915-47b7-beef-eaec8903eb50", scope: .itinerary, rank: 1,
                         matchesAllPreferences: false, tags: ["Cheapest"]),
            RankingEntry(id: "026ea155-4bf8-498a-96f5-cd0b83e482d7~MCAI", scope: .itinerary, rank: 2,
                         matchesAllPreferences: true, tags: []),
        ])
    }

    func testIntegerLikeItineraryKeysFollowJSOrderAndWarn() throws {
        let warnings = Warnings()
        let entries = ranking(fromFrame(try TestResources.json("fixtures/frames/itineraries-integer-keys.json"),
                                        product: .flight, warn: warnings.warn))
        XCTAssertEqual(entries.map(\.id), ["3", "20"])
        XCTAssertTrue(warnings.messages.contains { $0.contains("integer-like") })
    }

    func testRanksBothLegsAndDropsAnEntryWithoutLegId() throws {
        let warnings = Warnings()
        let entries = ranking(fromFrame(try TestResources.json("fixtures/frames/select-legs.json"), product: .flight, warn: warnings.warn))
        XCTAssertEqual(entries, [
            RankingEntry(id: "MS648ECONOMY", scope: .onward, rank: 0, matchesAllPreferences: true, tags: ["Fastest"]),
            RankingEntry(id: "J9222_J9733_EE", scope: .onward, rank: 1, matchesAllPreferences: false, tags: []),
            RankingEntry(id: "MS650*Return", scope: .return, rank: 0, matchesAllPreferences: true, tags: ["Cheapest"]),
        ])
        XCTAssertTrue(warnings.messages.contains("[smart-sort] dropped an entry without an id (scope return)"))
    }

    func testRanksHotelHtByHiStringifiesNumericIdsAndDropsDuplicates() throws {
        let warnings = Warnings()
        let entries = ranking(fromFrame(try TestResources.json("fixtures/frames/hotel-ht.json"), product: .hotel, warn: warnings.warn))
        XCTAssertEqual(entries, [
            RankingEntry(id: "5190553", scope: .hotel, rank: 0, matchesAllPreferences: true, tags: ["Recommended"]),
            RankingEntry(id: "7781203", scope: .hotel, rank: 1, matchesAllPreferences: false, tags: []),
        ])
        XCTAssertTrue(warnings.messages.contains("[smart-sort] dropped a duplicate entry 5190553 (scope hotel)"))
    }

    func testReadsTopLevelDataAsHotelsOrFlightsByProduct() throws {
        let hotels = ranking(fromFrame(try TestResources.json("fixtures/frames/hotel-data-array.json"), product: .hotel))
        XCTAssertEqual(hotels.map { "\($0.scope.rawValue) \($0.id) \($0.matchesAllPreferences)" },
                       ["hotel 22824606 true", "hotel 345346103 false"])
        XCTAssertNotNil(hotels.first?.item)
        let flights = ranking(fromFrame(try TestResources.json("fixtures/frames/flight-data-array.json"), product: .flight))
        XCTAssertEqual(flights.map { "\($0.scope.rawValue) \($0.id)" }, ["itinerary pr-105-pr-422", "itinerary ek-201"])
    }

    func testPrefersItineraryIdOverIdAndPassesTheItemThrough() {
        let item: JSONValue = ["itineraryId": "it-1", "id": "row-9"]
        let entries = ranking(fromFrame(["onwardFlightList": [item]], product: .flight))
        XCTAssertEqual(entries.map(\.id), ["it-1"])
        XCTAssertEqual(entries.first?.item, item)
    }

    func testEntitiesErrorsAndAcks() throws {
        guard case .entities(let entities, _) = fromFrame(try TestResources.json("fixtures/frames/entities.json"), product: .flight) else {
            return XCTFail("expected entities")
        }
        XCTAssertFalse(entities.isEmpty)
        XCTAssertNil(entities["parameter_change_notice"])
        guard case .error = fromFrame(try TestResources.json("fixtures/frames/error.json"), product: .flight) else {
            return XCTFail("expected an error")
        }
        XCTAssertEqual(fromFrame(try TestResources.json("fixtures/frames/ack.json"), product: .flight), .ignore)
        XCTAssertEqual(fromFrame(try TestResources.json("fixtures/frames/empty-results.json"), product: .flight), .ignore)
    }

    func testExplainFramesAreCumulativeText() {
        XCTAssertEqual(fromExplainFrame(["content": "Hello"]), .text("Hello"))
        XCTAssertEqual(fromExplainFrame(["done": true]), .end)
        XCTAssertEqual(fromExplainFrame(["content": ""]), .ignore)
    }

    func testAskResponseSplitsTheNotice() {
        let json: JSONValue = ["message": ["entities": [["stops_preference": ["0"], "parameter_change_notice": "Dates cannot change"]]]]
        let (entities, notice) = fromAskResponse(json)
        XCTAssertEqual(entities, JSONObject([("stops_preference", ["0"])]))
        XCTAssertEqual(notice, "Dates cannot change")
        XCTAssertNil(fromAskResponse(["message": ["entities": [["parameter_change_notice": "  "]]]]).notice)
    }
}
