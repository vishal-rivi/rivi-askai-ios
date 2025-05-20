import Foundation

/// A client for handling Server-Sent Events (SSE) connections
public class SSEClient {
    private var eventSource: URLSessionDataTask?
    private var session: URLSession
    
    /// Initialize the SSE client
    public init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = TimeInterval(Double.infinity)
        config.timeoutIntervalForResource = TimeInterval(Double.infinity)
        self.session = URLSession(configuration: config)
    }
    
    /// Start an SSE connection to the specified URL
    /// - Parameters:
    ///   - url: The URL to connect to
    ///   - onEvent: Callback for received events
    ///   - onError: Callback for connection errors
    public func connect(
        to url: URL,
        onEvent: @escaping (String) -> Void,
        onError: @escaping (Error) -> Void
    ) {
        disconnect()
        
        var request = URLRequest(url: url)
        request.timeoutInterval = TimeInterval(Double.infinity)
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        
        eventSource = session.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                onError(error)
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                onError(NSError(domain: "SSEClient", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response"]))
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                onError(NSError(domain: "SSEClient", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP error \(httpResponse.statusCode)"]))
                return
            }
            
            if let data = data, let dataString = String(data: data, encoding: .utf8) {
                // Process the SSE data
                onEvent(dataString)
            }
            
            // Reconnect after a successful response
            if let url = request.url {
                DispatchQueue.main.async {
                    self?.connect(to: url, onEvent: onEvent, onError: onError)
                }
            }
        }
        
        eventSource?.resume()
    }
    
    /// Disconnect from the current SSE connection
    public func disconnect() {
        eventSource?.cancel()
        eventSource = nil
    }
    
    deinit {
        disconnect()
    }
} 