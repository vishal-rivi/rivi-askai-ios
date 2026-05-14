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

    /// Perform an explain-ai request to get a natural-language explanation for the current ranking.
    /// The endpoint streams Server-Sent Events; each frame contains the cumulative content so far.
    /// - Parameters:
    ///   - request: The original AskAI request used to derive contextual fields
    ///   - extractedEntities: The `extracted_entities` payload returned from the prior AskAI response
    ///   - departureDate: Optional ISO 8601 departure date for flights
    ///   - returnDate: Optional ISO 8601 return date for round-trip flights
    ///   - rooms: Number of rooms (hotel) — defaults to 1
    ///   - cabinType: Cabin class (flight) — defaults to "Economy"
    ///   - onPartialContent: Optional callback invoked on the main actor with each cumulative content snapshot as it streams
    /// - Returns: ExplainAIResponse containing the final explanation text
    /// - Throws: Error if the request fails
    func performExplainAIRequest(
        request: AskAIRequest,
        extractedEntities: [String: Any],
        departureDate: Date?,
        returnDate: Date?,
        rooms: Int,
        cabinType: String,
        onPartialContent: (@MainActor (String) -> Void)?
    ) async throws -> ExplainAIResponse

    /// Subscribe to SSE events for a search ID
    /// - Parameters:
    ///   - searchId: The search ID to subscribe to
    ///   - onEvent: Callback for received events
    ///   - onError: Callback for connection errors
    func subscribeToEvents(
        searchId: String,
        config: SSEConfig,
        onState: ((SSEConnectionState) -> Void)?,
        onEvent: @escaping (String) -> Void,
        onError: @escaping (Error) -> Void
    )
    
    /// Disconnect from the SSE connection
    func disconnect()
}

/// Implementation of the AskAI API service
public class AskAIService: AskAIServiceProtocol {
    private var sseClient: SSEClient?
    private let logger: AskAILogger
    public init(logger: AskAILogger? = nil) {
        self.logger = logger ?? RiviAskAIConfiguration.shared.resolvedLogger
        self.sseClient = SSEClient()
    }
    
    /// Perform a sort-best request (without query)
    /// - Parameter request: The request parameters
    /// - Returns: AskAIResponse containing chips and parameter change notice
    /// - Throws: Error if the request fails
    public func performSortBestRequest(request: AskAIRequest) async throws -> AskAIResponse {
        // Create the URL request
        let urlString = "\(RiviAskAIConfiguration.shared.baseURL)/askai/sort-best"
        guard let url = URL(string: urlString) else {
            let error = NSError(
                domain: "RiviAskAI",
                code: 0,
                userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]
            )
            Logger.logError(message: "Invalid URL: \(urlString)")
            logger.error("Invalid URL: \(urlString)")
            throw error
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add authorization header if available
        if let authToken = RiviAskAIConfiguration.shared.authToken {
            urlRequest.setValue(authToken, forHTTPHeaderField: "authorization")
        }
        
        // Build the body. Flight and hotel sort-best use different field shapes — match
        // the gateway's expectations for each.
        var requestBody: [String: Any] = [
            "search_id": request.searchId,
            "is_round": request.isRound,
            "language": RiviAskAIConfiguration.shared.language.rawValue,
            "currency": request.currency,
            "destination": request.destination,
            "origin": request.origin,
            "adults": request.adults ?? 1,
            "children": request.children ?? 0
        ]

        switch request.queryType {
        case .flight:
        
            requestBody["departure_date"] = (request.departureDate ?? request.checkin)?.toISO8601String() ?? ""
            if let ret = request.returnDate ?? request.checkout {
                requestBody["return_date"] = ret.toISO8601String()
            } else {
                requestBody["return_date"] = ""
            }
            requestBody["infant"] = request.infant ?? 0
            requestBody["cabin_type"] = request.cabinType ?? "Economy"

        case .hotel:
            requestBody["query_type"] = request.queryType.rawValue
            requestBody["context"] = request.queryType.rawValue
            if let checkin = request.checkin {
                requestBody["checkin"] = checkin.toISO8601String()
            }
            if let checkout = request.checkout {
                requestBody["checkout"] = checkout.toISO8601String()
            }
            requestBody["rooms"] = request.rooms ?? 1
            if let childAges = request.childAges {
                requestBody["child_ages"] = childAges
            }
        }
        
        logger.info("Sending sort-best request with searchId: \(request.searchId)")
        Logger.logRequest(url: url, params: requestBody)
        
        do {
            urlRequest.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            Logger.logError(message: "Failed to serialize request body", error: error)
            logger.error(error)
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
                logger.error(error)
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
                logger.error(error)
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
                
                let entities = Self.extractEntities(from: jsonObject)

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
                    logger.warn("No entities found in response")
                    return AskAIResponse(
                        chips: [],
                        parameterChangeNotice: nil,
                        rawResponse: jsonObject,
                        entity: nil
                    )
                }
            } catch {
                Logger.logError(message: "Failed to parse response", error: error)
                logger.error(error)
                throw error
            }
        } catch {
            Logger.logError(message: "Sort-best request failed", error: error)
            logger.error(error)
            throw error
        }
    }
    
    /// Perform an AskAI request with the given parameters (async/await)
    /// - Parameter request: The request parameters
    /// - Returns: AskAIResponse containing chips and parameter change notice
    /// - Throws: Error if the request fails
    public func performAskAIRequest(request: AskAIRequest) async throws -> AskAIResponse {
        // Create the URL request
        let urlString = "\(RiviAskAIConfiguration.shared.baseURL)/askai"
        guard let url = URL(string: urlString) else {
            let error = NSError(
                domain: "RiviAskAI",
                code: 0,
                userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]
            )
            Logger.logError(message: "Invalid URL: \(urlString)")
            logger.error("Invalid URL: \(urlString)")
            throw error
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add authorization header if available
        if let authToken = RiviAskAIConfiguration.shared.authToken {
            urlRequest.setValue(authToken, forHTTPHeaderField: "authorization")
        }
        
        // Mirror the (working) /askai/sort-best body structure. Common fields go
        // top-level; per-type fields go in the switch. The only addition over
        // sort-best is `filter_query`.
        var requestBody: [String: Any] = [
            "filter_query": request.filterQuery,
            "search_id": request.searchId,
            "is_round": request.isRound,
            "language": RiviAskAIConfiguration.shared.language.rawValue,
            "currency": request.currency,
            "destination": request.destination,
            "origin": request.origin,
            "adults": request.adults ?? 1,
            "children": request.children ?? 0
        ]

        switch request.queryType {
        case .flight:
            // Flight uses ISO 8601 (LocalDateTime with millis + Z) for dates.
            requestBody["departure_date"] = (request.departureDate ?? request.checkin)?.toISO8601String() ?? ""
            if let ret = request.returnDate ?? request.checkout {
                requestBody["return_date"] = ret.toISO8601String()
            } else {
                requestBody["return_date"] = ""
            }
            requestBody["infant"] = request.infant ?? 0
            requestBody["cabin_type"] = request.cabinType ?? "Economy"

        case .hotel:
            requestBody["query_type"] = request.queryType.rawValue
            requestBody["context"] = request.queryType.rawValue
            // /askai hotel rejects ISO 8601 and requires MM/dd/yyyy (verified by
            // gateway error: "time data ... does not match format '%m/%d/%Y'").
            if let checkin = request.checkin {
                requestBody["checkin"] = checkin.toAPIDateString()
            }
            if let checkout = request.checkout {
                requestBody["checkout"] = checkout.toAPIDateString()
            }
            requestBody["rooms"] = request.rooms ?? 1
            if let childAges = request.childAges {
                requestBody["child_ages"] = childAges
            }
        }
        
        logger.info("Sending AskAI request with searchId: \(request.searchId)")
        Logger.logRequest(url: url, params: requestBody)
        
        do {
            urlRequest.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            Logger.logError(message: "Failed to serialize request body", error: error)
            logger.error(error)
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
                logger.error(error)
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
                logger.error(error)
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
                
                let entities = Self.extractEntities(from: jsonObject)

                if let entity = entities.first {
                    let chips = ChipsExtractor.extractChipsFromJSONEntity(entity, queryType: request.queryType)
                    let parameterChangeNotice = entity["parameter_change_notice"] as? String

                    // Auto-fire explain-ai when the user submitted a real query (i.e. tapped "Improve Results").
                    autoFireExplainAI(request: request, entity: entity)

                    return AskAIResponse(
                        chips: chips,
                        parameterChangeNotice: parameterChangeNotice?.isEmpty == false ? parameterChangeNotice : nil,
                        rawResponse: jsonObject,
                        entity: entity
                    )
                } else {
                    // No entities found
                    Logger.logError(message: "No entities found in response")
                    logger.warn("No entities found in response")
                    return AskAIResponse(
                        chips: [],
                        parameterChangeNotice: nil,
                        rawResponse: jsonObject,
                        entity: nil
                    )
                }
            } catch {
                Logger.logError(message: "Failed to parse response", error: error)
                logger.error(error)
                throw error
            }
        } catch {
            Logger.logError(message: "AskAI request failed", error: error)
            logger.error(error)
            throw error
        }
    }
    
    /// Perform an explain-ai request. The endpoint streams SSE; each `data:` frame carries
    /// the cumulative content. We forward intermediate snapshots to `onPartialContent` and
    /// resolve with the final snapshot.
    public func performExplainAIRequest(
        request: AskAIRequest,
        extractedEntities: [String: Any],
        departureDate: Date?,
        returnDate: Date?,
        rooms: Int,
        cabinType: String,
        onPartialContent: (@MainActor (String) -> Void)? = nil
    ) async throws -> ExplainAIResponse {
        let urlString = "\(RiviAskAIConfiguration.shared.baseURL)/askai/explain-ai"
        guard let url = URL(string: urlString) else {
            let error = NSError(
                domain: "RiviAskAI",
                code: 0,
                userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]
            )
            Logger.logError(message: "Invalid URL: \(urlString)")
            logger.error("Invalid URL: \(urlString)")
            throw error
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("text/event-stream", forHTTPHeaderField: "accept")

        if let authToken = RiviAskAIConfiguration.shared.authToken {
            urlRequest.setValue(authToken, forHTTPHeaderField: "authorization")
        }

        var sanitizedEntities = extractedEntities
        sanitizedEntities.removeValue(forKey: "parameter_change_notice")

        var requestBody: [String: Any] = [
            "search_type": request.queryType.rawValue,
            "filter_query": request.filterQuery,
            "extracted_entities": sanitizedEntities,
            "language": RiviAskAIConfiguration.shared.language.rawValue,
            "currency": request.currency,
            "search_id": request.searchId,
            "destination": request.destination,
            "origin": request.origin,
            "checkin": request.checkin?.toISO8601String() ?? "",
            "checkout": request.checkout?.toISO8601String() ?? "",
            "departure_date": departureDate?.toISO8601String() ?? "",
            "return_date": returnDate?.toISO8601String() ?? "",
            "adults": request.adults ?? 1,
            "children": request.children ?? 0,
            "rooms": rooms,
            "cabin_type": cabinType
        ]

        if let childAges = request.childAges {
            requestBody["child_ages"] = childAges
        }

        logger.info("Sending explain-ai request with searchId: \(request.searchId)")
        Logger.logRequest(url: url, params: requestBody)

        do {
            urlRequest.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            Logger.logError(message: "Failed to serialize explain-ai body", error: error)
            logger.error(error)
            throw error
        }

        let (bytes, response) = try await URLSession.shared.bytes(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            let error = NSError(
                domain: "RiviAskAI",
                code: 0,
                userInfo: [NSLocalizedDescriptionKey: "Invalid response"]
            )
            Logger.logError(message: "Invalid response", error: error)
            logger.error(error)
            throw error
        }

        if !(200...299).contains(httpResponse.statusCode) {
            // Drain so we can log the body before throwing
            var buffer = Data()
            for try await byte in bytes { buffer.append(byte) }
            Logger.logResponse(url: url, statusCode: httpResponse.statusCode, data: buffer)
            let error = NSError(
                domain: "RiviAskAI",
                code: httpResponse.statusCode,
                userInfo: [NSLocalizedDescriptionKey: "HTTP error \(httpResponse.statusCode)"]
            )
            logger.error(error)
            throw error
        }

        var latestContent = ""
        var latestFrame: [String: Any] = [:]
        var rawBuffer = Data()

        for try await line in bytes.lines {
            if let lineData = (line + "\n").data(using: .utf8) {
                rawBuffer.append(lineData)
            }

            // SSE frames look like "data: {json}". Skip blank lines and comments (": ...").
            guard line.hasPrefix("data:") else { continue }
            let payload = line.dropFirst("data:".count).trimmingCharacters(in: .whitespaces)
            guard !payload.isEmpty, payload != "[DONE]" else { continue }
            guard let payloadData = payload.data(using: .utf8),
                  let frame = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any]
            else { continue }

            if let content = frame["content"] as? String {
                latestContent = content
                latestFrame = frame
                if let onPartialContent {
                    await onPartialContent(content)
                }
            }
        }

        Logger.logResponse(url: url, statusCode: httpResponse.statusCode, data: rawBuffer)

        return ExplainAIResponse(content: latestContent, rawResponse: latestFrame)
    }

    /// Pulls the entity dictionary list out of the various response shapes the gateway returns.
    /// Handles every combination of:
    ///   - `entities` at the top level, under `message`, under `content`, or under `message.content`
    ///   - `entities` as either an array of dicts or a single dict
    static func extractEntities(from jsonObject: [String: Any]) -> [[String: Any]] {
        let containers: [[String: Any]] = [
            jsonObject,
            (jsonObject["message"] as? [String: Any]) ?? [:],
            (jsonObject["content"] as? [String: Any]) ?? [:],
            ((jsonObject["message"] as? [String: Any])?["content"] as? [String: Any]) ?? [:]
        ]

        for container in containers {
            if let array = container["entities"] as? [[String: Any]], !array.isEmpty {
                return array
            }
            if let dict = container["entities"] as? [String: Any] {
                return [dict]
            }
        }
        return []
    }

    /// Kick off an explain-ai stream in the background and forward partial content to the
    /// `onExplainContent` / `onExplainError` handlers configured on `RiviAskAIConfiguration`.
    /// Fires whenever a handler is registered — covers both "Improve Results" and "Sort Best".
    private func autoFireExplainAI(request: AskAIRequest, entity: [String: Any]) {
        let config = RiviAskAIConfiguration.shared
        guard config.onExplainContent != nil || config.onExplainError != nil else { return }

        // For flights, the AskAI request reuses `checkin` as the departure date — mirror that
        // mapping so explain-ai sees the right `departure_date` field.
        let departureDate = request.queryType == .flight ? request.checkin : nil
        let checkin = request.queryType == .hotel ? request.checkin : nil
        let checkout = request.queryType == .hotel ? request.checkout : nil

        let contextRequest = AskAIRequest(
            filterQuery: request.filterQuery,
            searchId: request.searchId,
            isRound: request.isRound,
            queryType: request.queryType,
            currency: request.currency,
            checkin: checkin,
            checkout: checkout,
            adults: request.adults,
            children: request.children,
            childAges: request.childAges,
            destination: request.destination,
            origin: request.origin
        )

        Task { [weak self] in
            guard let self else { return }
            do {
                _ = try await self.performExplainAIRequest(
                    request: contextRequest,
                    extractedEntities: entity,
                    departureDate: departureDate,
                    returnDate: nil,
                    rooms: 1,
                    cabinType: "Economy",
                    onPartialContent: { partial in
                        RiviAskAIConfiguration.shared.onExplainContent?(partial)
                    }
                )
            } catch {
                Logger.logError(message: "Auto explain-ai request failed", error: error)
                self.logger.error(error)
                if let handler = RiviAskAIConfiguration.shared.onExplainError {
                    await MainActor.run { handler(error) }
                }
            }
        }
    }

    /// Subscribe to SSE events for a search ID
    /// - Parameters:
    ///   - searchId: The search ID to subscribe to
    ///   - onEvent: Callback for received events
    ///   - onError: Callback for connection errors
    public func subscribeToEvents(
        searchId: String,
        config: SSEConfig = .default,
        onState: ((SSEConnectionState) -> Void)? = nil,
        onEvent: @escaping (String) -> Void,
        onError: @escaping (Error) -> Void
    ) {
        let authToken = RiviAskAIConfiguration.shared.authToken ?? ""
        let urlString = "\(RiviAskAIConfiguration.shared.baseURL)/askai/subscribe?searchId=\(searchId)&authorization=\(authToken)"
        guard let url = URL(string: urlString) else {
            let error = NSError(
                domain: "RiviAskAI",
                code: 0,
                userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]
            )
            Logger.logError(message: "Invalid SSE URL: \(urlString)")
            logger.error("Invalid SSE URL: \(urlString)")
            onError(error)
            return
        }

        logger.info("Subscribing to events for searchId: \(searchId)")
        let request = URLRequest(url: url)
        
        Logger.logRequest(url: url, params: ["searchId": searchId, "event": "connect"])
        
        sseClient?.connect(to: url, config: config , request: request, onStateChange: { state in
            onState?(state)
        }, onEvent: { eventData in
            Logger.logResponse(
                url: url,
                statusCode: 200,
                data: eventData.data(using: .utf8) ?? Data()
            )
            onEvent(eventData)
        }, onError: { error in
            Logger.logError(message: "SSE connection error", error: error)
            self.logger.error(error)
            onError(error)
        })
    }
    
    /// Disconnect from the SSE connection
    public func disconnect() {
        logger.debug("Disconnecting SSE client")
        Logger.logRequest(url: URL(string: "\(RiviAskAIConfiguration.shared.baseURL)/disconnect")!, params: ["message": "Disconnecting SSE client"])
        sseClient?.disconnect()
    }
    
    deinit {
        disconnect()
    }
}
