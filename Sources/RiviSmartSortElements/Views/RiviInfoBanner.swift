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
        
        /// Background color for the banner. Ignored when `backgroundGradient` is set.
        public var backgroundColor: Color
        /// Optional gradient background for the banner. Takes priority over `backgroundColor` when set.
        public var backgroundGradient: LinearGradient?
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

        /// When set, the loading state renders this text (with a subtle pulse) instead of the
        /// shimmering skeleton bars — e.g. "Generating explanation…" while streamed content is
        /// still in flight. `nil` (the default) keeps the shimmer skeleton.
        public var loadingText: String?

        /// Whether `descriptionText` types itself out character by character once loading ends
        /// (with `SmartSortStreamingText`).
        /// `true` (the default) suits streamed AI content; set `false` for a static, one-shot
        /// notice (e.g. "Filter Selection Removed") that should just appear immediately.
        public var animatesText: Bool

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
                backgroundColor: Color(light: "#DFEEFD", dark: "#232527"),
                backgroundGradient: LinearGradient(
                    colors: [Color(light: "#DFEEFD", dark: "#232527"), Color(light: "#F0EAFE", dark: "#323335")],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                borderColor: .clear,
                titleColor: AppColor.color5,
                descriptionColor: AppColor.color5,
                iconColor: Color(light: "#7B3AEC", dark: "#7B3AEC"),
                skeletonBaseColor: Color(light: "#C5DCFA", dark: "#414346"),
                skeletonHighlightColor: Color(light: "#FFFFFFCC", dark: "#FFFFFF33"),
                skeletonAnimationDuration: 1.3,
                skeletonCornerRadius: 4,
                skeletonTitleHeight: 10,
                skeletonTitleWidth: 110,
                skeletonDescriptionHeight: 9,
                loadingText: nil,
                animatesText: true
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
            backgroundGradient: LinearGradient? = nil,
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
            skeletonDescriptionHeight: CGFloat,
            loadingText: String? = nil,
            animatesText: Bool = true
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
            self.backgroundGradient = backgroundGradient
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
            self.loadingText = loadingText
            self.animatesText = animatesText
        }
    }
    
    // MARK: - Properties

    /// The configuration for this banner
    private let configuration: Configuration

    /// When true, the banner shows shimmering skeleton placeholders instead of the real content.
    private let isLoading: Bool

    /// Mirrors `isLoading`, except the loading → content switch is held for at least
    /// `minimumLoadingDuration` after loading started. Without this, a response that arrives
    /// in a single SSE chunk flips `isLoading` false almost immediately, so the user never
    /// actually sees the "Generating…" state before content replaces it.
    @State private var effectiveIsLoading: Bool
    @State private var loadingStartedAt: Date = Date()
    @State private var minimumLoadingTask: Task<Void, Never>? = nil
    private static let minimumLoadingDuration: TimeInterval = 2.5

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
        // Banners with a textual loading indicator (`loadingText != nil`) always start in the
        // loading state, even if `isLoading` is already false the moment this view first
        // mounts — e.g. because it's gated behind another condition (like the results list
        // finishing) and the AI content happened to arrive before that gate opened. Other
        // banners (shimmer skeleton) keep their original behavior of mirroring `isLoading`.
        self._effectiveIsLoading = State(initialValue: configuration.loadingText != nil ? true : isLoading)
    }

    // MARK: - Body

    public var body: some View {
        // The textual loading indicator is a single line, so it reads best centered against
        // the icon; the multi-line title+description layout (and the shimmer skeleton bars)
        // keep top alignment.
        let rowAlignment: VerticalAlignment = (effectiveIsLoading && configuration.loadingText != nil) ? .center : .top
        HStack(alignment: rowAlignment, spacing: configuration.iconSpacing) {
            if configuration.showIcon {
                iconView
            }

            VStack(alignment: .leading, spacing: configuration.textSpacing) {
                if effectiveIsLoading {
                    skeletonRows
                } else {
                    textRows
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(configuration.padding)
        .background {
            if let gradient = configuration.backgroundGradient {
                RoundedRectangle(cornerRadius: configuration.cornerRadius)
                    .fill(gradient)
            } else {
                RoundedRectangle(cornerRadius: configuration.cornerRadius)
                    .fill(configuration.backgroundColor)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: configuration.cornerRadius))
        .environment(\.layoutDirection, RiviSmartSortConfiguration.shared.language.layoutDirection)
        .onChange(of: isLoading) { newValue in
            if newValue {
                minimumLoadingTask?.cancel()
                loadingStartedAt = Date()
                // The text leaves the hierarchy while loading, so the next generation types out
                // from the start.
                effectiveIsLoading = true
            } else {
                scheduleReveal()
            }
        }
        .onAppear {
            if configuration.loadingText != nil {
                loadingStartedAt = Date()
                if !isLoading {
                    // Content was already ready by the time this banner first appeared (e.g. it
                    // was gated behind another loading condition) — still hold the loading text
                    // on screen for the minimum duration before revealing it.
                    scheduleReveal()
                }
            } else if isLoading {
                loadingStartedAt = Date()
            }
        }
        .onDisappear {
            minimumLoadingTask?.cancel()
        }
    }

    /// Reveals the real content once at least `minimumLoadingDuration` has elapsed since
    /// `loadingStartedAt`, so "Generating…" is always visible for a beat even when the content
    /// was already available (near-instant response, or arrived while this banner was still
    /// hidden behind another loading gate).
    private func scheduleReveal() {
        minimumLoadingTask?.cancel()
        let remaining = Self.minimumLoadingDuration - Date().timeIntervalSince(loadingStartedAt)
        guard remaining > 0 else {
            effectiveIsLoading = false
            return
        }
        minimumLoadingTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await MainActor.run { effectiveIsLoading = false }
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var iconView: some View {
        if configuration.iconName == "ic_sparkle" {
            AnimatedAISparkleIcon()
                .frame(width: max(configuration.iconSize, 22), height: max(configuration.iconSize, 22))
        } else {
            Image(configuration.iconName, bundle: .module)
                .resizable()
                .renderingMode(.template)
                .aspectRatio(contentMode: .fit)
                .frame(width: configuration.iconSize, height: configuration.iconSize)
                .foregroundStyle(configuration.iconColor)
                .padding(.top, 2)
        }
    }

    @ViewBuilder
    private var textRows: some View {
        if !configuration.titleText.isEmpty {
            Text(configuration.titleText)
                .font(configuration.titleFont)
                .foregroundStyle(configuration.titleColor)
        }
        // Streamed AI text grows in place; a new generation appears at once (see SmartSortStreamingText).
        SmartSortStreamingText(
            configuration.descriptionText,
            unit: .character,
            interval: 0.02,
            isAnimated: configuration.animatesText
        )
        .font(configuration.descriptionFont)
        .foregroundStyle(configuration.descriptionColor)
    }

    @ViewBuilder
    private var skeletonRows: some View {
        if let loadingText = configuration.loadingText {
            PulsingLoadingText(
                text: loadingText,
                font: configuration.descriptionFont,
                color: configuration.descriptionColor
            )
        } else {
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
}

/// A single 4-point "twinkle" sparkle — a diamond with concave sides pulled toward its center,
/// matching the AI-sparkle mark used across the design (three of these, at different sizes and
/// positions, make up `AnimatedAISparkleIcon`).
private struct Sparkle4PointShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        let cx = rect.midX
        let cy = rect.midY
        let top = CGPoint(x: cx, y: rect.minY)
        let right = CGPoint(x: rect.maxX, y: cy)
        let bottom = CGPoint(x: cx, y: rect.maxY)
        let left = CGPoint(x: rect.minX, y: cy)

        var path = Path()
        path.move(to: top)
        path.addQuadCurve(to: right, control: CGPoint(x: cx + w * 0.14, y: cy - h * 0.14))
        path.addQuadCurve(to: bottom, control: CGPoint(x: cx + w * 0.14, y: cy + h * 0.14))
        path.addQuadCurve(to: left, control: CGPoint(x: cx - w * 0.14, y: cy + h * 0.14))
        path.addQuadCurve(to: top, control: CGPoint(x: cx - w * 0.14, y: cy - h * 0.14))
        path.closeSubpath()
        return path
    }
}

/// The animated "AI sparkle" mark — a cluster of three twinkling sparkles (one large, two
/// smaller) in the app's blue-to-purple AI gradient, each independently pulsing scale/opacity
/// on a continuous loop. Used as the icon for AI-generated content banners (e.g. Explain AI).
struct AnimatedAISparkleIcon: View {
    @State private var scale1: CGFloat = 1
    @State private var scale2: CGFloat = 0.7
    @State private var scale3: CGFloat = 0.85

    private var gradient: LinearGradient {
        LinearGradient(
            colors: [Color(hex: "#349EE5"), Color(hex: "#7F91F5")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            ZStack {
                Sparkle4PointShape()
                    .fill(gradient)
                    .frame(width: s * 0.42, height: s * 0.42)
                    .scaleEffect(scale1)
                    .opacity(Double(scale1))
                    .position(x: s * 0.62, y: s * 0.645)

                Sparkle4PointShape()
                    .fill(gradient)
                    .frame(width: s * 0.26, height: s * 0.26)
                    .scaleEffect(scale2)
                    .opacity(Double(scale2))
                    .position(x: s * 0.3, y: s * 0.495)

                Sparkle4PointShape()
                    .fill(gradient)
                    .frame(width: s * 0.22, height: s * 0.22)
                    .scaleEffect(scale3)
                    .opacity(Double(scale3))
                    .position(x: s * 0.52, y: s * 0.255)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                scale1 = 0.65
            }
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true).delay(0.2)) {
                scale2 = 1.0
            }
            withAnimation(.easeInOut(duration: 1.3).repeatForever(autoreverses: true).delay(0.45)) {
                scale3 = 0.55
            }
        }
    }
}

/// A lightweight "still working" indicator shown in place of skeleton placeholder bars — the
/// banner appears first (its container/icon show immediately), then this text types itself out
/// character by character, and once fully typed it settles into a gentle opacity pulse for as
/// long as loading continues (e.g. "Generating explanation…").
private struct PulsingLoadingText: View {
    let text: String
    let font: Font
    let color: Color

    @State private var displayedText: String = ""
    @State private var opacity: Double = 1.0
    @State private var typingTask: Task<Void, Never>?

    var body: some View {
        Text(displayedText)
            .font(font)
            .foregroundStyle(color)
            .opacity(opacity)
            .onAppear { startTyping() }
            .onDisappear { typingTask?.cancel() }
    }

    private func startTyping() {
        typingTask?.cancel()
        displayedText = ""
        opacity = 1.0
        typingTask = Task {
            for char in text {
                guard !Task.isCancelled else { return }
                try? await Task.sleep(nanoseconds: 30_000_000) // 30ms per character
                guard !Task.isCancelled else { return }
                await MainActor.run { displayedText += String(char) }
            }
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                    opacity = 0.4
                }
            }
        }
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
