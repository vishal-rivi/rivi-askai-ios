import SwiftUI

/// The "Not sure which one to pick?" card shown inside the results list.
///
/// Its input is a fake: it types out example queries word by word, holds each one, fades it out
/// and moves to the next, only while the card is on screen. With Reduce Motion on, each example
/// shows in full and swaps every few seconds. Tapping the card calls `onTap` with the example on
/// screen, so the host can open Smart Sort with it as the placeholder; the ✕ calls `onDismiss`.
/// When to show the card (e.g. after the 4th result, only while Smart Sort is off) is the host's call.
public struct SmartSortPromptResultCard: View {
    // MARK: - Configuration

    public struct Configuration {
        // MARK: - Text
        /// The title next to the sparkle.
        public var titleText: String
        /// The line under the title. Empty uses the flight or hotel default.
        public var descriptionText: String
        /// The examples the input cycles through. Empty uses the flight or hotel defaults.
        public var examples: [String]
        /// Shown before each example when `quotesExample` is false.
        public var examplePrefix: String
        /// Shows each example in quotes with a blinking cursor, instead of after `examplePrefix`.
        public var quotesExample: Bool

        // MARK: - Fonts
        public var titleFont: Font
        public var descriptionFont: Font
        public var exampleFont: Font

        // MARK: - Timing
        /// How the examples type out, hold and fade.
        public var exampleAnimation: SmartSortExampleAnimation

        // MARK: - Layout
        public var padding: EdgeInsets
        public var cornerRadius: CGFloat
        public var sparkleSize: CGFloat
        public var inputHeight: CGFloat
        public var inputCornerRadius: CGFloat
        public var sendButtonSize: CGFloat

        // MARK: - Colors
        /// The card's fill.
        /// Fills the background with this gradient (leading to trailing, the design's 100°) instead
        /// of `backgroundColor`. nil by default.
        public var backgroundGradient: [Color]? = nil
        public var backgroundColor: Color
        /// A soft spotlight just off the top trailing corner.
        public var glowColor: Color
        /// The spotlight's opacity at its center; it fades to 0 at its edge.
        public var glowOpacity: Double
        public var borderColor: Color
        public var titleColor: Color
        public var descriptionColor: Color
        public var dismissButtonColor: Color
        public var sparkleConfiguration: SmartSortSparkle.Configuration
        public var inputBackgroundColor: Color
        public var inputBorderColor: Color
        public var exampleColor: Color
        /// The blinking cursor after a quoted example.
        public var cursorColor: Color
        public var sendButtonBackgroundColor: Color
        public var sendButtonIconColor: Color

        /// The Smart Sort V2 design.
        public static var `default`: Configuration {
            Configuration(
                titleText: "smart_sort_prompt_result_title".localized(),
                descriptionText: "",
                examples: [],
                examplePrefix: "smart_sort_prompt_example_prefix".localized(),
                quotesExample: true,
                titleFont: .system(size: 16, weight: .semibold),
                descriptionFont: .system(size: 14, weight: .regular),
                exampleFont: .system(size: 16, weight: .regular),
                exampleAnimation: .default,
                padding: EdgeInsets(top: 14, leading: 14, bottom: 14, trailing: 14),
                cornerRadius: 20,
                sparkleSize: 18,
                inputHeight: 52,
                inputCornerRadius: 14,
                sendButtonSize: 36,
                backgroundColor: Color(light: "#FBF9FF", dark: "#1F1A2E"),
                glowColor: Color(light: "#9B6BF5", dark: "#9B6BF5"),
                glowOpacity: 0.16,
                borderColor: Color(light: "#EBE6F5", dark: "#3B3159"),
                titleColor: Color(light: "#1B1B1F", dark: "#FAFAFA"),
                descriptionColor: Color(light: "#1B1B1F", dark: "#CBD5E1"),
                dismissButtonColor: Color(light: "#3A3A42", dark: "#FAFAFA"),
                sparkleConfiguration: .default,
                inputBackgroundColor: AppColor.background,
                inputBorderColor: Color(light: "#DCDBE0", dark: "#414346"),
                exampleColor: Color(light: "#2B2B33", dark: "#FAFAFA"),
                cursorColor: AppColor.smartSortAccent,
                sendButtonBackgroundColor: AppColor.smartSortAccent,
                sendButtonIconColor: AppColor.color2
            )
        }

        public init(
            titleText: String,
            descriptionText: String,
            examples: [String],
            examplePrefix: String,
            quotesExample: Bool,
            titleFont: Font,
            descriptionFont: Font,
            exampleFont: Font,
            exampleAnimation: SmartSortExampleAnimation,
            padding: EdgeInsets,
            cornerRadius: CGFloat,
            sparkleSize: CGFloat,
            inputHeight: CGFloat,
            inputCornerRadius: CGFloat,
            sendButtonSize: CGFloat,
            backgroundColor: Color,
            glowColor: Color,
            glowOpacity: Double,
            borderColor: Color,
            titleColor: Color,
            descriptionColor: Color,
            dismissButtonColor: Color,
            sparkleConfiguration: SmartSortSparkle.Configuration,
            inputBackgroundColor: Color,
            inputBorderColor: Color,
            exampleColor: Color,
            cursorColor: Color,
            sendButtonBackgroundColor: Color,
            sendButtonIconColor: Color
        ) {
            self.titleText = titleText
            self.descriptionText = descriptionText
            self.examples = examples
            self.examplePrefix = examplePrefix
            self.quotesExample = quotesExample
            self.titleFont = titleFont
            self.descriptionFont = descriptionFont
            self.exampleFont = exampleFont
            self.exampleAnimation = exampleAnimation
            self.padding = padding
            self.cornerRadius = cornerRadius
            self.sparkleSize = sparkleSize
            self.inputHeight = inputHeight
            self.inputCornerRadius = inputCornerRadius
            self.sendButtonSize = sendButtonSize
            self.backgroundColor = backgroundColor
            self.glowColor = glowColor
            self.glowOpacity = glowOpacity
            self.borderColor = borderColor
            self.titleColor = titleColor
            self.descriptionColor = descriptionColor
            self.dismissButtonColor = dismissButtonColor
            self.sparkleConfiguration = sparkleConfiguration
            self.inputBackgroundColor = inputBackgroundColor
            self.inputBorderColor = inputBorderColor
            self.exampleColor = exampleColor
            self.cursorColor = cursorColor
            self.sendButtonBackgroundColor = sendButtonBackgroundColor
            self.sendButtonIconColor = sendButtonIconColor
        }
    }

    // MARK: - State

    @Environment(\.layoutDirection) private var layoutDirection
    @State private var isOnScreen = false
    @State private var exampleIndex = 0

    // MARK: - Properties

    private let configuration: Configuration
    private let onTap: (String) -> Void
    private let onDismiss: (() -> Void)?

    // MARK: - Initialization

    /// - Parameters:
    ///   - configuration: Text, timing, layout and colors (defaults to `.default`).
    ///   - queryType: Picks the flight or hotel description and examples.
    ///   - onTap: Called with the example on screen when the card is tapped.
    ///   - onDismiss: Called by the ✕. nil hides the ✕.
    public init(
        configuration: Configuration = .default,
        queryType: QueryType,
        onTap: @escaping (String) -> Void,
        onDismiss: (() -> Void)? = nil
    ) {
        var resolved = configuration
        let isHotel = queryType == .hotel
        if resolved.descriptionText.isEmpty {
            resolved.descriptionText = (isHotel ? "smart_sort_prompt_result_description_hotel" : "smart_sort_prompt_result_description_flight").localized()
        }
        if resolved.examples.isEmpty {
            let prefix = isHotel ? "smart_sort_prompt_example_hotel_" : "smart_sort_prompt_example_flight_"
            resolved.examples = (1...5).map { (prefix + "\($0)").localized() }
        }
        self.configuration = resolved
        self.onTap = onTap
        self.onDismiss = onDismiss
    }

    // MARK: - Body

    public var body: some View {
        // The ✕ sits over the card rather than inside it, so the two taps never compete.
        Button {
            onTap(currentExample)
        } label: {
            card()
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(configuration.titleText))
        .accessibilityHint(Text("smart_sort_prompt_open_accessibility".localized()))
        .overlay(alignment: .topTrailing) {
            if let onDismiss {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(configuration.dismissButtonColor)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.top, configuration.padding.top - 12)
                .padding(.trailing, configuration.padding.trailing - 12)
                .accessibilityLabel(Text("smart_sort_prompt_dismiss_accessibility".localized()))
            }
        }
        .onAppear { isOnScreen = true }
        .onDisappear { isOnScreen = false }
    }

    @ViewBuilder
    private func card() -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                SmartSortSparkle(size: configuration.sparkleSize, configuration: configuration.sparkleConfiguration)
                Text(configuration.titleText)
                    .font(configuration.titleFont)
                    .foregroundStyle(configuration.titleColor)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: onDismiss == nil ? 0 : 36) // room for the ✕
            }
            Text(configuration.descriptionText)
                .font(configuration.descriptionFont)
                .foregroundStyle(configuration.descriptionColor)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            input()
                .padding(.top, 2)
        }
        .padding(configuration.padding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
        .overlay(RoundedRectangle(cornerRadius: configuration.cornerRadius).stroke(configuration.borderColor, lineWidth: 1))
        .contentShape(RoundedRectangle(cornerRadius: configuration.cornerRadius))
    }

    /// The fill, with a soft 220×180 elliptical spotlight centered 50pt in from the trailing edge
    /// and 10pt below the top, as in the design: `glowOpacity` at its center, 0 at its edge.
    private var cardBackground: some View {
        let shape = RoundedRectangle(cornerRadius: configuration.cornerRadius)
        return shape
            .fill(smartSortFill(configuration.backgroundColor, gradient: configuration.backgroundGradient))
            .overlay(alignment: .topTrailing) {
                Circle()
                    .fill(RadialGradient(
                        colors: [configuration.glowColor.opacity(configuration.glowOpacity), configuration.glowColor.opacity(0)],
                        center: .center, startRadius: 0, endRadius: 90
                    ))
                    .frame(width: 180, height: 180)
                    .scaleEffect(x: 220.0 / 180.0, y: 1)
                    // From the top trailing corner, move the center from (90, 90) in to (50, 10) in.
                    // offset(x:) is not mirrored in Arabic, so flip it by hand.
                    .offset(x: layoutDirection == .rightToLeft ? -40 : 40, y: -80)
                    .allowsHitTesting(false)
            }
            .clipShape(shape)
    }

    @ViewBuilder
    private func input() -> some View {
        HStack(spacing: 10) {
            SmartSortExampleTicker(
                examples: configuration.examples,
                prefix: configuration.examplePrefix,
                animation: configuration.exampleAnimation,
                isRunning: isOnScreen,
                index: $exampleIndex,
                cursorColor: configuration.quotesExample ? configuration.cursorColor : nil,
                lineLimit: 2
            )
            .font(configuration.exampleFont)
            .foregroundStyle(configuration.exampleColor)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityHidden(true)
            Image(systemName: "arrow.up")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(configuration.sendButtonIconColor)
                .frame(width: configuration.sendButtonSize, height: configuration.sendButtonSize)
                .background(Circle().fill(configuration.sendButtonBackgroundColor))
                .shadow(color: configuration.sendButtonBackgroundColor.opacity(0.3), radius: 6, y: 4)
                .accessibilityHidden(true)
        }
        .padding(.leading, 16)
        .padding(.trailing, 8)
        .padding(.vertical, 8)
        .frame(minHeight: configuration.inputHeight) // grows to fit a two-line example
        .background(RoundedRectangle(cornerRadius: configuration.inputCornerRadius).fill(configuration.inputBackgroundColor))
        .overlay(RoundedRectangle(cornerRadius: configuration.inputCornerRadius).stroke(configuration.inputBorderColor, lineWidth: 1.5))
    }

    // MARK: - Examples

    private var currentExample: String {
        guard !configuration.examples.isEmpty else { return "" }
        return configuration.examples[exampleIndex % configuration.examples.count]
    }
}
