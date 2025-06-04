import Foundation

/// Response from the AskAI API
public struct AskAIResponse: Decodable {
    /// The status of the response
    public let status: String?
    
    /// The status code of the response
    public let statusCode: Int?
    
    /// The message containing the response data
    public let message: MessageContent?
    
    /// Alternative content structure
    public let content: MessageContent?
    
    /// Custom coding keys for JSON decoding
    private enum CodingKeys: String, CodingKey {
        case status
        case statusCode = "status_code"
        case message
        case content
    }
    
    /// Initialize from decoder
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = try container.decodeIfPresent(String.self, forKey: .status)
        statusCode = try container.decodeIfPresent(Int.self, forKey: .statusCode)
        message = try container.decodeIfPresent(MessageContent.self, forKey: .message)
        content = try container.decodeIfPresent(MessageContent.self, forKey: .content)
    }
}

/// Content structure within the response
public struct MessageContent: Decodable {
    /// Array of entity objects in the response
    public let entities: [Entity]?
    
    /// Entity object in the response
    public struct Entity: Decodable {
        /// The chips or suggestions in the response
        public let chips: [String]?
        
        /// Custom coding keys for JSON decoding
        private enum CodingKeys: String, CodingKey {
            case chips
        }
        
        /// Initialize from decoder with custom handling for different formats
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            // Try to decode chips directly
            if let directChips = try? container.decodeIfPresent([String].self, forKey: .chips) {
                chips = directChips
            } else {
                // If direct decoding fails, set to nil
                chips = nil
            }
        }
    }
} 