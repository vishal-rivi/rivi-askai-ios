import RiviSmartSortContract

// The runtime loop around `reconcile` (spec 6.1; web: src/runtime/session.ts).

public struct RiviSessionOptions {
    public var baseURL: String
    public var tenant: String
    public var tier: String
    public var metadata: JSONObject
    public var locale: String
    public var currency: String
    /// Resolved per request. A 401 resolves it once more and retries once.
    public var auth: @Sendable () async throws -> String
    public var i18n: RiviI18n
    public var timings: RiviConfig
    public var transport: RiviTransport
    public var clock: RiviClock
    /// Reconnect jitter source, [0, 1).
    public var random: () -> Double
    /// Whether the app is in the background.
    public var isHidden: () -> Bool
    /// Requests, responses, stream activity and errors. Never receives tokens or the subscribe URL.
    public var logger: RiviLogger

    public init(
        baseURL: String,
        tenant: String,
        tier: String,
        metadata: JSONObject = JSONObject(),
        locale: String,
        currency: String,
        auth: @escaping @Sendable () async throws -> String,
        i18n: RiviI18n? = nil,
        timings: RiviConfig = .default,
        transport: RiviTransport = URLSessionTransport(),
        clock: RiviClock = SystemClock(),
        random: @escaping () -> Double = { Double.random(in: 0..<1) },
        isHidden: @escaping () -> Bool = { false },
        logger: RiviLogger = ConsoleRiviLogger()
    ) {
        self.baseURL = baseURL
        self.tenant = tenant
        self.tier = tier
        self.metadata = metadata
        self.locale = locale
        self.currency = currency
        self.auth = auth
        self.i18n = i18n ?? BundledData.i18n(locale: locale)
        self.timings = timings
        self.transport = transport
        self.clock = clock
        self.random = random
        self.isHidden = isHidden
        self.logger = logger
    }
}

/// Returned by `subscribe` / `onCommand`; call `cancel()` to stop listening.
public final class RiviSubscription {
    private var onCancel: (() -> Void)?

    init(_ onCancel: @escaping () -> Void) {
        self.onCancel = onCancel
    }

    public func cancel() {
        onCancel?()
        onCancel = nil
    }
}

/// Test-only observation points.
struct SessionHooks {
    var onReconcile: ((Input, [Command]) -> Void)?
    var onExecute: ((Command) -> Void)?
}

/// One Smart Sort session: one per results screen. All calls on the main actor.
///
/// `dispatch` runs `reconcile`, publishes the state, then executes the commands in order. An input
/// dispatched meanwhile (by a listener, or by an I/O result) waits in the queue; nothing re-enters.
@MainActor
public final class RiviSession {
    public private(set) var state: RiviState
    /// Supplies the filters sent with every ask and sort-best, in place of the contract's. The UI
    /// layer sets it: it keeps the tenant's filters on the device, so changing them makes no
    /// request, yet each request still carries the current ones.
    public var requestFilters: (() -> JSONValue?)?

    private var i18n: RiviI18n
    private var wire: WireContext
    private let options: RiviSessionOptions
    private let http: HTTPConfig
    private let hooks: SessionHooks
    private var destroyed = false
    private var draining = false
    private var queue: [Input] = []
    private var stateListeners: [Int: (RiviState) -> Void] = [:]
    private var commandListeners: [Int: (Command) -> Void] = [:]
    private var inputListeners: [Int: (Input) -> Void] = [:]
    private var nextListener = 0
    /// Scope `all`: the round's POST. Scope `explain`: the explain stream. Neither holds the ranking stream.
    private var allTasks: [Task<Void, Never>] = []
    private var explainTasks: [Task<Void, Never>] = []
    /// The search's one ranking subscription, and the round its frames belong to.
    private var ranking: (key: String, stream: RankingStream)?
    private var round: RoundContext?
    private lazy var timers = NamedTimers(clock: options.clock) { [weak self] timer, epoch in
        self?.dispatch(.timerFired(timer: timer, epoch: epoch))
    }

    public convenience init(options: RiviSessionOptions) {
        self.init(options: options, hooks: SessionHooks())
    }

    init(options: RiviSessionOptions, hooks: SessionHooks) {
        self.options = options
        self.hooks = hooks
        state = initialState(options.timings)
        i18n = options.i18n
        wire = WireContext(locale: options.locale, currency: options.currency)
        http = HTTPConfig(baseURL: options.baseURL, tenant: options.tenant, tier: options.tier,
                          metadata: options.metadata, auth: options.auth, transport: options.transport,
                          logger: options.logger)
    }

    // MARK: - Public API

    public func dispatch(_ input: Input) {
        guard !destroyed else { return }
        queue.append(input)
        guard !draining else { return }
        draining = true
        defer {
            draining = false
            if destroyed { queue.removeAll() }
        }
        while !queue.isEmpty && !destroyed {
            let next = queue.removeFirst()
            let (nextState, commands) = reconcile(state, next)
            hooks.onReconcile?(next, commands)
            log(next, commands)
            if nextState != state {
                state = nextState
                syncRanking()
                notify(stateListeners, state)
            }
            notify(inputListeners, next)
            for command in commands {
                if destroyed { break }
                execute(command)
            }
        }
    }

    /// Called after every state change. It does not replay the current state; read `state`.
    @discardableResult
    public func subscribe(_ listener: @escaping (RiviState) -> Void) -> RiviSubscription {
        guard !destroyed else { return RiviSubscription {} }
        nextListener += 1
        let id = nextListener
        stateListeners[id] = listener
        return RiviSubscription { [weak self] in self?.stateListeners[id] = nil }
    }

    /// RankingCleared, ConfirmSortChange and SortChanged only.
    @discardableResult
    public func onCommand(_ listener: @escaping (Command) -> Void) -> RiviSubscription {
        guard !destroyed else { return RiviSubscription {} }
        nextListener += 1
        let id = nextListener
        commandListeners[id] = listener
        return RiviSubscription { [weak self] in self?.commandListeners[id] = nil }
    }

    /// Called after every input is reconciled (and the state published), whether or not the state
    /// changed. The UI layer uses it to tell when the explain stream has ended.
    @discardableResult
    public func onInput(_ listener: @escaping (Input) -> Void) -> RiviSubscription {
        guard !destroyed else { return RiviSubscription {} }
        nextListener += 1
        let id = nextListener
        inputListeners[id] = listener
        return RiviSubscription { [weak self] in self?.inputListeners[id] = nil }
    }

    /// Switches locale: later chips and wire bodies use it, and current chips are re-projected.
    public func setI18n(_ next: RiviI18n) {
        guard !destroyed else { return }
        i18n = next
        wire.locale = next.locale
        guard let search = state.search, !state.entities.isEmpty else { return }
        dispatch(.askResponse(
            epoch: state.epoch,
            entities: state.entities,
            chips: toChips(state.entities, product: search.product, i18n: next),
            notice: state.notice
        ))
    }

    /// Call when the app moves between foreground and background.
    public func visibilityChanged() {
        ranking?.stream.visibilityChanged()
    }

    /// Cancels everything, including the ranking stream and any pending reconnect, and clears
    /// timers. Call it when the results screen goes away.
    public func destroy() {
        guard !destroyed else { return }
        destroyed = true
        queue.removeAll()
        cancel(.all)
        closeRanking()
        timers.cancel(.all)
        stateListeners.removeAll()
        commandListeners.removeAll()
        inputListeners.removeAll()
    }

    // MARK: - Commands

    private func execute(_ command: Command) {
        hooks.onExecute?(command)
        switch command {
        case let .fetch(epoch, request):
            runFetch(epoch: epoch, request: request)
        case .cancelInFlight(let scope):
            cancel(scope)
        case let .startTimer(timer, ms, epoch):
            timers.start(timer, ms: ms, epoch: epoch)
        case .cancelTimer(let target):
            timers.cancel(target)
        case .rankingCleared, .confirmSortChange, .sortChanged:
            notify(commandListeners, command)
        }
    }

    /// Scope `all` is the round's POST (and the explain); the ranking stream is not in it.
    private func cancel(_ scope: CancelScope) {
        if scope == .all {
            allTasks.forEach { $0.cancel() }
            allTasks.removeAll()
        }
        explainTasks.forEach { $0.cancel() }
        explainTasks.removeAll()
    }

    private var deps: FetcherDeps {
        FetcherDeps(
            http: http,
            clock: options.clock,
            dispatch: { [weak self] in self?.dispatch($0) },
            i18n: { [weak self] in self?.i18n ?? BundledData.i18n(locale: "en") },
            wire: { [weak self] in self?.wire ?? WireContext(locale: "en", currency: "") },
            roundReady: { [weak self] epoch, ask in self?.roundReady(epoch: epoch, ask: ask) }
        )
    }

    private func runFetch(epoch: Int, request: FetchRequest) {
        guard let search = state.search else { return }
        var deps = deps
        switch request {
        case let .explain(query, entities):
            let explainDeps = deps
            explainTasks.append(Task { await runExplain(explainDeps, epoch: epoch, search: search, query: query, entities: entities) })
        case let .ask(query, contractFilters):
            let filters = requestFilters.map { $0() } ?? contractFilters
            // Subscribe before the POST so no early frame is missed.
            let stream = ensureRanking(search)
            stream.clearExpectation()
            deps.subscribed = { [weak stream] in await stream?.requested() }
            round = RoundContext(epoch: epoch, isAsk: true)
            let roundDeps = deps
            allTasks.append(Task { await runAsk(roundDeps, epoch: epoch, search: search, query: query, filters: filters) })
        case .sortBest(let contractFilters):
            let filters = requestFilters.map { $0() } ?? contractFilters
            let stream = ensureRanking(search)
            stream.clearExpectation()
            deps.subscribed = { [weak stream] in await stream?.requested() }
            round = RoundContext(epoch: epoch, isAsk: false)
            let roundDeps = deps
            allTasks.append(Task { await runSortBest(roundDeps, epoch: epoch, search: search, filters: filters) })
        }
        allTasks.removeAll { $0.isCancelled }
        explainTasks.removeAll { $0.isCancelled }
    }

    private func roundReady(epoch: Int, ask: AskResult?) {
        guard var current = round, current.epoch == epoch else { return }
        current.ask = ask
        round = current
        guard let stream = ranking?.stream, !stream.isEnded else { return }
        stream.resetReplays()
        if !current.ranked {
            stream.expectRanking { [weak self] in
                self?.dispatch(.failed(epoch: epoch, error: RuntimeErrors.noRanking))
            }
        }
    }

    // MARK: - Ranking stream

    private func searchKey(_ search: RiviSearch) -> String { "\(search.product.rawValue):\(search.searchId)" }

    /// Opens the search's ranking stream unless it is already open (or reopens one that ended).
    private func ensureRanking(_ search: RiviSearch) -> RankingStream {
        let key = searchKey(search)
        if let ranking, ranking.key == key, !ranking.stream.isEnded { return ranking.stream }
        ranking?.stream.close()
        let product = search.product
        let logger = options.logger
        let warn: Warn = { logger.warn($0) }
        var stream: RankingStream!
        stream = RankingStream(.init(
            http: http,
            searchId: search.searchId,
            clock: options.clock,
            random: options.random,
            isHidden: options.isHidden,
            onFrame: { [weak self] json in
                guard let self else { return .other }
                guard let input = rankingInput(json, product: product, epoch: self.state.epoch,
                                               round: &self.round, i18n: self.i18n, warn: warn) else { return .other }
                if case .failed = input { stream?.clearExpectation() }
                self.dispatch(input)
                if case .rankingFrame = input { return .ranking }
                return .other
            },
            onFailed: { [weak self] error in
                guard let self else { return }
                self.dispatch(.failed(epoch: self.state.epoch, error: error))
            }
        ))
        ranking = (key, stream)
        stream.start()
        return stream
    }

    private func closeRanking() {
        ranking?.stream.close()
        ranking = nil
        round = nil
    }

    /// The stream belongs to one search identity: close it as soon as the state's differs.
    private func syncRanking() {
        guard let ranking else { return }
        if state.search.map(searchKey) != ranking.key { closeRanking() }
    }

    private func log(_ input: Input, _ commands: [Command]) {
        let logger = options.logger
        if case let .failed(epoch, error) = input, epoch == state.epoch {
            logger.error(LogFormat.failure("request failed", error))
        }
        if case let .rankingFrame(epoch, ranking) = input, epoch == state.epoch {
            logger.info("ranking: \(ranking.count) entries (epoch \(epoch))")
        }
        logger.debug("\(LogFormat.describe(input)) → [\(commands.map(LogFormat.describe).joined(separator: ", "))]")
    }

    private func notify<T>(_ listeners: [Int: (T) -> Void], _ value: T) {
        for (_, listener) in listeners.sorted(by: { $0.key < $1.key }) { listener(value) }
    }
}
