import SwiftUI

/// Represents a theme for customizing the RiviAskAI component's appearance
public struct RiviAskAITheme {
    /// The primary accent color of the theme
    public let accentColor: Color
    
    /// Main background color for the component
    public let backgroundColor: Color
    
    /// Main text color for the component
    public let textColor: Color
    
    /// Button-specific colors
    public let buttonBackgroundColor: Color
    public let buttonTextColor: Color
    
    /// Input field-specific colors
    public let inputBackgroundColor: Color
    public let inputBorderColor: Color
    public let inputTextColor: Color
    public let placeholderColor: Color
    
    /// Popup-specific colors
    public let popupBackgroundColor: Color
    public let popupHeaderTextColor: Color
    public let closeButtonColor: Color
    
    /// Font-specific properties
    public let fontName: String
    public let titleFontSize: CGFloat
    public let bodyFontSize: CGFloat
    public let buttonFontSize: CGFloat
    
    /// Initialize a theme with custom colors
    /// - Parameters:
    ///   - accentColor: The primary accent color
    ///   - backgroundColor: Main background color
    ///   - textColor: Main text color
    ///   - buttonBackgroundColor: Background color for buttons
    ///   - buttonTextColor: Text color for buttons
    ///   - inputBackgroundColor: Background color for input fields
    ///   - inputBorderColor: Border color for input fields
    ///   - inputTextColor: Text color for input fields
    ///   - placeholderColor: Placeholder text color
    ///   - popupBackgroundColor: Background color for popup
    ///   - popupHeaderTextColor: Text color for popup header
    ///   - closeButtonColor: Color for close button
    ///   - fontName: Custom font name to use (system font if empty)
    ///   - titleFontSize: Font size for titles and headers
    ///   - bodyFontSize: Font size for body text
    ///   - buttonFontSize: Font size for button text
    public init(
        accentColor: Color,
        backgroundColor: Color? = nil,
        textColor: Color? = nil,
        buttonBackgroundColor: Color? = nil,
        buttonTextColor: Color? = nil,
        inputBackgroundColor: Color? = nil,
        inputBorderColor: Color? = nil,
        inputTextColor: Color? = nil,
        placeholderColor: Color? = nil,
        popupBackgroundColor: Color? = nil,
        popupHeaderTextColor: Color? = nil,
        closeButtonColor: Color? = nil,
        fontName: String = "",
        titleFontSize: CGFloat = 18,
        bodyFontSize: CGFloat = 16,
        buttonFontSize: CGFloat = 16
    ) {
        self.accentColor = accentColor
        self.backgroundColor = backgroundColor ?? Color.RiviAskAI.background
        self.textColor = textColor ?? Color.RiviAskAI.text
        self.buttonBackgroundColor = buttonBackgroundColor ?? accentColor.opacity(0.12)
        self.buttonTextColor = buttonTextColor ?? accentColor
        self.inputBackgroundColor = inputBackgroundColor ?? Color.RiviAskAI.Input.background
        self.inputBorderColor = inputBorderColor ?? Color.RiviAskAI.Input.border
        self.inputTextColor = inputTextColor ?? Color.RiviAskAI.Input.text
        self.placeholderColor = placeholderColor ?? Color.RiviAskAI.Input.placeholder
        self.popupBackgroundColor = popupBackgroundColor ?? Color.RiviAskAI.Popup.background
        self.popupHeaderTextColor = popupHeaderTextColor ?? Color.RiviAskAI.Popup.headerText
        self.closeButtonColor = closeButtonColor ?? Color.RiviAskAI.Popup.closeButton
        self.fontName = fontName
        self.titleFontSize = titleFontSize
        self.bodyFontSize = bodyFontSize
        self.buttonFontSize = buttonFontSize
    }
    
    /// Convenience initializers for predefined themes
    
    /// Blue theme
    public static let blue = RiviAskAITheme(
        accentColor: Color.RiviAskAI.Theme.Blue.primary,
        backgroundColor: Color.RiviAskAI.Theme.Blue.background
    )
    
    /// Green theme
    public static let green = RiviAskAITheme(
        accentColor: Color.RiviAskAI.Theme.Green.primary,
        backgroundColor: Color.RiviAskAI.Theme.Green.background
    )
    
    /// Violet theme
    public static let violet = RiviAskAITheme(
        accentColor: Color.RiviAskAI.Theme.Violet.primary,
        backgroundColor: Color.RiviAskAI.Theme.Violet.background
    )
    
    /// Magenta theme
    public static let magenta = RiviAskAITheme(
        accentColor: Color.RiviAskAI.Theme.Magenta.primary,
        backgroundColor: Color.RiviAskAI.Theme.Magenta.background
    )
    
    /// Default theme (blue)
    public static let `default` = blue
    
    /// Returns the appropriate font for titles based on the theme settings
    public func titleFont() -> Font {
        return fontName.isEmpty ? .headline : .custom(fontName, size: titleFontSize)
    }
    
    /// Returns the appropriate font for body text based on the theme settings
    public func bodyFont() -> Font {
        return fontName.isEmpty ? .body : .custom(fontName, size: bodyFontSize)
    }
    
    /// Returns the appropriate font for buttons based on the theme settings
    public func buttonFont() -> Font {
        return fontName.isEmpty ? .system(size: buttonFontSize, weight: .medium) : .custom(fontName, size: buttonFontSize)
    }
} 
