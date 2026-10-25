import XCTest
@testable import RiviSmartSortContract

/// The web snapshots (test/adapters/chips.test.ts), so a chip reads and is identified the same
/// on every platform.
final class ChipsTests: XCTestCase {
    private func entities(_ path: String) throws -> Entities {
        try XCTUnwrap(TestResources.json(path).objectValue)
    }

    private func pairs(_ chips: [Chip]) -> [[String]] { chips.map { [$0.id, $0.label] } }

    func testProjectsEveryFlightRuleInEnglish() throws {
        let chips = toChips(try entities("fixtures/entities/flight-all.json"), product: .flight, i18n: TestResources.en)
        XCTAssertEqual(chips, [
            Chip(id: "preferred_airlines:7069f94d", label: "Emirates", group: "airline"),
            Chip(id: "preferred_airlines:c2f04dd6", label: "Qatar Airways", group: "airline"),
            Chip(id: "not_preferred_airlines:5f56050b", label: "Not preferred airline: Ryanair", group: "airline"),
            Chip(id: "trip_duration:736a3454", label: "Trip duration: under 10 hours", group: "duration"),
            Chip(id: "preferred_departure_time:400bc3c6", label: "Departure: morning, afternoon", group: "time"),
            Chip(id: "preferred_arrival_time:b22ce5f8", label: "Arrival: before noon", group: "time"),
            Chip(id: "preferred_return_time:45d5c200", label: "Return: evening", group: "time"),
            Chip(id: "stops_preference:e58f04ed", label: "Non-stop", group: "stops"),
            Chip(id: "stops_preference:e48f035a", label: "1 stop", group: "stops"),
            Chip(id: "stops_preference:e38f01c7", label: "2 stops", group: "stops"),
            Chip(id: "stops_preference:e28f0034", label: "3 stops", group: "stops"),
            Chip(id: "preferred_flight_duration:0542ed54", label: "Flight duration: under 8 hours", group: "duration"),
            Chip(id: "preferred_layover_airport_or_city:515beb0e", label: "Layover at DXB", group: "layover"),
            Chip(id: "not_preferred_layover_airport:542241ee", label: "Not Preferred Layover: LHR", group: "layover"),
            Chip(id: "preferred_layover_duration:f356d482", label: "Layover duration: under 2 hours", group: "layover"),
            Chip(id: "checked_baggage_weight_preference:e4fa1970", label: "Baggage weight: 23kg", group: "baggage"),
            Chip(id: "flight_budget:75bca5c1", label: "Budget: 500", group: "budget"),
            Chip(id: "in_policy_only:c2f5a0d5", label: "In policy only", group: "policy"),
            Chip(id: "flight_amenities:b3951de9", label: "WiFi", group: "amenities"),
            Chip(id: "preferred_departure_airport:2e564a7b", label: "Departure Airport: JFK, EWR", group: "airport"),
            Chip(id: "preferred_arrival_airport:38e69dc1", label: "Arrival Airport: DXB", group: "airport"),
            Chip(id: "not_preferred_departure_airport:3f2e7b54", label: "Not Preferred Departure Airport: LGA", group: "airport"),
            Chip(id: "not_preferred_arrival_airport:5077f33e", label: "Not Preferred Arrival Airport: SHJ", group: "airport"),
            Chip(id: "other_flight_preferences:049b4b5f", label: "window seat", group: "other"),
        ])
    }

    func testProjectsEveryFlightRuleInArabicWithTheDual() throws {
        let chips = toChips(try entities("fixtures/entities/flight-all.json"), product: .flight, i18n: TestResources.ar)
        XCTAssertEqual(pairs(chips), [
            ["preferred_airlines:7069f94d", "Emirates"],
            ["preferred_airlines:c2f04dd6", "Qatar Airways"],
            ["not_preferred_airlines:5f56050b", "شركة الطيران غير المفضلة: Ryanair"],
            ["trip_duration:736a3454", "مدة الرحلة: under 10 hours"],
            ["preferred_departure_time:400bc3c6", "المغادرة: morning وafternoon"],
            ["preferred_arrival_time:b22ce5f8", "الوصول: before noon"],
            ["preferred_return_time:45d5c200", "العودة: evening"],
            ["stops_preference:e58f04ed", "مباشر"],
            ["stops_preference:e48f035a", "محطة واحدة"],
            ["stops_preference:e38f01c7", "محطتان"],
            ["stops_preference:e28f0034", "3 محطات"],
            ["preferred_flight_duration:0542ed54", "مدة الطيران: under 8 hours"],
            ["preferred_layover_airport_or_city:515beb0e", "مرور في: DXB"],
            ["not_preferred_layover_airport:542241ee", "توقف غير مفضل: LHR"],
            ["preferred_layover_duration:f356d482", "مدة المرور: under 2 hours"],
            ["checked_baggage_weight_preference:e4fa1970", "وزن الحقيبة: 23kg"],
            ["flight_budget:75bca5c1", "الميزانية: 500"],
            ["in_policy_only:c2f5a0d5", "ضمن السياسة فقط"],
            ["flight_amenities:b3951de9", "WiFi"],
            ["preferred_departure_airport:2e564a7b", "مطار المغادرة: JFK وEWR"],
            ["preferred_arrival_airport:38e69dc1", "مطار الوصول: DXB"],
            ["not_preferred_departure_airport:3f2e7b54", "مطار المغادرة غير مفضل: LGA"],
            ["not_preferred_arrival_airport:5077f33e", "مطار الوصول غير مفضل: SHJ"],
            ["other_flight_preferences:049b4b5f", "window seat"],
        ])
    }

    func testProjectsEveryHotelRuleInEnglishAndIgnoresRecommendedHotelNames() throws {
        let chips = toChips(try entities("fixtures/entities/hotel-all.json"), product: .hotel, i18n: TestResources.en)
        XCTAssertEqual(chips, [
            Chip(id: "star_rating:a8ffd11c", label: "No Rating", group: "stars"),
            Chip(id: "star_rating:a4ffcad0", label: "4 star", group: "stars"),
            Chip(id: "star_rating:a5ffcc63", label: "5 star", group: "stars"),
            Chip(id: "preferred_user_rating:e7e69814", label: "User Ratings: 8+", group: "rating"),
            Chip(id: "stay_budget:0b05ba49", label: "Budget: 200 USD", group: "budget"),
            Chip(id: "amenities:3984c1f7", label: "pool", group: "amenities"),
            Chip(id: "amenities:aec53ed9", label: "spa", group: "amenities"),
            Chip(id: "accommodation_type:f3aecc90", label: "Accommodation Type: resort", group: "accommodation"),
            Chip(id: "preferred_room_type:fd8a76ae", label: "suite", group: "room"),
            Chip(id: "preferred_hotel_names:26de2f39", label: "Atlantis", group: "hotel"),
            Chip(id: "preferred_stay_location:93974c4f", label: "Near the beach", group: "location"),
            Chip(id: "preferred_hotel_brand:d2a11244", label: "Marriott", group: "brand"),
            Chip(id: "other_stay_preferences:cc6acc09", label: "quiet", group: "other"),
            Chip(id: "in_policy_only:c2f5a0d5", label: "In policy only", group: "policy"),
        ])
    }

    func testProjectsEveryHotelRuleInArabic() throws {
        let chips = toChips(try entities("fixtures/entities/hotel-all.json"), product: .hotel, i18n: TestResources.ar)
        XCTAssertEqual(pairs(chips), [
            ["star_rating:a8ffd11c", "بدون تقييم"],
            ["star_rating:a4ffcad0", "4 نجوم"],
            ["star_rating:a5ffcc63", "5 نجوم"],
            ["preferred_user_rating:e7e69814", "تقييم المستخدم: 8+"],
            ["stay_budget:0b05ba49", "الميزانية: 200 USD"],
            ["amenities:3984c1f7", "pool"],
            ["amenities:aec53ed9", "spa"],
            ["accommodation_type:f3aecc90", "نوع الإقامة: resort"],
            ["preferred_room_type:fd8a76ae", "suite"],
            ["preferred_hotel_names:26de2f39", "Atlantis"],
            ["preferred_stay_location:93974c4f", "قريب من: the beach"],
            ["preferred_hotel_brand:d2a11244", "Marriott"],
            ["other_stay_preferences:cc6acc09", "quiet"],
            ["in_policy_only:c2f5a0d5", "ضمن السياسة فقط"],
        ])
    }

    func testIdsAndGroupsAreIdenticalInEveryLocale() throws {
        for (path, product) in [("fixtures/entities/flight-all.json", Product.flight), ("fixtures/entities/hotel-all.json", .hotel)] {
            let record = try entities(path)
            let strip = { (chips: [Chip]) in chips.map { [$0.id, $0.group] } }
            XCTAssertEqual(strip(toChips(record, product: product, i18n: TestResources.ar)),
                           strip(toChips(record, product: product, i18n: TestResources.en)))
        }
    }

    func testArabicDualFewAndManyFormsWithWesternDigits() {
        XCTAssertEqual(toChips(JSONObject([("stops_preference", ["2"])]), product: .flight, i18n: TestResources.ar).map(\.label), ["محطتان"])
        XCTAssertEqual(toChips(JSONObject([("star_rating", ["2", "3", "11"])]), product: .hotel, i18n: TestResources.ar).map(\.label),
                       ["نجمتان", "3 نجوم", "11 نجمة"])
    }

    func testUsesTheHotelRulesForHotelsOnly() {
        XCTAssertEqual(toChips(JSONObject([("star_rating", [5])]), product: .hotel, i18n: TestResources.en).map(\.label), ["5 star"])
        XCTAssertEqual(toChips(JSONObject([("star_rating", [5])]), product: .flight, i18n: TestResources.en), [])
    }

    func testProducesNothingForEmptyValuesAndSkipsEmptyListItems() {
        let empty = JSONObject([
            ("preferred_airlines", []), ("trip_duration", .null), ("flight_budget", ""), ("preferred_departure_time", []),
        ])
        XCTAssertEqual(toChips(empty, product: .flight, i18n: TestResources.en), [])
        XCTAssertEqual(
            toChips(JSONObject([("other_flight_preferences", [.null, "", " ", "aisle"])]), product: .flight, i18n: TestResources.en),
            [Chip(id: "other_flight_preferences:d8bd020e", label: "aisle", group: "other")]
        )
    }

    func testWrapsLoneValuesAndJoinsArraysForScalarRules() {
        let record = JSONObject([
            ("stops_preference", "non-stop"), ("preferred_departure_time", "morning"), ("trip_duration", ["5h", "7h"]),
        ])
        XCTAssertEqual(toChips(record, product: .flight, i18n: TestResources.en), [
            Chip(id: "stops_preference:1cd6e469", label: "non-stop", group: "stops"),
            Chip(id: "preferred_departure_time:a17af23c", label: "Departure: morning", group: "time"),
            Chip(id: "trip_duration:894dbcfa", label: "Trip duration: 5h, 7h", group: "duration"),
        ])
    }

    func testUsesTheRawValueWhenAPluralRuleMeetsANonNumber() {
        XCTAssertEqual(toChips(JSONObject([("stops_preference", ["any", 2])]), product: .flight, i18n: TestResources.en), [
            Chip(id: "stops_preference:64e0526f", label: "any", group: "stops"),
            Chip(id: "stops_preference:e38f01c7", label: "2 stops", group: "stops"),
        ])
    }

    func testDropsObjectsNonTrueFlagsAndDuplicateLabels() {
        let record = JSONObject([
            ("flight_budget", ["min": 1]), ("in_policy_only", "yes"),
            ("other_flight_preferences", ["aisle"]), ("flight_amenities", ["aisle"]),
        ])
        XCTAssertEqual(toChips(record, product: .flight, i18n: TestResources.en).map(\.label), ["aisle"])
    }

    // MARK: - Chips added for the full entity list

    func testAvoidOvernightLayoverIsAFlag() {
        let chips = toChips(JSONObject([("avoid_overnight_layover", true)]), product: .flight, i18n: TestResources.en)
        XCTAssertEqual(chips.map(\.label), ["Avoid overnight layover"])
        XCTAssertEqual(chips.map(\.group), ["layover"])
        XCTAssertEqual(toChips(JSONObject([("avoid_overnight_layover", false)]), product: .flight, i18n: TestResources.en), [])
    }

    func testHotelExclusionsGetAChipEach() {
        let record = JSONObject([
            ("not_preferred_hotel_names", ["Hilton Garden"]),
            ("not_preferred_stay_location", ["airport", "downtown"]),
            ("not_preferred_hotel_brand", ["Ibis"]),
            ("not_preferred_amenities", ["casino"]),
            ("not_preferred_accommodation_type", ["hostel"]),
            ("not_preferred_room_type", ["shared"]),
            ("not_preferred_stay_preferences", ["noisy street"]),
        ])
        let chips = toChips(record, product: .hotel, i18n: TestResources.en)
        XCTAssertEqual(chips.map(\.label), [
            "Not preferred hotel: Hilton Garden",
            "Not preferred location: airport",
            "Not preferred location: downtown",
            "Not preferred brand: Ibis",
            "Not preferred amenity: casino",
            "Not preferred accommodation type: hostel",
            "Not preferred room type: shared",
            "Not preferred: noisy street",
        ])
        XCTAssertEqual(chips.map(\.group), ["hotel", "location", "location", "brand", "amenities", "accommodation", "room", "other"])
        // Every label has an Arabic message too.
        XCTAssertEqual(toChips(record, product: .hotel, i18n: TestResources.ar).count, chips.count)
        XCTAssertFalse(toChips(record, product: .hotel, i18n: TestResources.ar).contains { $0.label.hasPrefix("Not preferred") })
    }

    func testBudgetTakesTheRecordsCurrency() {
        let flight = toChips(JSONObject([("flight_budget", 500), ("budget_currency", "USD")]), product: .flight, i18n: TestResources.en)
        XCTAssertEqual(flight.map(\.label), ["Budget: 500 USD"])
        let hotel = toChips(JSONObject([("stay_budget", "150"), ("budget_currency", "SAR")]), product: .hotel, i18n: TestResources.en)
        XCTAssertEqual(hotel.map(\.label), ["Budget: 150 SAR"])
        // Optional, never doubled, and the currency itself is not a chip.
        XCTAssertEqual(toChips(JSONObject([("flight_budget", 500)]), product: .flight, i18n: TestResources.en).map(\.label), ["Budget: 500"])
        XCTAssertEqual(toChips(JSONObject([("stay_budget", "200 USD"), ("budget_currency", "usd")]), product: .hotel, i18n: TestResources.en).map(\.label),
                       ["Budget: 200 USD"])
        // The chip keeps its id whether or not a currency is given.
        let bare = toChips(JSONObject([("flight_budget", 500)]), product: .flight, i18n: TestResources.en)
        XCTAssertEqual(flight.map(\.id), bare.map(\.id))
    }

    func testStayLocationsGetAChipEach() {
        let chips = toChips(JSONObject([("preferred_stay_location", ["the beach", "old town"])]), product: .hotel, i18n: TestResources.en)
        XCTAssertEqual(chips.map(\.label), ["Near the beach", "Near old town"])
    }

    func testRulesCoverEveryEntityKey() {
        let flight: Set = [
            "preferred_airlines", "not_preferred_airlines", "trip_duration", "preferred_departure_time",
            "preferred_arrival_time", "preferred_return_time", "stops_preference", "preferred_flight_duration",
            "preferred_layover_airport_or_city", "not_preferred_layover_airport", "preferred_layover_duration",
            "checked_baggage_weight_preference", "flight_budget", "in_policy_only", "avoid_overnight_layover",
            "flight_amenities", "preferred_departure_airport", "preferred_arrival_airport",
            "not_preferred_departure_airport", "not_preferred_arrival_airport", "other_flight_preferences",
        ]
        let hotel: Set = [
            "star_rating", "preferred_user_rating", "stay_budget", "amenities", "accommodation_type",
            "preferred_room_type", "preferred_hotel_names", "preferred_stay_location", "preferred_hotel_brand",
            "other_stay_preferences", "in_policy_only", "not_preferred_hotel_names", "not_preferred_stay_location",
            "not_preferred_hotel_brand", "not_preferred_amenities", "not_preferred_accommodation_type",
            "not_preferred_room_type", "not_preferred_stay_preferences",
        ]
        XCTAssertEqual(Set(BundledData.rules.flight.map(\.key)), flight)
        XCTAssertEqual(Set(BundledData.rules.hotel.map(\.key)), hotel)
    }
}
