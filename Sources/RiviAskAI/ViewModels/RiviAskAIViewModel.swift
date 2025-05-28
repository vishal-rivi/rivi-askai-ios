import SwiftUI

/// ViewModel that manages the state and logic for the RiviAskAIButton
public class RiviAskAIViewModel: ObservableObject {
    /// Whether the popup is currently visible
    @Published public var isPopupVisible = false
    
    /// The current text input
    @Published public var inputText = ""
    
    /// Extracted chips from the API responses
    @Published public var chips: Set<String> = []
    
    /// API service
    private let apiService: RiviAskAIServiceProtocol
    
    /// Filter search parameters
    public let filterSearchParams: FilterSearchParams?
    
    /// Closure called when SSE events are received
    public let onEvent: ((RiviAskAIEvent) -> Void)
    
    /// Initialize the view model
    /// - Parameters:
    ///   - apiService: Service for handling API calls
    ///   - filterSearchParams: Parameters for filter search API
    ///   - onEvent: Closure called when SSE events are received
    public init(
        apiService: RiviAskAIServiceProtocol = RiviAskAIService(),
        filterSearchParams: FilterSearchParams? = nil,
        onEvent: @escaping ((RiviAskAIEvent) -> Void)
    ) {
        self.apiService = apiService
        self.filterSearchParams = filterSearchParams
        self.onEvent = onEvent
        
        RiviAskAILogger.log("RiviAskAIViewModel initialized", level: .debug)
        setupSSEConnectionIfNeeded()
    }
    
    private func setupSSEConnectionIfNeeded() {
        guard let searchId = filterSearchParams?.searchId,
              let authToken = filterSearchParams?.authToken else {
            RiviAskAILogger.log("Skipping SSE setup - missing searchId or authToken", level: .warning)
            print("===== SSE CONNECTION SKIPPED =====")
            print("Missing searchId or authToken")
            print("================================")
            return
        }
        
        RiviAskAILogger.log("Setting up SSE connection for search: \(searchId)", level: .debug)
        print("===== VIEWMODEL: STARTING SSE CONNECTION =====")
        print("Search ID: \(searchId)")
        print("Auth Token available: \(authToken.isEmpty ? "No" : "Yes")")
        print("=============================================")
        
        // Disconnect any existing connection first
        apiService.disconnect()
        
        apiService.subscribeToEvents(
            searchId: searchId,
            authToken: authToken,
            onEvent: { [weak self] data in
                print("===== VIEWMODEL: SSE EVENT RECEIVED =====")
                print("Data length: \(data.count) characters")
                print("Event data: \(data.prefix(100))...")
                print("========================================")
                
                DispatchQueue.main.async {
                    RiviAskAILogger.log("Forwarding SSE data event to handler", level: .debug)
                    
                    // Try to decode as FlightResponse
                    self?.tryDecodeAsFlightResponse(data)
                    
                    // Also forward the raw data event
                    self?.onEvent(.data(data))
                }
            },
            onError: { [weak self] error in
                print("===== VIEWMODEL: SSE ERROR RECEIVED =====")
                print("Error: \(error.localizedDescription)")
                print("========================================")
                
                DispatchQueue.main.async {
                    RiviAskAILogger.logError("Forwarding SSE error to handler", error: error)
                    self?.onEvent(.error(error))
                    
                    // Try to reconnect after error
                    DispatchQueue.global().asyncAfter(deadline: .now() + 3.0) {
                        self?.setupSSEConnectionIfNeeded()
                    }
                }
            }
        )
    }
    
    /// Tries to decode SSE data as FlightResponse
    private func tryDecodeAsFlightResponse(_ sseData: String) {
        // Extract JSON data from SSE format
        var jsonString = sseData
        
        // Handle different SSE data formats (similar to SSEDataProcessor.parseSSEData)
        if sseData.contains("Ask AI event: data(") {
            // Extract the data part inside quotes
            if let dataStartIndex = sseData.range(of: "data(\"")?.upperBound,
               let dataEndIndex = sseData.range(of: "\")", options: .backwards)?.lowerBound {
                let dataContent = String(sseData[dataStartIndex..<dataEndIndex])
                    .replacingOccurrences(of: "\\\"", with: "\"")
                    .replacingOccurrences(of: "\\\\", with: "\\")
                
                if let innerJsonStartIndex = dataContent.range(of: "data: ")?.upperBound {
                    jsonString = String(dataContent[innerJsonStartIndex...])
                } else {
                    jsonString = dataContent
                }
            }
        } else if let jsonStartIndex = sseData.range(of: "data: ")?.upperBound {
            jsonString = String(sseData[jsonStartIndex...])
        }
        
        guard let jsonData = jsonString.data(using: .utf8) else {
            RiviAskAILogger.logError("Failed to convert SSE data to UTF-8 data")
            return
        }
        
        do {
            let decoder = JSONDecoder()
            let flightResponse = try decoder.decode(FlightResponse.self, from: jsonData)
            RiviAskAILogger.log("Successfully decoded FlightResponse from SSE data", level: .info)
            print("===== FLIGHT RESPONSE DECODED =====")
            print("Request ID: \(flightResponse.requestID)")
            print("Status: \(flightResponse.status)")
            print("Flight response fetched successfully")
            print("==================================")
            
            // Emit the flight response event
            print("===== EMITTING FLIGHT RESPONSE EVENT =====")
            print("Calling onEvent with flightResponse")
            print("=======================================")
            self.onEvent(.flightResponse(flightResponse))
        } catch {
            // This is expected for events that are not flight responses
            RiviAskAILogger.log("Could not decode SSE data as FlightResponse: \(error.localizedDescription)", level: .debug)
        }
    }
    
    /// Call the filter search API
    private func callFilterSearchAPI() {
        guard let filterSearchParams = filterSearchParams else {
            RiviAskAILogger.log("Cannot call filter search API - missing parameters", level: .warning)
            return
        }
        
        RiviAskAILogger.log("Calling filter search API with query: \(inputText)", level: .info)
        apiService.filterSearch(
            query: inputText,
            params: filterSearchParams
        ) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let extractedChips):
                    RiviAskAILogger.log("Filter search API call successful", level: .info)
                    
                    // Update chips if any were extracted
                    if !extractedChips.isEmpty {
                        RiviAskAILogger.log("Found \(extractedChips.count) chips in filter search response", level: .info)
                        self?.chips = extractedChips
                        
                        // Print the chips for now as requested
                        print("===== EXTRACTED CHIPS =====")
                        extractedChips.forEach { chip in
                            print("- \(chip)")
                        }
                        print("==========================")
                        
                        // Emit the chipsExtracted event
                        RiviAskAILogger.log("Emitting chipsExtracted event with \(extractedChips.count) chips")
                        self?.onEvent(.chipsExtracted(extractedChips))
                    } else {
                        RiviAskAILogger.log("No chips extracted from filter search response", level: .warning)
                    }
                    
                    self?.onEvent(.filterSearchCompleted)
                    
                case .failure(let error):
                    RiviAskAILogger.logError("Filter search API call failed", error: error)
                    self?.onEvent(.error(error))
                }
            }
        }
    }
    
    deinit {
        RiviAskAILogger.log("RiviAskAIViewModel deinitializing", level: .debug)
        apiService.disconnect()
        onEvent(.disconnected)
    }
    
    /// Toggle the popup visibility
    public func togglePopup() {
        isPopupVisible.toggle()
        RiviAskAILogger.log("Popup visibility toggled to: \(isPopupVisible)", level: .debug)
    }
    
    /// Set the input text to a selected suggestion
    /// - Parameter suggestion: The suggestion to use
    public func selectSuggestion(_ suggestion: String) {
        RiviAskAILogger.log("Selected suggestion: \(suggestion)", level: .debug)
        inputText = suggestion
    }
    
    /// Call the improve results closure and close the popup
    public func improveResults() {
        RiviAskAILogger.log("Improving results with query: \(inputText)", level: .info)
        callFilterSearchAPI()
        isPopupVisible = false
    }
    
    /// Call the filterSearch API with the current input text
    /// This can be called directly when chips are removed
    public func callFilterSearchWithCurrentText() {
        RiviAskAILogger.log("Calling filter search with remaining chips: \(inputText)", level: .info)
        callFilterSearchAPI()
    }
} 
