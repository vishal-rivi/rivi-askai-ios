// CLDR plural and list rules for the shipped locales. Foundation exposes neither plural categories
// nor the `unit` list style, and `ListFormatter` adds "and", unlike the web's
// `Intl.ListFormat(type: 'unit')`. A new locale adds its rules here.

/// The base language of a locale tag: `ar-SA` and `ar_SA` → `ar`.
public func baseLanguage(_ locale: String) -> String {
    locale.split(whereSeparator: { $0 == "-" || $0 == "_" }).first.map(String.init)?.lowercased() ?? ""
}

private let rtlLanguages: Set<String> = ["ar", "fa", "he", "ur", "ps", "sd", "ug", "yi", "dv", "ckb"]

public enum LayoutDirection: String, Sendable {
    case ltr, rtl
}

public func directionOf(_ locale: String) -> LayoutDirection {
    rtlLanguages.contains(baseLanguage(locale)) ? .rtl : .ltr
}

/// The CLDR cardinal plural category of `n` in `locale`.
public func pluralCategory(_ n: Double, locale: String) -> PluralCategory {
    let absolute = abs(n)
    let integral = absolute.rounded() == absolute
    switch baseLanguage(locale) {
    case "ar":
        guard integral else { return .other }
        let mod100 = Int(absolute.truncatingRemainder(dividingBy: 100))
        if absolute == 0 { return .zero }
        if absolute == 1 { return .one }
        if absolute == 2 { return .two }
        if (3...10).contains(mod100) { return .few }
        if (11...99).contains(mod100) { return .many }
        return .other
    default:
        // English rules: one for the integer 1 with no visible fraction.
        return integral && absolute == 1 ? .one : .other
    }
}

/// `Intl.ListFormat(locale, { type: 'unit', style: 'long' })`.
public func formatList(_ items: [String], locale: String) -> String {
    let joiner: String
    switch baseLanguage(locale) {
    case "ar": joiner = " و"
    default: joiner = ", "
    }
    return items.joined(separator: joiner)
}
