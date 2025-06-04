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
        
        /// Create a default configuration
        public static var `default`: Configuration {
            Configuration(
                titleText: "Ask AI",
                placeholderText: "e.g. Direct flights that reach before 4PM with meals included",
                submitButtonText: "Improve Results",
                titleFont: .system(size: 18, weight: .regular),
                inputFont: .system(size: 16, weight: .regular),
                submitButtonFont: .system(size: 16, weight: .medium),
                padding: EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16),
                lineLimit: 7,
                spacing: 16,
                headerIconSize: 20,
                showHeaderIcon: true,
                headerSpacing: 8,
                backgroundColor: Color(light: "#FFFFFF", dark: "#FFFFFF"),
                titleColor: Color(light: "#7C3AED", dark: "#7C3AED"),
                titleBackgroundColor: Color(light: "#EFE5FF", dark: "#EFE5FF"),
                textColor: Color(light: "#1A1A1E", dark: "#1A1A1E"),
                closeButtonColor: Color(light: "#7C3AED", dark: "#7C3AED"),
                submitButtonBackgroundColor: Color(light: "#7B3AEC", dark: "#7B3AEC"),
                submitButtonTextColor: Color(light: "#FFFFFF", dark: "#FFFFFF"),
                headerIconColor: Color(light: "#7B3AEC", dark: "#7B3AEC"),
                textFieldBorderColor: Color(light: "#D9D9DE", dark: "#D9D9DE"),
                textFieldBackgroundColor: Color(light: "#FFFFFF", dark: "#FFFFFF")
            )
        }
    }
    
    // MARK: - Properties
    @State private var sheetContentHeight: CGFloat = 0
    
    /// The configuration for this sheet
    private let configuration: Configuration
    
    /// Whether the sheet is presented
    @Binding private var isPresented: Bool
    
    /// The text entered in the text field
    @State private var inputText: String = ""
    
    /// The action to perform when the user submits their query
    private let onSubmit: (String) -> Void
    
    // MARK: - Initialization
    
    /// Initialize with a configuration and presentation binding
    public init(
        configuration: Configuration = .default,
        isPresented: Binding<Bool>,
        onSubmit: @escaping (String) -> Void
    ) {
        self.configuration = configuration
        self._isPresented = isPresented
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
    private func content() -> some View {
        return VStack(spacing: configuration.spacing) {
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
            
            if #available(iOS 16.0, *) {
                TextField(
                    configuration.placeholderText,
                    text: $inputText,
                    axis: .vertical
                )
                .tint(configuration.textColor)
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
                    text: $inputText
                )
                .tint(configuration.textColor)
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
                onSubmit(inputText)
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
