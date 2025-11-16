import Foundation

/// A client for handling Server-Sent Events (SSE) connections
public class SSEClient {
    private var urlSession: URLSession?
    private var task: URLSessionDataTask?
    private var isConnected = false
    private var eventHandler: ((String) -> Void)?
    private var errorHandler: ((Error) -> Void)?
    private var buffer = ""
    
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
        
        task = urlSession?.dataTask(with: finalRequest)
        task?.resume()
        isConnected = true
    }
    
    /// Process received data from the SSE connection
    /// - Parameter data: The data received
    func processData(_ data: Data) {
        guard let dataString = String(data: data, encoding: .utf8) else {
            Logger.logError(message: "Received non-UTF8 data")
            return
        }
        
        buffer += dataString
        
        // Process any complete events in the buffer
        while let eventEndIndex = buffer.range(of: "\n\n") {
            let eventString = String(buffer[..<eventEndIndex.lowerBound])
            buffer = String(buffer[eventEndIndex.upperBound...])
            
            if !eventString.isEmpty {
                // Extract the JSON data from the event string
                // SSE format typically has "data: " prefix followed by the actual data
                var jsonString = eventString
                
                // If the event starts with "data: ", remove that prefix
                if let dataPrefix = jsonString.range(of: "data: ") {
                    jsonString = String(jsonString[dataPrefix.upperBound...])
                }
                
                // Handle multi-line data fields (each line starting with "data: ")
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
    
    /// Handle errors from the SSE connection
    /// - Parameter error: The error that occurred
    func handleError(_ error: Error) {
        Logger.logError(message: "SSE connection error", error: error)
        DispatchQueue.main.async { [weak self] in
            self?.errorHandler?(error)
        }
    }
    
    /// Disconnect from the current SSE connection
    public func disconnect() {
        if isConnected {
            task?.cancel()
            urlSession?.invalidateAndCancel()
            isConnected = false
            buffer = ""
        }
    }
    
    deinit {
        disconnect()
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
