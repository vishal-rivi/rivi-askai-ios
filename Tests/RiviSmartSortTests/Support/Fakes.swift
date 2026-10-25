import Foundation
import RiviSmartSortContract
@testable import RiviSmartSortRuntime

/// A response body the test feeds line by line.
final class FakeBody: @unchecked Sendable {
    let stream: AsyncThrowingStream<[UInt8], Error>
    private let continuation: AsyncThrowingStream<[UInt8], Error>.Continuation

    init() {
        (stream, continuation) = AsyncThrowingStream<[UInt8], Error>.makeStream()
    }

    func send(_ text: String) { continuation.yield(Array(text.utf8)) }
    func send(bytes: [UInt8]) { continuation.yield(bytes) }
    func finish() { continuation.finish() }
    func fail() { continuation.finish(throwing: URLError(.networkConnectionLost)) }

    static func complete(_ text: String) -> FakeBody {
        let body = FakeBody()
        body.send(text)
        body.finish()
        return body
    }
}

enum FakeReply {
    /// Never answers; throws when cancelled.
    case never
    case respond(status: Int, body: FakeBody)
    case fail

    static func json(_ text: String, status: Int = 200) -> FakeReply { .respond(status: status, body: .complete(text)) }
}

/// Records every request and answers from per-endpoint handlers.
final class FakeTransport: RiviTransport, @unchecked Sendable {
    private let lock = NSLock()
    private var _requests: [RiviHTTPRequest] = []
    var onSubscribe: (RiviHTTPRequest) -> FakeReply = { _ in .never }
    var onAsk: (RiviHTTPRequest) -> FakeReply = { _ in .never }
    var onSortBest: (RiviHTTPRequest) -> FakeReply = { _ in .never }
    var onExplain: (RiviHTTPRequest) -> FakeReply = { _ in .never }

    var requests: [RiviHTTPRequest] {
        lock.lock()
        defer { lock.unlock() }
        return _requests
    }

    func requests(_ endpoint: Endpoint) -> [RiviHTTPRequest] {
        requests.filter { $0.url.path == endpoint.rawValue }
    }

    private func record(_ request: RiviHTTPRequest) {
        lock.lock()
        _requests.append(request)
        lock.unlock()
    }

    func send(_ request: RiviHTTPRequest) async throws -> RiviHTTPResponse {
        record(request)
        let reply: FakeReply
        switch request.url.path {
        case Endpoint.subscribe.rawValue: reply = onSubscribe(request)
        case Endpoint.ask.rawValue: reply = onAsk(request)
        case Endpoint.sortBest.rawValue: reply = onSortBest(request)
        case Endpoint.explain.rawValue: reply = onExplain(request)
        default: reply = .fail
        }
        switch reply {
        case .never:
            try await neverReturn()
            throw CancellationError()
        case let .respond(status, body):
            return RiviHTTPResponse(status: status, body: body.stream)
        case .fail:
            throw URLError(.notConnectedToInternet)
        }
    }
}

private final class Gate: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Void, Error>?
    private var cancelled = false

    func wait() async throws {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (c: CheckedContinuation<Void, Error>) in
                lock.lock()
                if cancelled {
                    lock.unlock()
                    c.resume(throwing: CancellationError())
                } else {
                    continuation = c
                    lock.unlock()
                }
            }
        } onCancel: {
            lock.lock()
            cancelled = true
            let c = continuation
            continuation = nil
            lock.unlock()
            c?.resume(throwing: CancellationError())
        }
    }
}

/// Suspends until the task is cancelled.
func neverReturn() async throws {
    try await Gate().wait()
}

/// A clock that only moves when the test advances it.
final class ManualClock: RiviClock, @unchecked Sendable {
    private struct Sleeper {
        var id: Int
        var deadline: Int
        var continuation: CheckedContinuation<Void, Error>
    }

    private let lock = NSLock()
    private var now = 0
    private var nextId = 0
    private var sleepers: [Sleeper] = []

    var pendingCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return sleepers.count
    }

    /// Remaining time of every pending sleeper.
    var pendingDelays: [Int] {
        lock.lock()
        defer { lock.unlock() }
        return sleepers.map { $0.deadline - now }
    }

    private func register(_ milliseconds: Int) -> (id: Int, deadline: Int) {
        lock.lock()
        defer { lock.unlock() }
        nextId += 1
        return (nextId, now + milliseconds)
    }

    /// Adds the sleeper unless the task was already cancelled.
    private func park(_ sleeper: Sleeper, cancelled: Bool) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if cancelled { return false }
        sleepers.append(sleeper)
        return true
    }

    private func unpark(_ id: Int) -> Sleeper? {
        lock.lock()
        defer { lock.unlock() }
        return sleepers.firstIndex { $0.id == id }.map { sleepers.remove(at: $0) }
    }

    func sleep(milliseconds: Int) async throws {
        let (id, deadline) = register(milliseconds)
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (c: CheckedContinuation<Void, Error>) in
                if !park(Sleeper(id: id, deadline: deadline, continuation: c), cancelled: Task.isCancelled) {
                    c.resume(throwing: CancellationError())
                }
            }
        } onCancel: {
            unpark(id)?.continuation.resume(throwing: CancellationError())
        }
    }

    /// Moves time forward, waking every sleeper whose deadline has passed, in deadline order.
    /// Takes the earliest sleeper due by `target` and moves time to it; nil moves time to `target`.
    private func takeDue(by target: Int) -> Sleeper? {
        lock.lock()
        defer { lock.unlock() }
        let due = sleepers.enumerated().filter { $0.element.deadline <= target }.min { $0.element.deadline < $1.element.deadline }
        guard let due else {
            now = target
            return nil
        }
        sleepers.remove(at: due.offset)
        now = due.element.deadline
        return due.element
    }

    private var currentTime: Int {
        lock.lock()
        defer { lock.unlock() }
        return now
    }

    @MainActor
    func advance(by milliseconds: Int) async {
        let target = currentTime + milliseconds
        while true {
            await settle()
            guard let due = takeDue(by: target) else { break }
            due.continuation.resume()
        }
        await settle()
    }
}

/// Lets queued main-actor tasks, background auth and stream reads run.
@MainActor
func settle(_ rounds: Int = 15) async {
    for _ in 0..<rounds {
        await Task.yield()
        try? await Task.sleep(nanoseconds: 1_000_000)
    }
}

/// Polls `condition` in real time until it holds or `timeout` passes.
@MainActor
func waitUntil(timeout: Double = 3, _ condition: () -> Bool) async -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while !condition() {
        if Date() > deadline { return false }
        try? await Task.sleep(nanoseconds: 2_000_000)
    }
    await settle(3)
    return true
}

enum World {
    static let token = "T0K-3n"

    static let flight = RiviSearch.flight(FlightSearch(
        searchId: "S-1", tripType: .oneway, origin: "RUH", destination: "DXB", departureDate: "2026-10-10",
        pax: .init(adults: 1)
    ))

    @MainActor
    static func session(transport: FakeTransport, clock: ManualClock, hooks: SessionHooks = SessionHooks(),
                        auth: @escaping @Sendable () async throws -> String = { World.token },
                        timings: RiviConfig = .default) -> RiviSession {
        RiviSession(options: RiviSessionOptions(
            baseURL: "https://gw.test/",
            tenant: "sandbox",
            tier: "gold",
            metadata: JSONObject([("app", "ios")]),
            locale: "en",
            currency: "SAR",
            auth: auth,
            timings: timings,
            transport: transport,
            clock: clock,
            random: { 0.5 },
            logger: SilentRiviLogger()
        ), hooks: hooks)
    }

    static func rankingLine(_ ids: [String], seq: Int? = nil) -> String {
        let itineraries = JSONObject(ids.map { ($0, JSONValue.object(JSONObject([("recommendationTagList", [])]))) })
        return "data: \(seq.map(String.init) ?? "")\(JSONValue.object(JSONObject([("data", ["itineraries": .object(itineraries)])])).serialized())\n"
    }
}
