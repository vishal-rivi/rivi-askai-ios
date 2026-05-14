import SwiftUI
import UIKit

// MARK: - First-time coachmark (dim + cutout + banner card with pointer)

/// SwiftUI content rendered inside the coachmark window. Observes the presenter's
/// published `buttonFrame` so the dim cutout and banner pointer follow the button
/// even when its position changes (rotation, layout reflow, scrolling).
struct RiviAskAIFirstTimeCoachmark: View {
    @ObservedObject var presenter: RiviAskAICoachmarkPresenter
    let configuration: RiviAskAIFirstTimeBanner.Configuration
    let dimColor: Color
    let dimOpacity: Double
    let onCTA: () -> Void
    let onBackgroundTap: () -> Void

    private let pointerWidth: CGFloat = 18
    private let pointerHeight: CGFloat = 10
    private let cardCornerRadius: CGFloat = 16
    private let buttonCutoutCornerRadius: CGFloat = 24
    private let buttonCutoutInset: CGFloat = -6 // negative = larger cutout than button

    public var body: some View {
        GeometryReader { proxy in
            let buttonFrame = presenter.buttonFrame
            let cardWidth = min(configuration.maxWidth, proxy.size.width - 32)
            let cardX = clampedCardX(buttonMidX: buttonFrame.midX, cardWidth: cardWidth, screenWidth: proxy.size.width)
            let pointerX = buttonFrame.midX
            let pointerTopY = buttonFrame.maxY + 12
            let cardTopY = pointerTopY + pointerHeight

            ZStack(alignment: .topLeading) {
                // 1) Dim with cutout that tracks the button
                dimWithCutout(buttonFrame: buttonFrame)
                    .contentShape(Rectangle())
                    .onTapGesture { onBackgroundTap() }

                // 2) Pointer triangle aligned to button center
                Triangle()
                    .fill(configuration.backgroundColor)
                    .frame(width: pointerWidth, height: pointerHeight)
                    .offset(x: pointerX - pointerWidth / 2, y: pointerTopY)

                // 3) Banner card. Apply the configured layout direction ONLY to the card's
                //    inner content (so Arabic text + icon mirror correctly inside the card),
                //    while keeping positioning math in LTR via the outer environment override.
                bannerCard
                    .environment(\.layoutDirection, RiviAskAIConfiguration.shared.language.layoutDirection)
                    .frame(width: cardWidth, alignment: .leading)
                    .background(configuration.backgroundColor)
                    .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius))
                    .shadow(color: .black.opacity(0.25), radius: 20, x: 0, y: 10)
                    .offset(x: cardX, y: cardTopY)
            }
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.2), value: presenter.buttonFrame)
        }
        .ignoresSafeArea()
        // Force the coachmark's positioning to LTR so `.topLeading`, `.offset(x:)`, and the
        // cutout coords all evaluate against the screen's actual left/right edges. The card's
        // textual content gets its own RTL/LTR env above.
        .environment(\.layoutDirection, .leftToRight)
    }

    private func dimWithCutout(buttonFrame: CGRect) -> some View {
        dimColor.opacity(dimOpacity)
            .ignoresSafeArea()
            .mask(
                Rectangle()
                    .ignoresSafeArea()
                    .overlay(
                        RoundedRectangle(cornerRadius: buttonCutoutCornerRadius)
                            .fill(.black)
                            .frame(
                                width: max(0, buttonFrame.width - buttonCutoutInset * 2),
                                height: max(0, buttonFrame.height - buttonCutoutInset * 2)
                            )
                            .position(x: buttonFrame.midX, y: buttonFrame.midY)
                            .blendMode(.destinationOut)
                    )
                    .compositingGroup()
            )
    }

    @ViewBuilder
    private var bannerCard: some View {
        let cfg = configuration
        VStack(alignment: .leading, spacing: cfg.ctaSpacing) {
            HStack(alignment: .top, spacing: cfg.iconSpacing) {
                Image(cfg.iconName, bundle: .module)
                    .resizable()
                    .renderingMode(.template)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: cfg.iconSize, height: cfg.iconSize)
                    .foregroundStyle(cfg.iconColor)

                VStack(alignment: .leading, spacing: cfg.textSpacing) {
                    Text(cfg.titleText)
                        .font(cfg.titleFont)
                        .foregroundStyle(cfg.titleColor)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(cfg.descriptionText)
                        .font(cfg.descriptionFont)
                        .foregroundStyle(cfg.descriptionColor)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack {
                Spacer(minLength: 0)
                Button(action: onCTA) {
                    Text(cfg.ctaText)
                        .font(cfg.ctaFont)
                        .foregroundStyle(cfg.ctaTextColor)
                        .padding(cfg.ctaPadding)
                        .background(cfg.ctaBackgroundColor)
                        .clipShape(RoundedRectangle(cornerRadius: cfg.ctaCornerRadius))
                }
            }
        }
        .padding(cfg.padding)
    }

    private func clampedCardX(buttonMidX: CGFloat, cardWidth: CGFloat, screenWidth: CGFloat) -> CGFloat {
        let ideal = buttonMidX - cardWidth / 2
        return max(16, min(ideal, screenWidth - cardWidth - 16))
    }
}

// MARK: - Pointer shape

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Public modifier (works for any custom Ask AI button)

/// Preference key used by `.riviAskAIFirstTimeCoachmark()` to forward the host view's
/// global frame to the modifier. Last non-zero value wins so transient `.zero` reports
/// during teardown don't overwrite a good frame.
struct RiviAskAICustomButtonFrameKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let next = nextValue()
        if next != .zero { value = next }
    }
}

private struct RiviAskAIFirstTimeCoachmarkModifier: ViewModifier {
    let configuration: RiviAskAIFirstTimeBanner.Configuration
    let enabled: Bool
    let onCTA: () -> Void

    @State private var capturedFrame: CGRect = .zero
    @State private var hasPresented: Bool = false

    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { geo in
                    Color.clear
                        .preference(key: RiviAskAICustomButtonFrameKey.self, value: geo.frame(in: .global))
                }
            )
            .onPreferenceChange(RiviAskAICustomButtonFrameKey.self) { frame in
                capturedFrame = frame
                // Drive live cutout tracking when the coachmark is already on screen.
                RiviAskAICoachmarkPresenter.shared.updateButtonFrame(frame)
                tryPresent()
            }
            .onAppear { tryPresent() }
            .onDisappear {
                if hasPresented {
                    RiviAskAICoachmarkPresenter.shared.dismiss()
                }
            }
    }

    private func tryPresent() {
        guard enabled,
              !RiviAskAIFirstTimeBannerStorage.hasBeenShown,
              !hasPresented,
              capturedFrame != .zero
        else { return }

        hasPresented = true
        RiviAskAIFirstTimeBannerStorage.markAsShown()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            RiviAskAICoachmarkPresenter.shared.present(
                buttonFrame: capturedFrame,
                configuration: configuration,
                onCTA: onCTA
            )
        }
    }
}

public extension View {
    /// Attach the first-time Ask AI coachmark (dim + cutout over the host view + banner
    /// card with pointer) to **any** view that acts as your Ask AI trigger. Use this for
    /// custom Ask AI buttons; `RiviAskAIButton` already provides the same effect built-in.
    ///
    /// The first time the host view is laid out — gated by
    /// `RiviAskAIFirstTimeBannerStorage.hasBeenShown` — the SDK presents the coachmark
    /// over a dedicated `UIWindow`. The cutout tracks the host view's global frame, so it
    /// follows rotation / layout changes.
    /// - Parameters:
    ///   - configuration: Banner content & theme. Defaults to `.default`.
    ///   - enabled: Pass `false` to suppress the coachmark (e.g. when the button is disabled).
    ///   - onCTA: Fires when the user taps the banner's CTA button.
    func riviAskAIFirstTimeCoachmark(
        configuration: RiviAskAIFirstTimeBanner.Configuration = .default,
        enabled: Bool = true,
        onCTA: @escaping () -> Void = {}
    ) -> some View {
        modifier(RiviAskAIFirstTimeCoachmarkModifier(
            configuration: configuration,
            enabled: enabled,
            onCTA: onCTA
        ))
    }
}

// MARK: - UIWindow presenter

/// Presents the first-time coachmark on its own `UIWindow` so the dim layer can cover the
/// entire app regardless of where the button is mounted. The button's global frame is
/// published so the cutout follows the button on layout changes (rotation, scroll, etc.).
@MainActor
final class RiviAskAICoachmarkPresenter: ObservableObject {
    static let shared = RiviAskAICoachmarkPresenter()

    /// Global frame of the Ask AI button. The coachmark observes this and re-renders
    /// the dim cutout + pointer + card whenever it changes.
    @Published var buttonFrame: CGRect = .zero

    private var window: UIWindow?
    private init() {}

    var isPresenting: Bool { window != nil }

    /// Push the latest captured button frame. Safe to call before, during, or after
    /// the coachmark is on screen — it just updates the published value.
    func updateButtonFrame(_ frame: CGRect) {
        guard frame != .zero, frame != buttonFrame else { return }
        buttonFrame = frame
    }

    func present(
        buttonFrame: CGRect,
        configuration: RiviAskAIFirstTimeBanner.Configuration,
        dimColor: Color = .black,
        dimOpacity: Double = 0.6,
        onCTA: @escaping () -> Void
    ) {
        guard window == nil, buttonFrame != .zero else { return }

        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        guard let scene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first
        else { return }

        // Seed the published frame so the first render is correct.
        self.buttonFrame = buttonFrame

        let window = UIWindow(windowScene: scene)
        window.windowLevel = .alert + 1
        window.backgroundColor = .clear

        let dismiss: () -> Void = { [weak self] in self?.dismiss() }

        let coachmark = RiviAskAIFirstTimeCoachmark(
            presenter: self,
            configuration: configuration,
            dimColor: dimColor,
            dimOpacity: dimOpacity,
            onCTA: {
                dismiss()
                onCTA()
            },
            onBackgroundTap: dismiss
        )

        let host = UIHostingController(rootView: coachmark)
        host.view.backgroundColor = .clear
        host.view.isOpaque = false
        window.rootViewController = host
        window.isHidden = false
        window.makeKeyAndVisible()
        self.window = window
    }

    func dismiss() {
        window?.isHidden = true
        window?.rootViewController = nil
        window = nil
    }
}
