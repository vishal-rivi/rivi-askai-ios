import RiviSmartSortContract

/// What the session made of a frame: a ranking, or anything else.
enum FrameVerdict {
    case ranking
    case other
}

/// The one ranking subscription of a search (spec 6.2; web: RankingStream in stream.ts). It stays
/// open across rank rounds and closes only on `close()` (new search identity, destroy).
///
/// - Every attempt that ends — an error, a non-2xx status, or EOF — is a failure. Failures back
///   off 1 s, 2 s, 4 s, 8 s; the fifth in a row surfaces `Failed{stream, retryable: true}` once
///   and ends the stream.
/// - The failure count resets on a parsed, non-replayed frame that `onFrame` calls a ranking.
/// - The replay guard survives reconnects; `resetReplays()` starts a fresh one for a new round.
/// - `expectRanking(onTimeout:)` is the per-round watchdog: no ranking frame within 30 s calls
///   `onTimeout` once. The stream stays open.
/// - Hidden (app in background): the attempt is cancelled, retry and watchdog pause, nothing is
///   counted. Visible again: reconnect at once and re-arm the watchdog.
/// - A 401 twice, or a failing `auth()`, surfaces that error once and ends the stream.
@MainActor
final class RankingStream {
    struct Options {
        var http: HTTPConfig
        var searchId: String
        var clock: RiviClock
        var random: () -> Double
        var isHidden: () -> Bool
        var onFrame: (JSONValue) -> FrameVerdict
        var onFailed: (RiviError) -> Void
        var rankingTimeoutMs: Int = watchdogMs
    }

    private let options: Options
    private var budget = FailureBudget()
    private var replays = ReplayGuard()
    private(set) var isEnded = false
    private var suspended = false
    private var started = false
    private var attempt: Task<Void, Never>?
    private var attemptId = 0
    private var retry: Task<Void, Never>?
    private var expectation: (() -> Void)?
    private var expectationTimer: Task<Void, Never>?
    private var issued = false
    private var issueWaiters: [CheckedContinuation<Void, Never>] = []

    init(_ options: Options) {
        self.options = options
    }

    func start() {
        guard !started else { return }
        started = true
        if options.isHidden() {
            suspended = true
            return
        }
        connect()
    }

    /// Stops for good, silently.
    func close() {
        finish()
    }

    func visibilityChanged() {
        guard started, !isEnded else { return }
        if options.isHidden() {
            guard !suspended else { return }
            suspended = true
            clearRetry()
            pauseExpectation()
            cancelAttempt()
            markIssued()
            return
        }
        guard suspended else { return }
        suspended = false
        armExpectation()
        connect()
    }

    /// Returns once the subscription request has reached the transport, so a round's POST never
    /// overtakes it (the gateway must hold the subscription before results are pushed). Returns
    /// at once when the stream is suspended or ended.
    func requested() async {
        if issued || isEnded || suspended { return }
        await withCheckedContinuation { issueWaiters.append($0) }
    }

    private func markIssued() {
        issued = true
        let waiters = issueWaiters
        issueWaiters.removeAll()
        waiters.forEach { $0.resume() }
    }

    /// A new round's POST succeeded: its frames must not be mistaken for the last round's.
    func resetReplays() {
        replays = ReplayGuard()
    }

    /// Calls `onTimeout` once if no ranking frame arrives within the timeout.
    func expectRanking(onTimeout: @escaping () -> Void) {
        guard !isEnded else { return }
        expectation = onTimeout
        armExpectation()
    }

    func clearExpectation() {
        expectation = nil
        pauseExpectation()
    }

    // MARK: - Connection

    private func connect() {
        retry = nil
        guard !isEnded, !suspended else { return }
        attemptId += 1
        let id = attemptId
        attempt = Task { [weak self] in
            guard let self else { return }
            await self.run(attempt: id)
        }
    }

    private func isCurrent(_ id: Int) -> Bool {
        id == attemptId && !Task.isCancelled && !isEnded
    }

    private func run(attempt id: Int) async {
        var decoder = LineDecoder()
        do {
            let response = try await send(options.http, .subscribe(searchId: options.searchId)) { [weak self] in
                await self?.markIssued()
            }
            defer { response.cancel() }
            reading: for try await chunk in response.body {
                guard isCurrent(id) else { return }
                for line in decoder.push(chunk) where !onLine(line, attempt: id) { break reading }
            }
            if isCurrent(id) { for line in decoder.end() where !onLine(line, attempt: id) { break } }
        } catch let failure as RequestFailure where failure.error.kind == .auth {
            guard isCurrent(id) else { return }
            fail(failure.error)
            return
        } catch {
            // Network drop or cancellation: handled below.
        }
        guard isCurrent(id) else { return }
        attempt = nil
        markIssued()
        if budget.fail() {
            fail(RuntimeErrors.streamExhausted)
            return
        }
        let delay = Reconnect.backoffDelay(failures: budget.count, random: options.random)
        options.http.logger.warn("ranking stream for \(options.searchId) dropped; reconnecting in \(delay) ms (failure \(budget.count) of \(Reconnect.budget))")
        retry = Task { [clock = options.clock, weak self] in
            do { try await clock.sleep(milliseconds: delay) } catch { return }
            guard let self, !Task.isCancelled, self.retry != nil else { return }
            self.connect()
        }
    }

    /// Returns false to stop reading.
    private func onLine(_ line: String, attempt id: Int) -> Bool {
        guard isCurrent(id) else { return false }
        guard let frame = parseFrameLine(line) else { return true }
        if replays.isReplay(frame) {
            options.http.logger.debug("ranking stream: dropped a replayed frame (seq \(frame.seq ?? "-"))")
            return true
        }
        options.http.logger.debug(LogFormat.event("STREAM EVENT", .subscribe, seq: frame.seq, payload: frame.payload))
        if options.onFrame(frame.json) == .ranking {
            budget.reset()
            clearExpectation()
        }
        return isCurrent(id)
    }

    // MARK: - Ranking watchdog

    private func armExpectation() {
        pauseExpectation()
        guard expectation != nil, !isEnded, !suspended else { return }
        expectationTimer = Task { [clock = options.clock, ms = options.rankingTimeoutMs, weak self] in
            do { try await clock.sleep(milliseconds: ms) } catch { return }
            guard let self, !Task.isCancelled, self.expectationTimer != nil else { return }
            self.expectationTimer = nil
            let onTimeout = self.expectation
            self.expectation = nil
            onTimeout?()
        }
    }

    private func pauseExpectation() {
        expectationTimer?.cancel()
        expectationTimer = nil
    }

    // MARK: - Ending

    private func fail(_ error: RiviError) {
        guard !isEnded else { return }
        finish()
        options.onFailed(error)
    }

    private func finish() {
        isEnded = true
        markIssued()
        clearRetry()
        clearExpectation()
        cancelAttempt()
    }

    private func cancelAttempt() {
        attemptId += 1
        attempt?.cancel()
        attempt = nil
    }

    private func clearRetry() {
        retry?.cancel()
        retry = nil
    }
}
