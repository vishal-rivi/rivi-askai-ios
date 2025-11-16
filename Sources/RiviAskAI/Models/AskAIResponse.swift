import Foundation

/// Response from the AskAI API
public struct AskAIResponse {
    /// The extracted filter chips
    public let chips: Set<String>
    
    /// Parameter change notice message (if any)
    public let parameterChangeNotice: String?
    
    /// The raw response data from the API
    public let rawResponse: [String: Any]
    
    /// The first entity from the response (if available)
    public let entity: [String: Any]?
    
    public init(chips: Set<String>, parameterChangeNotice: String?, rawResponse: [String: Any], entity: [String: Any]?) {
        self.chips = chips
        self.parameterChangeNotice = parameterChangeNotice
        self.rawResponse = rawResponse
        self.entity = entity
    }
}
