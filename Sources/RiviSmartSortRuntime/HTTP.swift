import Foundation
import RiviSmartSortContract

// HTTP for the runtime (spec 6.2; web: src/runtime/http.ts).

/// The only four paths the runtime ever requests.
public enum Endpoint: String, Sendable {
    case ask = "/api/v1/askai"
    case sortBest = "/api/v1/askai/sort-best"
    case explain = "/api/v1/askai/explain-ai"
    case subscribe = "/api/v1/askai/subscribe"
}

/// Watchdog for the ask / sort-best POST and an explain stream with no frame.
public let watchdogMs = 30_000

// MARK: - Transport

public struct RiviHTTPRequest: Sendable {
    public var method: String
    public var url: URL
    public var headers: [String: String]
    public var body: Data?
}

public struct RiviHTTPResponse: Sendable {
    public var status: Int
    /// The body in chunks. Iterating it after the request was cancelled ends it.
    public var body: AsyncThrowingStream<[UInt8], Error>
    /// Stops reading the body and releases the connection.
    public var cancel: @Sendable () -> Void

    public init(status: Int, body: AsyncThrowingStream<[UInt8], Error>, cancel: @escaping @Sendable () -> Void = {}) {
        self.status = status
        self.body = body
        self.cancel = cancel
    }
}

/// The network seam. `URLSessionTransport` in production, a fake in tests.
public protocol RiviTransport: Sendable {
    /// Resolves once the response headers arrive. Honours task cancellation.
    func send(_ request: RiviHTTPRequest) async throws -> RiviHTTPResponse
}

/// Streams response bodies with `URLSession.bytes(for:)`, read off the main actor in chunks
/// that end at a newline (or 4 KiB), so line framing stays cheap.
public struct URLSessionTransport: RiviTransport {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func send(_ request: RiviHTTPRequest) async throws -> RiviHTTPResponse {
        var urlRequest = URLRequest(url: request.url)
        urlRequest.httpMethod = request.method
        urlRequest.httpBody = request.body
        // Streams stay open for minutes; the runtime's own watchdogs handle silence.
        urlRequest.timeoutInterval = 300
        for (name, value) in request.headers { urlRequest.setValue(value, forHTTPHeaderField: name) }
        let (bytes, response) = try await session.bytes(for: urlRequest)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        let (stream, continuation) = AsyncThrowingStream<[UInt8], Error>.makeStream()
        let reader = Task.detached {
            var chunk: [UInt8] = []
            chunk.reserveCapacity(4096)
            do {
                for try await byte in bytes {
                    chunk.append(byte)
                    if byte == 0x0A || chunk.count >= 4096 {
                        continuation.yield(chunk)
                        chunk.removeAll(keepingCapacity: true)
                    }
                }
                if !chunk.isEmpty { continuation.yield(chunk) }
                continuation.finish()
            } catch {
                continuation.finish(throwing: error)
            }
        }
        continuation.onTermination = { _ in reader.cancel() }
        return RiviHTTPResponse(status: status, body: stream, cancel: {
            reader.cancel()
            bytes.task.cancel()
        })
    }
}

// MARK: - Errors

/// A failure the runtime turns into a `Failed` input. Its message never contains a URL.
public struct RequestFailure: Error, Sendable {
    public let error: RiviError
}

public enum RuntimeErrors {
    public static let network = RiviError(kind: .network, message: "Network request failed", retryable: true)
    public static let timeout = RiviError(kind: .timeout, message: "No response within 30 s", retryable: true)
    public static let authRejected = RiviError(
        kind: .auth,
        message: "The gateway rejected the token twice (HTTP 401). Supply the new token through auth.",
        retryable: false
    )
    public static let authUnavailable = RiviError(kind: .auth, message: "auth() did not return a token", retryable: true)
    public static let askNotJSON = RiviError(kind: .server, message: "The ask response was not JSON", retryable: true)
    public static let streamExhausted = RiviError(kind: .stream, message: "The ranking stream failed 5 times in a row", retryable: true)
    public static let noRanking = RiviError(kind: .timeout, message: "No ranking within 30 s", retryable: true)

    public static func server(_ status: Int) -> RiviError {
        RiviError(kind: .server, message: "HTTP \(status)", retryable: status >= 500 || status == 429)
    }

    public static func stream(_ message: String) -> RiviError {
        RiviError(kind: .stream, message: message.isEmpty ? "The ranking stream reported an error" : message, retryable: true)
    }
}

func toRiviError(_ error: Error) -> RiviError {
    (error as? RequestFailure)?.error ?? RuntimeErrors.network
}

// MARK: - Requests

public struct HTTPConfig: Sendable {
    public var baseURL: String
    public var tenant: String
    public var tier: String
    public var metadata: JSONObject
    /// Resolved per request. A 401 resolves it once more and retries once.
    public var auth: @Sendable () async throws -> String
    public var transport: RiviTransport
    public var logger: RiviLogger = SilentRiviLogger()
}

private func trimBase(_ baseURL: String) -> String {
    var base = baseURL
    while base.hasSuffix("/") { base.removeLast() }
    return base
}

/// `encodeURIComponent`.
private func encodeComponent(_ value: String) -> String {
    var allowed = CharacterSet.alphanumerics.intersection(CharacterSet(charactersIn: Unicode.Scalar(0)..<Unicode.Scalar(128)))
    allowed.insert(charactersIn: "-_.!~*'()")
    return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
}

func endpointURL(_ baseURL: String, _ endpoint: Endpoint) -> URL? {
    URL(string: trimBase(baseURL) + endpoint.rawValue)
}

/// The ranking stream URL. The token travels in the query string (spec Q5), so this is the only
/// place the URL is built, and nothing in the runtime logs it or puts it in an error.
func subscribeURL(_ baseURL: String, searchId: String, token: String) -> URL? {
    URL(string: trimBase(baseURL) + Endpoint.subscribe.rawValue +
        "?searchId=\(encodeComponent(searchId))&authorization=\(encodeComponent(token))")
}

func buildHeaders(_ config: HTTPConfig, token: String, accept: String = "application/json") -> [String: String] {
    [
        "authorization": token,
        "tenant-name": config.tenant,
        "tenant-tier": config.tier,
        "metadata": JSONValue.object(config.metadata).serialized(),
        "Content-Type": "application/json",
        "Accept": accept,
    ]
}

enum SendTarget: Sendable {
    case post(Endpoint, body: JSONValue)
    case subscribe(searchId: String)
}

private func resolveToken(_ config: HTTPConfig) async throws -> String {
    let token: String
    do {
        token = try await config.auth()
    } catch {
        try Task.checkCancellation()
        throw RequestFailure(error: RuntimeErrors.authUnavailable)
    }
    try Task.checkCancellation()
    guard !token.isEmpty else { throw RequestFailure(error: RuntimeErrors.authUnavailable) }
    return token
}

private func attempt(_ config: HTTPConfig, _ target: SendTarget, token: String,
                     onIssue: @Sendable () async -> Void) async throws -> RiviHTTPResponse {
    let request: RiviHTTPRequest
    switch target {
    case let .post(endpoint, body):
        guard let url = endpointURL(config.baseURL, endpoint) else { throw RequestFailure(error: RuntimeErrors.network) }
        request = RiviHTTPRequest(method: "POST", url: url, headers: buildHeaders(config, token: token),
                                  body: Data(body.serialized().utf8))
    case .subscribe(let searchId):
        guard let url = subscribeURL(config.baseURL, searchId: searchId, token: token) else {
            throw RequestFailure(error: RuntimeErrors.network)
        }
        request = RiviHTTPRequest(method: "GET", url: url,
                                  headers: buildHeaders(config, token: token, accept: "text/event-stream"), body: nil)
    }
    let logger = config.logger
    let endpoint: Endpoint
    switch target {
    case let .post(postEndpoint, body):
        endpoint = postEndpoint
        logger.info(LogFormat.request("POST", postEndpoint, details: [("tenant", "\(config.tenant) / \(config.tier)")],
                                      body: logger.isEnabled(.debug) ? body : nil))
    case .subscribe(let searchId):
        endpoint = .subscribe
        logger.info(LogFormat.request("GET", .subscribe, details: [("searchId", searchId)], body: nil))
    }
    await onIssue()
    let started = Date()
    do {
        let response = try await config.transport.send(request)
        let ms = Int(Date().timeIntervalSince(started) * 1000)
        if endpoint == .subscribe || !(200..<300).contains(response.status) {
            logger.info(LogFormat.response(endpoint, status: response.status, milliseconds: ms, body: nil))
        }
        return response
    } catch {
        try Task.checkCancellation()
        throw RequestFailure(error: RuntimeErrors.network)
    }
}

/// One request with the spec's auth rule. Resolves only with a 2xx response. `onIssue` runs just
/// before each attempt reaches the transport.
func send(_ config: HTTPConfig, _ target: SendTarget,
          onIssue: @Sendable () async -> Void = {}) async throws -> RiviHTTPResponse {
    var response = try await attempt(config, target, token: try await resolveToken(config), onIssue: onIssue)
    if response.status == 401 {
        response.cancel()
        response = try await attempt(config, target, token: try await resolveToken(config), onIssue: onIssue)
        if response.status == 401 {
            response.cancel()
            throw RequestFailure(error: RuntimeErrors.authRejected)
        }
    }
    guard (200..<300).contains(response.status) else {
        response.cancel()
        throw RequestFailure(error: RuntimeErrors.server(response.status))
    }
    return response
}

/// Reads a whole body as text.
func readText(_ response: RiviHTTPResponse) async throws -> String {
    var bytes: [UInt8] = []
    for try await chunk in response.body { bytes += chunk }
    try Task.checkCancellation()
    return String(decoding: bytes, as: UTF8.self)
}
