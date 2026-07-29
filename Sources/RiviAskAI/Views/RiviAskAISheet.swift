import SwiftUI

/// A customizable Ask AI bottom sheet component
public struct RiviAskAISheet: View {
    // MARK: - Configuration
    
    /// Configuration options for the RiviAskAISheet
    public struct Configuration {
        /// The title text to display
        public var titleText: String
        /// The placeholder text for the text field
        public var placeholderText: String
        /// The submit button text
        public var submitButtonText: String
        /// The clear all button text
        public var clearButtonText: String
        /// The info tooltip text
        public var infoTooltipText: String
        /// The title font
        public var titleFont: Font
        /// The input field font
        public var inputFont: Font
        /// The submit button font
        public var submitButtonFont: Font
        /// The clear all button font
        public var clearButtonFont: Font
        /// The padding inside the sheet
        public var padding: EdgeInsets
        /// The line limit of the text input field
        public var lineLimit: Int
        /// The spacing between elements
        public var spacing: CGFloat
        /// The icon size for the header
        public var headerIconSize: CGFloat
        /// Whether to show the icon in the header
        public var showHeaderIcon: Bool
        /// The spacing in the header
        public var headerSpacing: CGFloat
        /// Whether to show the info button
        public var showInfoButton: Bool
        /// The info button icon size
        public var infoButtonSize: CGFloat
        /// Configuration for the chips view displayed above the text field
        public var chipsConfiguration: RiviChipsView.Configuration

        // MARK: - Theme Properties
        
        /// Background color for the sheet
        public var backgroundColor: Color
        /// Text color for title
        public var titleColor: Color
        /// Background color for title
        public var titleBackgroundColor: Color
        /// Text color for input
        public var textColor: Color
        /// Close button color
        public var closeButtonColor: Color
        /// Submit button background color
        public var submitButtonBackgroundColor: Color
        /// Submit button text color
        public var submitButtonTextColor: Color
        /// Clear all button color
        public var clearButtonColor: Color
        /// Header icon color
        public var headerIconColor: Color
        /// Border color for the text field
        public var textFieldBorderColor: Color
        /// Background color for the text field
        public var textFieldBackgroundColor: Color
        /// Info button color
        public var infoButtonColor: Color
        /// Tooltip background color
        public var tooltipBackgroundColor: Color
        /// Tooltip text color
        public var tooltipTextColor: Color
        /// Tooltip font
        public var tooltipFont: Font
        
        /// Create a default configuration
        public static var `default`: Configuration {
            Configuration(
                titleText: "ask_ai_sheet_title".localized(),
                placeholderText: "",
                submitButtonText: "ask_ai_sheet_submit_button".localized(),
                infoTooltipText: "",
                titleFont: .system(size: 18, weight: .regular),
                inputFont: .system(size: 16, weight: .regular),
                submitButtonFont: .system(size: 16, weight: .medium),
                padding: EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16),
                lineLimit: 7,
                spacing: 16,
                headerIconSize: 20,
                showHeaderIcon: true,
                headerSpacing: 8,
                showInfoButton: true,
                infoButtonSize: 12,
                chipsConfiguration: RiviChipsView.Configuration(
                    font: .system(size: 14, weight: .regular),
                    cornerRadius: 8,
                    chipPadding: EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12),
                    spacing: 8,
                    removeIconSize: 12,
                    textIconSpacing: 6,
                    showClearAllButton: false,
                    clearAllText: "chips_clear_all_button".localized(),
                    clearAllFont: .system(size: 14, weight: .semibold),
                    clearAllSpacing: 8,
                    chipBackgroundColor: Color(light: "#F3F7FC", dark: "#F2F2F7"),
                    chipBorderColor: Color(light: "#FFFFFF", dark: "#E5E5EA"),
                    chipTextColor: Color(light: "#64748B", dark: "#1C1C1E"),
                    removeIconColor: Color(light: "#8E8E93", dark: "#8E8E93"),
                    clearAllColor: Color(light: "#017ACB", dark: "#7C3AED")
                ),
                backgroundColor: Color(light: "#FFFFFF", dark: "#FFFFFF"),
                titleColor: Color(light: "#171A1C", dark: "#7C3AED"),
                titleBackgroundColor: Color(light: "#FFFFFF", dark: "#EFE5FF"),
                textColor: Color(light: "#1A1A1E", dark: "#1A1A1E"),
                closeButtonColor: Color(light: "#171A1C", dark: "#7C3AED"),
                submitButtonBackgroundColor: Color(light: "#017ACB", dark: "#7B3AEC"),
                submitButtonTextColor: Color(light: "#FFFFFF", dark: "#FFFFFF"),
                headerIconColor: Color(light: "#349EE5", dark: "#FFFFFF"),
                textFieldBorderColor: Color(light: "#D9D9DE", dark: "#D9D9DE"),
                textFieldBackgroundColor: Color(light: "#FFFFFF", dark: "#FFFFFF"),
                infoButtonColor: Color(light: "#9294A0", dark: "#9294A0"),
                tooltipBackgroundColor: Color(light: "#2A282E", dark: "#2A282E"),
                tooltipTextColor: Color(light: "#FFFFFF", dark: "#FFFFFF"),
                tooltipFont: .system(size: 14, weight: .regular),
                clearButtonText: "ask_ai_sheet_clear_button".localized(),
                clearButtonFont: .system(size: 14, weight: .medium),
                clearButtonColor: Color(light: "#017ACB", dark: "#7C3AED")
            )
        }
        
        public init(
            titleText: String,
            placeholderText: String,
            submitButtonText: String,
            infoTooltipText: String,
            titleFont: Font,
            inputFont: Font,
            submitButtonFont: Font,
            padding: EdgeInsets,
            lineLimit: Int,
            spacing: CGFloat,
            headerIconSize: CGFloat,
            showHeaderIcon: Bool,
            headerSpacing: CGFloat,
            showInfoButton: Bool,
            infoButtonSize: CGFloat,
            chipsConfiguration: RiviChipsView.Configuration,
            backgroundColor: Color,
            titleColor: Color,
            titleBackgroundColor: Color,
            textColor: Color,
            closeButtonColor: Color,
            submitButtonBackgroundColor: Color,
            submitButtonTextColor: Color,
            headerIconColor: Color,
            textFieldBorderColor: Color,
            textFieldBackgroundColor: Color,
            infoButtonColor: Color,
            tooltipBackgroundColor: Color,
            tooltipTextColor: Color,
            tooltipFont: Font,
            clearButtonText: String,
            clearButtonFont: Font,
            clearButtonColor: Color
        ) {
            self.titleText = titleText
            self.placeholderText = placeholderText
            self.submitButtonText = submitButtonText
            self.clearButtonText = clearButtonText
            self.infoTooltipText = infoTooltipText
            self.titleFont = titleFont
            self.inputFont = inputFont
            self.submitButtonFont = submitButtonFont
            self.clearButtonFont = clearButtonFont
            self.padding = padding
            self.lineLimit = lineLimit
            self.spacing = spacing
            self.headerIconSize = headerIconSize
            self.showHeaderIcon = showHeaderIcon
            self.headerSpacing = headerSpacing
            self.showInfoButton = showInfoButton
            self.infoButtonSize = infoButtonSize
            self.chipsConfiguration = chipsConfiguration
            self.backgroundColor = backgroundColor
            self.titleColor = titleColor
            self.titleBackgroundColor = titleBackgroundColor
            self.textColor = textColor
            self.closeButtonColor = closeButtonColor
            self.submitButtonBackgroundColor = submitButtonBackgroundColor
            self.submitButtonTextColor = submitButtonTextColor
            self.clearButtonColor = clearButtonColor
            self.headerIconColor = headerIconColor
            self.textFieldBorderColor = textFieldBorderColor
            self.textFieldBackgroundColor = textFieldBackgroundColor
            self.infoButtonColor = infoButtonColor
            self.tooltipBackgroundColor = tooltipBackgroundColor
            self.tooltipTextColor = tooltipTextColor
            self.tooltipFont = tooltipFont
        }
    }
    
    // MARK: - Properties
    @State private var sheetContentHeight: CGFloat = 0
    @State private var showTooltip: Bool = false
    
    /// The configuration for this sheet
    private let configuration: Configuration
    
    /// Whether the sheet is presented
    @Binding private var isPresented: Bool
    
    /// The text entered in the text field
    @State private var userQuery: String = ""
    
    /// Parameter change notice message
    private let parameterChangeNotice: String?
    
    /// The action to perform when the user submits their query
    private let onSubmit: (String) -> Void

    /// The action to perform when the user taps "Clear All"
    private let onClear: (() -> Void)?

    /// The chips to display above the text field
    @Binding private var chips: Set<String>

    /// The action to perform when a chip is removed
    private let onRemoveChip: ((String) -> Void)?

    // MARK: - Initialization

    /// Initialize with a configuration and presentation binding
    /// - Parameters:
    ///   - configuration: The configuration for the sheet
    ///   - isPresented: Binding to control sheet presentation
    ///   - queryType: The type of query (hotel or flight) to customize the tooltip and placeholder
    ///   - userQuery: Optional initial text to prefill the text field
    ///   - parameterChangeNotice: Optional parameter change notice to display as warning
    ///   - onSubmit: Callback when user submits the query
    ///   - onClear: Optional callback when user taps "Clear All" to reset the active query
    public init(
        configuration: RiviAskAISheet.Configuration = .default,
        isPresented: Binding<Bool>,
        queryType: QueryType,
        userQuery: String = "",
        chips: Binding<Set<String>> = .constant([]),
        parameterChangeNotice: String? = nil,
        onSubmit: @escaping (String) -> Void,
        onRemoveChip: ((String) -> Void)? = nil,
        onClear: (() -> Void)? = nil
    ) {
        // Create a modified configuration with query-type-specific text
        var modifiedConfig = configuration
        
        // Update tooltip text if empty
        if modifiedConfig.infoTooltipText.isEmpty {
            modifiedConfig.infoTooltipText =
            switch queryType {
            case .hotel:
                "ask_ai_sheet_tooltip_hotel".localized()
            case .flight:
                "ask_ai_sheet_tooltip_flight".localized()
            }
        }
        
        // Update placeholder text if empty
        if modifiedConfig.placeholderText.isEmpty {
            modifiedConfig.placeholderText =
            switch queryType {
            case .hotel:
                "ask_ai_sheet_placeholder_hotel".localized()
            case .flight:
                "ask_ai_sheet_placeholder_flight".localized()
            }
        }
        
        self.configuration = modifiedConfig
        self._isPresented = isPresented
        self._userQuery = State(initialValue: userQuery)
        self._chips = chips
        self.parameterChangeNotice = parameterChangeNotice
        self.onSubmit = onSubmit
        self.onRemoveChip = onRemoveChip
        self.onClear = onClear
    }
    
    // MARK: - Body
    public var body: some View {
        if #available(iOS 16.4, *) {
            content()
                .ignoresSafeArea(edges: .bottom)
                .readSize(onChange: { size in
                    sheetContentHeight = size.height
                })
                .environment(\.layoutDirection, RiviAskAIConfiguration.shared.language.layoutDirection)
                .presentationDetents([.height(sheetContentHeight)])
                .presentationDragIndicator(.hidden)
                .presentationCornerRadius(12)
                .presentationBackground(configuration.backgroundColor)
        } else if #available(iOS 16.0, *) {
            content()
                .ignoresSafeArea(edges: .bottom)
                .readSize(onChange: { size in
                    sheetContentHeight = size.height
                })
                .environment(\.layoutDirection, RiviAskAIConfiguration.shared.language.layoutDirection)
                .presentationDetents([.height(sheetContentHeight)])
                .presentationDragIndicator(.hidden)
        } else {
            // Fallback on earlier versions
            content()
                .ignoresSafeArea(edges: .bottom)
                .environment(\.layoutDirection, RiviAskAIConfiguration.shared.language.layoutDirection)
        }
    }
    
    /// Submit is enabled only once the user has typed non-whitespace text.
    private var isSubmitEnabled: Bool {
        !userQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Methods
    @ViewBuilder
    private func content() -> some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: configuration.spacing) {

                // Header with title and close button
                HStack {
                    HStack(spacing: configuration.headerSpacing) {
                        if configuration.showHeaderIcon {
                            Image("ic_sparkle", bundle: .module)
                                .resizable()
                                .renderingMode(.template)
                                .aspectRatio(contentMode: .fit)
                                .frame(width: configuration.headerIconSize, height: configuration.headerIconSize)
                                .foregroundStyle(LinearGradient(
                                    colors: [Color(light: "#349EE5", dark: "#349EE5"), Color(light: "#7F91F5", dark: "#7F91F5")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ))
                        }

                        Text(configuration.titleText)
                            .font(configuration.titleFont)
                            .foregroundStyle(configuration.titleColor)

                        if configuration.showInfoButton {
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) { showTooltip.toggle() }
                                if showTooltip {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                        withAnimation(.easeInOut(duration: 0.2)) { showTooltip = false }
                                    }
                                }
                            } label: {
                                Image("ic_info", bundle: .module)
                                    .resizable()
                                    .renderingMode(.template)
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: configuration.infoButtonSize, height: configuration.infoButtonSize)
                                    .foregroundStyle(configuration.infoButtonColor)
                            }
                        }
                    }
                
                Spacer()

                if !userQuery.isEmpty || !chips.isEmpty {
                    Button(action: {
                        userQuery = ""
                        chips.removeAll()
                        onClear?()
                    }) {
                        Text(configuration.clearButtonText)
                            .font(configuration.clearButtonFont)
                            .foregroundStyle(configuration.clearButtonColor)
                    }
                    .padding(.trailing, 12)
                }

                Button(action: {
                    isPresented = false
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(configuration.closeButtonColor)
                }
            }
            .padding(configuration.padding)
            .background(configuration.titleBackgroundColor)
            
            // Parameter change notice banner
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

                RiviInfoBanner(configuration: warningConfig, isLoading: false)
                    .padding(.horizontal, configuration.padding.leading)
            }

            if !chips.isEmpty {
                RiviChipsView(
                    configuration: configuration.chipsConfiguration,
                    chips: $chips,
                    onRemove: { chip in
                        onRemoveChip?(chip)
                    }
                )
                .padding(.horizontal, configuration.padding.leading)
            }

            TextField(
                configuration.placeholderText,
                text: $userQuery,
                axis: .vertical
            )
            .font(configuration.inputFont)
            .foregroundStyle(configuration.textColor)
            .lineLimit(configuration.lineLimit, reservesSpace: true)
            .padding(12)
            .background(configuration.textFieldBackgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(configuration.textFieldBorderColor, lineWidth: 1)
            )
            .padding(.horizontal, configuration.padding.leading)
            
            // Improve Results button
            Button(action: {
                onSubmit(userQuery)
                isPresented = false
            }) {
                Text(configuration.submitButtonText)
                    .font(configuration.submitButtonFont)
                    .foregroundStyle(isSubmitEnabled ? configuration.submitButtonTextColor : Color(UIColor.systemGray))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(isSubmitEnabled ? configuration.submitButtonBackgroundColor : Color(UIColor.systemGray5))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(!isSubmitEnabled)
            .padding(.horizontal, configuration.padding.leading)
            .padding(.bottom, configuration.padding.bottom)
        }
        .background(configuration.backgroundColor)

            if showTooltip {
                InfoTooltipView(
                    text: configuration.infoTooltipText,
                    font: configuration.tooltipFont,
                    textColor: configuration.tooltipTextColor,
                    backgroundColor: configuration.tooltipBackgroundColor
                )
                .padding(.leading, configuration.padding.leading)
                .padding(.top, configuration.padding.top + CGFloat(configuration.headerIconSize) + 4)
                .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
                .zIndex(10)
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) { showTooltip = false }
                }
            }
        }
    }
}

// Arrow at the TOP of the bubble — used when the tooltip sits below the anchor point.
private struct InfoTooltipUpArrowShape: Shape {
    var cornerRadius: CGFloat = 8
    var arrowW: CGFloat = 14
    var arrowH: CGFloat = 8
    var arrowLeadingOffset: CGFloat = 80

    func path(in rect: CGRect) -> Path {
        let bodyRect = CGRect(x: 0, y: arrowH, width: rect.width, height: rect.height - arrowH)
        var path = Path(roundedRect: bodyRect, cornerRadius: cornerRadius)
        let midX = min(max(arrowW / 2, arrowLeadingOffset + arrowW / 2), rect.width - arrowW / 2)
        path.move(to: CGPoint(x: midX - arrowW / 2, y: arrowH))
        path.addLine(to: CGPoint(x: midX, y: 0))
        path.addLine(to: CGPoint(x: midX + arrowW / 2, y: arrowH))
        path.closeSubpath()
        return path
    }
}

private struct InfoTooltipView: View {
    let text: String
    let font: Font
    let textColor: Color
    let backgroundColor: Color

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .regular))
            .foregroundStyle(textColor)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .padding(10)
            .padding(.top, 8) // account for up-arrow height
            .frame(width: 190, height: 93, alignment: .topLeading)
            .background(
                InfoTooltipUpArrowShape(cornerRadius: 8, arrowLeadingOffset: 80)
                    .fill(backgroundColor)
            )
    }
}
