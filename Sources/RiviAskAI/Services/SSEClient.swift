import Foundation

/// A client for handling Server-Sent Events (SSE) connections
public class SSEClient {
    private var urlSession: URLSession?
    private var task: URLSessionDataTask?
    private var isConnected = false
    private var eventHandler: ((String) -> Void)?
    private var errorHandler: ((Error) -> Void)?
    private var buffer = ""
    
    /// Initialize the SSE client
    public init() {
        RiviAskAILogger.log("SSEClient initialized", level: .debug)
    }
    
    /// Start an SSE connection to the specified URL
    /// - Parameters:
    ///   - url: The URL to connect to
    ///   - request: Optional custom URLRequest to use instead of creating one
    ///   - onEvent: Callback for received events
    ///   - onError: Callback for connection errors
    public func connect(
        to url: URL,
        request: URLRequest? = nil,
        onEvent: @escaping (String) -> Void,
        onError: @escaping (Error) -> Void
    ) {
        disconnect()
        
        self.eventHandler = onEvent
        self.errorHandler = onError
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = TimeInterval(Double.infinity)
        config.timeoutIntervalForResource = TimeInterval(Double.infinity)
        
        let delegate = SSESessionDelegate(client: self)
        self.urlSession = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
        
        var finalRequest: URLRequest
        if let customRequest = request {
            finalRequest = customRequest
            finalRequest.timeoutInterval = TimeInterval(Double.infinity)
            if finalRequest.value(forHTTPHeaderField: "Accept") == nil {
                finalRequest.setValue("text/event-stream", forHTTPHeaderField: "Accept")
            }
        } else {
            finalRequest = URLRequest(url: url)
            finalRequest.timeoutInterval = TimeInterval(Double.infinity)
            finalRequest.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        }
        
        RiviAskAILogger.log("Connecting to SSE endpoint: \(url.absoluteString)", level: .debug)
        
        task = urlSession?.dataTask(with: finalRequest)
        task?.resume()
        isConnected = true
        RiviAskAILogger.log("SSE connection started", level: .info)
    }
    
    /// Process received data from the SSE connection
    /// - Parameter data: The data received
    func processData(_ data: Data) {
        guard let dataString = String(data: data, encoding: .utf8) else {
            RiviAskAILogger.log("Received non-UTF8 data", level: .warning)
            print("===== SSE RECEIVED NON-UTF8 DATA =====")
            print("Data bytes: \(data.count)")
            print("===================================")
            return
        }
            
//        print("===== SSE RAW DATA RECEIVED =====")
//        print("Data: \(dataString)")
//        print("===============================")
            
        buffer += dataString
        
        // Process any complete events in the buffer
        while let eventEndIndex = buffer.range(of: "\n\n") {
            let eventString = String(buffer[..<eventEndIndex.lowerBound])
            buffer = String(buffer[eventEndIndex.upperBound...])
            
            if !eventString.isEmpty {
                let truncatedString = eventString.count > 100 ? eventString.prefix(100) + "..." : eventString
                RiviAskAILogger.log("Received SSE event: \(truncatedString)", level: .debug)
                print("===== SSE EVENT PROCESSED =====")
                print("Event: \(eventString)")
                print("============================")
                DispatchQueue.main.async { [weak self] in
                    self?.eventHandler?(eventString)
                }
            }
        }
    }
    
    /// Handle errors from the SSE connection
    /// - Parameter error: The error that occurred
    func handleError(_ error: Error) {
        RiviAskAILogger.logError("SSE connection error", error: error)
        DispatchQueue.main.async { [weak self] in
            self?.errorHandler?(error)
        }
    }
    
    /// Disconnect from the current SSE connection
    public func disconnect() {
        if isConnected {
            RiviAskAILogger.log("Disconnecting SSE connection", level: .debug)
            task?.cancel()
            urlSession?.invalidateAndCancel()
            isConnected = false
            buffer = ""
        }
    }
    
    deinit {
        disconnect()
        RiviAskAILogger.log("SSEClient deinitializing", level: .debug)
    }
}

/// URLSession delegate for handling SSE connection events
private class SSESessionDelegate: NSObject, URLSessionDataDelegate {
    private weak var client: SSEClient?
    
    init(client: SSEClient) {
        self.client = client
        super.init()
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        print("===== SSE DELEGATE: DATA RECEIVED =====")
        print("Data size: \(data.count) bytes")
        print("=====================================")
        client?.processData(data)
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        print("===== SSE DELEGATE: RESPONSE RECEIVED =====")
        if let httpResponse = response as? HTTPURLResponse {
            print("Status code: \(httpResponse.statusCode)")
            print("Headers: \(httpResponse.allHeaderFields)")
        } else {
            print("Non-HTTP response received")
        }
        print("=========================================")
        completionHandler(.allow)
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        print("===== SSE DELEGATE: TASK COMPLETED =====")
        if let error = error {
            print("Error: \(error.localizedDescription)")
            client?.handleError(error)
        } else {
            print("Task completed successfully")
        }
        print("======================================")
    }
    
    func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        print("===== SSE DELEGATE: SESSION INVALIDATED =====")
        if let error = error {
            print("Error: \(error.localizedDescription)")
            client?.handleError(error)
        } else {
            print("Session invalidated without error")
        }
        print("==========================================")
    }
} 
