import SwiftUI

/// A customizable info banner component to display informational messages
public struct RiviInfoBanner: View {
    // MARK: - Configuration
    
    /// Configuration options for the RiviInfoBanner
    public struct Configuration {
        /// The icon name
        public var iconName: String
        /// The title text to display
        public var titleText: String
        /// The description text to display
        public var descriptionText: String
        /// The title font
        public var titleFont: Font
        /// The description font
        public var descriptionFont: Font
        /// The corner radius of the banner
        public var cornerRadius: CGFloat
        /// The padding inside the banner
        public var padding: EdgeInsets
        /// The spacing between icon and text
        public var iconSpacing: CGFloat
        /// The spacing between title and description
        public var textSpacing: CGFloat
        /// Whether to show the icon
        public var showIcon: Bool
        /// The icon size
        public var iconSize: CGFloat
        
        // MARK: - Theme Properties
        
        /// Background color for the banner
        public var backgroundColor: Color
        /// Border color for the banner
        public var borderColor: Color
        /// Title text color
        public var titleColor: Color
        /// Description text color
        public var descriptionColor: Color
        /// Icon color
        public var iconColor: Color
        
        /// Create a default configuration
        public static var `default`: Configuration {
            Configuration(
                iconName: "ic_info_2",
                titleText: "info_banner_title".localized(),
                descriptionText: "info_banner_description".localized(),
                titleFont: .system(size: 12, weight: .medium),
                descriptionFont: .system(size: 11, weight: .regular),
                cornerRadius: 8,
                padding: EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8),
                iconSpacing: 8,
                textSpacing: 2,
                showIcon: true,
                iconSize: 12,
                backgroundColor: Color(light: "#EFE5FF", dark: "#EFE5FF"),
                borderColor: Color(light: "#D4B5FF", dark: "#D4B5FF"),
                titleColor: Color(light: "#7B3AEC", dark: "#7B3AEC"),
                descriptionColor: Color(light: "#7B3AEC", dark: "#7B3AEC"),
                iconColor: Color(light: "#7B3AEC", dark: "#7B3AEC")
            )
        }
        
        public init(
            iconName: String,
            titleText: String,
            descriptionText: String,
            titleFont: Font,
            descriptionFont: Font,
            cornerRadius: CGFloat,
            padding: EdgeInsets,
            iconSpacing: CGFloat,
            textSpacing: CGFloat,
            showIcon: Bool,
            iconSize: CGFloat,
            backgroundColor: Color,
            borderColor: Color,
            titleColor: Color,
            descriptionColor: Color,
            iconColor: Color
        ) {
            self.iconName = iconName
            self.titleText = titleText
            self.descriptionText = descriptionText
            self.titleFont = titleFont
            self.descriptionFont = descriptionFont
            self.cornerRadius = cornerRadius
            self.padding = padding
            self.iconSpacing = iconSpacing
            self.textSpacing = textSpacing
            self.showIcon = showIcon
            self.iconSize = iconSize
            self.backgroundColor = backgroundColor
            self.borderColor = borderColor
            self.titleColor = titleColor
            self.descriptionColor = descriptionColor
            self.iconColor = iconColor
        }
    }
    
    // MARK: - Properties
    
    /// The configuration for this banner
    private let configuration: Configuration
    
    // MARK: - Initialization
    
    /// Initialize with a configuration
    public init(configuration: RiviInfoBanner.Configuration = .default) {
        self.configuration = configuration
    }
    
    // MARK: - Body
    
    public var body: some View {
        HStack(alignment: .top, spacing: configuration.iconSpacing) {
            if configuration.showIcon {
                Image(configuration.iconName, bundle: .module)
                    .resizable()
                    .renderingMode(.template)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: configuration.iconSize, height: configuration.iconSize)
                    .foregroundStyle(configuration.iconColor)
                    .padding(.top, 2)
            }
            
            VStack(alignment: .leading, spacing: configuration.textSpacing) {
                Text(configuration.titleText)
                    .font(configuration.titleFont)
                    .foregroundStyle(configuration.titleColor)
                
                Text(configuration.descriptionText)
                    .font(configuration.descriptionFont)
                    .foregroundStyle(configuration.descriptionColor)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(configuration.padding)
        .background(configuration.backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: configuration.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: configuration.cornerRadius)
                .stroke(configuration.borderColor, lineWidth: 1)
        )
        .padding(1)
        .environment(\.layoutDirection, RiviAskAIConfiguration.shared.language.layoutDirection)
    }
}
