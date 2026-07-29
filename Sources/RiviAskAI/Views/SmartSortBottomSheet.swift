import SwiftUI

/// A Smart Sort bottom sheet with Almatar-styled design.
///
/// Functionally equivalent to `RiviAskAISheet` (same callbacks, parameter change notice,
/// clear-all confirmation, info tooltip) but with a different visual layout:
/// - Close (X) and info (i) live in the navigation toolbar so they pick up the system
///   liquid-glass treatment on iOS 26+.
/// - A centered "Smart Sort" title.
/// - A white card containing the sparkle prompt, "Clear all" action, text input, and a
///   live character counter.
/// - A full-width "Improve results" submit button.
public struct SmartSortBottomSheet: View {
    // MARK: - Configuration

    /// Configuration options for the AlmatarSmartSortBottomSheet
    public struct Configuration {
        /// The toolbar title text
        public var titleText: String
        /// The prompt/description shown above the input
        public var promptText: String
        /// The placeholder text for the text field
        public var placeholderText: String
        /// The submit button text
        public var submitButtonText: String
        /// The clear all button text
        public var clearButtonText: String
        /// The info tooltip text
        public var infoTooltipText: String
        /// Maximum number of characters allowed in the input
        public var characterLimit: Int

        // MARK: - Fonts
        /// The title font
        public var titleFont: Font
        /// The prompt/description font
        public var promptFont: Font
        /// The input field font
        public var inputFont: Font
        /// The submit button font
        public var submitButtonFont: Font
        /// The clear all button font
        public var clearButtonFont: Font
        /// The character counter font
        public var counterFont: Font
        /// Tooltip font
        public var tooltipFont: Font

        // MARK: - Layout
        /// The outer padding inside the sheet
        public var padding: EdgeInsets
        /// The line limit of the text input field
        public var lineLimit: Int
        /// The spacing between major sections
        public var spacing: CGFloat
        /// The sparkle icon size
        public var sparkleIconSize: CGFloat
        /// Whether to show the sparkle icon in the prompt card
        public var showSparkleIcon: Bool
        /// Whether to show the info button in the toolbar
        public var showInfoButton: Bool
        /// The image used for the info toolbar button.
        ///
        /// Defaults to the system "info" SF Symbol. Pass any `Image` value to override
        /// — for example `Image("ic_info")` from your asset catalog. If using a template
        /// asset, configure it with `.renderingMode(.template)` so `infoButtonColor`
        /// tints it; if using an SF Symbol, the symbol size is controlled by
        /// `infoButtonIconSize`.
        public var infoButtonImage: Image
        /// The point size applied to the info button image (used as the SF Symbol size
        /// via `.font(...)`). Custom raster images should be sized via the `Image`
        /// itself (e.g. `.resizable().frame(width:height:)`).
        public var infoButtonIconSize: CGFloat
        /// Card corner radius
        public var cardCornerRadius: CGFloat
        /// Submit button corner radius
        public var submitButtonCornerRadius: CGFloat

        // MARK: - Colors
        /// Background color for the sheet
        public var backgroundColor: Color
        /// Background color for the white prompt card
        public var cardBackgroundColor: Color
        /// Text color for title
        public var titleColor: Color
        /// Color for the prompt/description text
        public var promptColor: Color
        /// Text color for input
        public var textColor: Color
        /// Toolbar close button tint
        public var closeButtonColor: Color
        /// Toolbar info button tint
        public var infoButtonColor: Color
        /// Sparkle icon color
        public var sparkleIconColor: Color
        /// Clear all button color
        public var clearButtonColor: Color
        /// Submit button background color
        public var submitButtonBackgroundColor: Color
        /// Submit button text color
        public var submitButtonTextColor: Color
        /// Character counter color
        public var counterColor: Color
        /// Tooltip background color
        public var tooltipBackgroundColor: Color
        /// Tooltip text color
        public var tooltipTextColor: Color

        /// Create a default configuration matching the Almatar Smart Sort design
        public static var `default`: Configuration {
            Configuration(
                titleText: "almatar_smart_sort_title".localized(),
                promptText: "",
                placeholderText: "",
                submitButtonText: "almatar_smart_sort_submit_button".localized(),
                clearButtonText: "ask_ai_sheet_clear_button".localized(),
                infoTooltipText: "",
                characterLimit: 200,
                titleFont: .system(size: 17, weight: .semibold),
                promptFont: .system(size: 15, weight: .regular),
                inputFont: .system(size: 15, weight: .regular),
                submitButtonFont: .system(size: 16, weight: .semibold),
                clearButtonFont: .system(size: 14, weight: .semibold),
                counterFont: .system(size: 12, weight: .regular),
                tooltipFont: .system(size: 14, weight: .regular),
                padding: EdgeInsets(top: 12, leading: 16, bottom: 16, trailing: 16),
                lineLimit: 6,
                spacing: 16,
                sparkleIconSize: 18,
                showSparkleIcon: true,
                showInfoButton: true,
                infoButtonImage: Image(systemName: "info"),
                infoButtonIconSize: 14,
                cardCornerRadius: 16,
                submitButtonCornerRadius: 28,
                backgroundColor: Color(light: "#F2F2F4", dark: "#F2F2F4"),
                cardBackgroundColor: Color(light: "#FFFFFF", dark: "#FFFFFF"),
                titleColor: Color(light: "#1A1A1E", dark: "#1A1A1E"),
                promptColor: Color(light: "#7B3AEC", dark: "#7B3AEC"),
                textColor: Color(light: "#1A1A1E", dark: "#1A1A1E"),
                closeButtonColor: Color(light: "#1A1A1E", dark: "#1A1A1E"),
                infoButtonColor: Color(light: "#1A1A1E", dark: "#1A1A1E"),
                sparkleIconColor: Color(light: "#7B3AEC", dark: "#7B3AEC"),
                clearButtonColor: Color(light: "#7B3AEC", dark: "#7B3AEC"),
                submitButtonBackgroundColor: Color(light: "#7B3AEC", dark: "#7B3AEC"),
                submitButtonTextColor: Color(light: "#FFFFFF", dark: "#FFFFFF"),
                counterColor: Color(light: "#9294A0", dark: "#9294A0"),
                tooltipBackgroundColor: Color(light: "#2A282E", dark: "#2A282E"),
                tooltipTextColor: Color(light: "#FFFFFF", dark: "#FFFFFF")
            )
        }

        public init(
            titleText: String,
            promptText: String,
            placeholderText: String,
            submitButtonText: String,
            clearButtonText: String,
            infoTooltipText: String,
            characterLimit: Int,
            titleFont: Font,
            promptFont: Font,
            inputFont: Font,
            submitButtonFont: Font,
            clearButtonFont: Font,
            counterFont: Font,
            tooltipFont: Font,
            padding: EdgeInsets,
            lineLimit: Int,
            spacing: CGFloat,
            sparkleIconSize: CGFloat,
            showSparkleIcon: Bool,
            showInfoButton: Bool,
            infoButtonImage: Image,
            infoButtonIconSize: CGFloat,
            cardCornerRadius: CGFloat,
            submitButtonCornerRadius: CGFloat,
            backgroundColor: Color,
            cardBackgroundColor: Color,
            titleColor: Color,
            promptColor: Color,
            textColor: Color,
            closeButtonColor: Color,
            infoButtonColor: Color,
            sparkleIconColor: Color,
            clearButtonColor: Color,
            submitButtonBackgroundColor: Color,
            submitButtonTextColor: Color,
            counterColor: Color,
            tooltipBackgroundColor: Color,
            tooltipTextColor: Color
        ) {
            self.titleText = titleText
            self.promptText = promptText
            self.placeholderText = placeholderText
            self.submitButtonText = submitButtonText
            self.clearButtonText = clearButtonText
            self.infoTooltipText = infoTooltipText
            self.characterLimit = characterLimit
            self.titleFont = titleFont
            self.promptFont = promptFont
            self.inputFont = inputFont
            self.submitButtonFont = submitButtonFont
            self.clearButtonFont = clearButtonFont
            self.counterFont = counterFont
            self.tooltipFont = tooltipFont
            self.padding = padding
            self.lineLimit = lineLimit
            self.spacing = spacing
            self.sparkleIconSize = sparkleIconSize
            self.showSparkleIcon = showSparkleIcon
            self.showInfoButton = showInfoButton
            self.infoButtonImage = infoButtonImage
            self.infoButtonIconSize = infoButtonIconSize
            self.cardCornerRadius = cardCornerRadius
            self.submitButtonCornerRadius = submitButtonCornerRadius
            self.backgroundColor = backgroundColor
            self.cardBackgroundColor = cardBackgroundColor
            self.titleColor = titleColor
            self.promptColor = promptColor
            self.textColor = textColor
            self.closeButtonColor = closeButtonColor
            self.infoButtonColor = infoButtonColor
            self.sparkleIconColor = sparkleIconColor
            self.clearButtonColor = clearButtonColor
            self.submitButtonBackgroundColor = submitButtonBackgroundColor
            self.submitButtonTextColor = submitButtonTextColor
            self.counterColor = counterColor
            self.tooltipBackgroundColor = tooltipBackgroundColor
            self.tooltipTextColor = tooltipTextColor
        }
    }

    // MARK: - State
    @State private var contentBodyHeight: CGFloat = 480
    @State private var showTooltip: Bool = false
    @State private var userQuery: String = ""

    /// Approximate height of the inline navigation bar (chrome added by NavigationStack).
    private let navigationBarHeight: CGFloat = 56

    // MARK: - Properties
    private let configuration: Configuration
    @Binding private var isPresented: Bool
    private let parameterChangeNotice: String?
    private let onSubmit: (String) -> Void
    private let onClear: (() -> Void)?

    // MARK: - Initialization

    /// Initialize the Almatar Smart Sort sheet.
    /// - Parameters:
    ///   - configuration: The configuration for the sheet (defaults to `.default`)
    ///   - isPresented: Binding to control sheet presentation
    ///   - queryType: The type of query (hotel or flight) to customize tooltip, prompt and placeholder text
    ///   - userQuery: Optional initial text to prefill the text field
    ///   - parameterChangeNotice: Optional parameter change notice to display as warning
    ///   - onSubmit: Callback when user submits the query
    ///   - onClear: Optional callback when user confirms "Clear All"
    public init(
        configuration: SmartSortBottomSheet.Configuration = .default,
        isPresented: Binding<Bool>,
        queryType: QueryType,
        userQuery: String = "",
        parameterChangeNotice: String? = nil,
        onSubmit: @escaping (String) -> Void,
        onClear: (() -> Void)? = nil
    ) {
        var modifiedConfig = configuration

        if modifiedConfig.infoTooltipText.isEmpty {
            modifiedConfig.infoTooltipText =
            switch queryType {
            case .hotel:
                "ask_ai_sheet_tooltip_hotel".localized()
            case .flight:
                "ask_ai_sheet_tooltip_flight".localized()
            }
        }

        if modifiedConfig.placeholderText.isEmpty {
            modifiedConfig.placeholderText =
            switch queryType {
            case .hotel:
                "almatar_smart_sort_placeholder_hotel".localized()
            case .flight:
                "almatar_smart_sort_placeholder_flight".localized()
            }
        }

        if modifiedConfig.promptText.isEmpty {
            modifiedConfig.promptText =
            switch queryType {
            case .hotel:
                "almatar_smart_sort_prompt_hotel".localized()
            case .flight:
                "almatar_smart_sort_prompt_flight".localized()
            }
        }

        self.configuration = modifiedConfig
        self._isPresented = isPresented
        self._userQuery = State(initialValue: userQuery)
        self.parameterChangeNotice = parameterChangeNotice
        self.onSubmit = onSubmit
        self.onClear = onClear
    }

    // MARK: - Body
    public var body: some View {
        if #available(iOS 16.4, *) {
            navigationContent()
                .environment(\.layoutDirection, RiviAskAIConfiguration.shared.language.layoutDirection)
                .presentationDetents([.height(contentBodyHeight + navigationBarHeight)])
                .presentationDragIndicator(.hidden)
                .presentationBackground(configuration.backgroundColor)
        } else if #available(iOS 16.0, *) {
            navigationContent()
                .environment(\.layoutDirection, RiviAskAIConfiguration.shared.language.layoutDirection)
                .presentationDetents([.height(contentBodyHeight + navigationBarHeight)])
                .presentationDragIndicator(.hidden)
        } else {
            navigationContent()
                .environment(\.layoutDirection, RiviAskAIConfiguration.shared.language.layoutDirection)
        }
    }

    // MARK: - Methods
    @ViewBuilder
    private func navigationContent() -> some View {
        if #available(iOS 16.0, *) {
            NavigationStack {
                measuredContent()
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { toolbarContent() }
                    .toolbarBackground(configuration.backgroundColor, for: .navigationBar)
                    .toolbarBackground(.visible, for: .navigationBar)
            }
        } else {
            NavigationView {
                measuredContent()
                    .navigationBarTitle(configuration.titleText, displayMode: .inline)
                    .navigationBarItems(
                        leading: closeToolbarButton(),
                        trailing: infoToolbarButton()
                    )
            }
            .navigationViewStyle(.stack)
        }
    }

    @ViewBuilder
    private func measuredContent() -> some View {
        content()
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .preference(key: SizePreferenceKey.self, value: proxy.size)
                }
            )
            .onPreferenceChange(SizePreferenceKey.self) { newSize in
                let measured = newSize.height
                if measured > 0 && abs(measured - contentBodyHeight) > 0.5 {
                    contentBodyHeight = measured
                }
            }
    }

    @ToolbarContentBuilder
    private func toolbarContent() -> some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            closeToolbarButton()
        }
        ToolbarItem(placement: .principal) {
            Text(configuration.titleText)
                .font(configuration.titleFont)
                .foregroundStyle(configuration.titleColor)
        }
        if configuration.showInfoButton {
            ToolbarItem(placement: .topBarTrailing) {
                infoToolbarButton()
            }
        }
    }

    @ViewBuilder
    private func closeToolbarButton() -> some View {
        Button {
            isPresented = false
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(configuration.closeButtonColor)
        }
        .accessibilityLabel(Text("almatar_smart_sort_close_accessibility".localized()))
    }

    @ViewBuilder
    private func infoToolbarButton() -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                showTooltip = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showTooltip = false
                }
            }
        } label: {
            configuration.infoButtonImage
                .font(.system(size: configuration.infoButtonIconSize, weight: .semibold))
                .foregroundStyle(configuration.infoButtonColor)
        }
        .accessibilityLabel(Text("almatar_smart_sort_info_accessibility".localized()))
    }

    @ViewBuilder
    private func tooltipOverlay() -> some View {
        if showTooltip {
            HStack {
                Spacer()
                VStack(alignment: .trailing, spacing: 0) {
                    Triangle()
                        .fill(configuration.tooltipBackgroundColor)
                        .frame(width: 12, height: 6)
                        .padding(.trailing, 14)
                    Text(configuration.infoTooltipText)
                        .font(configuration.tooltipFont)
                        .fontWeight(.light)
                        .foregroundStyle(configuration.tooltipTextColor)
                        .multilineTextAlignment(.leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(configuration.tooltipBackgroundColor)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .frame(maxWidth: 260, alignment: .trailing)
            }
            .padding(.horizontal, 12)
            .padding(.top, 4)
            .transition(.opacity)
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showTooltip = false
                }
            }
        }
    }

    @ViewBuilder
    private func tooltipContent() -> some View {
        if #available(iOS 16.4, *) {
            Text(configuration.infoTooltipText)
                .font(configuration.tooltipFont)
                .fontWeight(.light)
                .foregroundStyle(configuration.tooltipTextColor)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(configuration.tooltipBackgroundColor)
                .presentationCompactAdaptation(.popover)
        } else {
            Text(configuration.infoTooltipText)
                .font(configuration.tooltipFont)
                .fontWeight(.light)
                .foregroundStyle(configuration.tooltipTextColor)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(configuration.tooltipBackgroundColor)
        }
    }

    @ViewBuilder
    private func content() -> some View {
        VStack(spacing: configuration.spacing) {
            if let notice = parameterChangeNotice, !notice.isEmpty {
                let warningConfig = RiviInfoBanner.Configuration(
                    iconName: "ic_warning",
                    titleText: "parameter_change_warning_title".localized(),
                    descriptionText: "parameter_change_warning_description".localized(),
                    titleFont: .system(size: 12, weight: .medium),
                    descriptionFont: .system(size: 11, weight: .regular),
                    cornerRadius: 8,
                    padding: EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8),
                    iconSpacing: 8,
                    textSpacing: 2,
                    showIcon: true,
                    iconSize: 12,
                    backgroundColor: Color(light: "#F7C55B1A", dark: "#F7C55B1A"),
                    borderColor: Color(light: "#D3BD8C", dark: "#D3BD8C"),
                    titleColor: Color(light: "#B17E10", dark: "#B17E10"),
                    descriptionColor: Color(light: "#B17E10", dark: "#B17E10"),
                    iconColor: Color(light: "#B17E10", dark: "#B17E10"),
                    skeletonBaseColor: Color(light: "#D3BD8C", dark: "#D3BD8C"),
                    skeletonHighlightColor: Color(light: "#FFFFFFCC", dark: "#FFFFFFCC"),
                    skeletonAnimationDuration: 1.3,
                    skeletonCornerRadius: 4,
                    skeletonTitleHeight: 10,
                    skeletonTitleWidth: 110,
                    skeletonDescriptionHeight: 9
                )
                RiviInfoBanner(configuration: warningConfig)
                    .padding(.horizontal, configuration.padding.leading)
            }

            promptCard()
                .padding(.horizontal, configuration.padding.leading)

            submitButton()
                .padding(.horizontal, configuration.padding.leading)
                .padding(.bottom, configuration.padding.bottom)
        }
        .padding(.top, configuration.padding.top)
        .background(configuration.backgroundColor)
        .overlay(alignment: .top) {
            tooltipOverlay()
        }
    }

    @ViewBuilder
    private func promptCard() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                if configuration.showSparkleIcon {
                    Image("ic_sparkle", bundle: .module)
                        .resizable()
                        .renderingMode(.template)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: configuration.sparkleIconSize, height: configuration.sparkleIconSize)
                        .foregroundStyle(configuration.sparkleIconColor)
                        .padding(.top, 2)
                }
                Text(configuration.promptText)
                    .font(configuration.promptFont)
                    .foregroundStyle(configuration.promptColor)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }

            HStack {
                Spacer()
                if !userQuery.isEmpty {
                    Button {
                        userQuery = ""
                        onClear?()
                    } label: {
                        Text(configuration.clearButtonText)
                            .font(configuration.clearButtonFont)
                            .foregroundStyle(configuration.clearButtonColor)
                    }
                }
            }

            ZStack(alignment: .bottomTrailing) {
                TextField(
                    configuration.placeholderText,
                    text: $userQuery,
                    axis: .vertical
                )
                .font(configuration.inputFont)
                .foregroundStyle(configuration.textColor)
                .lineLimit(configuration.lineLimit, reservesSpace: true)
                .padding(12)
                .padding(.bottom, 16)
                .background(configuration.backgroundColor)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .onChange(of: userQuery) { newValue in
                    if newValue.count > configuration.characterLimit {
                        userQuery = String(newValue.prefix(configuration.characterLimit))
                    }
                }

                Text("\(userQuery.count)/\(configuration.characterLimit)")
                    .font(configuration.counterFont)
                    .foregroundStyle(configuration.counterColor)
                    .padding(.trailing, 12)
                    .padding(.bottom, 8)
            }
        }
        .padding(16)
        .background(configuration.cardBackgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: configuration.cardCornerRadius))
    }

    /// Submit is enabled only once the user has typed non-whitespace text.
    private var isSubmitEnabled: Bool {
        !userQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    @ViewBuilder
    private func submitButton() -> some View {
        Button {
            onSubmit(userQuery)
            isPresented = false
        } label: {
            Text(configuration.submitButtonText)
                .font(configuration.submitButtonFont)
                .foregroundStyle(isSubmitEnabled ? configuration.submitButtonTextColor : Color(UIColor.systemGray))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(isSubmitEnabled ? configuration.submitButtonBackgroundColor : Color(UIColor.systemGray5))
                .clipShape(RoundedRectangle(cornerRadius: configuration.submitButtonCornerRadius))
        }
        .disabled(!isSubmitEnabled)
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
