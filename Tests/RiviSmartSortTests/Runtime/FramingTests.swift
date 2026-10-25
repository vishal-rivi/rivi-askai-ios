import Foundation
import XCTest
import RiviSmartSortContract
@testable import RiviSmartSortRuntime

/// Line framing, the replay guard and the reconnect policy, including the web's recorded SSE
/// fixtures (test/fixtures/sse).
final class FramingTests: XCTestCase {
    func testAUTF8CharacterSplitAcrossChunksSurvives() {
        var decoder = LineDecoder()
        let bytes = Array("data: {\"content\":\"مرحبا\"}\n".utf8)
        let split = bytes.firstIndex(of: 0xD8)! + 1 // inside the first Arabic letter
        XCTAssertEqual(decoder.push(Array(bytes[..<split])), [])
        let lines = decoder.push(Array(bytes[split...]))
        XCTAssertEqual(lines.count, 1)
        XCTAssertEqual(parseFrameLine(lines[0])?.json["content"], "مرحبا")
    }

    func testCRLFAndAMissingTrailingNewline() {
        var decoder = LineDecoder()
        XCTAssertEqual(decoder.push(Array("a\r\nb".utf8)), ["a"])
        XCTAssertEqual(decoder.end(), ["b"])
    }

    func testFrameLines() {
        XCTAssertEqual(parseFrameLine("data: 12{\"a\":1}")?.seq, "12")
        XCTAssertEqual(parseFrameLine("data: 12{\"a\":1}")?.payload, "{\"a\":1}")
        XCTAssertNil(parseFrameLine("data: {\"a\":1}")?.seq)
        XCTAssertNotNil(parseFrameLine("{\"bare\":true}"))
        XCTAssertNil(parseFrameLine(": keepalive"))
        XCTAssertNil(parseFrameLine("event: message"))
        XCTAssertNil(parseFrameLine("retry: 1000"))
        XCTAssertNil(parseFrameLine("data: not json"))
        XCTAssertNil(parseFrameLine(""))
    }

    func testReplayGuardDropsOnlySequencedRepeats() throws {
        var replays = ReplayGuard(cap: 2)
        let one = try XCTUnwrap(parseFrameLine("data: 1{\"a\":1}"))
        let bare = try XCTUnwrap(parseFrameLine("data: {\"a\":1}"))
        XCTAssertFalse(replays.isReplay(one))
        XCTAssertTrue(replays.isReplay(one))
        XCTAssertFalse(replays.isReplay(bare))
        XCTAssertFalse(replays.isReplay(bare))
        XCTAssertFalse(replays.isReplay(try XCTUnwrap(parseFrameLine("data: 2{\"a\":1}"))))
        XCTAssertFalse(replays.isReplay(try XCTUnwrap(parseFrameLine("data: 3{\"a\":1}"))))
        XCTAssertFalse(replays.isReplay(one), "the oldest key was evicted past the cap")
    }

    func testDjb2MatchesTheWeb() {
        // JS: let h = 5381; for (c of s) h = ((h << 5) + h + c.charCodeAt(0)) | 0; (h >>> 0).toString(36)
        XCTAssertEqual(hashPayload(""), "45h")
        XCTAssertEqual(hashPayload("a"), "3t3a")
        XCTAssertEqual(hashPayload("رتّب"), hashPayload("رتّب"))
    }

    func testBackoffIsExponentialCappedAndJittered() {
        XCTAssertEqual((1...7).map { Reconnect.backoffDelay(failures: $0, random: { 0.5 }) },
                       [1000, 2000, 4000, 8000, 16000, 30000, 30000])
        XCTAssertEqual(Reconnect.backoffDelay(failures: 1, random: { 0 }), 800)
        XCTAssertEqual(Reconnect.backoffDelay(failures: 1, random: { 0.999999 }), 1200)
        var budget = FailureBudget()
        XCTAssertEqual((1...5).map { _ in budget.fail() }, [false, false, false, false, true])
    }

    /// Every recorded SSE fixture yields exactly its expected frames, whatever the chunking.
    func testRecordedSSEFixtures() throws {
        for name in ["split-utf8", "no-trailing-newline", "seq-prefix", "single-newline-framing", "hotel-datalist"] {
            let fixture = try TestResources.json("fixtures/sse/\(name).json")
            let expected = try XCTUnwrap(fixture["frames"]?.arrayValue, name)
            var frames: [JSONValue] = []
            var replays = ReplayGuard()
            for connection in fixture["connections"]?.arrayValue ?? [] {
                var decoder = LineDecoder()
                // `splitAt` lists byte offsets where the recording was chunked.
                let bytes = Array((connection["text"]?.stringValue ?? "").utf8)
                var cuts = (connection["splitAt"]?.arrayValue ?? []).compactMap { $0.numberValue.map { Int($0) } }
                cuts = [0] + cuts.filter { $0 > 0 && $0 < bytes.count } + [bytes.count]
                let chunks = zip(cuts, cuts.dropFirst()).map { Array(bytes[$0..<$1]) }
                var lines: [String] = []
                for chunk in chunks { lines += decoder.push(chunk) }
                lines += decoder.end()
                for line in lines {
                    if let frame = parseFrameLine(line), !replays.isReplay(frame) { frames.append(frame.json) }
                }
            }
            XCTAssertEqual(frames, expected, name)
        }
    }
}

final class RiviDateTests: XCTestCase {
    /// The gateway parses `%Y-%m-%dT%H:%M:%S.%fZ`: milliseconds and a Z are required.
    func testFormatsWithMillisecondsInUTC() {
        let date = Date(timeIntervalSince1970: 1_791_970_278.5) // 2026-10-14T09:31:18.500Z
        XCTAssertEqual(RiviDate.string(from: date), "2026-10-14T09:31:18.500Z")
        XCTAssertEqual(RiviDate.string(from: Date(timeIntervalSince1970: 0)), "1970-01-01T00:00:00.000Z")
    }
}
