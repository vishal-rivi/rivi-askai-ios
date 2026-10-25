import Foundation

/// The shared data files, synced from the web contract by `scripts/sync-contract.sh` and pinned
/// in `contract.lock.json`: chip rules, hosted strings and design tokens.
public enum BundledData {
    /// The strings version this code reads (`/i18n/smart-sort/v<rulesVersion>/`).
    public static let rulesVersion = 1

    public static let rules: ChipRules = {
        do {
            return try ChipRules(json: load("rules.json"))
        } catch {
            preconditionFailure("[rivi] bundled rules.json is invalid: \(error)")
        }
    }()

    /// The locales shipped in this build.
    public static let supportedLocales: [String] = ["ar", "en"]

    /// The bundle for a locale: exact tag, then base language, then `en`.
    public static func strings(for locale: String) -> StringsBundle {
        let tag = locale.lowercased().replacingOccurrences(of: "_", with: "-")
        let chosen = [tag, baseLanguage(tag), "en"].first(where: supportedLocales.contains) ?? "en"
        return cachedStrings(chosen)
    }

    /// `RiviI18n` for a locale with the bundled strings and optional tenant overrides.
    public static func i18n(locale: String, overrides: StringOverrides = [:]) -> RiviI18n {
        RiviI18n(locale: locale, bundle: strings(for: locale), fallback: strings(for: "en"), overrides: overrides)
    }

    /// `tokens.json`: primitive, semantic and component design tokens.
    public static let tokens: JSONValue = (try? load("tokens.json")) ?? .null

    private final class StringsCache: @unchecked Sendable {
        private let lock = NSLock()
        private var bundles: [String: StringsBundle] = [:]

        func bundle(_ locale: String, load: () throws -> StringsBundle) rethrows -> StringsBundle {
            lock.lock()
            defer { lock.unlock() }
            if let cached = bundles[locale] { return cached }
            let bundle = try load()
            bundles[locale] = bundle
            return bundle
        }
    }

    private static let stringsCache = StringsCache()

    private static func cachedStrings(_ locale: String) -> StringsBundle {
        do {
            return try stringsCache.bundle(locale) { try StringsBundle(json: load("i18n/\(locale).json")) }
        } catch {
            preconditionFailure("[rivi] bundled i18n/\(locale).json is invalid: \(error)")
        }
    }

    static func load(_ path: String) throws -> JSONValue {
        guard let root = Bundle.module.url(forResource: "smart-sort", withExtension: nil) else {
            throw ContractDecodingError("smart-sort resources are missing from the bundle")
        }
        return try JSONValue.parse(bytes: Data(contentsOf: root.appendingPathComponent(path)))
    }
}
