public struct JSONParseError: Error, Sendable, CustomStringConvertible {
    public let offset: Int
    public let reason: String
    public var description: String { "JSON parse error at byte \(offset): \(reason)" }
}

extension JSONValue {
    /// Parses RFC 8259 JSON, keeping object key order. A duplicate key keeps its first position
    /// and its last value, as `JSON.parse` does.
    public static func parse(_ text: String) throws -> JSONValue {
        try parse(bytes: Array(text.utf8))
    }

    public static func parse<Bytes: Collection>(bytes: Bytes) throws -> JSONValue where Bytes.Element == UInt8 {
        var parser = JSONParser(bytes: Array(bytes))
        parser.skipWhitespace()
        let value = try parser.parseValue(depth: 0)
        parser.skipWhitespace()
        guard parser.atEnd else { throw parser.error("trailing characters") }
        return value
    }

    /// Compact serialization, matching `JSON.stringify` (no whitespace, raw non-ASCII).
    public func serialized() -> String {
        var out = ""
        write(into: &out)
        return out
    }

    private func write(into out: inout String) {
        switch self {
        case .null: out += "null"
        case .bool(let value): out += value ? "true" : "false"
        case .number(let value): out += value.isFinite ? jsNumberString(value) : "null"
        case .string(let value): writeString(value, into: &out)
        case .array(let items):
            out += "["
            for (index, item) in items.enumerated() {
                if index > 0 { out += "," }
                item.write(into: &out)
            }
            out += "]"
        case .object(let object):
            out += "{"
            for (index, pair) in object.enumerated() {
                if index > 0 { out += "," }
                writeString(pair.key, into: &out)
                out += ":"
                pair.value.write(into: &out)
            }
            out += "}"
        }
    }
}

private func writeString(_ value: String, into out: inout String) {
    out += "\""
    for scalar in value.unicodeScalars {
        switch scalar {
        case "\"": out += "\\\""
        case "\\": out += "\\\\"
        case "\u{08}": out += "\\b"
        case "\u{0C}": out += "\\f"
        case "\n": out += "\\n"
        case "\r": out += "\\r"
        case "\t": out += "\\t"
        default:
            if scalar.value < 0x20 {
                let hex = String(scalar.value, radix: 16)
                out += "\\u" + String(repeating: "0", count: 4 - hex.count) + hex
            } else {
                out.unicodeScalars.append(scalar)
            }
        }
    }
    out += "\""
}

/// ECMAScript `Number::toString(10)`: the shortest round-trip digits, in decimal notation for
/// 1e-7 <= |x| < 1e21 and exponential notation otherwise. `1` → "1", `4.5` → "4.5".
public func jsNumberString(_ value: Double) -> String {
    if value == 0 { return "0" }
    if value.isNaN { return "NaN" }
    if value.isInfinite { return value < 0 ? "-Infinity" : "Infinity" }
    let negative = value < 0
    // Swift's description is also the shortest round-trip representation; only the layout differs.
    let description = String(describing: abs(value))
    var mantissa = Substring(description)
    var exponent = 0
    if let e = description.firstIndex(where: { $0 == "e" || $0 == "E" }) {
        mantissa = description[..<e]
        exponent = Int(description[description.index(after: e)...]) ?? 0
    }
    var digits = ""
    var pointIndex = mantissa.count
    for (offset, char) in mantissa.enumerated() {
        if char == "." { pointIndex = offset } else { digits.append(char) }
    }
    // Strip leading zeros (0.001 → digits "0001") and trailing zeros (100.0 → "1000").
    var n = pointIndex + exponent
    while digits.count > 1, digits.first == "0" {
        digits.removeFirst()
        n -= 1
    }
    while digits.count > 1, digits.last == "0" { digits.removeLast() }
    let k = digits.count
    var out: String
    if k <= n && n <= 21 {
        out = digits + String(repeating: "0", count: n - k)
    } else if 0 < n && n <= 21 {
        let split = digits.index(digits.startIndex, offsetBy: n)
        out = digits[..<split] + "." + digits[split...]
    } else if -6 < n && n <= 0 {
        out = "0." + String(repeating: "0", count: -n) + digits
    } else {
        let e = n - 1
        let sign = e < 0 ? "-" : "+"
        let head = digits.prefix(1)
        let tail = digits.dropFirst()
        out = head + (tail.isEmpty ? "" : "." + tail) + "e" + sign + String(abs(e))
    }
    return negative ? "-" + out : out
}

private struct JSONParser {
    let bytes: [UInt8]
    var index = 0

    var atEnd: Bool { index >= bytes.count }

    func error(_ reason: String) -> JSONParseError {
        JSONParseError(offset: index, reason: reason)
    }

    mutating func skipWhitespace() {
        while index < bytes.count {
            switch bytes[index] {
            case 0x20, 0x09, 0x0A, 0x0D: index += 1
            default: return
            }
        }
    }

    mutating func parseValue(depth: Int) throws -> JSONValue {
        guard depth < 512 else { throw error("nesting too deep") }
        guard index < bytes.count else { throw error("unexpected end") }
        switch bytes[index] {
        case UInt8(ascii: "{"): return try parseObject(depth: depth)
        case UInt8(ascii: "["): return try parseArray(depth: depth)
        case UInt8(ascii: "\""): return .string(try parseString())
        case UInt8(ascii: "t"): try expect("true"); return .bool(true)
        case UInt8(ascii: "f"): try expect("false"); return .bool(false)
        case UInt8(ascii: "n"): try expect("null"); return .null
        default: return .number(try parseNumber())
        }
    }

    mutating func expect(_ word: String) throws {
        for byte in word.utf8 {
            guard index < bytes.count, bytes[index] == byte else { throw error("expected \(word)") }
            index += 1
        }
    }

    mutating func parseObject(depth: Int) throws -> JSONValue {
        index += 1
        var object = JSONObject()
        skipWhitespace()
        if index < bytes.count, bytes[index] == UInt8(ascii: "}") {
            index += 1
            return .object(object)
        }
        while true {
            skipWhitespace()
            guard index < bytes.count, bytes[index] == UInt8(ascii: "\"") else { throw error("expected key") }
            let key = try parseString()
            skipWhitespace()
            guard index < bytes.count, bytes[index] == UInt8(ascii: ":") else { throw error("expected :") }
            index += 1
            skipWhitespace()
            object[key] = try parseValue(depth: depth + 1)
            skipWhitespace()
            guard index < bytes.count else { throw error("unterminated object") }
            if bytes[index] == UInt8(ascii: ",") { index += 1; continue }
            if bytes[index] == UInt8(ascii: "}") { index += 1; return .object(object) }
            throw error("expected , or }")
        }
    }

    mutating func parseArray(depth: Int) throws -> JSONValue {
        index += 1
        var items: [JSONValue] = []
        skipWhitespace()
        if index < bytes.count, bytes[index] == UInt8(ascii: "]") {
            index += 1
            return .array(items)
        }
        while true {
            skipWhitespace()
            items.append(try parseValue(depth: depth + 1))
            skipWhitespace()
            guard index < bytes.count else { throw error("unterminated array") }
            if bytes[index] == UInt8(ascii: ",") { index += 1; continue }
            if bytes[index] == UInt8(ascii: "]") { index += 1; return .array(items) }
            throw error("expected , or ]")
        }
    }

    mutating func parseString() throws -> String {
        index += 1
        var scalars = String.UnicodeScalarView()
        var run: [UInt8] = []
        func flush() throws {
            guard !run.isEmpty else { return }
            // Invalid UTF-8 is repaired to U+FFFD, as TextDecoder does on the web.
            scalars.append(contentsOf: String(decoding: run, as: UTF8.self).unicodeScalars)
            run.removeAll(keepingCapacity: true)
        }
        while index < bytes.count {
            let byte = bytes[index]
            if byte == UInt8(ascii: "\"") {
                index += 1
                try flush()
                return String(scalars)
            }
            if byte == UInt8(ascii: "\\") {
                try flush()
                index += 1
                guard index < bytes.count else { break }
                let escape = bytes[index]
                index += 1
                switch escape {
                case UInt8(ascii: "\""): scalars.append("\"")
                case UInt8(ascii: "\\"): scalars.append("\\")
                case UInt8(ascii: "/"): scalars.append("/")
                case UInt8(ascii: "b"): scalars.append("\u{08}")
                case UInt8(ascii: "f"): scalars.append("\u{0C}")
                case UInt8(ascii: "n"): scalars.append("\n")
                case UInt8(ascii: "r"): scalars.append("\r")
                case UInt8(ascii: "t"): scalars.append("\t")
                case UInt8(ascii: "u"):
                    let high = try parseHex4()
                    if (0xD800...0xDBFF).contains(high), index + 1 < bytes.count,
                       bytes[index] == UInt8(ascii: "\\"), bytes[index + 1] == UInt8(ascii: "u") {
                        index += 2
                        let low = try parseHex4()
                        if (0xDC00...0xDFFF).contains(low) {
                            let code = 0x10000 + ((high - 0xD800) << 10) + (low - 0xDC00)
                            scalars.append(Unicode.Scalar(code) ?? "\u{FFFD}")
                        } else {
                            scalars.append("\u{FFFD}")
                            scalars.append(Unicode.Scalar(low) ?? "\u{FFFD}")
                        }
                    } else {
                        scalars.append(Unicode.Scalar(high) ?? "\u{FFFD}")
                    }
                default: throw error("invalid escape")
                }
                continue
            }
            guard byte >= 0x20 else { throw error("control character in string") }
            run.append(byte)
            index += 1
        }
        throw error("unterminated string")
    }

    mutating func parseHex4() throws -> UInt32 {
        guard index + 4 <= bytes.count else { throw error("short \\u escape") }
        var value: UInt32 = 0
        for _ in 0..<4 {
            let byte = bytes[index]
            let digit: UInt32
            switch byte {
            case UInt8(ascii: "0")...UInt8(ascii: "9"): digit = UInt32(byte - UInt8(ascii: "0"))
            case UInt8(ascii: "a")...UInt8(ascii: "f"): digit = UInt32(byte - UInt8(ascii: "a") + 10)
            case UInt8(ascii: "A")...UInt8(ascii: "F"): digit = UInt32(byte - UInt8(ascii: "A") + 10)
            default: throw error("invalid hex digit")
            }
            value = value * 16 + digit
            index += 1
        }
        return value
    }

    mutating func parseNumber() throws -> Double {
        let start = index
        if index < bytes.count, bytes[index] == UInt8(ascii: "-") { index += 1 }
        let digitsStart = index
        while index < bytes.count, (UInt8(ascii: "0")...UInt8(ascii: "9")).contains(bytes[index]) { index += 1 }
        guard index > digitsStart else { throw error("invalid number") }
        if index < bytes.count, bytes[index] == UInt8(ascii: ".") {
            index += 1
            let fraction = index
            while index < bytes.count, (UInt8(ascii: "0")...UInt8(ascii: "9")).contains(bytes[index]) { index += 1 }
            guard index > fraction else { throw error("invalid fraction") }
        }
        if index < bytes.count, bytes[index] == UInt8(ascii: "e") || bytes[index] == UInt8(ascii: "E") {
            index += 1
            if index < bytes.count, bytes[index] == UInt8(ascii: "+") || bytes[index] == UInt8(ascii: "-") { index += 1 }
            let exponent = index
            while index < bytes.count, (UInt8(ascii: "0")...UInt8(ascii: "9")).contains(bytes[index]) { index += 1 }
            guard index > exponent else { throw error("invalid exponent") }
        }
        let text = String(decoding: bytes[start..<index], as: UTF8.self)
        guard let value = Double(text) else { throw error("invalid number") }
        return value
    }
}
