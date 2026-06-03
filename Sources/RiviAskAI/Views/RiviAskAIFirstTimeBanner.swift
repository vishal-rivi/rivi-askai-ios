import SwiftUI

/// Which edge of the banner the pointer/notch sits on.
///
/// `.top` makes the notch point up (banner sits **below** the anchor button — the default).
/// `.bottom` flips it so the notch points down (banner sits **above** the anchor button).
public enum RiviAskAIFirstTimeBannerNotchEdge {
    case top
    case bottom
}

/// A one-time onboarding banner shown the first time the Ask AI button appears.
/// Renders as a purple card with a sparkle icon, title, description, and a "Let's Go!" CTA,
/// with a notch on one edge (top by default) so it visually points at the anchor button.
public struct RiviAskAIFirstTimeBanner: View {
    // MARK: - Configuration

    public struct Configuration {
        /// Icon asset name (rendered as template)
        public var iconName: String
        /// Title text
        public var titleText: String
        /// Description text
        public var descriptionText: String
        /// "Let's Go!" CTA text
        public var ctaText: String

        /// Title font
        public var titleFont: Font
        /// Description font
        public var descriptionFont: Font
        /// CTA font
        public var ctaFont: Font

        /// Card corner radius
        public var cornerRadius: CGFloat
        /// Card padding (inside the rounded body, excluding the notch)
        public var padding: EdgeInsets
        /// Spacing between icon and the text block
        public var iconSpacing: CGFloat
        /// Spacing between title and description
        public var textSpacing: CGFloat
        /// Spacing between the text block and the CTA
        public var ctaSpacing: CGFloat
        /// Sparkle icon size
        public var iconSize: CGFloat
        /// Width of the notch
        public var notchWidth: CGFloat
        /// Height of the notch
        public var notchHeight: CGFloat
        /// Which edge the notch sits on (default `.top`)
        public var notchEdge: RiviAskAIFirstTimeBannerNotchEdge
        /// Maximum banner width
        public var maxWidth: CGFloat
        /// Vertical alignment of the sparkle icon relative to the text block.
        /// Defaults to `.top` so the icon aligns with the first line of the title.
        public var iconAlignment: VerticalAlignment

        // MARK: Theme

        /// Card background color (purple)
        public var backgroundColor: Color
        /// Title color (white in default theme)
        public var titleColor: Color
        /// Description color (white in default theme)
        public var descriptionColor: Color
        /// Sparkle icon color (white in default theme)
        public var iconColor: Color
        /// CTA background color (white in default theme)
        public var ctaBackgroundColor: Color
        /// CTA text color (purple brand)
        public var ctaTextColor: Color
        /// CTA padding
        public var ctaPadding: EdgeInsets
        /// CTA corner radius
        public var ctaCornerRadius: CGFloat

        public static var `default`: Configuration {
            Configuration(
                iconName: "ic_sparkle",
                titleText: "first_time_banner_title".localized(),
                descriptionText: "first_time_banner_description".localized(),
                ctaText: "first_time_banner_cta".localized(),
                titleFont: .system(size: 18, weight: .semibold),
                descriptionFont: .system(size: 14, weight: .regular),
                ctaFont: .system(size: 14, weight: .semibold),
                cornerRadius: 16,
                padding: EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16),
                iconSpacing: 10,
                textSpacing: 6,
                ctaSpacing: 12,
                iconSize: 20,
                notchWidth: 18,
                notchHeight: 9,
                notchEdge: .top,
                maxWidth: 320,
                iconAlignment: .top,
                backgroundColor: Color(light: "#9D7BFA", dark: "#9D7BFA"),
                titleColor: Color(light: "#FFFFFF", dark: "#FFFFFF"),
                descriptionColor: Color(light: "#FFFFFF", dark: "#FFFFFF"),
                iconColor: Color(light: "#FFFFFF", dark: "#FFFFFF"),
                ctaBackgroundColor: Color(light: "#FFFFFF", dark: "#FFFFFF"),
                ctaTextColor: Color(light: "#7B3AEC", dark: "#7B3AEC"),
                ctaPadding: EdgeInsets(top: 10, leading: 20, bottom: 10, trailing: 20),
                ctaCornerRadius: 12
            )
        }

        public init(
            iconName: String,
            titleText: String,
            descriptionText: String,
            ctaText: String,
            titleFont: Font,
            descriptionFont: Font,
            ctaFont: Font,
            cornerRadius: CGFloat,
            padding: EdgeInsets,
            iconSpacing: CGFloat,
            textSpacing: CGFloat,
            ctaSpacing: CGFloat,
            iconSize: CGFloat,
            notchWidth: CGFloat,
            notchHeight: CGFloat,
            notchEdge: RiviAskAIFirstTimeBannerNotchEdge,
            maxWidth: CGFloat,
            iconAlignment: VerticalAlignment,
            backgroundColor: Color,
            titleColor: Color,
            descriptionColor: Color,
            iconColor: Color,
            ctaBackgroundColor: Color,
            ctaTextColor: Color,
            ctaPadding: EdgeInsets,
            ctaCornerRadius: CGFloat
        ) {
            self.iconName = iconName
            self.titleText = titleText
            self.descriptionText = descriptionText
            self.ctaText = ctaText
            self.titleFont = titleFont
            self.descriptionFont = descriptionFont
            self.ctaFont = ctaFont
            self.cornerRadius = cornerRadius
            self.padding = padding
            self.iconSpacing = iconSpacing
            self.textSpacing = textSpacing
            self.ctaSpacing = ctaSpacing
            self.iconSize = iconSize
            self.notchWidth = notchWidth
            self.notchHeight = notchHeight
            self.notchEdge = notchEdge
            self.maxWidth = maxWidth
            self.iconAlignment = iconAlignment
            self.backgroundColor = backgroundColor
            self.titleColor = titleColor
            self.descriptionColor = descriptionColor
            self.iconColor = iconColor
            self.ctaBackgroundColor = ctaBackgroundColor
            self.ctaTextColor = ctaTextColor
            self.ctaPadding = ctaPadding
            self.ctaCornerRadius = ctaCornerRadius
        }
    }

    // MARK: - Properties

    private let configuration: Configuration
    /// Explicit banner width. When nil, falls back to `configuration.maxWidth`.
    private let width: CGFloat?
    /// X-position of the notch center, in points from the leading edge of the banner.
    /// When nil, the notch is centered horizontally.
    private let notchOffsetFromLeading: CGFloat?
    private let onCTATapped: () -> Void

    // MARK: - Init

    public init(
        configuration: Configuration = .default,
        width: CGFloat? = nil,
        notchOffsetFromLeading: CGFloat? = nil,
        onCTATapped: @escaping () -> Void
    ) {
        self.configuration = configuration
        self.width = width
        self.notchOffsetFromLeading = notchOffsetFromLeading
        self.onCTATapped = onCTATapped
    }

    // MARK: - Body

    public var body: some View {
        VStack(alignment: .leading, spacing: configuration.ctaSpacing) {
            HStack(alignment: configuration.iconAlignment, spacing: configuration.iconSpacing) {
                Image(configuration.iconName, bundle: .module)
                    .resizable()
                    .renderingMode(.template)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: configuration.iconSize, height: configuration.iconSize)
                    .foregroundStyle(configuration.iconColor)

                VStack(alignment: .leading, spacing: configuration.textSpacing) {
                    Text(configuration.titleText)
                        .font(configuration.titleFont)
                        .foregroundStyle(configuration.titleColor)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(configuration.descriptionText)
                        .font(configuration.descriptionFont)
                        .foregroundStyle(configuration.descriptionColor)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack {
                Spacer(minLength: 0)
                Button(action: onCTATapped) {
                    Text(configuration.ctaText)
                        .font(configuration.ctaFont)
                        .foregroundStyle(configuration.ctaTextColor)
                        .padding(configuration.ctaPadding)
                        .background(configuration.ctaBackgroundColor)
                        .clipShape(RoundedRectangle(cornerRadius: configuration.ctaCornerRadius))
                }
            }
        }
        .padding(configuration.padding)
        .frame(width: width ?? configuration.maxWidth, alignment: .leading)
        .background(
            BannerWithNotchShape(
                cornerRadius: configuration.cornerRadius,
                notchWidth: configuration.notchWidth,
                notchHeight: configuration.notchHeight,
                notchCenterX: notchOffsetFromLeading
            )
            .fill(configuration.backgroundColor)
            // The shape itself always draws the notch on its top edge. For
            // `.bottom`, flip vertically so the notch lands on the bottom edge.
            // The card fill is a flat color, so flipping the shape's drawing
            // has no visible effect on the content above it.
            .scaleEffect(y: configuration.notchEdge == .bottom ? -1 : 1)
        )
        .padding(configuration.notchEdge == .top ? .top : .bottom, configuration.notchHeight)
        .environment(\.layoutDirection, RiviAskAIConfiguration.shared.language.layoutDirection)
    }
}

/// A rounded-rect with an upward-pointing notch on the top edge.
/// `notchCenterX` is the X position of the notch's center in points from the leading edge.
/// When nil, the notch is centered.
private struct BannerWithNotchShape: Shape {
    let cornerRadius: CGFloat
    let notchWidth: CGFloat
    let notchHeight: CGFloat
    let notchCenterX: CGFloat?

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let bodyTop = notchHeight
        let r = cornerRadius
        let minNotchCenter = r + notchWidth / 2 + 4
        let maxNotchCenter = rect.width - r - notchWidth / 2 - 4
        let rawCenter = notchCenterX ?? rect.midX
        let notchCenter = max(minNotchCenter, min(rawCenter, maxNotchCenter))
        let notchLeftX = notchCenter - notchWidth / 2
        let notchRightX = notchCenter + notchWidth / 2

        path.move(to: CGPoint(x: r, y: bodyTop))
        path.addLine(to: CGPoint(x: notchLeftX, y: bodyTop))
        path.addLine(to: CGPoint(x: notchCenter, y: 0))
        path.addLine(to: CGPoint(x: notchRightX, y: bodyTop))
        path.addLine(to: CGPoint(x: rect.width - r, y: bodyTop))
        path.addArc(
            center: CGPoint(x: rect.width - r, y: bodyTop + r),
            radius: r,
            startAngle: .degrees(-90),
            endAngle: .degrees(0),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: rect.width, y: rect.height - r))
        path.addArc(
            center: CGPoint(x: rect.width - r, y: rect.height - r),
            radius: r,
            startAngle: .degrees(0),
            endAngle: .degrees(90),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: r, y: rect.height))
        path.addArc(
            center: CGPoint(x: r, y: rect.height - r),
            radius: r,
            startAngle: .degrees(90),
            endAngle: .degrees(180),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: 0, y: bodyTop + r))
        path.addArc(
            center: CGPoint(x: r, y: bodyTop + r),
            radius: r,
            startAngle: .degrees(180),
            endAngle: .degrees(270),
            clockwise: false
        )
        path.closeSubpath()
        return path
    }
}

// MARK: - First-time presentation gate

/// Tracks whether the first-time Ask AI banner has been shown to the user.
public enum RiviAskAIFirstTimeBannerStorage {
    static let userDefaultsKey = "rivi_ask_ai_first_time_banner_shown"

    /// Whether the banner has already been shown (and should not be shown again).
    public static var hasBeenShown: Bool {
        UserDefaults.standard.bool(forKey: userDefaultsKey)
    }

    /// Marks the banner as shown so it will not appear again.
    public static func markAsShown() {
        UserDefaults.standard.set(true, forKey: userDefaultsKey)
    }

    /// Resets the shown flag (useful for testing or a "reset onboarding" feature).
    public static func reset() {
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
    }
}
