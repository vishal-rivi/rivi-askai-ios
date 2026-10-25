import Foundation
import SwiftUI
import RiviSmartSortContract
import RiviSmartSortRuntime
import RiviSmartSortElements
#if canImport(UIKit)
import UIKit
#endif

/// Who the tenant is. Sent as `tenant-name` / `tenant-tier`.
public struct RiviTenant: Sendable, Equatable {
    public var name: String
    public var tier: String

    public init(name: String, tier: String) {
        self.name = name
        self.tier = tier
    }
}

/// The gateway. Paths (`/api/v1/askai…`) are added by the runtime.
public enum RiviSmartSortEnvironment: Sendable, Equatable {
    case staging
    case production
    case custom(baseURL: String)

    public var baseURL: String {
        switch self {
        case .staging: return "https://askai-gateway-staging.rivi.co"
        case .production: return "https://askai-gateway.rivi.co"
        case .custom(let baseURL): return baseURL
        }
    }
}

/// What the SDK tells the tenant (web: the `rivi-*` DOM events).
public enum RiviSmartSortEvent: Sendable, Equatable {
    /// The order to apply. `ranking` is empty off Best ("use your own order"); `all` is the
    /// stage's ranking whatever the sort, for tenants whose items come only from Rivi.
    case ranking(ranking: [RankingEntry], all: [RankingEntry], status: RankingStatus)
    /// The query was cleared: go back to your own order.
    case rankingCleared
    /// Leaving Best with an active query needs confirmation (rule 10). When
    /// `presentsSortConfirmation` is false, answer with `resolveSortConfirmation(accepted:)`.
    case confirmSortChange(SortMode)
    /// Set your sort tab to this (after an ask from another tab, or a declined confirmation).
    case sortChanged(SortMode)
    case error(RiviError)
    /// "Show matches" / "Show them": the ids of hidden full matches.
    case showHidden([String])
}

/// The Smart Sort session for one results screen.
///
/// The tenant reports five facts — `search`, `sort`, `stage`, `pool` and `filters` — plus
/// the optional `visible`, and listens to `onEvent` / `events`. Every behaviour rule lives in the
/// shared contract. The `RiviSmartSort…` views drive the existing RiviSmartSortElements views from this model.
@MainActor
public final class RiviSmartSort: ObservableObject {
    /// The contract state. Read it through the derived properties below.
    @Published public private(set) var state: RiviState
    /// True while the built-in sort confirmation should show (see `presentsSortConfirmation`).
    @Published public var isConfirmingSortChange = false
    @Published public private(set) var i18n: RiviI18n
    /// The explanation as of the end of its stream (or its failure). While `explanation` differs,
    /// a stream is still arriving.
    @Published public private(set) var completedExplanation = ""

    /// When true (the default) the `riviSmartSortConfirmation` modifier asks the user; when false
    /// the tenant handles `.confirmSortChange` itself and calls `resolveSortConfirmation`.
    public var presentsSortConfirmation = true
    /// Receives every event, on the main actor.
    public var onEvent: ((RiviSmartSortEvent) -> Void)?

    public let tenant: RiviTenant
    private let session: RiviSession
    private var overrides: StringOverrides
    private var sent = SentFacts()
    private var lastRanking: [RankingEntry] = []
    private var lastAll: [RankingEntry] = []
    private var lastStatus: RankingStatus = .none
    private var lastError: RiviError?
    private var eventContinuations: [UUID: AsyncStream<RiviSmartSortEvent>.Continuation] = [:]
    private let observers = ObserverBag()
    private let background = BackgroundFlag()

    private struct SentFacts {
        var search: RiviSearch?
        var sort: SortMode?
        var stage: Stage?
        var pool: PoolFact?
        /// nil until filters are first reported; then the last value reported (`.some(nil)` = none).
        /// Changing them makes no request; the next ask or sort-best carries them.
        var filters: JSONValue??
        var visible: [String]??
    }

    /// - Parameters:
    ///   - auth: Resolved per request; a 401 resolves it once more. Return the tenant token.
    ///   - strings: Optional wording overrides, `[locale: [key: message]]` (ICU subset).
    ///   - logLevel: Minimum level the console logs (default `.info`). Ignored when `logger` is set.
    ///   - logger: Where logs go; it filters by its own `isEnabled(_:)`. nil uses the console.
    ///     Tokens are never logged.
    public init(
        tenant: RiviTenant,
        environment: RiviSmartSortEnvironment = .production,
        locale: String = "en",
        currency: String,
        metadata: [String: String] = [:],
        strings: StringOverrides = [:],
        auth: @escaping @Sendable () async throws -> String,
        logLevel: RiviLogLevel = .info,
        logger: RiviLogger? = nil,
        transport: RiviTransport = URLSessionTransport(),
        clock: RiviClock = SystemClock()
    ) {
        self.tenant = tenant
        overrides = strings
        let i18n = BundledData.i18n(locale: locale, overrides: strings)
        self.i18n = i18n
        let background = self.background
        session = RiviSession(options: RiviSessionOptions(
            baseURL: environment.baseURL,
            tenant: tenant.name,
            tier: tenant.tier,
            metadata: JSONObject(metadata.sorted { $0.key < $1.key }.map { ($0.key, JSONValue.string($0.value)) }),
            locale: locale,
            currency: currency,
            auth: auth,
            i18n: i18n,
            transport: transport,
            clock: clock,
            isHidden: { background.isHidden },
            logger: logger ?? ConsoleRiviLogger(level: logLevel)
        ))
        state = session.state
        // Every ask and sort-best carries the app's current filters; reporting them makes no request.
        session.requestFilters = { [weak self] in self?.filters }
        session.subscribe { [weak self] state in self?.onState(state) }
        session.onCommand { [weak self] command in self?.later { $0.onCommand(command) } }
        session.onInput { [weak self] input in self?.onInput(input) }
        syncElementsLanguage(locale)
        observeAppLifecycle()
    }

    /// The bound elements take their layout direction and built-in strings from
    /// `RiviSmartSortConfiguration.shared.language`.
    private func syncElementsLanguage(_ locale: String) {
        RiviSmartSortConfiguration.shared.language = baseLanguage(locale) == "ar" ? .arabic : .english
    }

    deinit {
        observers.removeAll()
        let session = self.session
        Task { @MainActor in session.destroy() }
    }

    /// Ends the session: closes the ranking stream and cancels everything in flight. Call it
    /// when the results screen goes away (it also happens on deinit).
    public func destroy() {
        observers.removeAll()
        session.destroy()
        eventContinuations.values.forEach { $0.finish() }
        eventContinuations.removeAll()
    }

    // MARK: - Tenant facts

    /// The current search. A new `searchId` (or product) resets Smart Sort (rule 9).
    public var search: RiviSearch? {
        get { sent.search }
        set { update(search: newValue) }
    }

    /// The tenant's sort tab. Leaving Best with an active query asks first (rule 10).
    public var sort: SortMode {
        get { state.sort }
        set { update(sort: newValue) }
    }

    /// The leg being shown. Smart Sort is off on the return leg (rule 16).
    public var stage: Stage {
        get { state.stage }
        set { update(stage: newValue) }
    }

    /// Optional: how many results the tenant has loaded, and whether loading finished. Leave it
    /// unset when the list is Rivi's.
    public var pool: PoolFact? {
        get { sent.pool }
        set { update(pool: newValue) }
    }

    /// Optional: the tenant's applied filters, any JSON value (e.g. `["stops": [0], "maxPrice": 500]`).
    /// nil means no filters. Your app filters its list locally, so changing them makes no request
    /// (no sort-best, no ask). The next request (an ask, a chip removal, a new search) carries the
    /// current filters. With `visible`, they also let the banner say when your filters may be
    /// hiding recommended results.
    public var filters: JSONValue? {
        get { sent.filters ?? nil }
        set { update(filters: .some(newValue)) }
    }

    /// Optional: the ids the tenant actually renders after its own filters and paging.
    public var visible: [String]? {
        get { sent.visible ?? nil }
        set { update(visible: .some(newValue)) }
    }

    /// Reports several facts at once, dispatched in the contract's order (R3): pool, sort,
    /// stage, filters, search, visible. Only real changes are dispatched.
    public func update(search: RiviSearch? = nil, sort: SortMode? = nil, stage: Stage? = nil,
                       pool: PoolFact? = nil, filters: JSONValue?? = nil, visible: [String]?? = nil) {
        if let pool, pool != sent.pool {
            sent.pool = pool
            session.dispatch(.poolChanged(pool))
        }
        if let sort, sort != sent.sort ?? state.sort {
            sent.sort = sort
            session.dispatch(.setSort(sort))
        }
        if let stage, stage != sent.stage ?? state.stage {
            sent.stage = stage
            session.dispatch(.setStage(stage))
        }
        if let filters {
            // Not dispatched, so a filter change makes no request. `session.requestFilters` reads
            // them when the next ask or sort-best is sent.
            sent.filters = .some(filters.flatMap { $0.isNull ? nil : $0 })
        }
        if let search, search != sent.search {
            sent.search = search
            session.dispatch(.setSearch(search))
        }
        if let visible, sent.visible == nil || visible != sent.visible! {
            sent.visible = .some(visible)
            session.dispatch(.setVisible(visible))
        }
    }

    /// Switches language: chips are re-projected and later requests use it.
    public func setLocale(_ locale: String, strings: StringOverrides? = nil) {
        if let strings { overrides = strings }
        let next = BundledData.i18n(locale: locale, overrides: overrides)
        i18n = next
        syncElementsLanguage(locale)
        session.setI18n(next)
    }

    // MARK: - User intents (the bound views call these)

    public func ask(_ text: String) { session.dispatch(.ask(text: text)) }

    /// Asks with these filters: they replace the reported ones (making no request of their own) and
    /// go in this ask's body. nil keeps the filters already reported.
    public func ask(_ text: String, filters: JSONValue?) {
        if let filters { self.filters = filters }
        ask(text)
    }
    public func removeChip(id: String) { session.dispatch(.removeChip(id: id)) }

    /// The elements report chips by label; labels are unique.
    public func removeChip(label: String) {
        guard let chip = state.chips.first(where: { $0.label == label }) else { return }
        removeChip(id: chip.id)
    }

    public func clearAll() { session.dispatch(.clearAll) }
    public func retry() { session.dispatch(.retry) }
    public func dismissError() { session.dispatch(.dismissError) }

    /// Answers `.confirmSortChange`.
    public func resolveSortConfirmation(accepted: Bool) {
        isConfirmingSortChange = false
        guard state.pendingConfirm != nil else { return }
        session.dispatch(.confirmResolved(accepted: accepted))
    }

    /// "Show matches": tells the tenant which hidden full matches to reveal.
    public func showHiddenMatches() {
        let ids = selectHiddenMatches(state)
        if !ids.isEmpty { emit(.showHidden(ids)) }
    }

    // MARK: - Derived state (the selectors)

    /// Smart Sort can be used now: a search is set, it is not multi-city, and this is the onward leg.
    public var isAvailable: Bool { state.available }
    public var chips: [Chip] { selectChipsVisible(state) ? state.chips : [] }
    public var chipLabels: Set<String> { Set(chips.map(\.label)) }
    public var banner: BannerView { selectBanner(state) }
    public var explanation: String { state.explanation }
    /// False while the explain stream is still sending text: the banners wait for the whole
    /// explanation and then type it out.
    public var isExplanationComplete: Bool { state.explanation == completedExplanation }
    public var notice: String? { state.notice }
    public var error: RiviError? { state.error }
    public var inputValue: InputValue { selectInputValue(state) }
    public var ranking: [RankingEntry] { selectRanking(state) }
    public var rankingStatus: RankingStatus { state.rankingStatus }
    public var hiddenMatches: [String] { selectHiddenMatches(state) }
    public var queryType: QueryType { state.search?.product == .hotel ? .hotel : .flight }

    /// Rule 11: the partial-match indicator for one result. nil when the id is not ranked.
    public func matchesAllPreferences(id: String) -> Bool? {
        ranking.first { $0.id == id }?.matchesAllPreferences
    }

    public func tags(for id: String) -> [String] {
        ranking.first { $0.id == id }?.tags ?? []
    }

    /// The localized message for a key (ICU subset), e.g. `explain.fallback`.
    public func text(_ key: String, _ values: [String: MessageArg] = [:]) -> String {
        i18n.t(key, values)
    }

    // MARK: - Events

    /// Every event, as an async sequence. Each call returns an independent stream.
    public var events: AsyncStream<RiviSmartSortEvent> {
        let id = UUID()
        let (stream, continuation) = AsyncStream<RiviSmartSortEvent>.makeStream()
        eventContinuations[id] = continuation
        continuation.onTermination = { [weak self] _ in
            Task { @MainActor in self?.eventContinuations[id] = nil }
        }
        return stream
    }

    private func emit(_ event: RiviSmartSortEvent) {
        onEvent?(event)
        for continuation in eventContinuations.values { continuation.yield(event) }
    }

    /// Runs on the next main-actor turn, so tenant handlers that call back into the model never
    /// re-enter the session.
    private func later(_ run: @escaping (RiviSmartSort) -> Void) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            run(self)
        }
    }

    /// The explanation is whole once its stream ends or fails; until then frames keep extending it.
    private func onInput(_ input: Input) {
        switch input {
        case .explainEnd(let epoch), .failed(let epoch, _):
            guard epoch == state.epoch, completedExplanation != state.explanation else { return }
            completedExplanation = state.explanation
        default:
            // A reset or cleared query empties the explanation; nothing is streaming then.
            if state.explanation.isEmpty && !completedExplanation.isEmpty { completedExplanation = "" }
        }
    }

    private func onState(_ next: RiviState) {
        state = next
        let ranking = selectRanking(next)
        var best = next
        best.sort = .best
        let all = next.sort == .best ? ranking : selectRanking(best)
        if next.rankingStatus != lastStatus || ranking != lastRanking || all != lastAll {
            lastRanking = ranking
            lastAll = all
            lastStatus = next.rankingStatus
            let status = next.rankingStatus
            self.later { $0.emit(.ranking(ranking: ranking, all: all, status: status)) }
        }
        if next.error != lastError {
            lastError = next.error
            if let error = next.error { self.later { $0.emit(.error(error)) } }
        }
        if next.pendingConfirm == nil && isConfirmingSortChange { isConfirmingSortChange = false }
    }

    private func onCommand(_ command: Command) {
        switch command {
        case .rankingCleared:
            emit(.rankingCleared)
        case .confirmSortChange(let sort):
            if presentsSortConfirmation { isConfirmingSortChange = true }
            emit(.confirmSortChange(sort))
        case .sortChanged(let sort):
            // The contract already holds this sort, so the tenant echoing it is not a change.
            sent.sort = sort
            emit(.sortChanged(sort))
        default:
            break
        }
    }

    // MARK: - App lifecycle

    private func observeAppLifecycle() {
        #if canImport(UIKit)
        // The observers capture only the session and the flag (both Sendable), never self, and
        // are removed in destroy() / deinit.
        let session = self.session
        let background = self.background
        let center = NotificationCenter.default
        for (name, hidden) in [(UIApplication.didEnterBackgroundNotification, true),
                               (UIApplication.willEnterForegroundNotification, false)] {
            observers.add(center.addObserver(forName: name, object: nil, queue: .main) { _ in
                MainActor.assumeIsolated {
                    background.isHidden = hidden
                    session.visibilityChanged()
                }
            })
        }
        #endif
    }
}

/// NotificationCenter observer tokens, removable from deinit.
private final class ObserverBag: @unchecked Sendable {
    private let lock = NSLock()
    private var tokens: [NSObjectProtocol] = []

    func add(_ token: NSObjectProtocol) {
        lock.lock()
        tokens.append(token)
        lock.unlock()
    }

    func removeAll() {
        lock.lock()
        let removed = tokens
        tokens.removeAll()
        lock.unlock()
        removed.forEach(NotificationCenter.default.removeObserver)
    }
}

/// Whether the app is in the background, readable from the runtime's closure.
private final class BackgroundFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var hidden = false

    var isHidden: Bool {
        get { lock.lock(); defer { lock.unlock() }; return hidden }
        set { lock.lock(); hidden = newValue; lock.unlock() }
    }
}
