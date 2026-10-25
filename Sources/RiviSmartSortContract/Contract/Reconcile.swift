// The pure reconciler (web: smart-sort-core/src/contract/reconcile.ts). No clock, no randomness,
// no network, no UI: same inputs, same outputs. Keep it line-for-line comparable with the web.

public func initialState(_ config: RiviConfig = .default) -> RiviState {
    RiviState(
        search: nil,
        config: config,
        available: false,
        stage: .onward,
        sort: .best,
        pool: .rivi,
        query: "",
        chips: [],
        entities: Entities(),
        notice: nil,
        ranking: [],
        rankingStatus: .none,
        bannerMode: .hidden,
        explanation: "",
        explanationEpoch: nil,
        visible: nil,
        filters: nil,
        pendingAsk: nil,
        pendingConfirm: nil,
        epoch: 0,
        rankedEpoch: nil,
        explainedEpoch: nil,
        error: nil
    )
}

/// Smart Sort needs a search, is off for multi-city, and is off on the return leg (rule 16).
public func isAvailable(_ search: RiviSearch?, _ stage: Stage) -> Bool {
    guard let search else { return false }
    if search.tripType == .multicity { return false }
    return stage == .onward
}

public typealias Reconciled = (state: RiviState, commands: [Command])

private func keep(_ s: RiviState) -> Reconciled { (s, []) }

private func poolReady(_ s: RiviState) -> Bool {
    switch s.pool {
    case .rivi: return true
    case .fact(let pool): return pool.size > 0
    }
}

private func poolComplete(_ s: RiviState) -> Bool {
    switch s.pool {
    case .rivi: return true
    case .fact(let pool): return pool.complete
    }
}

private func canRound(_ s: RiviState) -> Bool { s.search != nil && s.available && poolReady(s) }
private func hasQuery(_ s: RiviState) -> Bool { s.query != "" || s.pendingAsk != nil }
private func hasEntities(_ s: RiviState) -> Bool { !s.entities.isEmpty }
private func hasPartial(_ ranking: [RankingEntry]) -> Bool { ranking.contains { !$0.matchesAllPreferences } }

/// Every rank round goes through here: a new epoch, everything in flight cancelled, one fetch.
/// The previous ranking and explanation stay until the new round replaces them (no flicker).
private func startRound(_ s: RiviState, prefix: [Command] = []) -> Reconciled {
    let epoch = s.epoch + 1
    let keepsBanner = s.bannerMode == .explanation || s.bannerMode == .fallback
    var next = s
    next.epoch = epoch
    next.rankingStatus = .provisional
    next.rankedEpoch = nil
    next.explainedEpoch = nil
    next.error = nil
    next.bannerMode = s.query == "" ? .hidden : keepsBanner ? s.bannerMode : .loading
    return (next, prefix + [
        .cancelInFlight(scope: .all),
        .cancelTimer(.one(.explain)),
        .cancelTimer(.one(.settle)),
        .fetch(epoch: epoch, request: rankRequest(s)),
    ])
}

/// The round's POST: ask with a query, sort-best without. Filters ride along when reported.
private func rankRequest(_ s: RiviState) -> FetchRequest {
    s.query == "" ? .sortBest(filters: s.filters) : .ask(query: s.query, filters: s.filters)
}

/// JSON null is no filters, as on the web.
private func normalizedFilters(_ filters: JSONValue?) -> JSONValue? {
    guard let filters, !filters.isNull else { return nil }
    return filters
}

/// Clearing the query hands ordering back, then re-ranks for Best without a query (R1).
private func clearQuery(_ s: RiviState, patch: (inout RiviState) -> Void = { _ in }) -> Reconciled {
    var cleared = s
    patch(&cleared)
    cleared.query = ""
    cleared.chips = []
    cleared.entities = Entities()
    cleared.notice = nil
    cleared.ranking = []
    cleared.rankingStatus = .none
    cleared.bannerMode = .hidden
    cleared.explanation = ""
    cleared.explanationEpoch = nil
    cleared.pendingAsk = nil
    cleared.pendingConfirm = nil
    cleared.rankedEpoch = nil
    cleared.explainedEpoch = nil
    cleared.error = nil
    if canRound(cleared) { return startRound(cleared, prefix: [.rankingCleared]) }
    cleared.epoch = s.epoch + 1
    return (cleared, [.rankingCleared, .cancelInFlight(scope: .all), .cancelTimer(.all)])
}

/// Explain needs a query, entities (never chips, rule 13) and a ranking frame in this epoch.
private func explainGate(_ s: RiviState) -> [Command] {
    if s.query == "" || !hasEntities(s) { return [] }
    if s.rankedEpoch != s.epoch || s.explainedEpoch == s.epoch { return [] }
    return [.startTimer(timer: .explain, ms: s.config.explainDebounceMs, epoch: s.epoch)]
}

public func reconcile(_ s: RiviState, _ input: Input) -> Reconciled {
    switch input {
    case .setSearch(let search):
        if let current = s.search, current.searchId == search.searchId, current.product == search.product {
            var next = s
            next.search = search
            next.available = isAvailable(search, s.stage)
            return keep(next)
        }
        // A new search resets the session but keeps the facts the tenant reported (R2).
        var fresh = initialState(s.config)
        fresh.sort = s.sort
        fresh.stage = s.stage
        fresh.filters = s.filters
        fresh.pool = s.pool
        fresh.search = search
        fresh.available = isAvailable(search, s.stage)
        fresh.epoch = s.epoch
        if canRound(fresh) { return startRound(fresh, prefix: [.cancelTimer(.all)]) }
        fresh.epoch = s.epoch + 1
        return (fresh, [.cancelInFlight(scope: .all), .cancelTimer(.all)])

    case .setStage(let stage):
        // The banner and chips hide through `available`; nothing is cleared (R5).
        var next = s
        next.stage = stage
        next.available = isAvailable(s.search, stage)
        if next.rankingStatus == .none && canRound(next) { return startRound(next) }
        return keep(next)

    case .poolChanged(let pool):
        let prev = s.pool
        var next = s
        next.pool = .fact(pool)
        if !canRound(next) { return keep(next) }
        guard case .fact(let prevFact) = prev, prevFact.size > 0 else {
            if let pending = next.pendingAsk {
                next.pendingAsk = nil
                return reconcile(next, .ask(text: pending))
            }
            return startRound(next)
        }
        if pool.size > prevFact.size {
            return (next, [.startTimer(timer: .chunk, ms: s.config.chunkCoalesceMs, epoch: s.epoch)])
        }
        if pool.complete && !prevFact.complete && s.rankedEpoch == s.epoch {
            return (next, [.startTimer(timer: .settle, ms: s.config.settleMs, epoch: s.epoch)])
        }
        return keep(next)

    case .setVisible(let ids):
        var next = s
        next.visible = ids
        return keep(next)

    case .setFilters(let raw):
        // JSONValue equality ignores object key order, so equal filters are not a change.
        let filters = normalizedFilters(raw)
        if filters == s.filters { return keep(s) }
        var next = s
        next.filters = filters
        // Rule 3: a filter change re-ranks with the query kept; a held ask stays held.
        return canRound(next) ? startRound(next) : keep(next)

    case .ask(let raw):
        let text = raw.trimmingWhitespace()
        if text == "" || !s.available { return keep(s) }
        if !poolReady(s) {
            var next = s
            next.pendingAsk = text
            next.bannerMode = .loading
            next.notice = nil
            next.error = nil
            return keep(next)
        }
        var cmds: [Command] = []
        if s.sort != .best { cmds.append(.sortChanged(sort: .best)) } // R4
        var next = s
        next.query = text
        next.pendingAsk = nil
        next.sort = .best
        next.pendingConfirm = nil
        next.chips = []
        next.entities = Entities()
        next.notice = nil
        next.explanation = ""
        next.explanationEpoch = nil
        next.bannerMode = .loading
        return startRound(next, prefix: cmds)

    case .removeChip(let id):
        if !s.chips.contains(where: { $0.id == id }) { return keep(s) }
        let remaining = s.chips.filter { $0.id != id }
        if remaining.isEmpty { return reconcile(s, .clearAll) } // rule 4
        var next = s
        next.chips = remaining
        next.query = remaining.map(\.label).joined(separator: ", ")
        next.entities = Entities()
        next.notice = nil
        next.explanation = ""
        next.explanationEpoch = nil
        next.bannerMode = .loading
        if !canRound(next) {
            // No round can start: drop the old query's in-flight work and park the re-ask.
            next.epoch = s.epoch + 1
            next.pendingConfirm = nil
            next.bannerMode = .hidden
            next.pendingAsk = next.search != nil && next.available ? next.query : nil
            return (next, [.cancelInFlight(scope: .all), .cancelTimer(.all)])
        }
        return startRound(next)

    case .clearAll:
        if !hasQuery(s) && s.chips.isEmpty { return keep(s) }
        return clearQuery(s) // rule 5

    case .setSort(let sort):
        if sort == s.sort { return keep(s) }
        let leavingBest = s.sort == .best && sort != .best
        if leavingBest && hasQuery(s) {
            var next = s
            next.pendingConfirm = sort
            return (next, [.confirmSortChange(sort: sort)]) // rule 10
        }
        var next = s
        next.sort = sort
        next.pendingConfirm = nil
        return keep(next) // rules 6, 15: never a fetch

    case .confirmResolved(let accepted):
        guard let target = s.pendingConfirm else { return keep(s) }
        if !accepted {
            var next = s
            next.pendingConfirm = nil
            return (next, [.sortChanged(sort: s.sort)])
        }
        return clearQuery(s) { $0.sort = target }

    case .retry:
        if s.error == nil { return keep(s) }
        if !canRound(s) {
            var next = s
            next.error = nil
            return keep(next)
        }
        return startRound(s)

    case .dismissError:
        var next = s
        next.error = nil
        return keep(next)

    case let .askResponse(epoch, entities, chips, notice):
        if epoch != s.epoch { return keep(s) }
        var next = s
        next.entities = entities
        next.chips = chips
        next.notice = chips.isEmpty ? nil : notice
        if !hasEntities(next) {
            next.bannerMode = .hidden
            next.explanation = ""
            next.explanationEpoch = nil
            return keep(next)
        }
        return (next, explainGate(next))

    case let .rankingFrame(epoch, ranking):
        if epoch != s.epoch { return keep(s) }
        var next = s
        next.ranking = ranking
        next.rankedEpoch = s.epoch
        // After an explain ended with no text, fallback follows the latest ranking.
        let explainEnded = s.query != "" &&
            s.explanation == "" &&
            s.error == nil &&
            s.explainedEpoch == s.epoch &&
            (s.bannerMode == .fallback || s.bannerMode == .hidden) &&
            hasEntities(s)
        if explainEnded { next.bannerMode = hasPartial(ranking) ? .fallback : .hidden }
        var cmds = explainGate(next)
        if poolComplete(next) {
            cmds.append(.startTimer(timer: .settle, ms: s.config.settleMs, epoch: s.epoch))
        }
        return (next, cmds)

    case let .explainFrame(epoch, text):
        if epoch != s.epoch || s.query == "" || text == "" { return keep(s) }
        var next = s
        next.explanation = text
        next.explanationEpoch = s.epoch
        next.bannerMode = .explanation
        return keep(next)

    case .explainEnd(let epoch):
        if epoch != s.epoch || s.query == "" { return keep(s) }
        var next = s
        if s.explanationEpoch == s.epoch && s.explanation != "" {
            next.bannerMode = .explanation
            return keep(next)
        }
        next.explanation = ""
        next.explanationEpoch = nil
        next.bannerMode = hasPartial(s.ranking) ? .fallback : .hidden // rules 11, 17
        return keep(next)

    case let .failed(epoch, error):
        if epoch != s.epoch { return keep(s) }
        var next = s
        next.error = error
        next.pendingAsk = nil
        next.bannerMode = s.explanation != "" ? s.bannerMode : .hidden
        return (next, [.cancelTimer(.one(.explain)), .cancelTimer(.one(.settle))])

    case let .timerFired(timer, epoch):
        if epoch != s.epoch { return keep(s) }
        switch timer {
        case .chunk:
            return canRound(s) ? startRound(s) : keep(s)
        case .explain:
            if s.query == "" || !hasEntities(s) { return keep(s) }
            if s.rankedEpoch != s.epoch || s.explainedEpoch == s.epoch { return keep(s) }
            var next = s
            next.explainedEpoch = s.epoch
            return (next, [
                .cancelInFlight(scope: .explain),
                .fetch(epoch: s.epoch, request: .explain(query: s.query, entities: s.entities)),
            ])
        case .settle:
            guard s.rankedEpoch == s.epoch else { return keep(s) }
            var next = s
            next.rankingStatus = .final
            return keep(next)
        }
    }
}

extension String {
    /// `String.prototype.trim()`: strips ECMAScript WhiteSpace and LineTerminator characters.
    func trimmingWhitespace() -> String {
        let scalars = unicodeScalars
        guard let first = scalars.firstIndex(where: { !$0.isJSWhitespace }) else { return "" }
        let last = scalars.lastIndex(where: { !$0.isJSWhitespace })!
        return String(scalars[first...last])
    }
}

extension Unicode.Scalar {
    var isJSWhitespace: Bool {
        switch value {
        case 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x20, 0xA0, 0x1680, 0x2028, 0x2029, 0x202F, 0x205F, 0x3000, 0xFEFF:
            return true
        case 0x2000...0x200A:
            return true
        default:
            return false
        }
    }
}
