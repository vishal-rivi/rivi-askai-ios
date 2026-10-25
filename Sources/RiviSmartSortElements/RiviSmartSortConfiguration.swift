import Foundation

/// Shared configuration for the Smart Sort elements.
public class RiviSmartSortConfiguration {
    /// Shared instance
    public static let shared = RiviSmartSortConfiguration()

    /// Language for the elements' built-in strings and layout direction. `RiviSmartSort` sets it
    /// from its locale.
    public var language: Language = .english

    private init() {}
}
