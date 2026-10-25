import SwiftUI

/// The Smart Sort label: `SmartSortSparkle`, "Smart Sort" and a count badge, in a pill.
///
/// While `count` is 0 the sparkle breathes and twinkles every `twinkleInterval`, and a light
/// shimmer sweeps across the text after each twinkle. With a count (Smart Sort is active) the pill
/// takes `activeBackgroundColor`, shows the badge, and stays still. Wrap it in a `Button` to make
/// it tappable.
public struct SmartSortTwinkleText: View {
    // MARK: - Configuration

    public struct Configuration {
        /// The label text.
        public var text: String
        /// The label font.
        public var font: Font
        /// The label and sparkle color.
        public var textColor: Color
        /// The sparkle's colors. Its own timing is ignored: this view drives the twinkle.
        public var sparkleConfiguration: SmartSortSparkle.Configuration
        /// The sparkle's size.
        public var sparkleSize: CGFloat
        /// Color of the band that sweeps across the text after a twinkle.
        public var shimmerColor: Color
        /// Seconds between twinkles while inactive. nil twinkles once, after `initialDelay`.
        public var twinkleInterval: TimeInterval?
        /// Seconds before the first twinkle.
        public var initialDelay: TimeInterval

        /// The badge font.
        public var badgeFont: Font
        /// The badge fill.
        public var badgeBackgroundColor: Color
        /// The badge number color.
        public var badgeTextColor: Color
        /// The badge's minimum width and its height.
        public var badgeSize: CGFloat

        /// The pill fill while inactive (count 0).
        public var backgroundColor: Color
        /// The pill fill while active (count above 0).
        public var activeBackgroundColor: Color
        /// Space between the sparkle, the text and the badge.
        public var spacing: CGFloat
        /// Padding inside the pill.
        public var padding: EdgeInsets

        /// The Smart Sort label, as in the results bar.
        public static var `default`: Configuration {
            Configuration(
                text: "smart_sort_sheet_title".localized(),
                font: .system(size: 15, weight: .semibold),
                textColor: AppColor.smartSortAccent,
                sparkleConfiguration: .default,
                sparkleSize: 18,
                shimmerColor: Color(light: "#F8F4FF", dark: "#FFFFFF"),
                twinkleInterval: 6,
                initialDelay: 0.35,
                badgeFont: .system(size: 11, weight: .bold),
                badgeBackgroundColor: AppColor.smartSortAccent,
                badgeTextColor: AppColor.color2,
                badgeSize: 20,
                backgroundColor: .clear,
                activeBackgroundColor: AppColor.smartSortTint,
                spacing: 6,
                padding: EdgeInsets(top: 10, leading: 14, bottom: 10, trailing: 14)
            )
        }

        public init(
            text: String,
            font: Font,
            textColor: Color,
            sparkleConfiguration: SmartSortSparkle.Configuration,
            sparkleSize: CGFloat,
            shimmerColor: Color,
            twinkleInterval: TimeInterval?,
            initialDelay: TimeInterval,
            badgeFont: Font,
            badgeBackgroundColor: Color,
            badgeTextColor: Color,
            badgeSize: CGFloat,
            backgroundColor: Color,
            activeBackgroundColor: Color,
            spacing: CGFloat,
            padding: EdgeInsets
        ) {
            self.text = text
            self.font = font
            self.textColor = textColor
            self.sparkleConfiguration = sparkleConfiguration
            self.sparkleSize = sparkleSize
            self.shimmerColor = shimmerColor
            self.twinkleInterval = twinkleInterval
            self.initialDelay = initialDelay
            self.badgeFont = badgeFont
            self.badgeBackgroundColor = badgeBackgroundColor
            self.badgeTextColor = badgeTextColor
            self.badgeSize = badgeSize
            self.backgroundColor = backgroundColor
            self.activeBackgroundColor = activeBackgroundColor
            self.spacing = spacing
            self.padding = padding
        }
    }

    // MARK: - Properties

    private let configuration: Configuration
    private let count: Int
    private let isAnimating: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var twinkleTrigger = 0
    @State private var shimmerStart: Date?

    /// The shimmer starts 0.45s into a twinkle and lasts 1.2s.
    private let shimmerDelay: TimeInterval = 0.45
    private let shimmerDuration: TimeInterval = 1.2

    // MARK: - Initialization

    /// - Parameters:
    ///   - configuration: Text, colors and timing (defaults to `.default`).
    ///   - count: Active preferences. 0 hides the badge and keeps the label animating.
    ///   - isAnimating: false keeps the label still whatever the count.
    public init(configuration: Configuration = .default, count: Int = 0, isAnimating: Bool = true) {
        self.configuration = configuration
        self.count = count
        self.isAnimating = isAnimating
    }

    // MARK: - Body

    public var body: some View {
        let isActive = count > 0
        let animates = isAnimating && !isActive && !reduceMotion

        HStack(spacing: configuration.spacing) {
            SmartSortSparkle(
                size: configuration.sparkleSize,
                configuration: sparkleConfiguration,
                isAnimating: animates,
                twinkleTrigger: twinkleTrigger
            )

            label(animates: animates)

            if isActive {
                Text("\(count)")
                    .font(configuration.badgeFont)
                    .foregroundStyle(configuration.badgeTextColor)
                    .padding(.horizontal, 5)
                    .frame(minWidth: configuration.badgeSize, minHeight: configuration.badgeSize)
                    .background(Capsule().fill(configuration.badgeBackgroundColor))
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(configuration.padding)
        .background(Capsule().fill(isActive ? configuration.activeBackgroundColor : configuration.backgroundColor))
        .animation(.easeInOut(duration: 0.2), value: isActive)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilityText))
        .task(id: animates) {
            guard animates else { return }
            try? await Task.sleep(nanoseconds: UInt64(configuration.initialDelay * 1_000_000_000))
            while !Task.isCancelled {
                twinkleTrigger += 1
                shimmerStart = Date().addingTimeInterval(shimmerDelay)
                let shimmerEnds = shimmerDelay + shimmerDuration
                try? await Task.sleep(nanoseconds: UInt64(shimmerEnds * 1_000_000_000))
                shimmerStart = nil // stops the shimmer's timeline until the next twinkle
                guard let interval = configuration.twinkleInterval else { return }
                try? await Task.sleep(nanoseconds: UInt64(max(interval - shimmerEnds, 0) * 1_000_000_000))
            }
        }
    }

    /// The sparkle's colors without its own timer: this view schedules the twinkles.
    private var sparkleConfiguration: SmartSortSparkle.Configuration {
        var sparkle = configuration.sparkleConfiguration
        sparkle.showsBurst = true // the pill's sparkle bursts, as in the design
        sparkle.twinkleInterval = nil
        return sparkle
    }

    private var accessibilityText: String {
        guard count > 0 else { return configuration.text }
        return configuration.text + ", " + String(format: "smart_sort_twinkle_count_accessibility".localized(), count)
    }

    // MARK: - Label and shimmer

    @ViewBuilder
    private func label(animates: Bool) -> some View {
        let text = Text(configuration.text)
            .font(configuration.font)
            .lineLimit(1)
        text
            .foregroundStyle(configuration.textColor)
            .overlay {
                if animates, let shimmerStart {
                    TimelineView(.animation) { timeline in
                        shimmerBand(progress: timeline.date.timeIntervalSince(shimmerStart) / shimmerDuration)
                    }
                    .mask(text)
                    .allowsHitTesting(false)
                }
            }
    }

    /// A soft band, 40% of the text's width, sweeping from before the leading edge to past the
    /// trailing edge.
    @ViewBuilder
    private func shimmerBand(progress: Double) -> some View {
        GeometryReader { proxy in
            if progress > 0 && progress < 1 {
                let bandWidth = proxy.size.width * 0.4
                let start = -1.3 * bandWidth, end = 3.3 * bandWidth
                LinearGradient(
                    colors: [configuration.shimmerColor.opacity(0), configuration.shimmerColor.opacity(0.95), configuration.shimmerColor.opacity(0)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: bandWidth, height: proxy.size.height)
                .offset(x: start + (end - start) * SmartSortEasing.shimmer(progress))
            }
        }
    }
}
