import Foundation

/// Protocol defining the API service interface
public protocol AskAIServiceProtocol {
    /// Perform a sort-best request (without query)
    /// - Parameter request: The request parameters
    /// - Returns: AskAIResponse containing chips and parameter change notice
    /// - Throws: Error if the request fails
    func performSortBestRequest(request: AskAIRequest) async throws -> AskAIResponse
    
    /// Perform an AskAI request with the given parameters (async/await)
    /// - Parameter request: The request parameters
    /// - Returns: AskAIResponse containing chips and parameter change notice
    /// - Throws: Error if the request fails
    func performAskAIRequest(request: AskAIRequest) async throws -> AskAIResponse
    
    /// Subscribe to SSE events for a search ID
    /// - Parameters:
    ///   - searchId: The search ID to subscribe to
    ///   - authToken: The authorization token
    ///   - onEvent: Callback for received events
    ///   - onError: Callback for connection errors
    func subscribeToEvents(
        searchId: String,
        authToken: String,
        onEvent: @escaping (String) -> Void,
        onError: @escaping (Error) -> Void
    )
    
    /// Disconnect from the SSE connection
    func disconnect()
}

/// Implementation of the AskAI API service
public class AskAIService: AskAIServiceProtocol {
    private let baseURL: String
    private var sseClient: SSEClient?
    
    /// Initialize with a base URL
    /// - Parameter baseURL: The base URL for API requests
    public init(baseURL: String = "https://askai-gateway.rivi.co/api/v1") {
        self.baseURL = baseURL
        self.sseClient = SSEClient()
    }
    
    /// Perform a sort-best request (without query)
    /// - Parameter request: The request parameters
    /// - Returns: AskAIResponse containing chips and parameter change notice
    /// - Throws: Error if the request fails
    public func performSortBestRequest(request: AskAIRequest) async throws -> AskAIResponse {
        // Create the URL request
        let urlString = "\(baseURL)/askai/sort-best"
        guard let url = URL(string: urlString) else {
            let error = NSError(
                domain: "RiviAskAI",
                code: 0,
                userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]
            )
            Logger.logError(message: "Invalid URL: \(urlString)")
            throw error
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add authorization header if available
        if let authToken = request.authToken {
            urlRequest.setValue(authToken, forHTTPHeaderField: "authorization")
        }
        
        // Create request body (without filter_query, with context)
        var requestBody: [String: Any] = [
            "search_id": request.searchId,
            "is_round": request.isRound,
            "query_type": request.queryType.rawValue,
            "context": request.queryType.rawValue,  // Same as query_type
            "language": request.language.rawValue,
            "currency": request.currency,
            "destination": request.destination,
            "origin": request.origin
        ]
        
        // Add optional date fields
        if let checkin = request.checkin {
            requestBody["checkin"] = checkin.toAPIDateString()
        }
        if let checkout = request.checkout {
            requestBody["checkout"] = checkout.toAPIDateString()
        }
        
        // Log the request
        Logger.logRequest(url: url, params: requestBody)
        
        do {
            urlRequest.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            Logger.logError(message: "Failed to serialize request body", error: error)
            throw error
        }
        
        // Perform the request using async/await
        do {
            let (data, response) = try await URLSession.shared.data(for: urlRequest)
            
            // Check for valid HTTP response
            guard let httpResponse = response as? HTTPURLResponse else {
                let error = NSError(
                    domain: "RiviAskAI",
                    code: 0,
                    userInfo: [NSLocalizedDescriptionKey: "Invalid response"]
                )
                Logger.logError(message: "Invalid response", error: error)
                throw error
            }
            
            // Log the response
            Logger.logResponse(url: url, statusCode: httpResponse.statusCode, data: data)
            
            // Check for HTTP errors
            if !(200...299).contains(httpResponse.statusCode) {
                let error = NSError(
                    domain: "RiviAskAI",
                    code: httpResponse.statusCode,
                    userInfo: [NSLocalizedDescriptionKey: "HTTP error \(httpResponse.statusCode)"]
                )
                throw error
            }
            
            // Parse the response using JSONSerialization instead of Decodable
            do {
                guard let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    throw NSError(
                        domain: "RiviAskAI",
                        code: 0,
                        userInfo: [NSLocalizedDescriptionKey: "Invalid JSON format"]
                    )
                }
                
                // Try to extract entities from different response formats
                var entities: [[String: Any]] = []
                
                // Check for "message" -> "entities" structure
                if let message = jsonObject["message"] as? [String: Any],
                   let messageEntities = message["entities"] as? [[String: Any]] {
                    entities = messageEntities
                }
                // Check for "content" -> "entities" structure
                else if let content = jsonObject["content"] as? [String: Any],
                        let contentEntities = content["entities"] as? [[String: Any]] {
                    entities = contentEntities
                }
                
                // Extract chips and parameter change notice from the first entity if available
                if let entity = entities.first {
                    let chips = ChipsExtractor.extractChipsFromJSONEntity(entity, queryType: request.queryType)
                    let parameterChangeNotice = entity["parameter_change_notice"] as? String
                    
                    return AskAIResponse(
                        chips: chips,
                        parameterChangeNotice: parameterChangeNotice?.isEmpty == false ? parameterChangeNotice : nil,
                        rawResponse: jsonObject,
                        entity: entity
                    )
                } else {
                    // No entities found
                    Logger.logError(message: "No entities found in response")
                    return AskAIResponse(
                        chips: [],
                        parameterChangeNotice: nil,
                        rawResponse: jsonObject,
                        entity: nil
                    )
                }
            } catch {
                Logger.logError(message: "Failed to parse response", error: error)
                throw error
            }
        } catch {
            Logger.logError(message: "Sort-best request failed", error: error)
            throw error
        }
    }
    
    /// Perform an AskAI request with the given parameters (async/await)
    /// - Parameter request: The request parameters
    /// - Returns: AskAIResponse containing chips and parameter change notice
    /// - Throws: Error if the request fails
    public func performAskAIRequest(request: AskAIRequest) async throws -> AskAIResponse {
        // Create the URL request
        let urlString = "\(baseURL)/askai"
        guard let url = URL(string: urlString) else {
            let error = NSError(
                domain: "RiviAskAI",
                code: 0,
                userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]
            )
            Logger.logError(message: "Invalid URL: \(urlString)")
            throw error
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add authorization header if available
        if let authToken = request.authToken {
            urlRequest.setValue(authToken, forHTTPHeaderField: "authorization")
        }
        
        // Create request body
        var requestBody: [String: Any] = [
            "filter_query": request.filterQuery,
            "search_id": request.searchId,
            "is_round": request.isRound,
            "query_type": request.queryType.rawValue,
            "language": request.language.rawValue,
            "currency": request.currency,
            "destination": request.destination,
            "origin": request.origin
        ]
        
        // Add optional date fields
        if let checkin = request.checkin {
            requestBody["checkin"] = checkin.toAPIDateString()
        }
        if let checkout = request.checkout {
            requestBody["checkout"] = checkout.toAPIDateString()
        }
        
        // Log the request
        Logger.logRequest(url: url, params: requestBody)
        
        do {
            urlRequest.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            Logger.logError(message: "Failed to serialize request body", error: error)
            throw error
        }
        
        // Perform the request using async/await
        do {
            let (data, response) = try await URLSession.shared.data(for: urlRequest)
            
            // Check for valid HTTP response
            guard let httpResponse = response as? HTTPURLResponse else {
                let error = NSError(
                    domain: "RiviAskAI",
                    code: 0,
                    userInfo: [NSLocalizedDescriptionKey: "Invalid response"]
                )
                Logger.logError(message: "Invalid response", error: error)
                throw error
            }
            
            // Log the response
            Logger.logResponse(url: url, statusCode: httpResponse.statusCode, data: data)
            
            // Check for HTTP errors
            if !(200...299).contains(httpResponse.statusCode) {
                let error = NSError(
                    domain: "RiviAskAI",
                    code: httpResponse.statusCode,
                    userInfo: [NSLocalizedDescriptionKey: "HTTP error \(httpResponse.statusCode)"]
                )
                throw error
            }
            
            // Parse the response using JSONSerialization instead of Decodable
            do {
                guard let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    throw NSError(
                        domain: "RiviAskAI",
                        code: 0,
                        userInfo: [NSLocalizedDescriptionKey: "Invalid JSON format"]
                    )
                }
                
                // Try to extract entities from different response formats
                var entities: [[String: Any]] = []
                
                // Check for "message" -> "entities" structure
                if let message = jsonObject["message"] as? [String: Any],
                   let messageEntities = message["entities"] as? [[String: Any]] {
                    entities = messageEntities
                }
                // Check for "content" -> "entities" structure
                else if let content = jsonObject["content"] as? [String: Any],
                        let contentEntities = content["entities"] as? [[String: Any]] {
                    entities = contentEntities
                }
                
                // Extract chips and parameter change notice from the first entity if available
                if let entity = entities.first {
                    let chips = ChipsExtractor.extractChipsFromJSONEntity(entity, queryType: request.queryType)
                    let parameterChangeNotice = entity["parameter_change_notice"] as? String
                    
                    return AskAIResponse(
                        chips: chips,
                        parameterChangeNotice: parameterChangeNotice?.isEmpty == false ? parameterChangeNotice : nil,
                        rawResponse: jsonObject,
                        entity: entity
                    )
                } else {
                    // No entities found
                    Logger.logError(message: "No entities found in response")
                    return AskAIResponse(
                        chips: [],
                        parameterChangeNotice: nil,
                        rawResponse: jsonObject,
                        entity: nil
                    )
                }
            } catch {
                Logger.logError(message: "Failed to parse response", error: error)
                throw error
            }
        } catch {
            Logger.logError(message: "AskAI request failed", error: error)
            throw error
        }
    }
    
    /// Subscribe to SSE events for a search ID
    /// - Parameters:
    ///   - searchId: The search ID to subscribe to
    ///   - authToken: The authorization token
    ///   - onEvent: Callback for received events
    ///   - onError: Callback for connection errors
    public func subscribeToEvents(
        searchId: String,
        authToken: String,
        onEvent: @escaping (String) -> Void,
        onError: @escaping (Error) -> Void
    ) {
        let urlString = "\(baseURL)/askai/subscribe?searchId=\(searchId)"
        guard let url = URL(string: urlString) else {
            let error = NSError(
                domain: "RiviAskAI",
                code: 0,
                userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]
            )
            Logger.logError(message: "Invalid SSE URL: \(urlString)")
            onError(error)
            return
        }
        
        // Create a request with authorization header
        var request = URLRequest(url: url)
        request.setValue(authToken, forHTTPHeaderField: "authorization")
        
        Logger.logRequest(url: url, params: ["searchId": searchId, "event": "connect"])
        
        sseClient?.connect(to: url, request: request, onEvent: { eventData in
            Logger.logResponse(
                url: url,
                statusCode: 200,
                data: eventData.data(using: .utf8) ?? Data()
            )
            onEvent(eventData)
        }, onError: { error in
            Logger.logError(message: "SSE connection error", error: error)
            onError(error)
        })
    }
    
    /// Disconnect from the SSE connection
    public func disconnect() {
        Logger.logRequest(url: URL(string: "\(baseURL)/disconnect")!, params: ["message": "Disconnecting SSE client"])
        sseClient?.disconnect()
    }
    
    deinit {
        disconnect()
    }
}
