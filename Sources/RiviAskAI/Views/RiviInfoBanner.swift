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

        // MARK: - Skeleton Loading

        /// Base placeholder fill used for the skeleton bars when `isLoading` is true.
        public var skeletonBaseColor: Color
        /// Highlight color of the shimmer band that travels across the skeleton bars.
        public var skeletonHighlightColor: Color
        /// Duration (seconds) of one shimmer sweep, repeated for as long as `isLoading` is true.
        public var skeletonAnimationDuration: Double
        /// Corner radius of the placeholder bars rendered in the skeleton state.
        public var skeletonCornerRadius: CGFloat
        /// Height of the title placeholder bar.
        public var skeletonTitleHeight: CGFloat
        /// Width of the title placeholder bar. Use `nil` to fill available width.
        public var skeletonTitleWidth: CGFloat?
        /// Height of the description placeholder bar.
        public var skeletonDescriptionHeight: CGFloat
        
        /// Create a default configuration
        public static var `default`: Configuration {
            Configuration(
                iconName: "ic_sparkle",
                titleText: "",
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
                iconColor: Color(light: "#7B3AEC", dark: "#7B3AEC"),
                skeletonBaseColor: Color(light: "#D4B5FF", dark: "#D4B5FF"),
                skeletonHighlightColor: Color(light: "#FFFFFFCC", dark: "#FFFFFFCC"),
                skeletonAnimationDuration: 1.3,
                skeletonCornerRadius: 4,
                skeletonTitleHeight: 10,
                skeletonTitleWidth: 110,
                skeletonDescriptionHeight: 9
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
            iconColor: Color,
            skeletonBaseColor: Color,
            skeletonHighlightColor: Color,
            skeletonAnimationDuration: Double,
            skeletonCornerRadius: CGFloat,
            skeletonTitleHeight: CGFloat,
            skeletonTitleWidth: CGFloat?,
            skeletonDescriptionHeight: CGFloat
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
            self.skeletonBaseColor = skeletonBaseColor
            self.skeletonHighlightColor = skeletonHighlightColor
            self.skeletonAnimationDuration = skeletonAnimationDuration
            self.skeletonCornerRadius = skeletonCornerRadius
            self.skeletonTitleHeight = skeletonTitleHeight
            self.skeletonTitleWidth = skeletonTitleWidth
            self.skeletonDescriptionHeight = skeletonDescriptionHeight
        }
    }
    
    // MARK: - Properties

    /// The configuration for this banner
    private let configuration: Configuration

    /// When true, the banner shows shimmering skeleton placeholders instead of the real content.
    private let isLoading: Bool

    // MARK: - Initialization

    /// Initialize with a configuration and optional loading state.
    /// - Parameters:
    ///   - configuration: The configuration for the banner
    ///   - isLoading: When true (the default), renders shimmering skeleton bars in
    ///     place of the title/description. Pass `false` to render the actual text.
    public init(
        configuration: RiviInfoBanner.Configuration = .default,
        isLoading: Bool = true
    ) {
        self.configuration = configuration
        self.isLoading = isLoading
    }

    // MARK: - Body

    public var body: some View {
        HStack(alignment: .top, spacing: configuration.iconSpacing) {
            if configuration.showIcon {
                iconView
            }

            VStack(alignment: .leading, spacing: configuration.textSpacing) {
                if isLoading {
                    skeletonRows
                } else {
                    textRows
                }
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

    // MARK: - Subviews

    @ViewBuilder
    private var iconView: some View {
        Image(configuration.iconName, bundle: .module)
            .resizable()
            .renderingMode(.template)
            .aspectRatio(contentMode: .fit)
            .frame(width: configuration.iconSize, height: configuration.iconSize)
            .foregroundStyle(configuration.iconColor)
            .padding(.top, 2)
    }

    @ViewBuilder
    private var textRows: some View {
        if !configuration.titleText.isEmpty {
            Text(configuration.titleText)
                .font(configuration.titleFont)
                .foregroundStyle(configuration.titleColor)
        }
        Text(configuration.descriptionText)
            .font(configuration.descriptionFont)
            .foregroundStyle(configuration.descriptionColor)
    }

    @ViewBuilder
    private var skeletonRows: some View {
        if !configuration.titleText.isEmpty {
            ShimmerBar(
                baseColor: configuration.skeletonBaseColor,
                highlightColor: configuration.skeletonHighlightColor,
                cornerRadius: configuration.skeletonCornerRadius,
                duration: configuration.skeletonAnimationDuration
            )
            .frame(
                width: configuration.skeletonTitleWidth,
                height: configuration.skeletonTitleHeight
            )
            .frame(
                maxWidth: configuration.skeletonTitleWidth == nil ? .infinity : nil,
                alignment: .leading
            )
        }
        ShimmerBar(
            baseColor: configuration.skeletonBaseColor,
            highlightColor: configuration.skeletonHighlightColor,
            cornerRadius: configuration.skeletonCornerRadius,
            duration: configuration.skeletonAnimationDuration
        )
        .frame(maxWidth: .infinity)
        .frame(height: configuration.skeletonDescriptionHeight)
    }
}

/// A single skeleton bar with a shimmer band travelling across it.
private struct ShimmerBar: View {
    let baseColor: Color
    let highlightColor: Color
    let cornerRadius: CGFloat
    let duration: Double

    @State private var phase: CGFloat = -1

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        shape
            .fill(baseColor)
            .overlay(
                GeometryReader { proxy in
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: .clear, location: 0.0),
                            .init(color: highlightColor, location: 0.5),
                            .init(color: .clear, location: 1.0)
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: proxy.size.width * 0.6)
                    .offset(x: phase * proxy.size.width * 1.6)
                }
            )
            .clipShape(shape)
            .onAppear {
                phase = -1
                withAnimation(
                    .linear(duration: duration)
                    .repeatForever(autoreverses: false)
                ) {
                    phase = 1
                }
            }
    }
}
