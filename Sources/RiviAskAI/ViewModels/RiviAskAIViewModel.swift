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
//            print("===== SSE CONNECTION SKIPPED =====")
//            print("Missing searchId or authToken")
//            print("================================")
            return
        }
        
        RiviAskAILogger.log("Setting up SSE connection for search: \(searchId)", level: .debug)
//        print("===== VIEWMODEL: STARTING SSE CONNECTION =====")
//        print("Search ID: \(searchId)")
//        print("Auth Token available: \(authToken.isEmpty ? "No" : "Yes")")
//        print("=============================================")
        
        // Disconnect any existing connection first
        apiService.disconnect()
        
        apiService.subscribeToEvents(
            searchId: searchId,
            authToken: authToken,
            onEvent: { [weak self] data in
//                print("===== VIEWMODEL: SSE EVENT RECEIVED =====")
//                print("Data length: \(data.count) characters")
//                print("Event data: \(data.prefix(100))...")
//                print("========================================")
                
                DispatchQueue.main.async {
                    RiviAskAILogger.log("Forwarding SSE data event to handler", level: .debug)
                    
                    // Forward the raw data event directly
                    self?.onEvent(.data(data))
                }
            },
            onError: { [weak self] error in
//                print("===== VIEWMODEL: SSE ERROR RECEIVED =====")
//                print("Error: \(error.localizedDescription)")
//                print("========================================")
                
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
                        
                        // Emit the chipsExtracted event
                        RiviAskAILogger.log("Emitting chipsExtracted event with \(extractedChips.count) chips")
                        self?.onEvent(.chipsExtracted(extractedChips))
                    } else {
                        RiviAskAILogger.log("No chips extracted from filter search response", level: .warning)
                    }
                    
                    self?.onEvent(.filterSearchCompleted)
                    
                    // Close the popup after successfully extracting chips
                    self?.isPopupVisible = false
                    
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
    }
    
    /// Call the filterSearch API with the current input text
    /// This can be called directly when chips are removed
    public func callFilterSearchWithCurrentText() {
        RiviAskAILogger.log("Calling filter search with remaining chips: \(inputText)", level: .info)
        callFilterSearchAPI()
    }
    
    /// Call the filterSearch API with a specific query
    /// This can be called from external components
    public func callFilterSearchWithQuery(_ query: String) {
        inputText = query
        callFilterSearchAPI()
    }
} 
