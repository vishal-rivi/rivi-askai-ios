import SwiftUI

/// A customizable Ask AI button component
public struct RiviAskAIButton: View {
    // MARK: - Configuration

    /// Configuration options for the RiviAskAIButton
    public struct Configuration {
        /// The text to display
        public var text: String
        /// The font to use for the text
        public var font: Font
        /// Whether to show the icon
        public var showIcon: Bool
        /// The spacing between the icon and text
        public var spacing: CGFloat
        /// The corner radius of the button
        public var cornerRadius: CGFloat
        /// The padding inside the button
        public var padding: EdgeInsets
        /// The icon size
        public var iconSize: CGFloat

        // MARK: - Theme Properties

        /// Background color for the button
        public var backgroundColor: Color
        /// Text color for the button
        public var textColor: Color
        /// Icon color for the button
        public var iconColor: Color
        /// Disabled state background color
        public var disabledBackgroundColor: Color
        /// Disabled state text color
        public var disabledTextColor: Color

        // MARK: - First-time banner

        /// Whether to show the one-time onboarding banner the first time the button appears
        public var showFirstTimeBanner: Bool
        /// Configuration for the first-time onboarding banner
        public var firstTimeBanner: RiviAskAIFirstTimeBanner.Configuration

        /// Create a default configuration
        public static var `default`: Configuration {
            Configuration(
                text: "ask_ai_button_text".localized(),
                font: .system(size: 14, weight: .medium),
                showIcon: true,
                spacing: 6,
                cornerRadius: 24,
                padding: EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12),
                iconSize: 16,
                backgroundColor: Color(light: "#EFE5FE", dark: "#EFE5FE"),
                textColor: Color(light: "#7B3AEC", dark: "#7B3AEC"),
                iconColor: Color(light: "#7B3AEC", dark: "#7B3AEC"),
                disabledBackgroundColor: Color(light: "#F7F7F8", dark: "#F7F7F8"),
                disabledTextColor: Color(light: "#1A1A1E", dark: "#1A1A1E"),
                showFirstTimeBanner: true,
                firstTimeBanner: .default
            )
        }

        public init(
            text: String,
            font: Font,
            showIcon: Bool,
            spacing: CGFloat,
            cornerRadius: CGFloat,
            padding: EdgeInsets,
            iconSize: CGFloat,
            backgroundColor: Color,
            textColor: Color,
            iconColor: Color,
            disabledBackgroundColor: Color,
            disabledTextColor: Color,
            showFirstTimeBanner: Bool = true,
            firstTimeBanner: RiviAskAIFirstTimeBanner.Configuration = .default
        ) {
            self.text = text
            self.font = font
            self.showIcon = showIcon
            self.spacing = spacing
            self.cornerRadius = cornerRadius
            self.padding = padding
            self.iconSize = iconSize
            self.backgroundColor = backgroundColor
            self.textColor = textColor
            self.iconColor = iconColor
            self.disabledBackgroundColor = disabledBackgroundColor
            self.disabledTextColor = disabledTextColor
            self.showFirstTimeBanner = showFirstTimeBanner
            self.firstTimeBanner = firstTimeBanner
        }
    }

    // MARK: - Properties

    private let configuration: Configuration
    private let action: () -> Void
    @Binding private var isEnabled: Bool

    @State private var buttonFrame: CGRect = .zero
    @State private var hasPresentedCoachmark: Bool = false

    // MARK: - Initialization

    public init(
        configuration: RiviAskAIButton.Configuration = .default,
        isEnabled: Binding<Bool> = .constant(false),
        action: @escaping () -> Void
    ) {
        self.configuration = configuration
        self._isEnabled = isEnabled
        self.action = action
    }

    // MARK: - Body

    public var body: some View {
        Button(action: handleButtonTap) {
            HStack(spacing: configuration.spacing) {
                if configuration.showIcon {
                    Image("ic_sparkle", bundle: .module)
                        .resizable()
                        .renderingMode(.template)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: configuration.iconSize, height: configuration.iconSize)
                        .foregroundStyle(configuration.iconColor)
                }

                Text(configuration.text)
                    .font(configuration.font)
                    .foregroundStyle(isEnabled ? configuration.textColor : configuration.disabledTextColor)
            }
            .padding(configuration.padding)
            .background(isEnabled ? configuration.backgroundColor : configuration.disabledBackgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: configuration.cornerRadius))
        }
        .background(
            GeometryReader { geo in
                Color.clear
                    .preference(key: AskAIButtonFrameKey.self, value: geo.frame(in: .global))
            }
        )
        .onPreferenceChange(AskAIButtonFrameKey.self) { newFrame in
            buttonFrame = newFrame
            // Keep the presenter's frame in sync — when the coachmark is up, this
            // drives the dim cutout to track the button live.
            RiviAskAICoachmarkPresenter.shared.updateButtonFrame(newFrame)
            tryPresentFirstTimeCoachmark()
        }
        .onAppear { tryPresentFirstTimeCoachmark() }
        .onDisappear {
            // If the button leaves screen while the coachmark is up, dismiss it.
            if hasPresentedCoachmark {
                RiviAskAICoachmarkPresenter.shared.dismiss()
            }
        }
        .environment(\.layoutDirection, RiviAskAIConfiguration.shared.language.layoutDirection)
    }

    private func tryPresentFirstTimeCoachmark() {
        guard configuration.showFirstTimeBanner,
              !RiviAskAIFirstTimeBannerStorage.hasBeenShown,
              !hasPresentedCoachmark,
              buttonFrame != .zero
        else { return }

        hasPresentedCoachmark = true
        RiviAskAIFirstTimeBannerStorage.markAsShown()

        // Brief delay so the surrounding UI is fully laid out before the dim layer appears.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            RiviAskAICoachmarkPresenter.shared.present(
                buttonFrame: buttonFrame,
                configuration: configuration.firstTimeBanner,
                onCTA: action
            )
        }
    }

    // MARK: - Actions

    private func handleButtonTap() {
        // Tapping the button while the coachmark is up dismisses it before forwarding the tap.
        if RiviAskAICoachmarkPresenter.shared.isPresenting {
            RiviAskAICoachmarkPresenter.shared.dismiss()
        }
        action()
    }
}

// MARK: - Frame capture

private struct AskAIButtonFrameKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let next = nextValue()
        if next != .zero { value = next }
    }
}
