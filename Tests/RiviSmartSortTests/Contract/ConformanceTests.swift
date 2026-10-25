import CryptoKit
import Foundation
import XCTest
@testable import RiviSmartSortContract

/// CONTRACT.md "Running the corpus": every case passes, every rule 1–17 is covered, and no Fetch
/// asks for anything but ask, sortBest or explain.
final class ConformanceTests: XCTestCase {
    private let corpus = TestResources.corpus

    func testImplementsContractVersion2() {
        // A bump means an existing case changed meaning: review the diff before raising this.
        XCTAssertEqual(corpus.contractVersion, 2)
    }

    func testEveryCasePasses() {
        XCTAssertFalse(corpus.cases.isEmpty)
        for c in corpus.cases {
            let (state, commands) = runCase(c)
            let mismatches = verify(c, state: state, commands: commands)
            XCTAssertTrue(mismatches.isEmpty, "\(c.name):\n  " + mismatches.map(\.description).joined(separator: "\n  "))
        }
    }

    func testEveryRuleTheContractOwnsIsCovered() {
        // Rule 18 (spotlight once per device, info tooltip always) is component behaviour.
        let covered = Set(corpus.cases.flatMap(\.rules))
        for rule in 1...17 {
            XCTAssertTrue(covered.contains(rule), "rule \(rule) has no case")
        }
    }

    func testCaseNamesAreUnique() {
        let names = corpus.cases.map(\.name)
        XCTAssertEqual(Set(names).count, names.count)
    }

    func testNeverFetchesAnythingButAskSortBestAndExplain() {
        for c in corpus.cases {
            for case let .fetch(_, request) in runCase(c).commands {
                XCTAssertTrue(["ask", "sortBest", "explain"].contains(request.kindName), c.name)
            }
        }
    }

    /// The bundled copies are the files pinned in contract.lock.json (scripts/sync-contract.sh).
    func testBundledContractFilesMatchTheLock() throws {
        let lockURL = TestResources.repositoryRoot.appendingPathComponent("contract.lock.json")
        let lock = try JSONValue.parse(bytes: Data(contentsOf: lockURL))
        let files = try XCTUnwrap(lock["files"]?.objectValue)
        XCTAssertFalse(files.isEmpty)
        for (path, hash) in files {
            let data = try Data(contentsOf: TestResources.repositoryRoot.appendingPathComponent(path))
            let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
            XCTAssertEqual(digest, hash.stringValue, "\(path) differs from contract.lock.json: run scripts/sync-contract.sh")
        }
        let bundled = try TestResources.data("contract/cases.json")
        let source = try Data(contentsOf: TestResources.repositoryRoot
            .appendingPathComponent("Tests/RiviSmartSortTests/TestData/contract/cases.json"))
        XCTAssertEqual(bundled, source)
    }

    func testEpochGuardDropsLateResults() {
        var state = initialState()
        state = reconcile(state, .setSearch(.hotel(HotelSearch(
            searchId: "h1", destination: "Dubai", checkin: "2026-11-01", checkout: "2026-11-03",
            rooms: 1, pax: .init(adults: 2)
        )))).state
        let staleEpoch = state.epoch - 1
        for input: Input in [
            .askResponse(epoch: staleEpoch, entities: JSONObject([("star_rating", [5])]), chips: [], notice: nil),
            .rankingFrame(epoch: staleEpoch, ranking: []),
            .explainFrame(epoch: staleEpoch, text: "late"),
            .explainEnd(epoch: staleEpoch),
            .failed(epoch: staleEpoch, error: RiviError(kind: .network, message: "x", retryable: true)),
            .timerFired(timer: .settle, epoch: staleEpoch),
        ] {
            let (next, commands) = reconcile(state, input)
            XCTAssertEqual(next, state, "\(input)")
            XCTAssertTrue(commands.isEmpty, "\(input)")
        }
    }
}
