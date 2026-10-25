// Tiered string resolution (spec 7.5; web: src/i18n/resolve.ts).

/// One locale's hosted strings: `{ rulesVersion, locale, messages }`.
public struct StringsBundle: Sendable, Equatable {
    public var rulesVersion: Int
    public var locale: String
    public var messages: [String: String]

    public init(rulesVersion: Int, locale: String, messages: [String: String]) {
        self.rulesVersion = rulesVersion
        self.locale = locale
        self.messages = messages
    }

    public init(json: JSONValue) throws {
        guard let o = json.objectValue, let version = o["rulesVersion"]?.numberValue,
              let locale = o["locale"]?.stringValue, let messages = o["messages"]?.objectValue else {
            throw ContractDecodingError("not a strings bundle")
        }
        var out: [String: String] = [:]
        for (key, value) in messages {
            guard let text = value.stringValue else { throw ContractDecodingError("message \(key) is not a string") }
            out[key] = text
        }
        self.init(rulesVersion: Int(version), locale: locale, messages: out)
    }
}

/// Tenant string overrides: `[locale: [key: message]]`.
public typealias StringOverrides = [String: [String: String]]

public struct RiviI18n: Sendable {
    private struct Tier: Sendable {
        var locale: String
        var messages: [String: String]?
    }

    public let locale: String
    public let direction: LayoutDirection
    private let tiers: [Tier]

    /// Tenant overrides for the locale (exact tag, then base language) → the locale's bundle →
    /// the `en` bundle → the key itself. Each tier formats with its own locale, so an English
    /// fallback message never meets Arabic plural rules.
    public init(locale: String, bundle: StringsBundle, fallback: StringsBundle, overrides: StringOverrides = [:]) {
        let base = baseLanguage(locale)
        self.locale = locale
        direction = directionOf(locale)
        tiers = [
            Tier(locale: locale, messages: overrides[locale]),
            Tier(locale: locale, messages: base == locale ? nil : overrides[base]),
            Tier(locale: locale, messages: bundle.messages),
            Tier(locale: fallback.locale, messages: fallback.messages),
        ]
    }

    /// Never throws: a message that fails to format falls through to the next tier.
    public func t(_ key: String, _ values: [String: MessageArg] = [:]) -> String {
        for tier in tiers {
            guard let message = tier.messages?[key] else { continue }
            if let text = try? formatMessage(message, locale: tier.locale, values: values) { return text }
        }
        return key
    }

    public func list(_ items: [String]) -> String {
        formatList(items, locale: locale)
    }
}
