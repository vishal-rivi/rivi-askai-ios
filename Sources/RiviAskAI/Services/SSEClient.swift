import Foundation

/// A client for handling Server-Sent Events (SSE) connections
public class SSEClient {
    private var urlSession: URLSession?
    private var task: URLSessionDataTask?
    
    // Callbacks
    private var eventHandler: ((String) -> Void)?
    private var errorHandler: ((Error) -> Void)?
    private var onStateChange: ((SSEConnectionState) -> Void)?
    
    // Configuration
    private var currentConfig: SSEConfig = .default
    private var currentUrl: URL?
    
    // MARK: - Thread Safety & Mutable State
    // An NSRecursiveLock ensures thread safety and prevents deadlocks
    // if a method re-enters another locked method on the same thread.
    private let lock = NSRecursiveLock()
    
    private var isConnected = false
    private var currentRetryAttempt = 0
    private var hasBroadcastedConnectedState = false
    
    // Buffers
    private var dataBuffer = Data()
    private var buffer = ""
    
    // MARK: - Init
    public init() {}
    
    // MARK: - Helper: State Update
    private func updateState(_ newState: SSEConnectionState) {
        DispatchQueue.main.async { [weak self] in
            self?.onStateChange?(newState)
        }
    }
    
    // MARK: - Public API
    
    public func connect(
        to url: URL,
        config: SSEConfig = .default,
        request: URLRequest? = nil,
        onStateChange: @escaping (SSEConnectionState) -> Void,
        onEvent: @escaping (String) -> Void,
        onError: @escaping (Error) -> Void
    ) {
        disconnect(notify: false)
        
        lock.lock()
        self.currentConfig = config
        self.currentUrl = url
        self.onStateChange = onStateChange
        self.eventHandler = onEvent
        self.errorHandler = onError
        self.currentRetryAttempt = 0
        self.hasBroadcastedConnectedState = false
        lock.unlock()
        
        startConnection(url: url, customRequest: request)
    }
    
    private func startConnection(url: URL, customRequest: URLRequest? = nil) {
        updateState(.connecting)
        
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = currentConfig.connectTimeout
        sessionConfig.timeoutIntervalForResource = TimeInterval(Double.infinity)
        
        let delegate = SSESessionDelegate(client: self)
        
        lock.lock()
        self.urlSession = URLSession(configuration: sessionConfig, delegate: delegate, delegateQueue: nil)
        
        var finalRequest: URLRequest
        if let r = customRequest {
            finalRequest = r
            if finalRequest.timeoutInterval == 60.0 {
                finalRequest.timeoutInterval = TimeInterval(Double.infinity)
            }
        } else {
            finalRequest = URLRequest(url: url)
            finalRequest.timeoutInterval = TimeInterval(Double.infinity)
        }
        
        if finalRequest.value(forHTTPHeaderField: "Accept") == nil {
            finalRequest.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        }
        
        self.task = urlSession?.dataTask(with: finalRequest)
        self.task?.resume()
        self.isConnected = true
        lock.unlock()
    }
    
    // MARK: - Data Processing
    
    func processData(_ data: Data) {
        lock.lock()
        
        // 1. Handle Connection State
        if isConnected && !hasBroadcastedConnectedState {
            currentRetryAttempt = 0
            hasBroadcastedConnectedState = true
            updateState(.connected)
        }
        
        // 2. Handle Raw Bytes to prevent UTF-8 splitting
        dataBuffer.append(data)
        
        guard let validString = String(data: dataBuffer, encoding: .utf8) else {
            lock.unlock() // Wait for next packet to complete the character
            return
        }
        
        // 3. Move to String Buffer
        dataBuffer.removeAll()
        buffer += validString
        
        var eventsToProcess: [String] = []
        
        // 4. Safely extract complete events
        while let eventEndRange = buffer.range(of: "\n\n") {
            let eventString = String(buffer[..<eventEndRange.lowerBound])
            buffer = String(buffer[eventEndRange.upperBound...])
            
            if !eventString.isEmpty {
                eventsToProcess.append(eventString)
            }
        }
        
        lock.unlock()
        
        // 5. Parse and dispatch OUTSIDE the lock to keep the parser fast
        for eventString in eventsToProcess {
            parseAndDispatch(eventString)
        }
    }
    
    private func parseAndDispatch(_ eventString: String) {
        var jsonString = eventString
        
        if let dataPrefix = jsonString.range(of: "data: ") {
            jsonString = String(jsonString[dataPrefix.upperBound...])
        }
        
        if jsonString.contains("\ndata: ") {
            jsonString = jsonString.components(separatedBy: "\ndata: ").joined(separator: "")
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.eventHandler?(jsonString)
        }
    }
    
    // MARK: - Error Handling & Retry Logic
    
    func handleError(_ error: Error) {
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

        lock.lock()
        let shouldRetry = reason.isRecoverable && currentRetryAttempt < currentConfig.maxReconnectAttempts
        let attempt = currentRetryAttempt
        lock.unlock()

        if shouldRetry {
            // Recoverable (e.g. the connection was suspended while the app was backgrounded) — retry
            // silently. Only surface an error to the UI once retries are exhausted or the error is fatal,
            // so a transient blip doesn't flash an incorrect "offline" state.
            attemptReconnect(currentAttempt: attempt)
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.errorHandler?(error)
            }
            updateState(.disconnected(reason: reason))
        }
    }
    
    private func attemptReconnect(currentAttempt: Int) {
        lock.lock()
        currentRetryAttempt += 1
        let attemptForMath = currentRetryAttempt
        self.hasBroadcastedConnectedState = false
        lock.unlock()
        
        let exponent = Double(attemptForMath - 1)
        let backoff = currentConfig.initialReconnectDelay * pow(currentConfig.reconnectBackoffMultiplier, exponent)
        let delay = min(backoff, currentConfig.maxReconnectDelay)
        
        updateState(.reconnecting(
            attempt: attemptForMath,
            maxAttempts: currentConfig.maxReconnectAttempts,
            nextRetryIn: delay
        ))
        
        DispatchQueue.global().asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self, let url = self.currentUrl else { return }
            self.startConnection(url: url)
        }
    }
    
    // MARK: - Disconnect
    
    public func disconnect(notify: Bool = true) {
        lock.lock()
        defer { lock.unlock() }
        
        if isConnected || task != nil {
            task?.cancel()
            urlSession?.invalidateAndCancel()
            
            isConnected = false
            hasBroadcastedConnectedState = false
            buffer = ""
            dataBuffer.removeAll()
            
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
