// Selectors (web: smart-sort-core/src/contract/select.ts). The UI never reads raw state for these.

private let onwardScopes: Set<Scope> = [.itinerary, .onward, .hotel]

public func selectChipsVisible(_ s: RiviState) -> Bool {
    s.available && s.sort == .best && !s.chips.isEmpty
}

public func selectBannerVisible(_ s: RiviState) -> Bool {
    s.available && s.sort == .best && s.bannerMode != .hidden
}

/// The order the tenant applies to its own list. Empty means "use your own order".
public func selectRanking(_ s: RiviState) -> [RankingEntry] {
    if s.sort != .best { return [] }
    return s.ranking
        .filter { s.stage == .return ? $0.scope == .return : onwardScopes.contains($0.scope) }
        .enumerated()
        .sorted { ($0.element.rank, $0.offset) < ($1.element.rank, $1.offset) } // stable, like Array.prototype.sort
        .map(\.element)
}

public func selectVisibleRanking(_ s: RiviState) -> [RankingEntry] {
    let ranked = selectRanking(s)
    guard let visible = s.visible else { return ranked }
    let shown = Set(visible)
    return ranked.filter { shown.contains($0.id) }
}

/// Full matches in the top `topK` that the tenant is not rendering.
public func selectHiddenMatches(_ s: RiviState, topK: Int = 10) -> [String] {
    guard let visible = s.visible else { return [] }
    let shown = Set(visible)
    return selectRanking(s)
        .prefix(topK)
        .filter { $0.matchesAllPreferences && !shown.contains($0.id) }
        .map(\.id)
}

/// Every visible entry is partial and a full match is hidden. The hidden side counts only the
/// same top 10 as `selectHiddenMatches`, so "Show matches" always has something to show.
private func isConflict(_ s: RiviState) -> Bool {
    guard let visible = s.visible, s.query != "", s.bannerMode != .loading else { return false }
    if selectHiddenMatches(s).isEmpty { return false }
    let shown = Set(visible)
    return !selectRanking(s).contains { $0.matchesAllPreferences && shown.contains($0.id) }
}

/// The one value the banner renders. Still a single value, so rule 17 holds.
public func selectBanner(_ s: RiviState) -> BannerView {
    if !selectBannerVisible(s) { return .hidden }
    if isConflict(s) { return .conflict }
    if s.explanation != "" {
        return s.explanationEpoch != s.epoch && s.error == nil ? .refreshing : .explanation
    }
    if s.bannerMode == .loading { return .loading }
    if s.bannerMode == .fallback { return .fallback }
    return .hidden
}

public struct InputValue: Sendable, Equatable {
    public var text: String
    public var chips: [Chip]
}

/// The ask input restores itself from state (rule 8).
public func selectInputValue(_ s: RiviState) -> InputValue {
    InputValue(text: s.query != "" ? s.query : (s.pendingAsk ?? ""), chips: s.chips)
}

/// The selectors a conformance case may assert. Every platform implements all of them.
public enum SelectorName: String, CaseIterable, Sendable {
    case chipsVisible, bannerVisible, ranking, visibleRanking, hiddenMatches, banner, inputValue

    /// The selector's value on `state`, as JSON, for comparison with `cases.json`.
    public func evaluate(_ state: RiviState) -> JSONValue {
        switch self {
        case .chipsVisible: return .bool(selectChipsVisible(state))
        case .bannerVisible: return .bool(selectBannerVisible(state))
        case .ranking: return .array(selectRanking(state).map(\.json))
        case .visibleRanking: return .array(selectVisibleRanking(state).map(\.json))
        case .hiddenMatches: return .array(selectHiddenMatches(state).map { .string($0) })
        case .banner: return .string(selectBanner(state).rawValue)
        case .inputValue:
            let value = selectInputValue(state)
            return ["text": .string(value.text), "chips": .array(value.chips.map(\.json))]
        }
    }
}
