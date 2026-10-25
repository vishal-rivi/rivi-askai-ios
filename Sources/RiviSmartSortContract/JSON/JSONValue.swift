/// A JSON value with JS object semantics: objects keep insertion order and enumerate the way a JS
/// engine does (array-index keys first, ascending; see `JSONObject.jsKeys`).
///
/// Foundation's `JSONSerialization` and `[String: Any]` drop key order and bridge booleans to
/// `NSNumber`. The contract depends on both: chips follow the entity record's key order, and the
/// compact `data.itineraries` ranking *is* its key order. Every wire payload and every
/// conformance case goes through this type instead.
public enum JSONValue: Sendable, Hashable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([JSONValue])
    case object(JSONObject)

    public var stringValue: String? {
        if case .string(let value) = self { return value }
        return nil
    }

    public var numberValue: Double? {
        if case .number(let value) = self { return value }
        return nil
    }

    public var boolValue: Bool? {
        if case .bool(let value) = self { return value }
        return nil
    }

    public var arrayValue: [JSONValue]? {
        if case .array(let value) = self { return value }
        return nil
    }

    public var objectValue: JSONObject? {
        if case .object(let value) = self { return value }
        return nil
    }

    public var isNull: Bool {
        if case .null = self { return true }
        return false
    }

    public subscript(key: String) -> JSONValue? {
        objectValue?[key]
    }

    /// JSON equality: objects compare without regard to key order, as the conformance harness
    /// requires ("Deep equality is JSON equality").
    public static func == (lhs: JSONValue, rhs: JSONValue) -> Bool {
        switch (lhs, rhs) {
        case (.null, .null): return true
        case let (.bool(a), .bool(b)): return a == b
        case let (.number(a), .number(b)): return a == b
        case let (.string(a), .string(b)): return a == b
        case let (.array(a), .array(b)): return a == b
        case let (.object(a), .object(b)): return a == b
        default: return false
        }
    }

    public func hash(into hasher: inout Hasher) {
        switch self {
        case .null: hasher.combine(0)
        case .bool(let value): hasher.combine(value)
        case .number(let value): hasher.combine(value)
        case .string(let value): hasher.combine(value)
        case .array(let value): hasher.combine(value)
        case .object(let value): hasher.combine(value)
        }
    }
}

/// A JSON object with its keys in document order. Lookup is by key; iteration is in order.
public struct JSONObject: Sendable, Hashable, Sequence {
    public private(set) var keys: [String] = []
    private var storage: [String: JSONValue] = [:]

    public init() {}

    public init(_ pairs: [(String, JSONValue)]) {
        for (key, value) in pairs { self[key] = value }
    }

    public var isEmpty: Bool { keys.isEmpty }
    public var count: Int { keys.count }

    /// Setting an existing key keeps its position; a new key is appended (JS object semantics).
    /// Setting `nil` removes the key.
    public subscript(key: String) -> JSONValue? {
        get { storage[key] }
        set {
            if let newValue {
                if storage.updateValue(newValue, forKey: key) == nil { keys.append(key) }
            } else if storage.removeValue(forKey: key) != nil {
                keys.removeAll { $0 == key }
            }
        }
    }

    /// Keys in the order a JS engine enumerates them (`Object.keys`): array-index keys
    /// ("0", "7", "20" — canonical integers below 2³² − 1) ascending, then the rest in
    /// insertion order. The web iterates this way, so wherever the web enumerates an object the
    /// port does too.
    public var jsKeys: [String] {
        var indices: [(UInt32, String)] = []
        var named: [String] = []
        for key in keys {
            if let index = JSONObject.arrayIndex(key) { indices.append((index, key)) } else { named.append(key) }
        }
        return indices.sorted { $0.0 < $1.0 }.map(\.1) + named
    }

    static func arrayIndex(_ key: String) -> UInt32? {
        let utf8 = key.utf8
        guard let first = utf8.first, utf8.count <= 10,
              utf8.allSatisfy({ (UInt8(ascii: "0")...UInt8(ascii: "9")).contains($0) }),
              first != UInt8(ascii: "0") || utf8.count == 1,
              let value = UInt64(key), value < 4_294_967_295 else { return nil }
        return UInt32(value)
    }

    /// `{ ...self, ...other }`: existing keys keep their position, new keys are appended.
    public func merging(_ other: JSONObject) -> JSONObject {
        var out = self
        for (key, value) in other { out[key] = value }
        return out
    }

    /// Iterates in JS enumeration order (`jsKeys`), so serialization and every loop over an
    /// object match `JSON.stringify` and `Object.entries` on the web.
    public func makeIterator() -> AnyIterator<(key: String, value: JSONValue)> {
        let ordered = jsKeys
        var index = 0
        return AnyIterator {
            guard index < ordered.count else { return nil }
            defer { index += 1 }
            let key = ordered[index]
            return (key, storage[key]!)
        }
    }

    public static func == (lhs: JSONObject, rhs: JSONObject) -> Bool {
        lhs.storage == rhs.storage
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(storage)
    }
}

// No ExpressibleByNilLiteral: `cond ? value : nil` must stay `Optional<JSONValue>.none`, never `.null`.
extension JSONValue: ExpressibleByBooleanLiteral, ExpressibleByIntegerLiteral,
    ExpressibleByFloatLiteral, ExpressibleByStringLiteral, ExpressibleByArrayLiteral,
    ExpressibleByDictionaryLiteral {
    public init(booleanLiteral value: Bool) { self = .bool(value) }
    public init(integerLiteral value: Int) { self = .number(Double(value)) }
    public init(floatLiteral value: Double) { self = .number(value) }
    public init(stringLiteral value: String) { self = .string(value) }
    public init(arrayLiteral elements: JSONValue...) { self = .array(elements) }
    public init(dictionaryLiteral elements: (String, JSONValue)...) { self = .object(JSONObject(elements)) }
}
