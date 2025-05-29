import Foundation

/// Utility for logging AskAI related events with formatted output
public enum RiviAskAILogger {
    /// Log levels for controlling verbosity
    public enum LogLevel: Int {
        case none = 0
        case error = 1
        case warning = 2
        case info = 3
        case debug = 4
        
        var emoji: String {
            switch self {
            case .none: return ""
            case .error: return "❌"
            case .warning: return "⚠️"
            case .info: return "ℹ️"
            case .debug: return "🔍"
            }
        }
    }
    
    /// Current log level - set this to control verbosity
    public static var logLevel: LogLevel = .info
    
    /// Whether to include timestamps in logs
    public static var includeTimestamps: Bool = true
    
    /// Logs filter search API request details
    /// - Parameters:
    ///   - query: The filter query string
    ///   - params: The search parameters
    public static func logFilterSearch(query: String, params: [String: Any]) {
        guard logLevel.rawValue >= LogLevel.info.rawValue else { return }
        
        let divider = String(repeating: "=", count: 80)
        print("\n\(divider)")
        print("🔎 RIVI ASK AI FILTER SEARCH")
        print(divider)
        print("📍 Query:    \(query)")
        
        if !params.isEmpty {
            print("📍 Params:")
            params.forEach { key, value in
                print("   ├─ \(key): \(value)")
            }
        }
        
        print(divider)
    }
    
    /// Logs SSE connection events
    /// - Parameters:
    ///   - searchId: The search ID for the connection
    ///   - event: The connection event type (connect, disconnect, etc.)
    public static func logSSEConnection(searchId: String, event: String) {
        guard logLevel.rawValue >= LogLevel.info.rawValue else { return }
        
        let divider = String(repeating: "=", count: 80)
        print("\n\(divider)")
        print("🔌 RIVI ASK AI SSE CONNECTION")
        print(divider)
        print("📍 Search ID: \(searchId)")
        print("📍 Event:     \(event)")
        print(divider)
    }
    
    /// Logs SSE events received from server
    /// - Parameters:
    ///   - data: The received data
    public static func logSSEEvent(data: String) {
        guard logLevel.rawValue >= LogLevel.debug.rawValue else { return }
        
        let divider = String(repeating: "-", count: 80)
        print("\n\(divider)")
        print("📡 RIVI ASK AI SSE EVENT")
        print(divider)
        print("📍 Data:")
        
        if let jsonData = data.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: jsonData) {
            if let jsonData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted),
               let prettyString = String(data: jsonData, encoding: .utf8) {
                print(formatJSON(prettyString))
            } else {
                print("   \(data)")
            }
        } else {
            print("   \(data)")
        }
        
        print(divider)
    }
    
    /// Logs general information messages
    /// - Parameters:
    ///   - message: The message to log
    ///   - level: The log level for this message
    public static func log(_ message: String, level: LogLevel = .info) {
        guard logLevel.rawValue >= level.rawValue else { return }
        
        print("\(level.emoji) RIVI ASK AI: \(message)")
    }
    
    /// Logs errors with optional error object
    /// - Parameters:
    ///   - message: The error message
    ///   - error: Optional Error object
    public static func logError(_ message: String, error: Error? = nil) {
        guard logLevel.rawValue >= LogLevel.error.rawValue else { return }
        
        let divider = String(repeating: "-", count: 80)
        print("\n\(divider)")
        print("❌ RIVI ASK AI ERROR")
        print(divider)
        print("📍 Message: \(message)")
        if let error = error {
            print("📍 Error:   \(error.localizedDescription)")
        }
        print(divider)
    }
    
    /// Formats a JSON string with proper indentation
    /// - Parameter jsonString: The raw JSON string to format
    /// - Returns: A formatted JSON string with proper indentation
    private static func formatJSON(_ jsonString: String) -> String {
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data),
              let prettyData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted),
              let prettyString = String(data: prettyData, encoding: .utf8) else {
            return jsonString
        }
        return prettyString.split(separator: "\n")
            .map { "   \($0)" }
            .joined(separator: "\n")
    }
} 
