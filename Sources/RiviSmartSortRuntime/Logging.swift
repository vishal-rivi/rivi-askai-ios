import Foundation
import RiviSmartSortContract

/// Log levels, least to most severe. A logger set to a level logs that level and above.
public enum RiviLogLevel: Int, Sendable, Comparable {
    case all = 0, debug, info, warn, error, none

    public static func < (lhs: RiviLogLevel, rhs: RiviLogLevel) -> Bool { lhs.rawValue < rhs.rawValue }
}

/// Where the runtime's logs go. The runtime never passes a token or the subscribe URL here.
public protocol RiviLogger: Sendable {
    /// Whether messages at `level` are wanted, so callers skip building them otherwise.
    func isEnabled(_ level: RiviLogLevel) -> Bool
    func log(_ level: RiviLogLevel, _ message: String)
}

extension RiviLogger {
    func debug(_ message: @autoclosure () -> String) { if isEnabled(.debug) { log(.debug, message()) } }
    func info(_ message: @autoclosure () -> String) { if isEnabled(.info) { log(.info, message()) } }
    func warn(_ message: @autoclosure () -> String) { if isEnabled(.warn) { log(.warn, message()) } }
    func error(_ message: @autoclosure () -> String) { if isEnabled(.error) { log(.error, message()) } }
}

/// Prints to the console.
public struct ConsoleRiviLogger: RiviLogger {
    public let level: RiviLogLevel

    public init(level: RiviLogLevel = .info) {
        self.level = level
    }

    public func isEnabled(_ level: RiviLogLevel) -> Bool {
        level != .none && level >= self.level
    }

    public func log(_ level: RiviLogLevel, _ message: String) {
        guard isEnabled(level) else { return }
        let tag: String
        switch level {
        case .debug, .all: tag = "DEBUG"
        case .info: tag = "INFO"
        case .warn: tag = "WARN"
        case .error, .none: tag = "ERROR"
        }
        print("SmartSort SDK [\(tag)]: \(message)")
    }
}

/// Discards everything.
public struct SilentRiviLogger: RiviLogger {
    public init() {}
    public func isEnabled(_ level: RiviLogLevel) -> Bool { false }
    public func log(_ level: RiviLogLevel, _ message: String) {}
}

// MARK: - Formatting

enum LogFormat {
    private static let divider = String(repeating: "=", count: 80)
    private static let thin = String(repeating: "-", count: 80)

    static func request(_ method: String, _ endpoint: Endpoint, details: [(String, String)], body: JSONValue?) -> String {
        var lines = ["", divider, "🔵 SMART SORT REQUEST", divider, "📍 \(method) \(endpoint.rawValue)"]
        for (key, value) in details { lines.append("   ├─ \(key): \(value)") }
        if let body { lines += ["📍 Body:", pretty(body)] }
        lines.append(divider)
        return lines.joined(separator: "\n")
    }

    static func response(_ endpoint: Endpoint, status: Int, milliseconds: Int, body: String?) -> String {
        var lines = ["", divider, "🟢 SMART SORT RESPONSE", divider, "📍 \(endpoint.rawValue)",
                     "📍 Status Code: \(status) (\(milliseconds) ms)"]
        if let body, !body.isEmpty {
            lines.append("📍 Response:")
            lines.append((try? JSONValue.parse(body)).map { pretty($0) } ?? "   \(body)")
        }
        lines.append(divider)
        return lines.joined(separator: "\n")
    }

    /// One stream frame, in full.
    static func event(_ title: String, _ endpoint: Endpoint, seq: String?, payload: String) -> String {
        var lines = ["", divider, "🟢 SMART SORT \(title)", divider, "📍 \(endpoint.rawValue)"]
        if let seq { lines.append("📍 Sequence: \(seq)") }
        lines.append("📍 Data:")
        lines.append((try? JSONValue.parse(payload)).map { pretty($0) } ?? "   \(payload)")
        lines.append(divider)
        return lines.joined(separator: "\n")
    }

    static func failure(_ message: String, _ error: RiviError) -> String {
        ["", thin, "❌ SMART SORT ERROR", thin, "📍 Message: \(message)",
         "📍 Error: \(error.kind.rawValue) — \(error.message)\(error.retryable ? " (retryable)" : "")", thin]
            .joined(separator: "\n")
    }

    /// Indented, one key per line.
    static func pretty(_ value: JSONValue, indent: Int = 1) -> String {
        let pad = String(repeating: "   ", count: indent)
        switch value {
        case .object(let object) where !object.isEmpty:
            let inner = object.map { "\(pad)   \(JSONValue.string($0.key).serialized()): \(pretty($0.value, indent: indent + 1).trimmingCharacters(in: .whitespaces))" }
            return "\(pad){\n" + inner.joined(separator: ",\n") + "\n\(pad)}"
        case .array(let items) where items.contains(where: { $0.objectValue != nil || $0.arrayValue != nil }):
            let inner = items.map { pretty($0, indent: indent + 1) }
            return "\(pad)[\n" + inner.joined(separator: ",\n") + "\n\(pad)]"
        default:
            return pad + value.serialized()
        }
    }

    static func describe(_ input: Input) -> String {
        switch input {
        case .setSearch(let search): return "SetSearch(\(search.product.rawValue) \(search.searchId))"
        case .setSort(let sort): return "SetSort(\(sort.rawValue))"
        case .setStage(let stage): return "SetStage(\(stage.rawValue))"
        case .setFilters(let filters): return "SetFilters(\(filters.map { $0.serialized() } ?? "nil"))"
        case .poolChanged(let pool): return "PoolChanged(size: \(pool.size), complete: \(pool.complete))"
        case .setVisible(let ids): return "SetVisible(\(ids.map { "\($0.count) ids" } ?? "nil"))"
        case .ask(let text): return "Ask(\"\(text)\")"
        case .removeChip(let id): return "RemoveChip(\(id))"
        case .clearAll: return "ClearAll"
        case .confirmResolved(let accepted): return "ConfirmResolved(\(accepted))"
        case .retry: return "Retry"
        case .dismissError: return "DismissError"
        case let .askResponse(epoch, entities, chips, _): return "AskResponse(epoch \(epoch), \(entities.count) entities, \(chips.count) chips)"
        case let .rankingFrame(epoch, ranking): return "RankingFrame(epoch \(epoch), \(ranking.count) entries)"
        case let .explainFrame(epoch, text): return "ExplainFrame(epoch \(epoch), \(text.count) chars)"
        case .explainEnd(let epoch): return "ExplainEnd(epoch \(epoch))"
        case let .failed(epoch, error): return "Failed(epoch \(epoch), \(error.kind.rawValue))"
        case let .timerFired(timer, epoch): return "TimerFired(\(timer.rawValue), epoch \(epoch))"
        }
    }

    static func describe(_ command: Command) -> String {
        switch command {
        case let .fetch(epoch, request): return "Fetch(\(request.kindName), epoch \(epoch))"
        case .cancelInFlight(let scope): return "CancelInFlight(\(scope.rawValue))"
        case let .startTimer(timer, ms, _): return "StartTimer(\(timer.rawValue), \(ms) ms)"
        case .cancelTimer(.all): return "CancelTimer(all)"
        case .cancelTimer(.one(let timer)): return "CancelTimer(\(timer.rawValue))"
        case .rankingCleared: return "RankingCleared"
        case .confirmSortChange(let sort): return "ConfirmSortChange(\(sort.rawValue))"
        case .sortChanged(let sort): return "SortChanged(\(sort.rawValue))"
        }
    }
}
