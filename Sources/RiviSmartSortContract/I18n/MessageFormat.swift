// The ICU MessageFormat subset of spec 7.3: `{name}` placeholders and at most one `plural` per
// message (CLDR categories and `=N`), with `#` for the number. No select, no selectordinal, no
// skeletons. The web formats with intl-messageformat; this is the same subset, by hand, because
// Foundation has no public MessageFormat.

public enum MessageArg: Sendable, Equatable, ExpressibleByStringLiteral, ExpressibleByIntegerLiteral {
    case string(String)
    case number(Double)

    public init(stringLiteral value: String) { self = .string(value) }
    public init(integerLiteral value: Int) { self = .number(Double(value)) }
}

public struct MessageFormatError: Error, Sendable, CustomStringConvertible {
    public let description: String
}

indirect enum MessagePart: Sendable {
    case text(String)
    case argument(String)
    case pound
    case plural(name: String, exact: [(Double, [MessagePart])], categories: [(PluralCategory, [MessagePart])])
}

public enum PluralCategory: String, Sendable, CaseIterable {
    case zero, one, two, few, many, other
}

/// Parses a message in the subset. Throws on anything outside it.
func parseMessage(_ message: String) throws -> [MessagePart] {
    var parser = MessageParser(scalars: Array(message.unicodeScalars))
    let parts = try parser.parseParts(inPlural: false)
    guard parser.atEnd else { throw MessageFormatError(description: "unbalanced }") }
    return parts
}

/// Formats one message in `locale`. Throws when a value is missing or the message is invalid,
/// so the resolver can fall through to the next tier.
public func formatMessage(_ message: String, locale: String, values: [String: MessageArg] = [:]) throws -> String {
    try render(parseMessage(message), locale: locale, values: values, pound: nil)
}

/// The subset rule the build validator enforces: placeholders and at most one plural.
public func validateMessage(_ message: String) throws {
    let parts = try parseMessage(message)
    let plurals = parts.filter { if case .plural = $0 { return true } else { return false } }
    if plurals.count > 1 { throw MessageFormatError(description: "more than one plural") }
}

private func render(_ parts: [MessagePart], locale: String, values: [String: MessageArg], pound: Double?) throws -> String {
    var out = ""
    for part in parts {
        switch part {
        case .text(let text):
            out += text
        case .pound:
            if let pound { out += formatNumber(pound) } else { out += "#" }
        case .argument(let name):
            guard let value = values[name] else { throw MessageFormatError(description: "missing value {\(name)}") }
            switch value {
            case .string(let text): out += text
            case .number(let number): out += formatNumber(number)
            }
        case let .plural(name, exact, categories):
            guard let value = values[name] else { throw MessageFormatError(description: "missing value {\(name)}") }
            let number: Double
            switch value {
            case .number(let n): number = n
            case .string(let text):
                guard let n = Double(text.trimmingWhitespace()) else { throw MessageFormatError(description: "{\(name)} is not a number") }
                number = n
            }
            let branch: [MessagePart]
            if let match = exact.first(where: { $0.0 == number }) {
                branch = match.1
            } else {
                let category = pluralCategory(number, locale: locale)
                guard let match = categories.first(where: { $0.0 == category }) ?? categories.first(where: { $0.0 == .other }) else {
                    throw MessageFormatError(description: "plural without other")
                }
                branch = match.1
            }
            out += try render(branch, locale: locale, values: values, pound: number)
        }
    }
    return out
}

/// `#` and numeric arguments: Western digits (spec: `latn`), grouping by thousands, at most three
/// fraction digits, as `Intl.NumberFormat` with default options.
func formatNumber(_ value: Double) -> String {
    guard value.isFinite else { return jsNumberString(value) }
    let negative = value < 0
    let rounded = (abs(value) * 1000).rounded() / 1000
    let integer = rounded.rounded(.down)
    var fraction = ""
    let rest = rounded - integer
    if rest > 0 {
        let digits = jsNumberString((rest * 1000).rounded() / 1000)
        fraction = String(digits.drop(while: { $0 != "." }))
    }
    let integerDigits = Array(jsNumberString(integer))
    var grouped = ""
    for (offset, char) in integerDigits.enumerated() {
        if offset > 0 && (integerDigits.count - offset) % 3 == 0 { grouped.append(",") }
        grouped.append(char)
    }
    return (negative ? "-" : "") + grouped + fraction
}

private struct MessageParser {
    let scalars: [Unicode.Scalar]
    var index = 0

    var atEnd: Bool { index >= scalars.count }

    func fail(_ reason: String) -> MessageFormatError {
        MessageFormatError(description: "\(reason) at \(index)")
    }

    mutating func parseParts(inPlural: Bool) throws -> [MessagePart] {
        var parts: [MessagePart] = []
        var text = String.UnicodeScalarView()
        func flush() {
            if !text.isEmpty { parts.append(.text(String(text))); text = String.UnicodeScalarView() }
        }
        while index < scalars.count {
            let scalar = scalars[index]
            switch scalar {
            case "'":
                // ICU apostrophe quoting: '' is a literal apostrophe; ' before a syntax character
                // starts a quoted run up to the next lone apostrophe.
                if index + 1 < scalars.count, scalars[index + 1] == "'" {
                    text.append("'")
                    index += 2
                } else if index + 1 < scalars.count, ["{", "}", "#"].contains(scalars[index + 1]) {
                    index += 1
                    while index < scalars.count {
                        if scalars[index] == "'" {
                            if index + 1 < scalars.count, scalars[index + 1] == "'" {
                                text.append("'")
                                index += 2
                                continue
                            }
                            index += 1
                            break
                        }
                        text.append(scalars[index])
                        index += 1
                    }
                } else {
                    text.append("'")
                    index += 1
                }
            case "{":
                flush()
                index += 1
                parts.append(try parseArgument())
            case "}":
                flush()
                return parts
            case "#" where inPlural:
                flush()
                parts.append(.pound)
                index += 1
            default:
                text.append(scalar)
                index += 1
            }
        }
        flush()
        return parts
    }

    mutating func skipSpace() {
        while index < scalars.count, scalars[index].properties.isWhitespace { index += 1 }
    }

    mutating func identifier() throws -> String {
        skipSpace()
        var name = String.UnicodeScalarView()
        while index < scalars.count, !["{", "}", ",", "#", "'"].contains(scalars[index]),
              !scalars[index].properties.isWhitespace {
            name.append(scalars[index])
            index += 1
        }
        guard !name.isEmpty else { throw fail("expected a name") }
        return String(name)
    }

    mutating func parseArgument() throws -> MessagePart {
        let name = try identifier()
        skipSpace()
        guard index < scalars.count else { throw fail("unterminated argument") }
        if scalars[index] == "}" {
            index += 1
            return .argument(name)
        }
        guard scalars[index] == "," else { throw fail("expected , or }") }
        index += 1
        let type = try identifier()
        guard type == "plural" else { throw fail("unsupported argument type \(type)") }
        skipSpace()
        guard index < scalars.count, scalars[index] == "," else { throw fail("expected ,") }
        index += 1
        var exact: [(Double, [MessagePart])] = []
        var categories: [(PluralCategory, [MessagePart])] = []
        while true {
            skipSpace()
            guard index < scalars.count else { throw fail("unterminated plural") }
            if scalars[index] == "}" { index += 1; break }
            let selector = try identifier()
            skipSpace()
            guard index < scalars.count, scalars[index] == "{" else { throw fail("expected {") }
            index += 1
            let branch = try parseParts(inPlural: true)
            guard index < scalars.count, scalars[index] == "}" else { throw fail("unterminated branch") }
            index += 1
            if selector.hasPrefix("=") {
                guard let value = Double(selector.dropFirst()) else { throw fail("bad selector \(selector)") }
                exact.append((value, branch))
            } else if let category = PluralCategory(rawValue: selector) {
                categories.append((category, branch))
            } else {
                throw fail("unsupported selector \(selector)")
            }
        }
        guard categories.contains(where: { $0.0 == .other }) else { throw fail("plural without other") }
        return .plural(name: name, exact: exact, categories: categories)
    }
}
