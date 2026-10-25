import Foundation
import RiviSmartSortContract

// The three POSTs and how stream frames become inputs (web: src/runtime/fetchers.ts).

struct AskResult: Equatable {
    var entities: Entities
    var notice: String?
}

/// The rank round the ranking stream's frames currently belong to.
struct RoundContext {
    var epoch: Int
    var isAsk: Bool
    /// The ask's entities so far: the POST's, extended by entity frames.
    var ask: AskResult?
    /// A ranking frame arrived in this round.
    var ranked = false
}

/// What the fetchers need from the session.
@MainActor
struct FetcherDeps {
    var http: HTTPConfig
    var clock: RiviClock
    var dispatch: (Input) -> Void
    var i18n: () -> RiviI18n
    var wire: () -> WireContext
    /// The round's POST succeeded. `ask` is nil for a sort-best round.
    var roundReady: (Int, AskResult?) -> Void
    /// Returns once the ranking subscription has been requested (subscribe before the POST).
    var subscribed: () async -> Void = {}
}

/// POST under the 30 s watchdog; returns the response text. Cancelled → CancellationError.
@MainActor
private func post(_ deps: FetcherDeps, _ endpoint: Endpoint, body: JSONValue) async throws -> String {
    let logger = deps.http.logger
    let work = Task { @MainActor in
        let started = Date()
        let response = try await send(deps.http, .post(endpoint, body: body))
        let text = try await readText(response)
        logger.info(LogFormat.response(endpoint, status: response.status,
                                       milliseconds: Int(Date().timeIntervalSince(started) * 1000),
                                       body: logger.isEnabled(.debug) ? text : nil))
        return text
    }
    let dog = Watchdog(clock: deps.clock) { work.cancel() }
    defer { dog.stop() }
    return try await withTaskCancellationHandler {
        do {
            return try await work.value
        } catch {
            if dog.fired { throw RequestFailure(error: RuntimeErrors.timeout) }
            throw error
        }
    } onCancel: {
        work.cancel()
    }
}

/// Fetch(ask): POST ask, then dispatch its entities. The ranking stream is already open.
@MainActor
func runAsk(_ deps: FetcherDeps, epoch: Int, search: RiviSearch, query: String, filters: JSONValue?) async {
    await deps.subscribed()
    guard !Task.isCancelled else { return }
    let text: String
    do {
        text = try await post(deps, .ask, body: toAskBody(search, query: query, context: deps.wire(), filters: filters))
    } catch {
        if !Task.isCancelled { deps.dispatch(.failed(epoch: epoch, error: toRiviError(error))) }
        return
    }
    guard !Task.isCancelled else { return }
    guard let json = try? JSONValue.parse(text) else {
        deps.dispatch(.failed(epoch: epoch, error: RuntimeErrors.askNotJSON))
        return
    }
    logGatewayError(deps, .ask, json)
    let (entities, notice) = fromAskResponse(json)
    deps.roundReady(epoch, AskResult(entities: entities, notice: notice))
    deps.dispatch(.askResponse(
        epoch: epoch,
        entities: entities,
        chips: toChips(entities, product: search.product, i18n: deps.i18n()),
        notice: notice
    ))
}

/// The gateway reports some failures as HTTP 200 with `message.error` (e.g. a date it cannot
/// parse). The contract treats the reply as an empty result, as the web does; this makes the
/// cause visible in the logs.
@MainActor
private func logGatewayError(_ deps: FetcherDeps, _ endpoint: Endpoint, _ json: JSONValue) {
    guard let message = json["message"]?["error"]?.stringValue, !message.isEmpty else { return }
    deps.http.logger.error(LogFormat.failure("\(endpoint.rawValue) answered 200 with an error",
                                             RiviError(kind: .server, message: message, retryable: false)))
}

/// Fetch(sortBest): POST sort-best. The body is not used.
@MainActor
func runSortBest(_ deps: FetcherDeps, epoch: Int, search: RiviSearch, filters: JSONValue?) async {
    await deps.subscribed()
    guard !Task.isCancelled else { return }
    do {
        let text = try await post(deps, .sortBest, body: toSortBestBody(search, filters: filters))
        if let json = try? JSONValue.parse(text) { logGatewayError(deps, .sortBest, json) }
    } catch {
        if !Task.isCancelled { deps.dispatch(.failed(epoch: epoch, error: toRiviError(error))) }
        return
    }
    guard !Task.isCancelled else { return }
    deps.roundReady(epoch, nil)
}

/// One ranking-stream frame to the input to dispatch, tagged with `epoch`, the session's epoch
/// when the frame arrived. Entity frames extend the ask's entities, and only in an ask round of
/// that same epoch: in a sort-best round they are dropped, so a replayed entity frame cannot
/// bring cleared chips back. Mutates `round` (entities so far, `ranked`).
func rankingInput(_ json: JSONValue, product: Product, epoch: Int, round: inout RoundContext?,
                  i18n: RiviI18n, warn: @escaping Warn) -> Input? {
    switch fromFrame(json, product: product, warn: warn) {
    case .ranking(let ranking):
        if round?.epoch == epoch { round?.ranked = true }
        return .rankingFrame(epoch: epoch, ranking: ranking)
    case let .entities(frameEntities, frameNotice):
        guard var current = round, current.isAsk, current.epoch == epoch else { return nil }
        let base = current.ask ?? AskResult(entities: Entities(), notice: nil)
        let merged = base.entities.merging(frameEntities)
        let notice = frameNotice ?? base.notice
        if JSONValue.object(merged).serialized() == JSONValue.object(base.entities).serialized() && notice == base.notice {
            return nil
        }
        current.ask = AskResult(entities: merged, notice: notice)
        round = current
        return .askResponse(epoch: epoch, entities: merged, chips: toChips(merged, product: product, i18n: i18n), notice: notice)
    case .error(let message):
        return .failed(epoch: epoch, error: RuntimeErrors.stream(message))
    case .ignore:
        return nil
    }
}

/// Fetch(explain): POST explain-ai and read its stream. Frames are cumulative text. The stream
/// ends with ExplainEnd on an end frame or at EOF. 30 s without a frame is Failed{timeout}. A
/// cancelled explain reports nothing.
@MainActor
func runExplain(_ deps: FetcherDeps, epoch: Int, search: RiviSearch, query: String, entities: Entities) async {
    let run = ExplainRun()
    let body = toExplainBody(search, query: query, entities: entities, context: deps.wire())
    let work = Task { @MainActor () throws -> Void in
        let response = try await send(deps.http, .post(.explain, body: body))
        defer { response.cancel() }
        var decoder = LineDecoder()
        reading: for try await chunk in response.body {
            for line in decoder.push(chunk) where !run.handle(line, deps: deps, epoch: epoch) { break reading }
        }
        if !run.ended && !Task.isCancelled {
            for line in decoder.end() where !run.handle(line, deps: deps, epoch: epoch) { break }
        }
        try Task.checkCancellation()
    }
    let dog = Watchdog(clock: deps.clock) { work.cancel() }
    run.dog = dog
    defer { dog.stop() }
    do {
        try await withTaskCancellationHandler {
            try await work.value
        } onCancel: {
            work.cancel()
        }
        if !run.ended && !Task.isCancelled { deps.dispatch(.explainEnd(epoch: epoch)) }
    } catch {
        if dog.fired {
            deps.dispatch(.failed(epoch: epoch, error: RuntimeErrors.timeout))
        } else if !Task.isCancelled {
            deps.dispatch(.failed(epoch: epoch, error: toRiviError(error)))
        }
    }
}

/// The state of one explain stream.
@MainActor
private final class ExplainRun {
    var dog: Watchdog?
    private(set) var ended = false

    /// Returns false to stop reading.
    func handle(_ line: String, deps: FetcherDeps, epoch: Int) -> Bool {
        guard !Task.isCancelled else { return false }
        guard let frame = parseFrameLine(line) else { return true }
        dog?.kick()
        deps.http.logger.debug(LogFormat.event("EXPLAIN EVENT", .explain, seq: frame.seq, payload: frame.payload))
        switch fromExplainFrame(frame.json) {
        case .text(let text):
            deps.dispatch(.explainFrame(epoch: epoch, text: text))
            return !Task.isCancelled
        case .end:
            ended = true
            deps.dispatch(.explainEnd(epoch: epoch))
            return false
        case .ignore:
            return true
        }
    }
}
