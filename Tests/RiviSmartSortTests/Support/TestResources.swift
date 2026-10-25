import Foundation
import RiviSmartSortContract

enum TestResources {
    static var root: URL {
        Bundle.module.url(forResource: "TestData", withExtension: nil)!
    }

    static func data(_ path: String) throws -> Data {
        try Data(contentsOf: root.appendingPathComponent(path))
    }

    static func json(_ path: String) throws -> JSONValue {
        try JSONValue.parse(bytes: data(path))
    }

    /// The repository root, for checks over the source tree.
    static var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // Support
            .deletingLastPathComponent() // RiviSmartSortTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent()
    }

    static let corpus: ConformanceCorpus = {
        do {
            return try ConformanceCorpus(json: json("contract/cases.json"))
        } catch {
            fatalError("cases.json does not decode: \(error)")
        }
    }()

    static let en = BundledData.i18n(locale: "en")
    static let ar = BundledData.i18n(locale: "ar")
}
