import Foundation

/// Response from the AskAI explain endpoint
public struct ExplainAIResponse {
    /// The explanation text returned by the API
    public let content: String

    /// The raw response data from the API
    public let rawResponse: [String: Any]

    public init(content: String, rawResponse: [String: Any]) {
        self.content = content
        self.rawResponse = rawResponse
    }
}
