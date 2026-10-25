import Foundation
import XCTest

/// The contract target is pure (spec 4): no networking, clocks, timers, randomness or UI. The web
/// enforces this with a DOM-less tsconfig; here a scan of the sources does it.
final class PurityTests: XCTestCase {
    private let forbidden = [
        "URLSession", "URLRequest", "DispatchQueue", "Task.sleep", "Task {", "Date()",
        ".random(", "Random", "import SwiftUI", "import UIKit", "import Combine", "NotificationCenter", "print(",
    ]

    func testContractSourcesHaveNoSideEffects() throws {
        let root = TestResources.repositoryRoot.appendingPathComponent("Sources/RiviSmartSortContract")
        let files = try XCTUnwrap(FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil))
            .compactMap { $0 as? URL }
            .filter { $0.pathExtension == "swift" }
        XCTAssertFalse(files.isEmpty)
        for file in files {
            let source = try String(contentsOf: file, encoding: .utf8)
            for token in forbidden {
                XCTAssertFalse(source.contains(token), "\(file.lastPathComponent) uses \(token)")
            }
            // Foundation's Timer, not the contract's RiviTimer.
            let timer = try NSRegularExpression(pattern: "(?<![A-Za-z])Timer[.(]")
            XCTAssertNil(timer.firstMatch(in: source, range: NSRange(source.startIndex..., in: source)),
                         "\(file.lastPathComponent) uses Timer")
        }
    }
}
