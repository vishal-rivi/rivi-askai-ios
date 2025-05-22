import SwiftUI

/// ViewModel that manages the state and logic for the RiviAskAIButton
public class RiviAskAIViewModel: ObservableObject {
    /// Whether the popup is currently visible
    @Published public var isPopupVisible = false
    
    /// The current text input
    @Published public var inputText = ""
    
    /// The SSE client for handling events
    private var sseClient: SSEClient?
    
    /// Base URL for the SSE API
    private let baseURL: String
    
    /// Filter search parameters
    private let filterSearchParams: FilterSearchParams?
    
    /// Closure called when SSE events are received
    public let onEvent: ((RiviAskAIEvent) -> Void)?
    
    /// Initialize the view model
    /// - Parameters:
    ///   - baseURL: Base URL for the SSE API
    ///   - filterSearchParams: Parameters for filter search API
    ///   - onEvent: Closure called when SSE events are received
    public init(
        baseURL: String = "https://filter-gateway-service.rivi.co/api/v1",
        filterSearchParams: FilterSearchParams? = nil,
        onEvent: ((RiviAskAIEvent) -> Void)?
    ) {
        self.baseURL = baseURL
        self.filterSearchParams = filterSearchParams
        self.onEvent = onEvent
        
        setupSSEConnectionIfNeeded()
    }
    
    private func setupSSEConnectionIfNeeded() {
        guard let itineraryId = filterSearchParams?.itineraryId, let onEvent = onEvent else {
            return
        }
        
        let urlString = "\(baseURL)/subscribe?itineraryId=\(itineraryId)"
        guard let url = URL(string: urlString) else {
            onEvent(.error(NSError(domain: "RiviAskAI", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        
        sseClient = SSEClient()
        sseClient?.connect(
            to: url,
            onEvent: { [weak self] data in
                DispatchQueue.main.async {
                    onEvent(.data(data))
                }
            },
            onError: { [weak self] error in
                DispatchQueue.main.async {
                    onEvent(.error(error))
                }
            }
        )
    }
    
    /// Call the filter search API
    private func callFilterSearchAPI() {
        guard let itineraryId = filterSearchParams?.itineraryId,
              let filterSearchParams = filterSearchParams else {
            return
        }
        
        // Create the URL request
        let urlString = "\(baseURL)/filter-search"
        guard let url = URL(string: urlString) else {
            onEvent?(.error(NSError(domain: "RiviAskAI", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Create request body
        let filterQuery = inputText.isEmpty ? filterSearchParams.filterQuery : inputText
        let requestBody: [String: Any] = [
            "filter_query": filterQuery,
            "itinerary_id": itineraryId,
            "destination": filterSearchParams.destination,
            "checkin": filterSearchParams.checkin,
            "checkout": filterSearchParams.checkout,
            "adult": filterSearchParams.adult,
            "rooms": filterSearchParams.rooms,
            "query_type": filterSearchParams.queryType
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            onEvent?(.error(error))
            return
        }
        
        // Create and start the task
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    self?.onEvent?(.error(error))
                }
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                let error = NSError(
                    domain: "RiviAskAI",
                    code: (response as? HTTPURLResponse)?.statusCode ?? 0,
                    userInfo: [NSLocalizedDescriptionKey: "HTTP error"]
                )
                
                DispatchQueue.main.async {
                    self?.onEvent?(.error(error))
                }
                return
            }
            
            // Notify that the filter search was completed successfully
            DispatchQueue.main.async {
                self?.onEvent?(.filterSearchCompleted)
            }
        }
        
        task.resume()
    }
    
    deinit {
        sseClient?.disconnect()
        onEvent?(.disconnected)
    }
    
    /// Toggle the popup visibility
    public func togglePopup() {
        isPopupVisible.toggle()
    }
    
    /// Set the input text to a selected suggestion
    /// - Parameter suggestion: The suggestion to use
    public func selectSuggestion(_ suggestion: String) {
        inputText = suggestion
    }
    
    /// Call the improve results closure and close the popup
    public func improveResults() {
        callFilterSearchAPI()
        isPopupVisible = false
    }
} 
