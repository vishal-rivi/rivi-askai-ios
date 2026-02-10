import Foundation

/// A client for handling Server-Sent Events (SSE) connections
public class SSEClient {
    private var urlSession: URLSession?
    private var task: URLSessionDataTask?
    
    // State Tracking
    private var isConnected = false
    private var currentUrl: URL? // Required for reconnection
    
    // Callbacks
    private var eventHandler: ((String) -> Void)?
    private var errorHandler: ((Error) -> Void)?
    private var onStateChange: ((SSEConnectionState) -> Void)?
    
    // Parsing Buffer
    private var buffer = ""
    
    // Configuration & Retry State
    private var currentConfig: SSEConfig = .default
    private var currentRetryAttempt = 0
    
    // MARK: - Init
    public init() {}
    
    // MARK: - Helper: State Update
    private func updateState(_ newState: SSEConnectionState) {
        DispatchQueue.main.async { [weak self] in
            self?.onStateChange?(newState)
        }
    }
    
    // MARK: - Public API
    
    /// Start an SSE connection to the specified URL
    /// - Parameters:
    ///   - url: The URL to connect to
    ///   - request: Optional custom URLRequest to use instead of creating one
    ///   - onEvent: Callback for received events
    ///   - onError: Callback for connection errors
    public func connect(
        to url: URL,
        config: SSEConfig = .default,
        request: URLRequest? = nil,
        onStateChange: @escaping (SSEConnectionState) -> Void,
        onEvent: @escaping (String) -> Void,
        onError: @escaping (Error) -> Void
    ) {
        // Save Configuration & Callbacks
        self.currentConfig = config
        self.currentUrl = url
        self.onStateChange = onStateChange
        self.eventHandler = onEvent
        self.errorHandler = onError
        
        // Reset counters
        self.currentRetryAttempt = 0
        
        // Start
        startConnection(url: url, customRequest: request)
    }
    
    /// Internal method to start/restart connection
    private func startConnection(url: URL, customRequest: URLRequest? = nil) {
    
        disconnect(notify: false)
        
        updateState(.connecting)
        
        // Setup Session Config
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = currentConfig.connectTimeout
        sessionConfig.timeoutIntervalForResource = TimeInterval(Double.infinity)
        
        let delegate = SSESessionDelegate(client: self)
        self.urlSession = URLSession(configuration: sessionConfig, delegate: delegate, delegateQueue: nil)
        
        // Setup Request
        var finalRequest: URLRequest
        if let r = customRequest {
            finalRequest = r
            // If the user didn't set a custom timeout, use the config
            if finalRequest.timeoutInterval == 60.0 {
                finalRequest.timeoutInterval = TimeInterval(Double.infinity)
            }
        } else {
            finalRequest = URLRequest(url: url)
            finalRequest.timeoutInterval = TimeInterval(Double.infinity)
        }
        
        // Ensure Headers
        if finalRequest.value(forHTTPHeaderField: "Accept") == nil {
            finalRequest.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        }
        
        task = urlSession?.dataTask(with: finalRequest)
        task?.resume()
        isConnected = true
    }
    
    // MARK: - Data Processing
    
    func processData(_ data: Data) {
        // If this is the first data received, we are officially connected
        if isConnected {
             if currentRetryAttempt > 0 || isReconnectingState() {
                 currentRetryAttempt = 0
                 updateState(.connected)
             } else {
                 updateState(.connected)
             }
        }
        
        guard let dataString = String(data: data, encoding: .utf8) else {
            print("Error: Received non-UTF8 data")
            return
        }
        
        buffer += dataString
        
        while let eventEndIndex = buffer.range(of: "\n\n") {
            let eventString = String(buffer[..<eventEndIndex.lowerBound])
            buffer = String(buffer[eventEndIndex.upperBound...])
            
            if !eventString.isEmpty {
                var jsonString = eventString
                if let dataPrefix = jsonString.range(of: "data: ") {
                    jsonString = String(jsonString[dataPrefix.upperBound...])
                }
                
                if jsonString.contains("\ndata: ") {
                    jsonString = jsonString.components(separatedBy: "\ndata: ")
                        .joined(separator: "")
                }
                
                DispatchQueue.main.async { [weak self] in
                    self?.eventHandler?(jsonString)
                }
            }
        }
    }
    
    private func isReconnectingState() -> Bool {
        // Simple helper to check if we were previously retrying
        return currentRetryAttempt > 0
    }
    
    // MARK: - Error Handling & Retry Logic
    
    func handleError(_ error: Error) {
        print("SSE connection error: \(error.localizedDescription)")
        
        // Notify the generic error handler
        DispatchQueue.main.async { [weak self] in
            self?.errorHandler?(error)
        }
        
        // Determine Reason
        let reason: DisconnectReason
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut: reason = .timeout
            case .cancelled: reason = .cancelled
            case .notConnectedToInternet, .networkConnectionLost:
                reason = .networkError(message: urlError.localizedDescription)
            default: reason = .unknown(cause: error)
            }
        } else {
            reason = .unknown(cause: error)
        }
        
        // Check Retry Policy
        if reason.isRecoverable && currentRetryAttempt < currentConfig.maxReconnectAttempts {
            attemptReconnect()
        } else {
            updateState(.disconnected(reason: reason))
        }
    }
    
    private func attemptReconnect() {
        currentRetryAttempt += 1
        
        // Exponential Backoff: initial * (multiplier ^ (attempt - 1))
        let exponent = Double(currentRetryAttempt - 1)
        let backoff = currentConfig.initialReconnectDelay * pow(currentConfig.reconnectBackoffMultiplier, exponent)
        let delay = min(backoff, currentConfig.maxReconnectDelay)
        
        // Notify UI
        updateState(.reconnecting(
            attempt: currentRetryAttempt,
            maxAttempts: currentConfig.maxReconnectAttempts,
            nextRetryIn: delay
        ))
        
        // Schedule Retry
        DispatchQueue.global().asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self, let url = self.currentUrl else { return }
            self.startConnection(url: url)
        }
    }
    
    // MARK: - Disconnect
    
    public func disconnect(notify: Bool = true) {
        if isConnected || task != nil {
            task?.cancel()
            urlSession?.invalidateAndCancel()
            isConnected = false
            buffer = ""
            
            if notify {
                updateState(.disconnected(reason: .cancelled))
            }
        }
    }
    
    deinit {
        disconnect(notify: false)
    }
}

// MARK: - Session Delegate
private class SSESessionDelegate: NSObject, URLSessionDataDelegate {
    private weak var client: SSEClient?
    
    init(client: SSEClient) {
        self.client = client
        super.init()
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        client?.processData(data)
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        completionHandler(.allow)
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            client?.handleError(error)
        }
    }
    
    func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        if let error = error {
            client?.handleError(error)
        }
    }
}
