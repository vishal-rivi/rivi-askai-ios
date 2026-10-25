import XCTest
@testable import RiviSmartSortContract

final class JSONTests: XCTestCase {
    func testNumbersFormatLikeJavaScript() {
        let cases: [(Double, String)] = [
            (1, "1"), (4.5, "4.5"), (0.1, "0.1"), (100, "100"), (-3, "-3"), (0.00001, "0.00001"),
            (1e-7, "1e-7"), (1e21, "1e+21"), (123456789012, "123456789012"), (1.5e300, "1.5e+300"), (-0.0, "0"),
        ]
        for (value, expected) in cases { XCTAssertEqual(jsNumberString(value), expected, "\(value)") }
    }

    func testParsingKeepsOrderAndRoundTrips() throws {
        let text = #"{"b":1,"a":[true,null,"x\né😀"],"c":{"z":0,"y":-2.5}}"#
        let value = try JSONValue.parse(text)
        XCTAssertEqual(value.objectValue?.keys, ["b", "a", "c"])
        XCTAssertEqual(value.serialized(), #"{"b":1,"a":[true,null,"x\né😀"],"c":{"z":0,"y":-2.5}}"#)
    }

    func testObjectsEnumerateInJSOrder() throws {
        let value = try JSONValue.parse(#"{"b":1,"20":2,"a":3,"3":4,"07":5}"#)
        XCTAssertEqual(value.objectValue?.jsKeys, ["3", "20", "b", "a", "07"])
        XCTAssertEqual(value.serialized(), #"{"3":4,"20":2,"b":1,"a":3,"07":5}"#)
    }

    func testEqualityIgnoresKeyOrder() throws {
        XCTAssertEqual(try JSONValue.parse(#"{"a":1,"b":2}"#), try JSONValue.parse(#"{"b":2,"a":1}"#))
        XCTAssertNotEqual(try JSONValue.parse("[1,2]"), try JSONValue.parse("[2,1]"))
    }

    func testRejectsInvalidJSON() {
        for text in ["{", "[1,]", "{\"a\" 1}", "tru", "\"unterminated", "1 2"] {
            XCTAssertThrowsError(try JSONValue.parse(text), text)
        }
    }
}

final class MessageFormatTests: XCTestCase {
    func testPlaceholdersAndPlurals() throws {
        XCTAssertEqual(try formatMessage("Near {value}", locale: "en", values: ["value": "the beach"]), "Near the beach")
        let stops = "{n, plural, =0 {Non-stop} one {# stop} other {# stops}}"
        XCTAssertEqual(try formatMessage(stops, locale: "en", values: ["n": 0]), "Non-stop")
        XCTAssertEqual(try formatMessage(stops, locale: "en", values: ["n": 1]), "1 stop")
        XCTAssertEqual(try formatMessage(stops, locale: "en", values: ["n": 1200]), "1,200 stops")
    }

    func testArabicCategories() {
        XCTAssertEqual([0, 1, 2, 3, 10, 11, 99, 100, 102, 103].map { pluralCategory(Double($0), locale: "ar") },
                       [.zero, .one, .two, .few, .few, .many, .many, .other, .other, .few])
        XCTAssertEqual(pluralCategory(1.5, locale: "ar"), .other)
        XCTAssertEqual(pluralCategory(1, locale: "en-GB"), .one)
    }

    func testMissingValuesThrowAndTheResolverFallsThrough() {
        XCTAssertThrowsError(try formatMessage("Hi {name}", locale: "en"))
        let i18n = BundledData.i18n(locale: "ar", overrides: ["ar": ["sortInput.submit": "اسأل {broken"], "en": ["sortInput.submit": "Go"]])
        XCTAssertEqual(i18n.t("sortInput.submit"), BundledData.strings(for: "ar").messages["sortInput.submit"])
        XCTAssertEqual(BundledData.i18n(locale: "en", overrides: ["en": ["sortInput.submit": "Go"]]).t("sortInput.submit"), "Go")
        XCTAssertEqual(i18n.t("no.such.key"), "no.such.key")
    }

    func testQuotingAndDirection() throws {
        XCTAssertEqual(try formatMessage("It''s '{literal}'", locale: "en"), "It's {literal}")
        XCTAssertEqual(directionOf("ar-SA"), .rtl)
        XCTAssertEqual(directionOf("en"), .ltr)
        XCTAssertEqual(BundledData.strings(for: "ar_SA").locale, "ar")
        XCTAssertEqual(BundledData.strings(for: "fr").locale, "en")
    }

    /// Spec 7.3: every hosted message stays inside the subset, and every key the rules use exists
    /// in every bundled locale.
    func testBundledStringsStayInsideTheSubset() throws {
        for locale in BundledData.supportedLocales {
            let bundle = BundledData.strings(for: locale)
            XCTAssertEqual(bundle.rulesVersion, BundledData.rulesVersion)
            for (key, message) in bundle.messages {
                XCTAssertNoThrow(try validateMessage(message), "\(locale) \(key)")
            }
            for key in BundledData.rules.labelKeys {
                XCTAssertNotNil(bundle.messages[key], "\(locale) is missing \(key)")
            }
        }
    }
}
