import Foundation

public protocol RiviAskAIServiceProtocol {
    func filterSearch(
        query: String,
        params: FilterSearchParams,
        completion: @escaping (Result<Set<String>, Error>) -> Void
    )
    
    func subscribeToEvents(
        searchId: String,
        authToken: String,
        onEvent: @escaping (String) -> Void,
        onError: @escaping (Error) -> Void
    )
    
    func disconnect()
}

public class RiviAskAIService: RiviAskAIServiceProtocol {
    private let baseURL: String
    private var sseClient: SSEClient?
    private var authToken: String?
    
    public init(baseURL: String = "http://34.48.22.18:9000/api/v1") {
        self.baseURL = baseURL
        self.sseClient = SSEClient()
    }
    
    public func filterSearch(
        query: String,
        params: FilterSearchParams,
        completion: @escaping (Result<Set<String>, Error>) -> Void
    ) {
        // Create the URL request
        let urlString = "\(baseURL)/askai"
        guard let url = URL(string: urlString) else {
            let error = NSError(
                domain: "RiviAskAI",
                code: 0,
                userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]
            )
            RiviAskAILogger.logError("Invalid URL: \(urlString)", error: error)
            completion(.failure(error))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add authorization header if available
        if let authToken = params.authToken {
            request.setValue(authToken, forHTTPHeaderField: "authorization")
            self.authToken = authToken
        }
        
        // Create request body
        let filterQuery = query.isEmpty ? params.filterQuery : query
        let requestBody: [String: Any] = [
            "filter_query": filterQuery as Any,
            "search_id": params.searchId as Any,
            "is_round": params.isRound as Any
        ].compactMapValues { $0 }
        
        // Log the filter search request
        RiviAskAILogger.logFilterSearch(query: filterQuery ?? "", params: requestBody)
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            RiviAskAILogger.logError("Failed to serialize request body", error: error)
            completion(.failure(error))
            return
        }
        
        // Create and start the task
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                RiviAskAILogger.logError("Filter search request failed", error: error)
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
                let error = NSError(
                    domain: "RiviAskAI",
                    code: statusCode,
                    userInfo: [NSLocalizedDescriptionKey: "HTTP error \(statusCode)"]
                )
                
                RiviAskAILogger.logError("Filter search HTTP error: \(statusCode)")
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                let error = NSError(
                    domain: "RiviAskAI",
                    code: 0,
                    userInfo: [NSLocalizedDescriptionKey: "No data returned"]
                )
                RiviAskAILogger.logError("Filter search response has no data", error: error)
                completion(.failure(error))
                return
            }
            
            // Try to parse the response and extract chips
            do {
                // Log the raw response for debugging
                if let responseString = String(data: data, encoding: .utf8) {
                    RiviAskAILogger.log("Raw response: \(responseString)", level: .debug)
                }
                
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   (json["status"] as? String == "success" || json["status_code"] as? Int == 200),
                   let message = json["message"] as? [String: Any],
                   let entities = message["entities"] as? [[String: Any]],
                   !entities.isEmpty {
                    
                    // Log entity before extracting chips
                    RiviAskAILogger.log("Processing entity: \(entities[0])", level: .debug)
                    
                    // Extract chips from the first entity
                    let chips = SSEDataProcessor.extractChipsFromJSONEntity(entities[0], isFlightMode: true)
                    RiviAskAILogger.log("Extracted \(chips.count) chips from filter search response", level: .info)
                    
                    // Success with chips
                    completion(.success(chips))
                } else {
                    // Try alternative response format with content key
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let content = json["content"] as? [String: Any],
                       let entities = content["entities"] as? [[String: Any]],
                       !entities.isEmpty {
                        
                        // Extract chips from the first entity
                        let chips = SSEDataProcessor.extractChipsFromJSONEntity(entities[0], isFlightMode: true)
                        RiviAskAILogger.log("Extracted \(chips.count) chips from filter search response", level: .info)
                        
                        // Success with chips
                        completion(.success(chips))
                    } else {
                        // Success but no chips found
                        RiviAskAILogger.log("Filter search success, but no chips found", level: .info)
                        completion(.success([]))
                    }
                }
            } catch {
                RiviAskAILogger.logError("Failed to parse filter search response", error: error)
                if let responseString = String(data: data, encoding: .utf8) {
                    RiviAskAILogger.log("Raw response: \(responseString)", level: .debug)
                }
                // Still return success since the API call succeeded, but no chips
                completion(.success([]))
            }
        }
        
        task.resume()
    }
    
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
            RiviAskAILogger.logError("Invalid SSE URL: \(urlString)", error: error)
            onError(error)
            return
        }
        
        // Create a request with authorization header
        var request = URLRequest(url: url)
        request.setValue(authToken, forHTTPHeaderField: "authorization")
        
        RiviAskAILogger.logSSEConnection(searchId: searchId, event: "connect")
//        print("===== CONNECTING TO SSE =====")
//        print("URL: \(urlString)")
//        print("Search ID: \(searchId)")
//        print("==========================")
        
        sseClient?.connect(to: url, request: request, onEvent: { eventData in
            RiviAskAILogger.logSSEEvent(data: eventData)
//            print("===== SSE EVENT RECEIVED =====")
//            print(eventData)
//            print("=============================")
            onEvent(eventData)
        }, onError: { error in
            RiviAskAILogger.logError("SSE connection error", error: error)
//            print("===== SSE ERROR =====")
//            print(error.localizedDescription)
//            print("====================")
            onError(error)
        })
    }
    
    public func disconnect() {
        RiviAskAILogger.log("Disconnecting SSE client", level: .info)
        sseClient?.disconnect()
    }
    
    deinit {
        disconnect()
    }
} 
