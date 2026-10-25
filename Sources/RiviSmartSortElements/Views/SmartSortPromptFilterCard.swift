import SwiftUI

/// The "Try Smart Sort" row at the top of the host's filter sheet.
///
/// Its sparkle breathes and twinkles shortly after it appears and then every few seconds. Set
/// `isHighlighted` (e.g. once the user has picked 4 or more filters) to outline the row in the
/// accent color; the sparkle pops once each time it becomes highlighted. The whole row is one button that calls `onTap`, typically to apply the picked
/// filters and open the Smart Sort sheet.
public struct SmartSortPromptFilterCard: View {
    // MARK: - Configuration

    public struct Configuration {
        /// The text beside the sparkle. Empty uses the flight or hotel default.
        public var text: String
        /// What VoiceOver reads for the row ("Try Smart Sort"); the row shows a chevron.
        public var buttonText: String

        public var textFont: Font

        public var padding: EdgeInsets
        public var cornerRadius: CGFloat
        public var spacing: CGFloat
        public var sparkleSize: CGFloat
        /// The chevron's point size.
        public var arrowSize: CGFloat

        /// Fills the background with this gradient (leading to trailing, the design's 100°) instead
        /// of `backgroundColor`. nil by default.
        public var backgroundGradient: [Color]? = nil
        public var backgroundColor: Color
        public var borderColor: Color
        /// Border, and a 1pt ring outside it, while highlighted.
        public var highlightedBorderColor: Color
        public var textColor: Color
        /// The sparkle's colors and twinkle timing.
        public var sparkleConfiguration: SmartSortSparkle.Configuration
        /// The chevron's color.
        public var arrowColor: Color

        /// The Smart Sort V2 design.
        public static var `default`: Configuration {
            var sparkle = SmartSortSparkle.Configuration.default
            sparkle.initialDelay = 0.45
            return Configuration(
                text: "",
                buttonText: "smart_sort_prompt_filter_button".localized(),
                textFont: .system(size: 14, weight: .regular),
                padding: EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 12),
                cornerRadius: 14,
                spacing: 10,
                sparkleSize: 20,
                arrowSize: 15,
                backgroundColor: Color(light: "#F5F0FF", dark: "#221D33"),
                borderColor: Color(light: "#E3D8FA", dark: "#3B3159"),
                highlightedBorderColor: AppColor.smartSortAccent,
                textColor: Color(light: "#1B1B1F", dark: "#FAFAFA"),
                sparkleConfiguration: sparkle,
                arrowColor: AppColor.smartSortAccent
            )
        }

        public init(
            text: String,
            buttonText: String,
            textFont: Font,
            padding: EdgeInsets,
            cornerRadius: CGFloat,
            spacing: CGFloat,
            sparkleSize: CGFloat,
            arrowSize: CGFloat,
            backgroundColor: Color,
            borderColor: Color,
            highlightedBorderColor: Color,
            textColor: Color,
            sparkleConfiguration: SmartSortSparkle.Configuration,
            arrowColor: Color
        ) {
            self.text = text
            self.buttonText = buttonText
            self.textFont = textFont
            self.padding = padding
            self.cornerRadius = cornerRadius
            self.spacing = spacing
            self.sparkleSize = sparkleSize
            self.arrowSize = arrowSize
            self.backgroundColor = backgroundColor
            self.borderColor = borderColor
            self.highlightedBorderColor = highlightedBorderColor
            self.textColor = textColor
            self.sparkleConfiguration = sparkleConfiguration
            self.arrowColor = arrowColor
        }
    }

    // MARK: - Properties

    private let configuration: Configuration
    private let isHighlighted: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// When the current pop started. nil when no pop is playing.
    @State private var popStart: Date?
    private let popDuration: TimeInterval = 1.2
    private let onTap: () -> Void

    // MARK: - Initialization

    /// - Parameters:
    ///   - configuration: Text, layout and colors (defaults to `.default`).
    ///   - queryType: Picks the flight or hotel text.
    ///   - isHighlighted: Outlines the row in the accent color.
    ///   - onTap: Called when the row is tapped.
    public init(
        configuration: Configuration = .default,
        queryType: QueryType,
        isHighlighted: Bool = false,
        onTap: @escaping () -> Void
    ) {
        var resolved = configuration
        if resolved.text.isEmpty {
            resolved.text = (queryType == .hotel ? "smart_sort_prompt_filter_text_hotel" : "smart_sort_prompt_filter_text_flight").localized()
        }
        self.configuration = resolved
        self.isHighlighted = isHighlighted
        self.onTap = onTap
    }

    // MARK: - Body

    public var body: some View {
        let shape = RoundedRectangle(cornerRadius: configuration.cornerRadius)
        Button(action: onTap) {
            HStack(spacing: configuration.spacing) {
                TimelineView(.animation(minimumInterval: nil, paused: popStart == nil)) { timeline in
                    let pop = popTransform(at: timeline.date)
                    SmartSortSparkle(size: configuration.sparkleSize, configuration: configuration.sparkleConfiguration)
                        .scaleEffect(pop.scale)
                        .rotationEffect(.degrees(pop.rotation))
                }
                Text(configuration.text)
                    .font(configuration.textFont)
                    .foregroundStyle(configuration.textColor)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                // "chevron.forward" points the other way in Arabic.
                Image(systemName: "chevron.forward")
                    .font(.system(size: configuration.arrowSize, weight: .semibold))
                    .foregroundStyle(configuration.arrowColor)
            }
            .padding(configuration.padding)
            .background(shape.fill(smartSortFill(configuration.backgroundColor, gradient: configuration.backgroundGradient)))
            .overlay(shape.stroke(isHighlighted ? configuration.highlightedBorderColor : configuration.borderColor, lineWidth: 1))
            // The 1pt ring outside the border while highlighted.
            .overlay(shape.inset(by: -1).stroke(configuration.highlightedBorderColor.opacity(isHighlighted ? 1 : 0), lineWidth: 1))
            .contentShape(shape)
            .animation(.easeOut(duration: 0.25), value: isHighlighted)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(configuration.buttonText))
        .accessibilityHint(Text(configuration.text))
        .onAppear { if isHighlighted { playPop() } }
        .onChange(of: isHighlighted) { highlighted in
            if highlighted { playPop() }
        }
    }

    // MARK: - Pop

    private func playPop() {
        guard !reduceMotion else { return }
        let start = Date()
        popStart = start
        DispatchQueue.main.asyncAfter(deadline: .now() + popDuration) {
            if popStart == start { popStart = nil } // stops the timeline once the pop ends
        }
    }

    /// Keyframes: scale 1 → 1.3 (35%) → 1.06 (70%) → 1, rotating 0° → 14° → 3° → 0°, each step eased.
    private func popTransform(at date: Date) -> (scale: CGFloat, rotation: Double) {
        guard let popStart else { return (1, 0) }
        let progress = min(max(date.timeIntervalSince(popStart) / popDuration, 0), 1)
        let frames: [(at: Double, scale: Double, rotation: Double)] = [(0, 1, 0), (0.35, 1.3, 14), (0.7, 1.06, 3), (1, 1, 0)]
        for (from, to) in zip(frames, frames.dropFirst()) where progress <= to.at {
            let t = SmartSortEasing.pop((progress - from.at) / (to.at - from.at))
            return (from.scale + (to.scale - from.scale) * t, from.rotation + (to.rotation - from.rotation) * t)
        }
        return (1, 0)
    }
}
