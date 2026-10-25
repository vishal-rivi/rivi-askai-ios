import Foundation
import RiviSmartSortContract

// Stream framing, replay guard and reconnect policy (web: src/runtime/stream.ts, reconnect.ts).

/// Splits a byte stream into lines. Splitting happens on bytes, so a UTF-8 character split across
/// chunks survives (0x0A never occurs inside a multi-byte sequence). CRLF becomes LF. The gateway
/// sends no blank line between events, so every line is a candidate frame.
struct LineDecoder {
    private var buffer: [UInt8] = []

    mutating func push(_ chunk: [UInt8]) -> [String] {
        var lines: [String] = []
        for byte in chunk {
            if byte == 0x0A {
                lines.append(Self.decode(buffer))
                buffer.removeAll(keepingCapacity: true)
            } else {
                buffer.append(byte)
            }
        }
        return lines
    }

    mutating func end() -> [String] {
        defer { buffer.removeAll() }
        let tail = Self.decode(buffer)
        return tail.isEmpty ? [] : [tail]
    }

    private static func decode(_ bytes: [UInt8]) -> String {
        var line = bytes[...]
        if line.last == 0x0D { line = line.dropLast() }
        return String(decoding: line, as: UTF8.self)
    }
}

struct ParsedFrame {
    /// The numeric sequence prefix (`1{…}`), or nil.
    var seq: String?
    /// The JSON text, from the first `{` or `[`.
    var payload: String
    var json: JSONValue
}

/// One line to one frame. `data:` lines and bare JSON lines are frames; comments (`:`), other SSE
/// fields, blank lines and unparseable text are not.
func parseFrameLine(_ line: String) -> ParsedFrame? {
    var text = Substring(line.trimmingCharacters(in: .whitespacesAndNewlines))
    if text.isEmpty || text.hasPrefix(":") { return nil }
    for field in ["event", "id", "retry"] {
        if text.hasPrefix(field) {
            let rest = text.dropFirst(field.count).drop(while: { $0 == " " || $0 == "\t" })
            if rest.hasPrefix(":") { return nil }
        }
    }
    if text.hasPrefix("data:") { text = Substring(text.dropFirst(5).trimmingCharacters(in: .whitespacesAndNewlines)) }
    guard let start = text.firstIndex(where: { $0 == "{" || $0 == "[" }) else { return nil }
    let prefix = text[..<start].trimmingCharacters(in: .whitespaces)
    let payload = String(text[start...])
    guard let json = try? JSONValue.parse(payload) else { return nil }
    let isSeq = !prefix.isEmpty && prefix.allSatisfy { ("0"..."9").contains($0) }
    return ParsedFrame(seq: isSeq ? prefix : nil, payload: payload, json: json)
}

/// djb2 over the payload's UTF-16 code units, as the web keys its replay set.
func hashPayload(_ payload: String) -> String {
    var hash: Int32 = 5381
    for unit in payload.utf16 { hash = (hash &<< 5) &+ hash &+ Int32(unit) }
    return String(UInt32(bitPattern: hash), radix: 36)
}

let replayCap = 500

/// Drops frames the gateway replays when a subscription reopens. The key is sequence plus content,
/// so a gateway that restarts numbering cannot hide a new frame. Unsequenced frames are never
/// treated as replays. Oldest keys are evicted past the cap.
struct ReplayGuard {
    private var keys: Set<String> = []
    private var order: [String] = []
    private let cap: Int

    init(cap: Int = replayCap) {
        self.cap = cap
    }

    var count: Int { keys.count }

    mutating func isReplay(_ frame: ParsedFrame) -> Bool {
        guard let seq = frame.seq else { return false }
        let key = "\(seq)::\(hashPayload(frame.payload))"
        if keys.contains(key) { return true }
        keys.insert(key)
        order.append(key)
        if keys.count > cap { keys.remove(order.removeFirst()) }
        return false
    }
}

/// Reconnect policy for the ranking stream (spec 6.2).
enum Reconnect {
    static let baseMs = 1000.0
    static let factor = 2.0
    static let maxMs = 30_000.0
    static let jitter = 0.2
    static let budget = 5

    /// Delay before the next attempt after `failures` consecutive failures (1-based): 1 s, 2 s,
    /// 4 s, 8 s … with ±20% jitter, never above 30 s. `random` returns [0, 1); 0.5 means no jitter.
    static func backoffDelay(failures: Int, random: () -> Double) -> Int {
        let exponent = Double(max(0, failures - 1))
        let raw = min(baseMs * pow(factor, exponent), maxMs)
        let scale = 1 + (random() * 2 - 1) * jitter
        return Int(min(raw * scale, maxMs).rounded())
    }
}

/// Counts consecutive failures. `fail()` returns true once the budget is spent.
struct FailureBudget {
    private(set) var count = 0

    mutating func fail() -> Bool {
        count += 1
        return count >= Reconnect.budget
    }

    mutating func reset() {
        count = 0
    }
}
