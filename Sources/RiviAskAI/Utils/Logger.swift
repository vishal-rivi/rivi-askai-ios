import Foundation

/// Utility for logging AskAI related events with formatted output
/// - Note: Logging is automatically enabled in DEBUG builds and disabled in RELEASE builds
public enum Logger {
    /// Logs API request details
    /// - Parameters:
    ///   - url: The request URL
    ///   - params: The request parameters
    public static func logRequest(url: URL, params: [String: Any]) {
        #if DEBUG
        let divider = String(repeating: "=", count: 80)
        print("\n\(divider)")
        print("🔵 ASK AI REQUEST")
        print(divider)
        print("📍 URL: \(url.absoluteString)")
        
        if !params.isEmpty {
            print("📍 Params:")
            params.forEach { key, value in
                print("   ├─ \(key): \(value)")
            }
        }
        
        print(divider)
        #endif
    }
    
    /// Logs API response details
    /// - Parameters:
    ///   - url: The request URL
    ///   - statusCode: The HTTP status code
    ///   - data: The response data
    public static func logResponse(url: URL, statusCode: Int, data: Data) {
        #if DEBUG
        let divider = String(repeating: "=", count: 80)
        print("\n\(divider)")
        print("🟢 ASK AI RESPONSE")
        print(divider)
        print("📍 URL: \(url.absoluteString)")
        print("📍 Status Code: \(statusCode)")
        
        if let responseString = String(data: data, encoding: .utf8) {
            print("📍 Response:")
            print(formatJSON(responseString))
        }
        
        print(divider)
        #endif
    }
    
    /// Logs error details
    /// - Parameters:
    ///   - message: The error message
    ///   - error: Optional Error object
    public static func logError(message: String, error: Error? = nil) {
        #if DEBUG
        let divider = String(repeating: "-", count: 80)
        print("\n\(divider)")
        print("❌ ASK AI ERROR")
        print(divider)
        print("📍 Message: \(message)")
        if let error = error {
            print("📍 Error: \(error.localizedDescription)")
        }
        print(divider)
        #endif
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
