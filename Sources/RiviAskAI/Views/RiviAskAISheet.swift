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
        /// The info tooltip text
        public var infoTooltipText: String
        /// The title font
        public var titleFont: Font
        /// The input field font
        public var inputFont: Font
        /// The submit button font
        public var submitButtonFont: Font
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
                titleText: "Ask AI",
                placeholderText: "",
                submitButtonText: "Improve Results",
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
                backgroundColor: Color(light: "#FFFFFF", dark: "#FFFFFF"),
                titleColor: Color(light: "#7C3AED", dark: "#7C3AED"),
                titleBackgroundColor: Color(light: "#EFE5FF", dark: "#EFE5FF"),
                textColor: Color(light: "#1A1A1E", dark: "#1A1A1E"),
                closeButtonColor: Color(light: "#7C3AED", dark: "#7C3AED"),
                submitButtonBackgroundColor: Color(light: "#7B3AEC", dark: "#7B3AEC"),
                submitButtonTextColor: Color(light: "#FFFFFF", dark: "#FFFFFF"),
                headerIconColor: Color(light: "#7B3AEC", dark: "#7B3AEC"),
                textFieldBorderColor: Color(light: "#D9D9DE", dark: "#D9D9DE"),
                textFieldBackgroundColor: Color(light: "#FFFFFF", dark: "#FFFFFF"),
                infoButtonColor: Color(light: "#9294A0", dark: "#9294A0"),
                tooltipBackgroundColor: Color(light: "#2A282E", dark: "#2A282E"),
                tooltipTextColor: Color(light: "#FFFFFF", dark: "#FFFFFF"),
                tooltipFont: .system(size: 14, weight: .regular)
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
            tooltipFont: Font
        ) {
            self.titleText = titleText
            self.placeholderText = placeholderText
            self.submitButtonText = submitButtonText
            self.infoTooltipText = infoTooltipText
            self.titleFont = titleFont
            self.inputFont = inputFont
            self.submitButtonFont = submitButtonFont
            self.padding = padding
            self.lineLimit = lineLimit
            self.spacing = spacing
            self.headerIconSize = headerIconSize
            self.showHeaderIcon = showHeaderIcon
            self.headerSpacing = headerSpacing
            self.showInfoButton = showInfoButton
            self.infoButtonSize = infoButtonSize
            self.backgroundColor = backgroundColor
            self.titleColor = titleColor
            self.titleBackgroundColor = titleBackgroundColor
            self.textColor = textColor
            self.closeButtonColor = closeButtonColor
            self.submitButtonBackgroundColor = submitButtonBackgroundColor
            self.submitButtonTextColor = submitButtonTextColor
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
    
    // MARK: - Initialization
    
    /// Initialize with a configuration and presentation binding
    /// - Parameters:
    ///   - configuration: The configuration for the sheet
    ///   - isPresented: Binding to control sheet presentation
    ///   - queryType: The type of query (hotel or flight) to customize the tooltip and placeholder
    ///   - userQuery: Optional initial text to prefill the text field
    ///   - parameterChangeNotice: Optional parameter change notice to display as warning
    ///   - onSubmit: Callback when user submits the query
    public init(
        configuration: RiviAskAISheet.Configuration = .default,
        isPresented: Binding<Bool>,
        queryType: QueryType,
        userQuery: String = "",
        parameterChangeNotice: String? = nil,
        onSubmit: @escaping (String) -> Void
    ) {
        // Create a modified configuration with query-type-specific text
        var modifiedConfig = configuration
        
        // Update tooltip text if empty
        if modifiedConfig.infoTooltipText.isEmpty {
            modifiedConfig.infoTooltipText =
            switch queryType {
            case .hotel:
                "AI intelligently sorts hotels to prioritize your preferences - without filtering results."
            case .flight:
                "AI intelligently sorts flights to prioritize your preferences - without filtering results."
            }
        }
        
        // Update placeholder text if empty
        if modifiedConfig.placeholderText.isEmpty {
            modifiedConfig.placeholderText =
            switch queryType {
            case .hotel:
                "e.g. 4 star hotels near the airport with free breakfast"
            case .flight:
                "e.g. Direct flights that reach before 4PM with meals included"
            }
        }
        
        self.configuration = modifiedConfig
        self._isPresented = isPresented
        self._userQuery = State(initialValue: userQuery)
        self.parameterChangeNotice = parameterChangeNotice
        self.onSubmit = onSubmit
    }
    
    // MARK: - Body
    public var body: some View {
        if #available(iOS 16.0, *) {
            content()
                .readSize(onChange: { size in
                    sheetContentHeight = size.height
                })
                .presentationDetents([.height(sheetContentHeight)])
                .presentationDragIndicator(.hidden)
        } else {
            // Fallback on earlier versions
            content()
        }
    }
    
    // MARK: - Methods
    @ViewBuilder
    private func content() -> some View {
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
                            .foregroundStyle(configuration.headerIconColor)
                    }
                    
                    Text(configuration.titleText)
                        .font(configuration.titleFont)
                        .foregroundStyle(configuration.titleColor)
                    
                    if configuration.showInfoButton {
                        Button {
                            showTooltip.toggle()
                            
                            // Auto-hide tooltip after 3 seconds
                            if showTooltip {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                    showTooltip = false
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
                        .popover(isPresented: $showTooltip, arrowEdge: .bottom) {
                            if #available(iOS 16.4, *) {
                                Text(configuration.infoTooltipText)
                                    .fontWeight(.light)
                                    .foregroundStyle(configuration.tooltipTextColor)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .background(configuration.tooltipBackgroundColor)
                                    .presentationCompactAdaptation(.popover)
                            } else {
                                // Fallback on earlier versions
                                Text(configuration.infoTooltipText)
                                    .fontWeight(.light)
                                    .foregroundStyle(configuration.tooltipTextColor)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .background(configuration.tooltipBackgroundColor)
                            }
                        }
                    }
                }
                
                Spacer()
                
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
                    titleText: "Your prompt includes changes to trip details",
                    descriptionText: "To update trip details, use the search fields above.",
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
                    iconColor: Color(light: "#B17E10", dark: "#B17E10")
                )
                
                RiviInfoBanner(configuration: warningConfig)
                    .padding(.horizontal, configuration.padding.leading)
            }
            
            if #available(iOS 16.0, *) {
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
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(configuration.textFieldBorderColor, lineWidth: 1)
                )
                .padding(.horizontal, configuration.padding.leading)
            } else {
                // Fallback on earlier versions
                TextField(
                    configuration.placeholderText,
                    text: $userQuery
                )
                .font(configuration.inputFont)
                .foregroundStyle(configuration.textColor)
                .lineLimit(configuration.lineLimit)
                .padding(12)
                .background(configuration.textFieldBackgroundColor)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(configuration.textFieldBorderColor, lineWidth: 1)
                )
                .padding(.horizontal, configuration.padding.leading)
            }
            
            // Improve Results button
            Button(action: {
                onSubmit(userQuery)
                isPresented = false
            }) {
                Text(configuration.submitButtonText)
                    .font(configuration.submitButtonFont)
                    .foregroundStyle(configuration.submitButtonTextColor)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(configuration.submitButtonBackgroundColor)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .padding(.horizontal, configuration.padding.leading)
        }
        .background(configuration.backgroundColor)
    }
}
