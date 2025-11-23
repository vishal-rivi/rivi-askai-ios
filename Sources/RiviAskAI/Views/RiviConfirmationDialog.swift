import SwiftUI

/// A customizable confirmation dialog component with two action buttons
public struct RiviConfirmationDialog: View {
    // MARK: - Configuration
    
    /// Configuration options for the RiviConfirmationDialog
    public struct Configuration {
        /// The title text to display
        public var titleText: String
        /// The description text to display
        public var descriptionText: String
        /// The cancel button text
        public var cancelButtonText: String
        /// The confirm button text
        public var confirmButtonText: String
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
        /// The spacing between buttons
        public var buttonSpacing: CGFloat
        /// The button height
        public var buttonHeight: CGFloat
        
        // MARK: - Theme Properties
        
        /// Background color for the dialog
        public var backgroundColor: Color
        /// Title text color
        public var titleColor: Color
        /// Description text color
        public var descriptionColor: Color
        /// Cancel button background color
        public var cancelButtonBackgroundColor: Color
        /// Cancel button text color
        public var cancelButtonTextColor: Color
        /// Cancel button border color
        public var cancelButtonBorderColor: Color
        /// Confirm button background color
        public var confirmButtonBackgroundColor: Color
        /// Confirm button text color
        public var confirmButtonTextColor: Color
        /// Overlay background color
        public var overlayBackgroundColor: Color
        
        /// Create a default configuration
        public static var `default`: Configuration {
            Configuration(
                titleText: "clear_query_dialog_title".localized(),
                descriptionText: "clear_query_dialog_description".localized(),
                cancelButtonText: "clear_query_dialog_cancel".localized(),
                confirmButtonText: "clear_query_dialog_confirm".localized(),
                titleFont: .system(size: 16, weight: .medium),
                descriptionFont: .system(size: 13, weight: .regular),
                buttonFont: .system(size: 14, weight: .medium),
                cornerRadius: 8,
                padding: EdgeInsets(top: 24, leading: 16, bottom: 16, trailing: 16),
                spacing: 16,
                buttonSpacing: 12,
                buttonHeight: 42,
                backgroundColor: Color(light: "#FFFFFF", dark: "#FFFFFF"),
                titleColor: Color(light: "#1B1A20", dark: "#1B1A20"),
                descriptionColor: Color(light: "#62636F", dark: "#62636F"),
                cancelButtonBackgroundColor: Color(light: "#FFFFFF", dark: "#FFFFFF"),
                cancelButtonTextColor: Color(light: "#1B1A20", dark: "#1B1A20"),
                cancelButtonBorderColor: Color(light: "#1B1A20", dark: "#1B1A20"),
                confirmButtonBackgroundColor: Color(light: "#7B3AEC", dark: "#7B3AEC"),
                confirmButtonTextColor: Color(light: "#FFFFFF", dark: "#FFFFFF"),
                overlayBackgroundColor: Color.black.opacity(0.4)
            )
        }
        
        public init(
            titleText: String,
            descriptionText: String,
            cancelButtonText: String,
            confirmButtonText: String,
            titleFont: Font,
            descriptionFont: Font,
            buttonFont: Font,
            cornerRadius: CGFloat,
            padding: EdgeInsets,
            spacing: CGFloat,
            buttonSpacing: CGFloat,
            buttonHeight: CGFloat,
            backgroundColor: Color,
            titleColor: Color,
            descriptionColor: Color,
            cancelButtonBackgroundColor: Color,
            cancelButtonTextColor: Color,
            cancelButtonBorderColor: Color,
            confirmButtonBackgroundColor: Color,
            confirmButtonTextColor: Color,
            overlayBackgroundColor: Color
        ) {
            self.titleText = titleText
            self.descriptionText = descriptionText
            self.cancelButtonText = cancelButtonText
            self.confirmButtonText = confirmButtonText
            self.titleFont = titleFont
            self.descriptionFont = descriptionFont
            self.buttonFont = buttonFont
            self.cornerRadius = cornerRadius
            self.padding = padding
            self.spacing = spacing
            self.buttonSpacing = buttonSpacing
            self.buttonHeight = buttonHeight
            self.backgroundColor = backgroundColor
            self.titleColor = titleColor
            self.descriptionColor = descriptionColor
            self.cancelButtonBackgroundColor = cancelButtonBackgroundColor
            self.cancelButtonTextColor = cancelButtonTextColor
            self.cancelButtonBorderColor = cancelButtonBorderColor
            self.confirmButtonBackgroundColor = confirmButtonBackgroundColor
            self.confirmButtonTextColor = confirmButtonTextColor
            self.overlayBackgroundColor = overlayBackgroundColor
        }
    }
    
    // MARK: - Properties
    
    /// The configuration for this dialog
    private let configuration: Configuration
    
    /// Whether the dialog is presented
    @Binding private var isPresented: Bool
    
    /// Action to perform when cancel button is tapped
    private let onCancel: (() -> Void)?
    
    /// Action to perform when confirm button is tapped
    private let onConfirm: () -> Void
    
    // MARK: - Initialization
    
    /// Initialize with a configuration and presentation binding
    /// - Parameters:
    ///   - configuration: The configuration for the dialog
    ///   - isPresented: Binding to control dialog presentation
    ///   - onCancel: Optional callback when cancel button is tapped
    ///   - onConfirm: Callback when confirm button is tapped
    public init(
        configuration: RiviConfirmationDialog.Configuration = .default,
        isPresented: Binding<Bool>,
        onCancel: (() -> Void)? = nil,
        onConfirm: @escaping () -> Void
    ) {
        self.configuration = configuration
        self._isPresented = isPresented
        self.onCancel = onCancel
        self.onConfirm = onConfirm
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
                    .fixedSize(horizontal: false, vertical: true)
                
                // Buttons
                HStack(spacing: configuration.buttonSpacing) {
                    // Cancel Button
                    Button(action: {
                        dismiss()
                    }) {
                        Text(configuration.cancelButtonText)
                            .font(configuration.buttonFont)
                            .foregroundStyle(configuration.cancelButtonTextColor)
                            .frame(maxWidth: .infinity)
                            .frame(height: configuration.buttonHeight)
                            .background(configuration.cancelButtonBackgroundColor)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(configuration.cancelButtonBorderColor, lineWidth: 1)
                            )
                    }
                    
                    // Confirm Button
                    Button(action: {
                        confirm()
                    }) {
                        Text(configuration.confirmButtonText)
                            .font(configuration.buttonFont)
                            .foregroundStyle(configuration.confirmButtonTextColor)
                            .frame(maxWidth: .infinity)
                            .frame(height: configuration.buttonHeight)
                            .background(configuration.confirmButtonBackgroundColor)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding(.top, 8)
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
        onCancel?()
    }
    
    private func confirm() {
        withAnimation(.easeInOut) {
            isPresented = false
        }
        onConfirm()
    }
}
