import XCTest
@testable import RiviSmartSortContract

/// The published vectors from the web suite (test/adapters/stableId.test.ts).
final class StableIdTests: XCTestCase {
    func testMatchesThePublishedVectors() {
        XCTAssertEqual(stableId("stops_preference", "0"), "stops_preference:e58f04ed")
        XCTAssertEqual(stableId("stops_preference", "1"), "stops_preference:e48f035a")
        XCTAssertEqual(stableId("preferred_airlines", "Emirates"), "preferred_airlines:7069f94d")
        XCTAssertEqual(stableId("preferred_departure_time", ["morning", "evening"]), "preferred_departure_time:2a197d8e")
        XCTAssertEqual(stableId("in_policy_only", true), "in_policy_only:c2f5a0d5")
        XCTAssertEqual(stableId("preferred_stay_location", "قرب البحر"), "preferred_stay_location:abf8b34f")
    }

    func testTreatsANumberAndItsDecimalStringAsTheSameValue() {
        XCTAssertEqual(stableId("stops_preference", 0), stableId("stops_preference", "0"))
        XCTAssertEqual(stableId("stars", 4.5), stableId("stars", "4.5"))
    }

    func testIgnoresObjectKeyOrder() {
        XCTAssertEqual(stableId("flight_budget", ["max": 500, "min": 100]), "flight_budget:6d3ecae9")
        XCTAssertEqual(stableId("flight_budget", ["min": 100, "max": 500]), "flight_budget:6d3ecae9")
    }

    func testSeparatesRuleKeysAndArrayItems() {
        XCTAssertNotEqual(stableId("a", "b"), stableId("ab", ""))
        XCTAssertNotEqual(stableId("k", ["x", "y"]), stableId("k", "x,y"))
    }
}
