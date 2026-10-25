import SwiftUI

/// The Smart Sort button with a halo: the sparkle and "Smart Sort" in a rounded button whose
/// border has a bright arc travelling around it. With active preferences it shows their count.
///
/// The arc runs along a thin ring, clear for most of the turn, then brightening through
/// `haloColors` (the CSS `conic-gradient` of the Rivi design), one turn per `haloDuration`. With
/// Reduce Motion on, only the resting border shows. Use the bound `RiviSmartSortButton` in your app;
/// it disables itself where Smart Sort isn't available.
public struct SmartSortHaloButton: View {
    // MARK: - Configuration

    public struct Configuration {
        // MARK: - Text
        /// Defaults to "Smart Sort".
        public var text: String
        public var font: Font
        public var textColor: Color

        // MARK: - Sparkle
        public var sparkleSize: CGFloat
        public var sparkleConfiguration: SmartSortSparkle.Configuration

        // MARK: - Layout
        public var height: CGFloat
        public var horizontalPadding: CGFloat
        public var spacing: CGFloat
        public var cornerRadius: CGFloat

        // MARK: - Surface
        public var backgroundColor: Color
        /// The resting border, under the halo.
        public var borderColor: Color
        public var borderWidth: CGFloat

        // MARK: - Halo
        /// The arc's colors, from its faint tail to its bright head. The rest of the ring is clear.
        public var haloColors: [Color]
        /// Seconds per turn.
        public var haloDuration: TimeInterval
        public var haloWidth: CGFloat
        /// Shows the halo. true by default.
        public var showsHalo: Bool

        // MARK: - Count badge
        public var badgeFont: Font
        public var badgeBackgroundColor: Color
        public var badgeTextColor: Color
        public var badgeSize: CGFloat

        /// Purple, as the rest of the default design.
        public static var `default`: Configuration {
            Configuration(
                text: "smart_sort_sheet_title".localized(),
                font: .system(size: 13.5, weight: .semibold),
                textColor: AppColor.smartSortAccent,
                sparkleSize: 17,
                sparkleConfiguration: .default,
                height: 38,
                horizontalPadding: 14,
                spacing: 8,
                cornerRadius: 10,
                backgroundColor: AppColor.background,
                borderColor: Color(light: "#E6DDFB", dark: "#3B3159"),
                borderWidth: 1,
                haloColors: [Color(light: "#C9A8FF", dark: "#C9A8FF").opacity(0.55), Color(hex: "#9B6BF5"), AppColor.smartSortAccent],
                haloDuration: 2,
                haloWidth: 1,
                showsHalo: true,
                badgeFont: .system(size: 11, weight: .bold),
                badgeBackgroundColor: AppColor.smartSortAccent,
                badgeTextColor: .white,
                badgeSize: 18
            )
        }

        /// The Rivi design: blue text and arc on a light blue border, with the Rivi sparkle.
        public static var rivi: Configuration {
            var configuration = Configuration.default
            configuration.textColor = Color(light: "#017ACB", dark: "#00A1EB")
            configuration.sparkleConfiguration = .rivi
            configuration.borderColor = Color(light: "#D5E4F5", dark: "#2B4152")
            configuration.haloColors = [Color(red: 120 / 255, green: 175 / 255, blue: 235 / 255).opacity(0.55), Color(hex: "#4B9CF0"), Color(hex: "#0186DF")]
            configuration.badgeBackgroundColor = Color(light: "#0B7BD0", dark: "#0293D6")
            return configuration
        }

        public init(
            text: String, font: Font, textColor: Color,
            sparkleSize: CGFloat, sparkleConfiguration: SmartSortSparkle.Configuration,
            height: CGFloat, horizontalPadding: CGFloat, spacing: CGFloat, cornerRadius: CGFloat,
            backgroundColor: Color, borderColor: Color, borderWidth: CGFloat,
            haloColors: [Color], haloDuration: TimeInterval, haloWidth: CGFloat, showsHalo: Bool,
            badgeFont: Font, badgeBackgroundColor: Color, badgeTextColor: Color, badgeSize: CGFloat
        ) {
            self.text = text
            self.font = font
            self.textColor = textColor
            self.sparkleSize = sparkleSize
            self.sparkleConfiguration = sparkleConfiguration
            self.height = height
            self.horizontalPadding = horizontalPadding
            self.spacing = spacing
            self.cornerRadius = cornerRadius
            self.backgroundColor = backgroundColor
            self.borderColor = borderColor
            self.borderWidth = borderWidth
            self.haloColors = haloColors
            self.haloDuration = haloDuration
            self.haloWidth = haloWidth
            self.showsHalo = showsHalo
            self.badgeFont = badgeFont
            self.badgeBackgroundColor = badgeBackgroundColor
            self.badgeTextColor = badgeTextColor
            self.badgeSize = badgeSize
        }
    }

    // MARK: - Properties

    private let configuration: Configuration
    private let count: Int
    private let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    /// - Parameters:
    ///   - count: Active preferences, shown as a badge when above 0.
    ///   - action: Typically opens the Smart Sort sheet.
    public init(configuration: Configuration = .default, count: Int = 0, action: @escaping () -> Void) {
        self.configuration = configuration
        self.count = count
        self.action = action
    }

    // MARK: - Body

    public var body: some View {
        let shape = RoundedRectangle(cornerRadius: configuration.cornerRadius)
        Button(action: action) {
            HStack(spacing: configuration.spacing) {
                SmartSortSparkle(size: configuration.sparkleSize, configuration: configuration.sparkleConfiguration)
                Text(configuration.text)
                    .font(configuration.font)
                    .foregroundStyle(configuration.textColor)
                    .lineLimit(1)
                if count > 0 {
                    Text("\(count)")
                        .font(configuration.badgeFont)
                        .foregroundStyle(configuration.badgeTextColor)
                        .frame(minWidth: configuration.badgeSize, minHeight: configuration.badgeSize)
                        .background(Circle().fill(configuration.badgeBackgroundColor))
                }
            }
            .padding(.horizontal, configuration.horizontalPadding)
            .frame(height: configuration.height)
            .background(shape.fill(configuration.backgroundColor))
            .overlay(shape.strokeBorder(configuration.borderColor, lineWidth: configuration.borderWidth))
            .overlay {
                if configuration.showsHalo && !reduceMotion {
                    // The time drives the angle, so the halo never stalls when the view is rebuilt.
                    TimelineView(.animation) { timeline in
                        shape.strokeBorder(halo(at: timeline.date), lineWidth: configuration.haloWidth)
                    }
                }
            }
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .opacity(isEnabled ? 1 : 0.5)
        .fixedSize()
        .accessibilityLabel(Text(count > 0 ? "\(configuration.text), \(count)" : configuration.text))
    }

    /// Clear until 245°, then `haloColors` over 290°–356°, clear again at 360° (the design's
    /// `conic-gradient` stops), rotated by the time.
    private func halo(at date: Date) -> AngularGradient {
        let turn = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: configuration.haloDuration) / configuration.haloDuration
        let angle = turn * 360
        let colors = configuration.haloColors
        var stops: [Gradient.Stop] = [.init(color: .clear, location: 0), .init(color: .clear, location: 245 / 360)]
        let positions: [Double] = colors.count == 1 ? [335] : (0..<colors.count).map { 290 + Double($0) * (356 - 290) / Double(colors.count - 1) }
        for (color, position) in zip(colors, positions) {
            stops.append(.init(color: color, location: position / 360))
        }
        stops.append(.init(color: .clear, location: 1))
        return AngularGradient(stops: stops, center: .center, startAngle: .degrees(angle), endAngle: .degrees(angle + 360))
    }
}
