import SwiftUI

/// A customizable alert dialog component
public struct RiviAlertDialog: View {
    // MARK: - Configuration
    
    /// Configuration options for the RiviAlertDialog
    public struct Configuration {
        /// The icon to display
        public var iconName: String
        /// The title text to display
        public var titleText: String
        /// The description text to display
        public var descriptionText: String
        /// The button text
        public var buttonText: String
        /// The title font
        public var titleFont: Font
        /// The description font
        public var descriptionFont: Font
        /// The button font
        public var buttonFont: Font
        /// The corner radius of the dialog
        public var cornerRadius: CGFloat
        /// The padding inside the dialog
        public var padding: EdgeInsets
        /// The spacing between elements
        public var spacing: CGFloat
        /// The icon size
        public var iconSize: CGFloat
        
        // MARK: - Theme Properties
        
        /// Background color for the dialog
        public var backgroundColor: Color
        /// Icon color
        public var iconColor: Color
        /// Title text color
        public var titleColor: Color
        /// Description text color
        public var descriptionColor: Color
        /// Button background color
        public var buttonBackgroundColor: Color
        /// Button text color
        public var buttonTextColor: Color
        /// Overlay background color
        public var overlayBackgroundColor: Color
        
        /// Create a default configuration
        public static var `default`: Configuration {
            Configuration(
                iconName: "exclamationmark.triangle.fill",
                titleText: "alert_dialog_title".localized(),
                descriptionText: "alert_dialog_description".localized(),
                buttonText: "alert_dialog_button".localized(),
                titleFont: .system(size: 16, weight: .medium),
                descriptionFont: .system(size: 13, weight: .regular),
                buttonFont: .system(size: 14, weight: .medium),
                cornerRadius: 8,
                padding: EdgeInsets(top: 24, leading: 16, bottom: 16, trailing: 16),
                spacing: 16,
                iconSize: 26,
                backgroundColor: Color(light: "#FFFFFF", dark: "#FFFFFF"),
                iconColor: Color(light: "#B17E10", dark: "#B17E10"),
                titleColor: Color(light: "#1B1A20", dark: "#1B1A20"),
                descriptionColor: Color(light: "#62636F", dark: "#62636F"),
                buttonBackgroundColor: Color(light: "#7B3AEC", dark: "#7B3AEC"),
                buttonTextColor: Color(light: "#FFFFFF", dark: "#FFFFFF"),
                overlayBackgroundColor: Color.black.opacity(0.4)
            )
        }
        
        public init(
            iconName: String,
            titleText: String,
            descriptionText: String,
            buttonText: String,
            titleFont: Font,
            descriptionFont: Font,
            buttonFont: Font,
            cornerRadius: CGFloat,
            padding: EdgeInsets,
            spacing: CGFloat,
            iconSize: CGFloat,
            backgroundColor: Color,
            iconColor: Color,
            titleColor: Color,
            descriptionColor: Color,
            buttonBackgroundColor: Color,
            buttonTextColor: Color,
            overlayBackgroundColor: Color
        ) {
            self.iconName = iconName
            self.titleText = titleText
            self.descriptionText = descriptionText
            self.buttonText = buttonText
            self.titleFont = titleFont
            self.descriptionFont = descriptionFont
            self.buttonFont = buttonFont
            self.cornerRadius = cornerRadius
            self.padding = padding
            self.spacing = spacing
            self.iconSize = iconSize
            self.backgroundColor = backgroundColor
            self.iconColor = iconColor
            self.titleColor = titleColor
            self.descriptionColor = descriptionColor
            self.buttonBackgroundColor = buttonBackgroundColor
            self.buttonTextColor = buttonTextColor
            self.overlayBackgroundColor = overlayBackgroundColor
        }
    }
    
    // MARK: - Properties
    
    /// The configuration for this dialog
    private let configuration: Configuration
    
    /// Whether the dialog is presented
    @Binding private var isPresented: Bool
    
    /// Optional action to perform when button is tapped
    private let onDismiss: (() -> Void)
    
    // MARK: - Initialization
    
    /// Initialize with a configuration and presentation binding
    public init(
        configuration: RiviAlertDialog.Configuration = .default,
        isPresented: Binding<Bool>,
        onDismiss: @escaping (() -> Void)
    ) {
        self.configuration = configuration
        self._isPresented = isPresented
        self.onDismiss = onDismiss
    }
    
    // MARK: - Body
    
    public var body: some View {
        ZStack {
            // Semi-transparent background
            configuration.overlayBackgroundColor
                .ignoresSafeArea()
                .onTapGesture {
                    dismiss()
                }
            
            // Dialog content
            VStack(spacing: configuration.spacing) {
                // Icon
                Image("ic_warning", bundle: .module)
                    .resizable()
                    .renderingMode(.template)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: configuration.iconSize, height: configuration.iconSize)
                    .foregroundStyle(configuration.iconColor)
                
                VStack(alignment: .center, spacing: 4) {
                    // Title
                    Text(configuration.titleText)
                        .font(configuration.titleFont)
                        .foregroundStyle(configuration.titleColor)
                        .multilineTextAlignment(.center)
                    
                    // Description
                    Text(configuration.descriptionText)
                        .font(configuration.descriptionFont)
                        .foregroundStyle(configuration.descriptionColor)
                        .multilineTextAlignment(.center)
                }
                
                // Button
                Button(action: {
                    dismiss()
                }) {
                    Text(configuration.buttonText)
                        .font(configuration.buttonFont)
                        .foregroundStyle(configuration.buttonTextColor)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(configuration.buttonBackgroundColor)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .padding(.top, 14)
            }
            .padding(configuration.padding)
            .background(configuration.backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: configuration.cornerRadius))
            .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
            .padding(.horizontal, 32)
        }
        .environment(\.layoutDirection, RiviAskAIConfiguration.shared.language.layoutDirection)
    }
    
    // MARK: - Methods
    
    private func dismiss() {
        withAnimation(.easeInOut) {
            isPresented = false
        }
        onDismiss()
    }
}
