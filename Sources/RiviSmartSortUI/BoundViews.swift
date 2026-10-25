import SwiftUI
import RiviSmartSortContract
import RiviSmartSortElements

// The existing RiviSmartSortElements views, driven by a `RiviSmartSort` model. The views are unchanged: their
// inputs come from the contract's selectors and their callbacks become contract inputs. None of
// them takes a visibility input (rule 12): each shows itself when the contract says so.

extension RiviSmartSort {
    /// The elements bind a set of labels. Writes are ignored: removals arrive through the
    /// views' callbacks and change the state, which flows back here.
    fileprivate func labels(_ chips: [Chip]) -> Binding<Set<String>> {
        Binding(get: { Set(chips.map(\.label)) }, set: { _ in })
    }
}

/// `RiviChipsView` for the active query. Shown on Best with chips (rule 6), hidden otherwise.
public struct RiviSmartSortChips: View {
    @ObservedObject private var model: RiviSmartSort
    private let configuration: RiviChipsView.Configuration

    public init(_ model: RiviSmartSort, configuration: RiviChipsView.Configuration = .default) {
        self.model = model
        self.configuration = configuration
    }

    public var body: some View {
        let chips = model.chips
        if !chips.isEmpty {
            RiviChipsView(
                configuration: configuration,
                chips: model.labels(chips),
                onRemove: { model.removeChip(label: $0) }, // rule 4
                onClearAll: { model.clearAll() } // rule 5
            )
        }
    }
}

/// `RiviInfoBanner` for the explanation (rules 11, 13, 17). It renders the single banner value
/// the contract selects: loading, the explanation (also while it refreshes for a new round), the
/// fallback, or the conflict note. Hidden otherwise.
public struct RiviSmartSortBanner: View {
    @ObservedObject private var model: RiviSmartSort
    private let configuration: RiviInfoBanner.Configuration

    public init(_ model: RiviSmartSort, configuration: RiviInfoBanner.Configuration = .default) {
        self.model = model
        self.configuration = configuration
    }

    public var body: some View {
        let banner = model.banner
        if banner != .hidden {
            RiviInfoBanner(configuration: configured(for: banner), isLoading: banner == .loading || isAwaitingExplanation(banner))
        }
    }

    /// The explanation is still streaming: keep loading until it is whole, then type it out.
    private func isAwaitingExplanation(_ banner: BannerView) -> Bool {
        (banner == .explanation || banner == .refreshing) && !model.isExplanationComplete
    }

    private func configured(for banner: BannerView) -> RiviInfoBanner.Configuration {
        var configuration = self.configuration
        switch banner {
        case .explanation, .refreshing:
            // Refreshing keeps the previous text on screen instead of flashing the skeleton.
            configuration.descriptionText = model.explanation
        case .fallback:
            configuration.descriptionText = model.text("explain.fallback")
        case .conflict:
            configuration.descriptionText = model.text("explain.conflict", ["query": .string(model.state.query)])
        case .loading, .hidden:
            break
        }
        return configuration
    }
}

/// `SmartSortV2DynamicBanner` bound to the session. Shown while there are chips or an explanation
/// to show (the same banner value as `RiviSmartSortBanner`), hidden otherwise. ✕ clears the query,
/// a chip's ✕ re-asks without it, and a failed round shows the inline error with "Try again".
///
/// While a query is active and your app reports `filters`, the explanation gives way to a filter
/// notice: a yellow one when your filters hide every full match (the conflict banner), otherwise
/// "Your filters are hiding some recommended…". If your app also reports `visible`, that second
/// notice shows only while a top match is actually hidden.
public struct RiviSmartSortV2Banner: View {
    @ObservedObject private var model: RiviSmartSort
    private let configuration: SmartSortV2DynamicBanner.Configuration
    private let onEdit: () -> Void
    private let onClearFilters: (() -> Void)?

    /// - Parameters:
    ///   - onEdit: "Edit": typically reopens your Smart Sort sheet.
    ///   - onClearFilters: The notice's "Clear filters": clear your filters and report
    ///     `model.filters = nil`. nil hides the link.
    public init(_ model: RiviSmartSort, configuration: SmartSortV2DynamicBanner.Configuration = .default,
                onEdit: @escaping () -> Void, onClearFilters: (() -> Void)? = nil) {
        self.model = model
        self.configuration = configuration
        self.onEdit = onEdit
        self.onClearFilters = onClearFilters
    }

    public var body: some View {
        let banner = model.banner
        let chips = model.chips
        if !chips.isEmpty || banner != .hidden {
            SmartSortV2DynamicBanner(
                configuration: configuration,
                orderedChips: chips.map(\.label), // the query's order
                queryType: model.queryType,
                explanation: explanation(for: banner),
                // While the explanation streams in, keep loading; it types out once it is whole.
                isLoading: banner == .loading
                    || ((banner == .explanation || banner == .refreshing) && !model.isExplanationComplete),
                isShowingError: model.error != nil,
                filterNotice: filterNotice(for: banner),
                onEdit: onEdit,
                onClear: { model.clearAll() }, // rule 5
                onRemoveChip: { model.removeChip(label: $0) }, // rule 4
                onRetry: { model.retry() },
                onDismissError: { model.dismissError() },
                onClearFilters: onClearFilters
            )
        }
    }

    private func filterNotice(for banner: BannerView) -> SmartSortV2DynamicBanner.FilterNotice? {
        guard model.state.query != "", let filters = model.filters, filters != .null else { return nil }
        if banner == .conflict { return .hidingMatches(model.queryType) }
        // Without `visible` we can't tell what is hidden, so the notice stays up while filters are on.
        if model.visible != nil && model.hiddenMatches.isEmpty { return nil }
        return .hidingRecommended(model.queryType)
    }

    private func explanation(for banner: BannerView) -> String {
        switch banner {
        case .explanation, .refreshing: return model.explanation
        case .fallback: return model.text("explain.fallback")
        case .conflict: return model.text("explain.conflict", ["query": .string(model.state.query)])
        case .loading, .hidden: return ""
        }
    }
}

/// `RiviAskSheet` bound to the session: it restores the query and chips (rule 8), shows the
/// parameter-change notice, and sends Ask / RemoveChip / ClearAll.
public struct RiviSmartSortAskSheet: View {
    @ObservedObject private var model: RiviSmartSort
    @Binding private var isPresented: Bool
    private let configuration: RiviAskSheet.Configuration
    private let filters: JSONValue?

    /// - Parameter filters: Your applied filters, sent with the ask. nil keeps the ones you reported.
    public init(_ model: RiviSmartSort, isPresented: Binding<Bool>, configuration: RiviAskSheet.Configuration = .default,
                filters: JSONValue? = nil) {
        self.model = model
        _isPresented = isPresented
        self.configuration = configuration
        self.filters = filters
    }

    public var body: some View {
        let input = model.inputValue
        RiviAskSheet(
            configuration: configuration,
            isPresented: $isPresented,
            queryType: model.queryType,
            userQuery: input.text,
            chips: model.labels(input.chips),
            parameterChangeNotice: model.notice,
            onSubmit: { model.ask($0, filters: filters) },
            onRemoveChip: { model.removeChip(label: $0) },
            onClear: { model.clearAll() }
        )
    }
}

/// `SmartSortBottomSheet` (the classic Smart Sort sheet) bound to the session.
public struct RiviSmartSortBottomSheet: View {
    @ObservedObject private var model: RiviSmartSort
    @Binding private var isPresented: Bool
    private let configuration: SmartSortBottomSheet.Configuration
    private let filters: JSONValue?

    /// - Parameter filters: Your applied filters, sent with the ask. nil keeps the ones you reported.
    public init(_ model: RiviSmartSort, isPresented: Binding<Bool>, configuration: SmartSortBottomSheet.Configuration = .default,
                filters: JSONValue? = nil) {
        self.model = model
        _isPresented = isPresented
        self.configuration = configuration
        self.filters = filters
    }

    public var body: some View {
        SmartSortBottomSheet(
            configuration: configuration,
            isPresented: $isPresented,
            queryType: model.queryType,
            userQuery: model.inputValue.text,
            parameterChangeNotice: model.notice,
            onSubmit: { model.ask($0, filters: filters) },
            onClear: { model.clearAll() }
        )
    }
}

/// `SmartSortV2BottomSheet` bound to the session: it restores the current query and sends Ask.
/// Improve Results closes the sheet straight away; the ranking's progress and any error show in
/// `RiviSmartSortV2Banner`.
public struct RiviSmartSortV2BottomSheet: View {
    @ObservedObject private var model: RiviSmartSort
    @Binding private var isPresented: Bool
    private let configuration: SmartSortV2BottomSheet.Configuration
    private let focusesInputOnAppear: Bool
    private let startingExample: String?
    private let filters: JSONValue?
    private let filterLabels: [String]
    private let onClearAll: (() -> Void)?

    /// - Parameters:
    ///   - filters: Your applied filters, sent with the ask. nil keeps the ones you reported with
    ///     `model.filters`.
    ///   - filterLabels: The same filters in words ("Nonstop", "Morning"), for the "Your filters (…)
    ///     will now be used to rank flights." note. Shown only with `configuration.showsFiltersNote`.
    ///   - onClearAll: "Clear All" (with `configuration.showsClearAllButton`): called first, so you can
    ///     clear your filters (report `model.filters = nil`), then Smart Sort is cleared.
    public init(_ model: RiviSmartSort, isPresented: Binding<Bool>, configuration: SmartSortV2BottomSheet.Configuration = .default,
                focusesInputOnAppear: Bool = false, startingExample: String? = nil, filters: JSONValue? = nil,
                filterLabels: [String] = [], onClearAll: (() -> Void)? = nil) {
        self.model = model
        _isPresented = isPresented
        self.configuration = configuration
        self.focusesInputOnAppear = focusesInputOnAppear
        self.startingExample = startingExample
        self.filters = filters
        self.filterLabels = filterLabels
        self.onClearAll = onClearAll
    }

    public var body: some View {
        SmartSortV2BottomSheet(
            configuration: configuration,
            isPresented: $isPresented,
            queryType: model.queryType,
            userQuery: model.inputValue.text,
            startingExample: startingExample,
            filterLabels: filterLabels,
            focusesInputOnAppear: focusesInputOnAppear,
            onSubmit: { model.ask($0, filters: filters) },
            hasActiveQuery: !model.state.query.isEmpty,
            onClearAll: {
                onClearAll?()
                model.clearAll()
            }
        )
    }
}

/// `RiviAskButton`, enabled only while Smart Sort is available (rule 16: not on multi-city or
/// the return leg).
public struct RiviSmartSortAskButton: View {
    @ObservedObject private var model: RiviSmartSort
    private let configuration: RiviAskButton.Configuration
    private let action: () -> Void

    public init(_ model: RiviSmartSort, configuration: RiviAskButton.Configuration = .default, action: @escaping () -> Void) {
        self.model = model
        self.configuration = configuration
        self.action = action
    }

    public var body: some View {
        RiviAskButton(
            configuration: configuration,
            isEnabled: Binding(get: { model.isAvailable }, set: { _ in }),
            action: { if model.isAvailable { action() } }
        )
    }
}

extension View {
    /// Shows `RiviConfirmationDialog` when leaving Best would clear the active query (rule 10),
    /// and answers the contract with the user's choice. Set
    /// `model.presentsSortConfirmation = false` to show your own and call
    /// `resolveSortConfirmation(accepted:)` instead.
    public func riviSmartSortConfirmation(_ model: RiviSmartSort,
                                          configuration: RiviConfirmationDialog.Configuration = .default) -> some View {
        modifier(SortConfirmation(model: model, configuration: configuration))
    }
}

private struct SortConfirmation: ViewModifier {
    @ObservedObject var model: RiviSmartSort
    let configuration: RiviConfirmationDialog.Configuration

    func body(content: Content) -> some View {
        content.overlay {
            if model.isConfirmingSortChange {
                RiviConfirmationDialog(
                    configuration: configuration,
                    isPresented: $model.isConfirmingSortChange,
                    onCancel: { model.resolveSortConfirmation(accepted: false) },
                    onConfirm: { model.resolveSortConfirmation(accepted: true) }
                )
            }
        }
    }
}

/// `SmartSortHaloButton`, with the number of active preferences, disabled while Smart Sort isn't
/// available (rule 16: not on multi-city or the return leg).
public struct RiviSmartSortButton: View {
    @ObservedObject private var model: RiviSmartSort
    private let configuration: SmartSortHaloButton.Configuration
    private let action: () -> Void

    /// - Parameter action: Typically opens your Smart Sort sheet.
    public init(_ model: RiviSmartSort, configuration: SmartSortHaloButton.Configuration = .default, action: @escaping () -> Void) {
        self.model = model
        self.configuration = configuration
        self.action = action
    }

    public var body: some View {
        SmartSortHaloButton(configuration: configuration, count: model.chips.count, action: action)
            .disabled(!model.isAvailable)
    }
}

