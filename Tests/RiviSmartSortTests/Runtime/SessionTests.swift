import Foundation
import XCTest
import RiviSmartSortContract
@testable import RiviSmartSortRuntime

/// cases.json through the real Session, the way runCase replays it through reconcile: pool, then
/// search, then setup with commands discarded, then inputs with commands collected. The transport
/// never answers and the clock never moves, so the only inputs are the case's own.
@MainActor
final class SessionCasesTests: XCTestCase {
    func testEveryCaseBehavesTheSameThroughTheSession() {
        for c in TestResources.corpus.cases {
            var commands: [Command] = []
            var collecting = false
            let session = World.session(
                transport: FakeTransport(),
                clock: ManualClock(),
                hooks: SessionHooks(onReconcile: { _, cmds in if collecting { commands += cmds } }),
                timings: c.config
            )
            for input in c.preamble + c.setup { session.dispatch(input) }
            collecting = true
            for input in c.inputs { session.dispatch(input) }
            let state = session.state
            session.destroy()
            let expected = runCase(c)
            XCTAssertEqual(state, expected.state, c.name)
            XCTAssertEqual(commands, expected.commands, c.name)
            XCTAssertTrue(verify(c, state: state, commands: commands).isEmpty, c.name)
        }
    }
}

@MainActor
final class SessionRuntimeTests: XCTestCase {
    private var transport: FakeTransport!
    private var clock: ManualClock!

    override func setUp() async throws {
        transport = FakeTransport()
        clock = ManualClock()
    }

    func testFirstSearchSubscribesBeforeSortBestWithTheGatewayHeaders() async throws {
        transport.onSortBest = { _ in .json("{}") }
        let session = World.session(transport: transport, clock: clock)
        session.dispatch(.setSearch(World.flight))
        _ = await waitUntil { self.transport.requests.count >= 2 }
        let paths = transport.requests.map(\.url.path)
        XCTAssertEqual(paths, [Endpoint.subscribe.rawValue, Endpoint.sortBest.rawValue])

        let subscribe = try XCTUnwrap(transport.requests(.subscribe).first)
        XCTAssertEqual(subscribe.method, "GET")
        XCTAssertEqual(subscribe.url.absoluteString, "https://gw.test/api/v1/askai/subscribe?searchId=S-1&authorization=T0K-3n")
        XCTAssertEqual(subscribe.headers["Accept"], "text/event-stream")

        let post = try XCTUnwrap(transport.requests(.sortBest).first)
        XCTAssertEqual(post.headers["authorization"], World.token) // raw, no Bearer
        XCTAssertEqual(post.headers["tenant-name"], "sandbox")
        XCTAssertEqual(post.headers["tenant-tier"], "gold")
        XCTAssertEqual(post.headers["metadata"], #"{"app":"ios"}"#)
        XCTAssertEqual(post.body.map { String(decoding: $0, as: UTF8.self) },
                       toSortBestBody(World.flight).serialized())
        session.destroy()
    }

    func testRankingFramesReachStateAndOneStreamServesEveryRound() async throws {
        let body = FakeBody()
        transport.onSubscribe = { _ in .respond(status: 200, body: body) }
        transport.onSortBest = { _ in .json("{}") }
        transport.onAsk = { _ in .json(#"{"message":{"entities":[{"preferred_airlines":["Emirates"]}]}}"#) }
        let session = World.session(transport: transport, clock: clock)
        session.dispatch(.setSearch(World.flight))
        await settle()
        body.send(World.rankingLine(["IT-2", "IT-1"]))
        await settle()
        XCTAssertEqual(selectRanking(session.state).map(\.id), ["IT-2", "IT-1"])

        session.dispatch(.ask(text: "Emirates please"))
        await settle()
        XCTAssertEqual(session.state.chips.map(\.label), ["Emirates"])
        body.send(World.rankingLine(["IT-1", "IT-2"]))
        await settle()
        XCTAssertEqual(selectRanking(session.state).map(\.id), ["IT-1", "IT-2"])
        XCTAssertEqual(transport.requests(.subscribe).count, 1, "one subscription per search")
        session.destroy()
    }

    func testExplainIsDebouncedAfterARankingAndStreamsCumulativeText() async throws {
        let ranking = FakeBody()
        let explain = FakeBody()
        transport.onSubscribe = { _ in .respond(status: 200, body: ranking) }
        transport.onSortBest = { _ in .json("{}") }
        transport.onAsk = { _ in .json(#"{"message":{"entities":[{"stops_preference":["0"]}]}}"#) }
        transport.onExplain = { _ in .respond(status: 200, body: explain) }
        let session = World.session(transport: transport, clock: clock)
        session.dispatch(.setSearch(World.flight))
        session.dispatch(.ask(text: "non-stop"))
        await settle()
        ranking.send(World.rankingLine(["IT-1"]))
        await settle()
        XCTAssertTrue(transport.requests(.explain).isEmpty, "explain waits for its debounce")
        await clock.advance(by: 500)
        XCTAssertEqual(transport.requests(.explain).count, 1)
        explain.send("data: {\"content\":\"Non-stop flights\"}\n")
        await settle()
        explain.send("data: {\"content\":\"Non-stop flights first.\"}\n")
        explain.finish()
        await settle()
        XCTAssertEqual(session.state.explanation, "Non-stop flights first.")
        XCTAssertEqual(selectBanner(session.state), .explanation)
        session.destroy()
    }

    func testALateAskResponseFromAnEarlierRoundIsDropped() async throws {
        let first = FakeBody()
        var asks = 0
        transport.onSortBest = { _ in .json("{}") }
        transport.onAsk = { _ in
            asks += 1
            return asks == 1
                ? .respond(status: 200, body: first)
                : .json(#"{"message":{"entities":[{"preferred_airlines":["Qatar Airways"]}]}}"#)
        }
        let session = World.session(transport: transport, clock: clock)
        session.dispatch(.setSearch(World.flight))
        session.dispatch(.ask(text: "Emirates"))
        await settle()
        session.dispatch(.ask(text: "Qatar"))
        await settle()
        first.send(#"{"message":{"entities":[{"preferred_airlines":["Emirates"]}]}}"#)
        first.finish()
        await settle()
        XCTAssertEqual(session.state.chips.map(\.label), ["Qatar Airways"])
        session.destroy()
    }

    func testFiveFailedConnectionsSurfaceOneRetryableStreamError() async throws {
        transport.onSubscribe = { _ in .fail }
        transport.onSortBest = { _ in .json("{}") }
        var errors: [RiviError] = []
        let session = World.session(transport: transport, clock: clock)
        session.subscribe { state in if let error = state.error, errors.last != error { errors.append(error) } }
        session.dispatch(.setSearch(World.flight))
        for (attempt, delay) in [1000, 2000, 4000, 8000].enumerated() {
            let reached = await waitUntil { self.transport.requests(.subscribe).count == attempt + 1 && self.clock.pendingDelays.contains(delay) }
            XCTAssertTrue(reached, "attempt \(attempt + 1)")
            XCTAssertTrue(errors.isEmpty)
            await clock.advance(by: delay)
        }
        _ = await waitUntil { !errors.isEmpty }
        XCTAssertEqual(transport.requests(.subscribe).count, 5)
        XCTAssertEqual(errors, [RuntimeErrors.streamExhausted])
        await clock.advance(by: 60_000)
        XCTAssertEqual(transport.requests(.subscribe).count, 5, "an exhausted stream never reconnects")
        session.destroy()
    }

    func testA401ResolvesAuthOnceMoreThenFailsWithAuth() async throws {
        let calls = Counter()
        transport.onSubscribe = { _ in .never }
        transport.onSortBest = { _ in .json("", status: 401) }
        let session = World.session(transport: transport, clock: clock, auth: { calls.increment(); return "T\(calls.value)" })
        session.dispatch(.setSearch(World.flight))
        _ = await waitUntil { session.state.error != nil }
        XCTAssertEqual(transport.requests(.sortBest).map { $0.headers["authorization"] }, ["T3", "T4"])
        XCTAssertEqual(session.state.error, RuntimeErrors.authRejected)
        session.destroy()
    }

    func testANewSearchClosesTheOldStreamAndDestroyCancelsEverything() async throws {
        transport.onSortBest = { _ in .json("{}") }
        let session = World.session(transport: transport, clock: clock)
        session.dispatch(.setSearch(World.flight))
        await settle()
        guard case .flight(var other) = World.flight else { return XCTFail() }
        other.searchId = "S-2"
        session.dispatch(.setSearch(.flight(other)))
        await settle()
        XCTAssertEqual(transport.requests(.subscribe).map { $0.url.query ?? "" },
                       ["searchId=S-1&authorization=T0K-3n", "searchId=S-2&authorization=T0K-3n"])
        session.destroy()
        session.dispatch(.ask(text: "ignored"))
        await settle()
        XCTAssertEqual(transport.requests(.ask).count, 0)
        XCTAssertEqual(clock.pendingCount, 0)
    }

    func testNoRankingWithin30SecondsFailsTheRound() async throws {
        transport.onSubscribe = { _ in .respond(status: 200, body: FakeBody()) }
        transport.onSortBest = { _ in .json("{}") }
        let session = World.session(transport: transport, clock: clock)
        session.dispatch(.setSearch(World.flight))
        await settle()
        await clock.advance(by: 29_999)
        XCTAssertNil(session.state.error)
        await clock.advance(by: 1)
        XCTAssertEqual(session.state.error, RuntimeErrors.noRanking)
        session.destroy()
    }
}

final class Counter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 1

    var value: Int {
        lock.lock()
        defer { lock.unlock() }
        return count
    }

    func increment() {
        lock.lock()
        count += 1
        lock.unlock()
    }
}
