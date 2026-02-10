//
//  RiviAskAI
//
//  Created by Shubham Nanda on 09/02/26.
//

import Foundation

/// Log levels for the AskAI SDK.
public enum AskAILogLevel: Int, Comparable {
    case all = 0
    case debug = 1
    case info = 2
    case warn = 3
    case error = 4
    case none = 5

    /// Priority used for filtering; higher value = less verbose (only that level and above are logged).
    internal var priority: Int { rawValue }

    public static func < (lhs: AskAILogLevel, rhs: AskAILogLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// Logger protocol for the AskAI SDK.
/// Implement this protocol to redirect SDK logs to your preferred logging framework (e.g., os.log, CocoaLumberjack).
public protocol AskAILogger {
    /// Logs a debug message.
    func debug(_ message: String)

    /// Logs an informational message.
    func info(_ message: String)

    /// Logs a warning message.
    func warn(_ message: String)

    /// Logs an error message.
    func error(_ message: String)

    /// Logs an error with an Error object.
    func error(_ error: Error)
}

/// Default logger implementation using `print`.
internal class ConsoleAskAILogger: AskAILogger {
    private let logLevel: AskAILogLevel

    init(logLevel: AskAILogLevel = .info) {
        self.logLevel = logLevel
    }

    func debug(_ message: String) {
        if AskAILogLevel.debug.priority >= logLevel.priority {
            print("AskAI SDK [DEBUG]: \(message)")
        }
    }

    func info(_ message: String) {
        if AskAILogLevel.info.priority >= logLevel.priority {
            print("AskAI SDK [INFO]: \(message)")
        }
    }

    func warn(_ message: String) {
        if AskAILogLevel.warn.priority >= logLevel.priority {
            print("AskAI SDK [WARN]: \(message)")
        }
    }

    func error(_ message: String) {
        if AskAILogLevel.error.priority >= logLevel.priority {
            print("AskAI SDK [ERROR]: \(message)")
        }
    }

    func error(_ error: Error) {
        if AskAILogLevel.error.priority >= logLevel.priority {
            print("AskAI SDK [ERROR]: \(error)")
        }
    }
}
