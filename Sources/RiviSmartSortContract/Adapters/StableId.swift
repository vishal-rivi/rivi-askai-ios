/// Deterministic chip ids (web: src/adapters/stableId.ts). Byte-for-byte the web algorithm:
///
///     id = ruleKey + ":" + hex8(fnv1a32(utf8(ruleKey + U+001F + canonical(value))))
///
/// canonical(string) = the string; canonical(number) = its JS `String(n)` ("1", "4.5");
/// canonical(bool) = "true" | "false"; canonical(null) = ""; canonical(array) = items joined by
/// U+001E (nested arrays are not delimited, as on the web); canonical(object) =
/// "key=canonical(value)" for keys in sorted order, joined by U+001D.
public func stableId(_ ruleKey: String, _ value: JSONValue) -> String {
    "\(ruleKey):\(fnv1a32("\(ruleKey)\u{1F}\(canonical(value))"))"
}

private func canonical(_ value: JSONValue) -> String {
    switch value {
    case .null: return ""
    case .string(let text): return text
    case .number(let number): return jsNumberString(number)
    case .bool(let flag): return flag ? "true" : "false"
    case .array(let items): return items.map(canonical).joined(separator: "\u{1E}")
    case .object(let object):
        // JS sorts keys by UTF-16 code units.
        return object.keys
            .sorted { $0.utf16.lexicographicallyPrecedes($1.utf16) }
            .map { "\($0)=\(canonical(object[$0]!))" }
            .joined(separator: "\u{1D}")
    }
}

private func fnv1a32(_ text: String) -> String {
    var hash: UInt32 = 0x811C_9DC5
    for byte in text.utf8 {
        hash ^= UInt32(byte)
        hash = hash &* 0x0100_0193
    }
    let hex = String(hash, radix: 16)
    return String(repeating: "0", count: 8 - hex.count) + hex
}
