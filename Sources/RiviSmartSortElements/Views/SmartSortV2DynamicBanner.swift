import SwiftUI

/// The Smart Sort V2 results banner ("Ranked by your preferences").
///
/// A header with the sparkle, the title, "Edit" and ✕; the active preferences as removable chips
/// (`RiviChipsView` with the sparkle icon); then either a pulsing skeleton while `isLoading`, or
/// the explanation, which types itself out word by word as it streams in
/// (`SmartSortStreamingText`). If the last request failed, an inline error offers "Try again".
///
/// When the host's filters hide some of what Smart Sort recommends, pass a `filterNotice`: it
/// replaces the explanation with "Your filters are hiding some recommended flights · Clear filters"
/// (`.info`), or a yellow note when they hide the flights the user asked for (`.warning`).
///
/// With `layout: .collapsible` (the Rivi design) the header is instead a row that collapses and
/// expands the body: the sparkle, "Why these flights are recommended" and a chevron. The chips
/// share a row with "Edit", hidden until the chips arrive, there is no ✕, and the body (error, loading, notice or explanation)
/// closes over its content: nothing moves, and the explanation isn't typed out again on reopening.
public struct SmartSortV2DynamicBanner: View {
    // MARK: - Filter notice

    /// A note about the host's filters hiding recommended results.
    public struct FilterNotice: Equatable {
        public enum Tone: Equatable {
            /// Some recommended results are hidden.
            case info
            /// The results the user asked for are hidden.
            case warning
        }

        public var tone: Tone
        public var text: String

        public init(tone: Tone, text: String) {
            self.tone = tone
            self.text = text
        }

        /// "Your filters are hiding some recommended flights." (or hotels)
        public static func hidingRecommended(_ queryType: QueryType) -> FilterNotice {
            FilterNotice(tone: .info, text: (queryType == .hotel ? "smart_sort_v2_filters_hiding_hotel" : "smart_sort_v2_filters_hiding_flight").localized())
        }

        /// "Your filters are hiding the flights you asked for." (or hotels)
        public static func hidingMatches(_ queryType: QueryType) -> FilterNotice {
            FilterNotice(tone: .warning, text: (queryType == .hotel ? "smart_sort_v2_filters_hiding_matches_hotel" : "smart_sort_v2_filters_hiding_matches_flight").localized())
        }
    }

    // MARK: - Configuration

    public struct Configuration {
        /// How the banner is laid out.
        public enum Layout {
            /// Title, "Edit" and ✕ in the header; chips below; then the body (the default).
            case classic
            /// A header that collapses the body (sparkle, `collapsibleTitleText`, chevron); chips and
            /// "Edit" on one row; no ✕.
            case collapsible
        }

        /// What shows while the explanation loads.
        public enum LoadingStyle {
            /// Three pulsing bars (the default).
            case skeleton
            /// `loadingText` with a light band sweeping across it.
            case shimmerText
        }

        /// Where the filter notice's "Clear filters" goes.
        public enum ClearFiltersPlacement {
            /// Inline after the notice text, like a link (the default).
            case inline
            /// A button at the notice's trailing edge.
            case trailing
        }

        // MARK: - Layout options
        public var layout: Layout = .classic
        /// The `.collapsible` header's title. nil: "Why these flights are recommended" (or hotels,
        /// from the banner's `queryType`).
        public var collapsibleTitleText: String? = nil
        /// The header chevron (`.collapsible`). nil uses `clearButtonColor`.
        public var chevronColor: Color? = nil
        /// Shows the pencil before "Edit".
        public var showsEditIcon: Bool = true
        public var loadingStyle: LoadingStyle = .skeleton
        /// `.shimmerText`: the text. Defaults to "Explaining top picks…".
        public var loadingText: String = "smart_sort_v2_banner_explaining".localized()
        /// `.shimmerText`: the text's color, and the band that sweeps across it.
        public var loadingTextColor: Color = Color(light: "#6A6D70", dark: "#8D9195")
        public var loadingShimmerColor: Color = Color(light: "#C3CDD9", dark: "#5A6470")
        /// Chips fade and scale in one after another as they arrive (`RiviChipsView`'s
        /// `animatesEntrance`), whatever `chipsConfiguration` says.
        public var animatesChipEntrance: Bool = true
        public var clearFiltersPlacement: ClearFiltersPlacement = .inline
        /// The info notice's SF Symbol. Defaults to "info.circle".
        public var noticeIconName: String = "info.circle"

        // MARK: - Text
        public var titleText: String
        public var editButtonText: String
        public var errorText: String
        public var retryButtonText: String
        /// The link after a filter notice.
        public var clearFiltersText: String

        // MARK: - Fonts
        public var titleFont: Font
        public var editButtonFont: Font
        public var explanationFont: Font
        public var errorFont: Font
        public var retryButtonFont: Font
        public var filterNoticeFont: Font
        public var clearFiltersFont: Font

        // MARK: - Chips
        /// The chips' look. The default shows the sparkle icon and a bold key, without "Clear all".
        public var chipsConfiguration: RiviChipsView.Configuration

        // MARK: - Streaming
        /// How the explanation reveals itself.
        public var streamingUnit: SmartSortStreamingText.Unit
        /// Seconds between reveal steps.
        public var streamingInterval: TimeInterval

        // MARK: - Layout
        public var padding: EdgeInsets
        public var spacing: CGFloat
        public var cornerRadius: CGFloat
        public var sparkleSize: CGFloat
        /// Extra space between the explanation's lines.
        public var explanationLineSpacing: CGFloat

        // MARK: - Colors
        /// Fills the background with this gradient (leading to trailing, the design's 100°) instead
        /// of `backgroundColor`. nil by default.
        public var backgroundGradient: [Color]? = nil
        public var backgroundColor: Color
        public var borderColor: Color
        public var titleColor: Color
        public var sparkleConfiguration: SmartSortSparkle.Configuration
        public var editButtonColor: Color
        public var clearButtonColor: Color
        public var explanationColor: Color
        /// The first skeleton bar; the others use `skeletonSecondaryColor`.
        public var skeletonColor: Color
        public var skeletonSecondaryColor: Color
        public var errorBackgroundColor: Color
        public var errorBorderColor: Color
        public var errorTextColor: Color
        public var retryButtonBorderColor: Color
        public var retryButtonBackgroundColor: Color
        public var noticeBackgroundColor: Color
        public var noticeBorderColor: Color
        public var noticeTextColor: Color
        /// The info notice's icon.
        public var noticeIconColor: Color
        public var warningBackgroundColor: Color
        public var warningBorderColor: Color
        public var warningTextColor: Color
        public var clearFiltersColor: Color

        /// The chips' default look in this banner.
        public static var defaultChips: RiviChipsView.Configuration {
            var chips = RiviChipsView.Configuration.default
            chips.font = .system(size: 14, weight: .regular)
            chips.keyFont = .system(size: 14, weight: .semibold)
            chips.cornerRadius = 18
            chips.chipPadding = EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12)
            chips.removeIconSize = 12
            chips.textIconSpacing = 6
            chips.showClearAllButton = false
            chips.chipBackgroundColor = Color(light: "#EBE3FC", dark: "#2E2547")
            chips.chipBorderColor = .clear
            chips.chipTextColor = AppColor.smartSortAccent
            chips.removeIconColor = AppColor.smartSortAccent
            chips.icon = SmartSortSparkle.image
            chips.showsIcon = false // set true to show the sparkle in each chip
            chips.iconSize = 16
            chips.fadesEdges = true
            return chips
        }

        /// The Smart Sort V2 design.
        public static var `default`: Configuration {
            Configuration(
                titleText: "smart_sort_v2_banner_title".localized(),
                editButtonText: "smart_sort_v2_banner_edit".localized(),
                errorText: "smart_sort_v2_error".localized(),
                retryButtonText: "smart_sort_v2_retry_button".localized(),
                clearFiltersText: "smart_sort_v2_clear_filters".localized(),
                titleFont: .system(size: 15, weight: .semibold),
                editButtonFont: .system(size: 15, weight: .regular),
                explanationFont: .system(size: 14, weight: .regular),
                errorFont: .system(size: 13, weight: .regular),
                retryButtonFont: .system(size: 13, weight: .semibold),
                filterNoticeFont: .system(size: 14, weight: .regular),
                clearFiltersFont: .system(size: 14, weight: .semibold),
                chipsConfiguration: defaultChips,
                streamingUnit: .character, // the same typewriter as RiviInfoBanner's explanation
                streamingInterval: 0.02,
                padding: EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16),
                spacing: 12,
                cornerRadius: 16,
                sparkleSize: 18,
                explanationLineSpacing: 3,
                backgroundColor: Color(light: "#F8F5FE", dark: "#221D33"),
                borderColor: Color(light: "#E6DDFB", dark: "#3B3159"),
                titleColor: Color(light: "#1B1B1F", dark: "#FAFAFA"),
                sparkleConfiguration: .default,
                editButtonColor: AppColor.smartSortAccent,
                clearButtonColor: Color(light: "#3A3A42", dark: "#FAFAFA"),
                explanationColor: Color(light: "#3A3A42", dark: "#CBD5E1"),
                skeletonColor: Color(light: "#E6DEF7", dark: "#3B3159"),
                skeletonSecondaryColor: Color(light: "#EBE5F8", dark: "#332A4D"),
                errorBackgroundColor: Color(light: "#FDF0F2", dark: "#3A1F24"),
                errorBorderColor: Color(light: "#F6D2D8", dark: "#6B2A35"),
                errorTextColor: Color(light: "#8F1D2F", dark: "#FF8A9B"),
                retryButtonBorderColor: Color(light: "#E6B3BC", dark: "#6B2A35"),
                retryButtonBackgroundColor: AppColor.background,
                noticeBackgroundColor: AppColor.background,
                noticeBorderColor: Color(light: "#E6DDFB", dark: "#3B3159"),
                noticeTextColor: Color(light: "#3A3A42", dark: "#CBD5E1"),
                noticeIconColor: AppColor.smartSortAccent,
                warningBackgroundColor: Color(light: "#FDF6E7", dark: "#33290F"),
                warningBorderColor: Color(light: "#F1DFB5", dark: "#5C4A1F"),
                warningTextColor: Color(light: "#5C4400", dark: "#F1D58A"),
                clearFiltersColor: AppColor.smartSortAccent
            )
        }

        public init(
            titleText: String,
            editButtonText: String,
            errorText: String,
            retryButtonText: String,
            clearFiltersText: String,
            titleFont: Font,
            editButtonFont: Font,
            explanationFont: Font,
            errorFont: Font,
            retryButtonFont: Font,
            filterNoticeFont: Font,
            clearFiltersFont: Font,
            chipsConfiguration: RiviChipsView.Configuration,
            streamingUnit: SmartSortStreamingText.Unit,
            streamingInterval: TimeInterval,
            padding: EdgeInsets,
            spacing: CGFloat,
            cornerRadius: CGFloat,
            sparkleSize: CGFloat,
            explanationLineSpacing: CGFloat,
            backgroundColor: Color,
            borderColor: Color,
            titleColor: Color,
            sparkleConfiguration: SmartSortSparkle.Configuration,
            editButtonColor: Color,
            clearButtonColor: Color,
            explanationColor: Color,
            skeletonColor: Color,
            skeletonSecondaryColor: Color,
            errorBackgroundColor: Color,
            errorBorderColor: Color,
            errorTextColor: Color,
            retryButtonBorderColor: Color,
            retryButtonBackgroundColor: Color,
            noticeBackgroundColor: Color,
            noticeBorderColor: Color,
            noticeTextColor: Color,
            noticeIconColor: Color,
            warningBackgroundColor: Color,
            warningBorderColor: Color,
            warningTextColor: Color,
            clearFiltersColor: Color
        ) {
            self.titleText = titleText
            self.editButtonText = editButtonText
            self.errorText = errorText
            self.retryButtonText = retryButtonText
            self.clearFiltersText = clearFiltersText
            self.titleFont = titleFont
            self.editButtonFont = editButtonFont
            self.explanationFont = explanationFont
            self.errorFont = errorFont
            self.retryButtonFont = retryButtonFont
            self.filterNoticeFont = filterNoticeFont
            self.clearFiltersFont = clearFiltersFont
            self.chipsConfiguration = chipsConfiguration
            self.streamingUnit = streamingUnit
            self.streamingInterval = streamingInterval
            self.padding = padding
            self.spacing = spacing
            self.cornerRadius = cornerRadius
            self.sparkleSize = sparkleSize
            self.explanationLineSpacing = explanationLineSpacing
            self.backgroundColor = backgroundColor
            self.borderColor = borderColor
            self.titleColor = titleColor
            self.sparkleConfiguration = sparkleConfiguration
            self.editButtonColor = editButtonColor
            self.clearButtonColor = clearButtonColor
            self.explanationColor = explanationColor
            self.skeletonColor = skeletonColor
            self.skeletonSecondaryColor = skeletonSecondaryColor
            self.errorBackgroundColor = errorBackgroundColor
            self.errorBorderColor = errorBorderColor
            self.errorTextColor = errorTextColor
            self.retryButtonBorderColor = retryButtonBorderColor
            self.retryButtonBackgroundColor = retryButtonBackgroundColor
            self.noticeBackgroundColor = noticeBackgroundColor
            self.noticeBorderColor = noticeBorderColor
            self.noticeTextColor = noticeTextColor
            self.noticeIconColor = noticeIconColor
            self.warningBackgroundColor = warningBackgroundColor
            self.warningBorderColor = warningBorderColor
            self.warningTextColor = warningTextColor
            self.clearFiltersColor = clearFiltersColor
        }
    }

    // MARK: - Properties

    private let configuration: Configuration
    @Binding private var chips: Set<String>
    /// The chips in display order, when given as a list.
    private var orderedChips: [String]?
    private var queryType: QueryType
    private let explanation: String
    private let isLoading: Bool
    private let isShowingError: Bool
    private let filterNotice: FilterNotice?
    private let onEdit: () -> Void
    private let onClear: () -> Void
    private let onRemoveChip: (String) -> Void
    private let onRetry: (() -> Void)?
    private let onDismissError: (() -> Void)?
    private let onClearFilters: (() -> Void)?

    @State private var isCollapsed = false

    /// `cubic-bezier(.5,1,.89,1)`, as in the design.
    private static let collapseAnimation = Animation.timingCurve(0.5, 1, 0.89, 1, duration: 0.3)

    // MARK: - Initialization

    /// - Parameters:
    ///   - configuration: Text, fonts, layout and colors (defaults to `.default`).
    ///   - chips: The active preferences.
    ///   - explanation: The explanation so far. It may grow as it streams in.
    ///   - isLoading: Shows the skeleton in place of the explanation.
    ///   - isShowingError: Shows the inline error.
    ///   - filterNotice: Shown in place of the explanation while the host's filters hide results.
    ///   - onEdit: "Edit", typically to reopen the Smart Sort sheet.
    ///   - onClear: ✕, to clear Smart Sort.
    ///   - onRemoveChip: A chip's ✕, with its label.
    ///   - onRetry: The error's "Try again". nil hides the button.
    ///   - onDismissError: The error's ✕. nil hides the button.
    ///   - onClearFilters: The notice's "Clear filters" link: clear your filters. nil hides the link.
    public init(
        configuration: Configuration = .default,
        chips: Binding<Set<String>>,
        explanation: String,
        isLoading: Bool = false,
        isShowingError: Bool = false,
        filterNotice: FilterNotice? = nil,
        onEdit: @escaping () -> Void,
        onClear: @escaping () -> Void,
        onRemoveChip: @escaping (String) -> Void,
        onRetry: (() -> Void)? = nil,
        onDismissError: (() -> Void)? = nil,
        onClearFilters: (() -> Void)? = nil
    ) {
        self.configuration = configuration
        self._chips = chips
        self.orderedChips = nil
        self.queryType = .flight
        self.explanation = explanation
        self.isLoading = isLoading
        self.isShowingError = isShowingError
        self.filterNotice = filterNotice
        self.onEdit = onEdit
        self.onClear = onClear
        self.onRemoveChip = onRemoveChip
        self.onRetry = onRetry
        self.onDismissError = onDismissError
        self.onClearFilters = onClearFilters
    }

    /// The same, with the chips in a fixed order (the order of the query's preferences).
    /// - Parameters:
    ///   - chips: The active preferences, in display order. Remove a chip from your list in
    ///     `onRemoveChip`.
    ///   - queryType: Picks the `.collapsible` title's wording ("flights" or "hotels").
    public init(
        configuration: Configuration = .default,
        orderedChips chips: [String],
        queryType: QueryType = .flight,
        explanation: String,
        isLoading: Bool = false,
        isShowingError: Bool = false,
        filterNotice: FilterNotice? = nil,
        onEdit: @escaping () -> Void,
        onClear: @escaping () -> Void,
        onRemoveChip: @escaping (String) -> Void,
        onRetry: (() -> Void)? = nil,
        onDismissError: (() -> Void)? = nil,
        onClearFilters: (() -> Void)? = nil
    ) {
        self.init(configuration: configuration, chips: .constant(Set(chips)), explanation: explanation,
                  isLoading: isLoading, isShowingError: isShowingError, filterNotice: filterNotice,
                  onEdit: onEdit, onClear: onClear, onRemoveChip: onRemoveChip, onRetry: onRetry,
                  onDismissError: onDismissError, onClearFilters: onClearFilters)
        self.orderedChips = chips
        self.queryType = queryType
    }

    // MARK: - Body

    public var body: some View {
        Group {
            switch configuration.layout {
            case .classic: classicLayout
            case .collapsible: collapsibleLayout
            }
        }
        .padding(configuration.padding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: configuration.cornerRadius)
            .fill(smartSortFill(configuration.backgroundColor, gradient: configuration.backgroundGradient)))
        .overlay(RoundedRectangle(cornerRadius: configuration.cornerRadius).stroke(configuration.borderColor, lineWidth: 1))
        .animation(.timingCurve(0.33, 1, 0.68, 1, duration: 0.2), value: hasChips)
        .animation(.easeInOut(duration: 0.2), value: isLoading)
        .animation(.easeInOut(duration: 0.2), value: isShowingError)
        .animation(.easeInOut(duration: 0.2), value: filterNotice)
        .environment(\.layoutDirection, RiviSmartSortConfiguration.shared.language.layoutDirection)
    }

    private var hasChips: Bool { !(orderedChips?.isEmpty ?? chips.isEmpty) }

    private var hasBodyContent: Bool {
        isShowingError || isLoading || filterNotice != nil || !explanation.isEmpty
    }

    private var classicLayout: some View {
        VStack(alignment: .leading, spacing: configuration.spacing) {
            header()
            if hasChips {
                chipsView()
                    .transition(.opacity)
            }
            bodyContent()
        }
    }

    /// Header and chips always show; the body closes over its content when collapsed (height to
    /// 0, clipped, faded), so the text doesn't move and stays streamed.
    private var collapsibleLayout: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: configuration.spacing) {
                collapsibleHeader()
                // Hidden until the chips arrive (the banner shows straight away with "Explaining
                // top picks…"); then the row opens and the chips fade in one after another.
                if hasChips {
                    HStack(spacing: 8) {
                        chipsView()
                            .frame(maxWidth: .infinity, alignment: .leading)
                        editButton()
                    }
                    .transition(.opacity)
                }
            }
            VStack(alignment: .leading, spacing: 10) {
                bodyContent()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            // Expanded, the body takes its natural height, so a streaming explanation is never cut
            // off as it grows; collapsing animates that height to 0.
            .frame(height: isCollapsed ? 0 : nil, alignment: .top)
            .clipped()
            .opacity(isCollapsed ? 0 : 1)
            .padding(.top, isCollapsed || !hasBodyContent ? 0 : configuration.spacing)
            .allowsHitTesting(!isCollapsed)
            .accessibilityHidden(isCollapsed)
        }
    }

    @ViewBuilder
    private func chipsView() -> some View {
        let chipsConfiguration = {
            var chips = configuration.chipsConfiguration
            if configuration.animatesChipEntrance { chips.animatesEntrance = true }
            return chips
        }()
        if let orderedChips {
            RiviChipsView(configuration: chipsConfiguration, orderedChips: orderedChips, onRemove: onRemoveChip)
        } else {
            RiviChipsView(configuration: chipsConfiguration, chips: $chips, onRemove: onRemoveChip)
        }
    }

    /// Error, then the loading state, the filter notice, or the explanation.
    @ViewBuilder
    private func bodyContent() -> some View {
        if isShowingError {
            errorRow()
                .transition(.opacity)
        }
        if isLoading {
            Group {
                switch configuration.loadingStyle {
                case .skeleton:
                    SmartSortBannerSkeleton(primary: configuration.skeletonColor, secondary: configuration.skeletonSecondaryColor)
                case .shimmerText:
                    SmartSortShimmerText(text: configuration.loadingText, font: configuration.explanationFont,
                                         color: configuration.loadingTextColor, shimmer: configuration.loadingShimmerColor,
                                         lineSpacing: configuration.explanationLineSpacing)
                }
            }
            .transition(.opacity)
        } else if let filterNotice {
            filterNoticeRow(filterNotice)
                .transition(.opacity)
        } else if !explanation.isEmpty {
            SmartSortStreamingText(explanation, unit: configuration.streamingUnit, interval: configuration.streamingInterval)
                .font(configuration.explanationFont)
                .foregroundStyle(configuration.explanationColor)
                .lineSpacing(configuration.explanationLineSpacing)
                .frame(maxWidth: .infinity, alignment: .leading)
                .transition(.opacity)
        }
    }

    // MARK: - Subviews

    /// The `.collapsible` header: the whole row toggles the body. The chevron points up while
    /// expanded and turns over when collapsed.
    @ViewBuilder
    private func collapsibleHeader() -> some View {
        let title = configuration.collapsibleTitleText
            ?? (queryType == .hotel ? "smart_sort_v2_banner_why_hotel" : "smart_sort_v2_banner_why_flight").localized()
        Button {
            withAnimation(Self.collapseAnimation) { isCollapsed.toggle() }
        } label: {
            HStack(spacing: 8) {
                SmartSortSparkle(size: configuration.sparkleSize, configuration: configuration.sparkleConfiguration)
                Text(title)
                    .font(configuration.titleFont)
                    .foregroundStyle(configuration.titleColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.up")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(configuration.chevronColor ?? configuration.clearButtonColor)
                    .rotationEffect(.degrees(isCollapsed ? 180 : 0))
            }
            .padding(.leading, configuration.padding.leading)
            .padding(.trailing, configuration.padding.trailing + 2)
            .padding(.vertical, 6)
            .frame(minHeight: 40)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // The row reaches the banner's edges, so all of it is tappable.
        .padding(.leading, -configuration.padding.leading)
        .padding(.trailing, -configuration.padding.trailing)
        .accessibilityAddTraits(.isHeader)
        .accessibilityValue(Text((isCollapsed ? "smart_sort_v2_banner_collapsed_accessibility" : "smart_sort_v2_banner_expanded_accessibility").localized()))
    }

    private func editButton() -> some View {
        Button(action: onEdit) {
            HStack(spacing: 4) {
                if configuration.showsEditIcon {
                    Image(systemName: "pencil.line")
                        .font(.system(size: 14, weight: .regular))
                }
                Text(configuration.editButtonText)
                    .font(configuration.editButtonFont)
            }
            .foregroundStyle(configuration.editButtonColor)
            .padding(.horizontal, configuration.layout == .collapsible ? 2 : 0)
            .frame(minHeight: configuration.layout == .collapsible ? 30 : 32)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func header() -> some View {
        HStack(spacing: 8) {
            SmartSortSparkle(size: configuration.sparkleSize, configuration: configuration.sparkleConfiguration)
            Text(configuration.titleText)
                .font(configuration.titleFont)
                .foregroundStyle(configuration.titleColor)
                .lineLimit(1)
                .truncationMode(.tail)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 8)
            editButton()
            Button(action: onClear) {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(configuration.clearButtonColor)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.trailing, -6)
            .accessibilityLabel(Text("smart_sort_v2_banner_clear_accessibility".localized()))
        }
    }

    /// The notice, with "Clear filters" running inline after the text like a link, or as a button
    /// at its trailing edge (`clearFiltersPlacement`).
    @ViewBuilder
    private func filterNoticeRow(_ notice: FilterNotice) -> some View {
        let isWarning = notice.tone == .warning
        let textColor = isWarning ? configuration.warningTextColor : configuration.noticeTextColor
        let trailing = configuration.clearFiltersPlacement == .trailing
        HStack(alignment: trailing ? .center : .top, spacing: trailing ? 10 : 8) {
            Image(systemName: isWarning ? "exclamationmark.triangle" : configuration.noticeIconName)
                .foregroundStyle(isWarning ? configuration.warningTextColor : configuration.noticeIconColor)
                .font(.system(size: trailing ? 15 : 14, weight: trailing ? .regular : .medium))
                .padding(.top, trailing ? 0 : 2)
                .accessibilityHidden(true)
            if trailing {
                Text(notice.text)
                    .font(configuration.filterNoticeFont)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let onClearFilters {
                    Button(action: onClearFilters) {
                        Text(configuration.clearFiltersText)
                            .font(configuration.clearFiltersFont)
                            .foregroundStyle(configuration.clearFiltersColor)
                            .lineLimit(1)
                            .fixedSize()
                            .padding(.vertical, 6)
                            .padding(.horizontal, 4)
                    }
                    .buttonStyle(.plain)
                }
            } else {
                noticeText(notice.text)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .foregroundStyle(textColor)
        .padding(.leading, 12)
        .padding(.trailing, trailing ? 8 : 12)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: trailing ? 12 : 10).fill(isWarning ? configuration.warningBackgroundColor : configuration.noticeBackgroundColor))
        .overlay(RoundedRectangle(cornerRadius: trailing ? 12 : 10).stroke(isWarning ? configuration.warningBorderColor : configuration.noticeBorderColor, lineWidth: 1))
        .environment(\.openURL, OpenURLAction { url in
            guard url == Self.clearFiltersURL else { return .systemAction }
            onClearFilters?()
            return .handled
        })
    }

    private static let clearFiltersURL = URL(string: "rivi-smart-sort://clear-filters")!

    private func noticeText(_ text: String) -> Text {
        guard onClearFilters != nil else { return Text(text).font(configuration.filterNoticeFont) }
        var link = AttributedString(configuration.clearFiltersText)
        link.link = Self.clearFiltersURL
        link.foregroundColor = configuration.clearFiltersColor
        link.font = configuration.clearFiltersFont
        return Text(text + " ").font(configuration.filterNoticeFont) + Text(link)
    }

    @ViewBuilder
    private func errorRow() -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 16, weight: .medium))
            Text(configuration.errorText)
                .font(configuration.errorFont)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let onRetry {
                Button(action: onRetry) {
                    Text(configuration.retryButtonText)
                        .font(configuration.retryButtonFont)
                        .lineLimit(1)
                        .padding(.horizontal, 12)
                        .frame(height: 32)
                        .background(RoundedRectangle(cornerRadius: 8).fill(configuration.retryButtonBackgroundColor))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(configuration.retryButtonBorderColor, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            if let onDismissError {
                Button(action: onDismissError) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .medium))
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("smart_sort_prompt_dismiss_accessibility".localized()))
            }
        }
        .foregroundStyle(configuration.errorTextColor)
        .padding(.leading, 12)
        .padding(.trailing, 6)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 12).fill(configuration.errorBackgroundColor))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(configuration.errorBorderColor, lineWidth: 1))
    }
}

/// Three bars (100%, 92%, 55% wide) pulsing while the explanation loads.
private struct SmartSortBannerSkeleton: View {
    let primary: Color
    let secondary: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dimmed = false

    var body: some View {
        GeometryReader { proxy in
            VStack(alignment: .leading, spacing: 8) {
                bar(primary, width: proxy.size.width)
                bar(secondary, width: proxy.size.width * 0.92)
                bar(secondary, width: proxy.size.width * 0.55)
            }
        }
        .frame(height: 9 * 3 + 8 * 2)
        .padding(.vertical, 2)
        .opacity(dimmed ? 0.55 : 1)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) { dimmed = true }
        }
        .accessibilityElement()
        .accessibilityLabel(Text("smart_sort_v2_banner_loading_accessibility".localized()))
    }

    private func bar(_ color: Color, width: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 5).fill(color).frame(width: width, height: 9)
    }
}

/// Text with a light band sweeping across it, every 1.6s, while the explanation loads. Still with
/// Reduce Motion.
private struct SmartSortShimmerText: View {
    let text: String
    let font: Font
    let color: Color
    let shimmer: Color
    let lineSpacing: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = 1

    var body: some View {
        let label = Text(text).font(font)
        label
            .lineSpacing(lineSpacing)
            .foregroundStyle(color)
            .overlay {
                if !reduceMotion {
                    GeometryReader { geo in
                        LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: shimmer, location: 0.5), .init(color: .clear, location: 1)],
                                       startPoint: .leading, endPoint: .trailing)
                            .frame(width: geo.size.width * 0.6)
                            .offset(x: phase * geo.size.width * 1.6 - geo.size.width * 0.3)
                    }
                    .mask(label.lineSpacing(lineSpacing))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .onAppear {
                guard !reduceMotion else { return }
                phase = 1
                withAnimation(.linear(duration: 1.6).repeatForever(autoreverses: false)) { phase = -0.4 }
            }
            .accessibilityLabel(Text("smart_sort_v2_banner_loading_accessibility".localized()))
    }
}

/// A background fill: `gradient` (leading to trailing, the CSS `linear-gradient(100deg, …)`) when
/// given, otherwise `color`.
func smartSortFill(_ color: Color, gradient: [Color]?) -> AnyShapeStyle {
    guard let gradient, !gradient.isEmpty else { return AnyShapeStyle(color) }
    return AnyShapeStyle(LinearGradient(colors: gradient, startPoint: UnitPoint(x: 0, y: 0.41), endPoint: UnitPoint(x: 1, y: 0.59)))
}
