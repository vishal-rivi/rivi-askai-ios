import SwiftUI

/// The Smart Sort sparkle, as in the design: a four-point star with a small "+" at its top
/// trailing corner.
///
/// `style: .rivi` draws the Rivi design instead: a gradient four-point star with a "+" top
/// trailing and a smaller "+" bottom leading, each pulsing on its own loop.
///
/// While animating, on a 4.5s loop the star gives a small wiggle (up to 1.07× and 10°) and the
/// "+" twinkles (0.35 → 1 opacity). With `showsBurst` (the Smart Sort pill), four tiny stars also
/// pop out around it, one after another, every `twinkleInterval` after `initialDelay`; changing
/// `twinkleTrigger` plays one more burst. With Reduce Motion on, or `isAnimating` false, the
/// sparkle is static.
public struct SmartSortSparkle: View {
    // MARK: - Configuration

    public struct Configuration {
        /// Which design to draw.
        public enum Style {
            /// The star with a "+" that twinkles while the star wiggles (the default).
            case classic
            /// The Rivi design: a gradient star and two "+" marks, each pulsing on its own loop.
            case rivi
        }

        /// The star and "+" color.
        public var primaryColor: Color
        /// The burst's four particle colors, in order.
        public var burstColors: [Color]
        /// Plays the burst of tiny stars (used on the Smart Sort pill).
        public var showsBurst: Bool
        /// Seconds per star wiggle and "+" twinkle.
        public var loopDuration: TimeInterval
        /// Seconds between bursts. nil plays a burst only when `twinkleTrigger` changes.
        public var twinkleInterval: TimeInterval?
        /// Seconds before the first burst.
        public var initialDelay: TimeInterval
        /// Which design to draw. `.classic` by default.
        public var style: Style = .classic
        /// `.rivi`: the star's gradient, top leading to bottom trailing. nil fills it with
        /// `primaryColor`.
        public var starGradient: [Color]? = nil
        /// `.rivi`: the top trailing "+". nil uses `primaryColor`.
        public var plusColor: Color? = nil
        /// `.rivi`: the small bottom leading "+". nil uses `primaryColor`.
        public var secondaryPlusColor: Color? = nil

        /// The design's sparkle: purple, no burst.
        public static var `default`: Configuration {
            Configuration(
                primaryColor: AppColor.smartSortAccent,
                burstColors: [Color(light: "#B48CFF", dark: "#C9A8FF"), AppColor.smartSortAccent,
                              Color(light: "#C9A8FF", dark: "#DCC8FF"), Color(light: "#B48CFF", dark: "#C9A8FF")],
                showsBurst: false,
                loopDuration: 4.5,
                twinkleInterval: 6,
                initialDelay: 0.9
            )
        }

        /// The Rivi design: a blue gradient star (#4B9CF0 → #1D6FD1), a "+" in #2F86E0 and a small
        /// "+" in #5AA3EF.
        public static var rivi: Configuration {
            var configuration = Configuration.default
            configuration.style = .rivi
            configuration.primaryColor = Color(hex: "#2F86E0")
            configuration.starGradient = [Color(hex: "#4B9CF0"), Color(hex: "#1D6FD1")]
            configuration.plusColor = Color(hex: "#2F86E0")
            configuration.secondaryPlusColor = Color(hex: "#5AA3EF")
            configuration.burstColors = [Color(hex: "#9CC6EE"), Color(hex: "#4B9CF0"), Color(hex: "#5AA3EF"), Color(hex: "#9CC6EE")]
            return configuration
        }

        /// The design's sparkle with the burst, as on the Smart Sort pill.
        public static var withBurst: Configuration {
            var configuration = Configuration.default
            configuration.showsBurst = true
            return configuration
        }

        /// A static sparkle in one color, for use inside buttons.
        public static func plain(_ color: Color) -> Configuration {
            var configuration = Configuration.default
            configuration.primaryColor = color
            configuration.burstColors = Array(repeating: color, count: 4)
            configuration.twinkleInterval = nil
            configuration.starGradient = nil
            configuration.plusColor = nil
            configuration.secondaryPlusColor = nil
            return configuration
        }

        public init(
            primaryColor: Color,
            burstColors: [Color],
            showsBurst: Bool,
            loopDuration: TimeInterval,
            twinkleInterval: TimeInterval?,
            initialDelay: TimeInterval
        ) {
            self.primaryColor = primaryColor
            self.burstColors = burstColors
            self.showsBurst = showsBurst
            self.loopDuration = loopDuration
            self.twinkleInterval = twinkleInterval
            self.initialDelay = initialDelay
        }
    }

    /// The sparkle as a static template image, for places that take an `Image`, such as
    /// `RiviChipsView.Configuration.icon`. Tint it with `.foregroundStyle`.
    public static var image: Image {
        Image("ic_smart_sort_sparkle", bundle: .module)
    }

    // MARK: - Properties

    private let size: CGFloat
    private let configuration: Configuration
    private let isAnimating: Bool
    private let isBreathing: Bool
    private let twinkleTrigger: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// When the repeating bursts started (set on appear).
    @State private var burstsStart: Date?
    /// When the last triggered burst started.
    @State private var triggeredBurst: Date?

    // MARK: - Initialization

    /// - Parameters:
    ///   - size: Width and height of the sparkle.
    ///   - configuration: Colors and timing (defaults to `.default`).
    ///   - isAnimating: false shows a static sparkle.
    ///   - isBreathing: false pauses the star's wiggle and the "+"'s twinkle (e.g. while typing).
    ///   - twinkleTrigger: Change it to play one burst now (with `showsBurst`).
    public init(
        size: CGFloat = 20,
        configuration: Configuration = .default,
        isAnimating: Bool = true,
        isBreathing: Bool = true,
        twinkleTrigger: Int = 0
    ) {
        self.size = size
        self.configuration = configuration
        self.isAnimating = isAnimating
        self.isBreathing = isBreathing
        self.twinkleTrigger = twinkleTrigger
    }

    // MARK: - Body

    public var body: some View {
        let animates = isAnimating && !reduceMotion
        let bursts = configuration.showsBurst && (configuration.twinkleInterval != nil || triggeredBurst != nil)
        TimelineView(.animation(minimumInterval: nil, paused: !animates || (!isBreathing && !bursts))) { timeline in
            frame(at: animates ? timeline.date : nil)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
        .onAppear { burstsStart = Date() }
        .onChange(of: twinkleTrigger) { _ in
            if animates { triggeredBurst = Date() }
        }
    }

    // MARK: - Drawing

    @ViewBuilder
    private func frame(at date: Date?) -> some View {
        if configuration.style == .rivi {
            riviFrame(at: isBreathing ? date : nil, burstDate: date)
        } else {
            classicFrame(at: date)
        }
    }

    /// The Rivi design, on its 24pt grid. Each part pulses on its own loop (`rv-tw-a/b/c`).
    @ViewBuilder
    private func riviFrame(at date: Date?, burstDate: Date?) -> some View {
        let unit = size / 24
        let star = date.map { Self.riviPulse($0, duration: 3.2, delay: 0, low: 0.5, from: (1, 1), to: (0.82, 0.7)) } ?? (1, 1)
        let plus = date.map { Self.riviPulse($0, duration: 2.4, delay: 0.6, low: 0.45, from: (1, 1), to: (0.45, 0.25)) } ?? (1, 1)
        let small = date.map { Self.riviPulse($0, duration: 2.8, delay: 1.3, low: 0.5, from: (0.55, 0.35), to: (1.1, 1)) } ?? (1, 1)
        let starStyle: AnyShapeStyle = configuration.starGradient.map {
            AnyShapeStyle(LinearGradient(colors: $0, startPoint: .topLeading, endPoint: .bottomTrailing))
        } ?? AnyShapeStyle(configuration.primaryColor)
        ZStack(alignment: .topLeading) {
            RiviSparkleStar()
                .fill(starStyle)
                .overlay(RiviSparkleStar().stroke(starStyle, style: StrokeStyle(lineWidth: unit, lineJoin: .round)))
                .scaleEffect(star.scale)
                .opacity(star.opacity)
            RiviSparklePlus(center: CGPoint(x: 20, y: 4), arm: 2)
                .stroke(configuration.plusColor ?? configuration.primaryColor, style: StrokeStyle(lineWidth: 2 * unit, lineCap: .round))
                .scaleEffect(plus.scale, anchor: UnitPoint(x: 20.0 / 24, y: 4.0 / 24))
                .opacity(plus.opacity)
            RiviSparklePlus(center: CGPoint(x: 4, y: 19.5), arm: 1.5)
                .stroke(configuration.secondaryPlusColor ?? configuration.primaryColor, style: StrokeStyle(lineWidth: 1.8 * unit, lineCap: .round))
                .scaleEffect(small.scale, anchor: UnitPoint(x: 4.0 / 24, y: 19.5 / 24))
                .opacity(small.opacity)
            if configuration.showsBurst, let burstDate {
                ForEach(Self.particles.indices, id: \.self) { index in
                    particle(index, at: burstDate)
                }
            }
        }
        .frame(width: size, height: size, alignment: .topLeading)
    }

    /// A CSS keyframe loop with `ease-in-out` between stops: `from` at 0% and 100%, `to` at `low`.
    /// Before `delay` it rests at `from`, as an animation with a delay does.
    private static func riviPulse(_ date: Date, duration: TimeInterval, delay: TimeInterval, low: Double,
                                  from: (CGFloat, Double), to: (CGFloat, Double)) -> (scale: CGFloat, opacity: Double) {
        let t = date.timeIntervalSinceReferenceDate - delay
        let phase = (t.truncatingRemainder(dividingBy: duration) + duration).truncatingRemainder(dividingBy: duration) / duration
        let k = phase < low
            ? SmartSortEasing.easeInOut(phase / low)
            : 1 - SmartSortEasing.easeInOut((phase - low) / (1 - low))
        return (from.0 + (to.0 - from.0) * CGFloat(k), from.1 + (to.1 - from.1) * k)
    }

    @ViewBuilder
    private func classicFrame(at date: Date?) -> some View {
        let loop: Double? = isBreathing ? date.map { Self.loopPhase($0, duration: configuration.loopDuration) } : nil
        let star = loop.map(Self.star) ?? (scale: 1, rotation: 0)
        let plus = loop.map(Self.plus) ?? (scale: 1, opacity: 1)

        ZStack(alignment: .topLeading) {
            Image("ic_smart_sort_star", bundle: .module)
                .resizable()
                .renderingMode(.template)
                .foregroundStyle(configuration.primaryColor)
                .scaleEffect(star.scale)
                .rotationEffect(.degrees(star.rotation))
            Image("ic_smart_sort_star_plus", bundle: .module)
                .resizable()
                .renderingMode(.template)
                .foregroundStyle(configuration.primaryColor)
                .scaleEffect(plus.scale, anchor: UnitPoint(x: 20.0 / 24, y: 5.0 / 24)) // around the "+"
                .opacity(plus.opacity)
            if configuration.showsBurst, let date {
                ForEach(Self.particles.indices, id: \.self) { index in
                    particle(index, at: date)
                }
            }
        }
        .frame(width: size, height: size, alignment: .topLeading)
    }

    /// One tiny star of the burst. Positions are the design's, on an 18pt icon.
    @ViewBuilder
    private func particle(_ index: Int, at date: Date) -> some View {
        let spec = Self.particles[index]
        if let elapsed = burstElapsed(for: spec, at: date) {
            let unit = size / 18
            let state = Self.particleState(elapsed)
            BurstStar()
                .fill(configuration.burstColors[index % max(configuration.burstColors.count, 1)])
                .frame(width: spec.size * unit, height: spec.size * unit)
                .scaleEffect(state.scale)
                .rotationEffect(.degrees(state.rotation))
                .opacity(state.opacity)
                .offset(x: spec.x * unit, y: spec.y * unit)
        }
    }

    // MARK: - Timing

    /// 0...1 through the current loop. All sparkles share the clock, so they move together.
    private static func loopPhase(_ date: Date, duration: TimeInterval) -> Double {
        date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: duration) / duration
    }

    /// `alm-star`: still until 70%, up to 1.07× and 10° at 82%, back by 100%.
    private static func star(_ phase: Double) -> (scale: CGFloat, rotation: Double) {
        let k: Double
        if phase < 0.7 { k = 0 }
        else if phase < 0.82 { k = SmartSortEasing.easeInOut((phase - 0.7) / 0.12) }
        else { k = 1 - SmartSortEasing.easeInOut((phase - 0.82) / 0.18) }
        return (CGFloat(1 + 0.07 * k), 10 * k)
    }

    /// `alm-twinkle`: dim (0.35, 0.85×) until 55%, bright (1, 1×) at 72%, dim again by 100%.
    private static func plus(_ phase: Double) -> (scale: CGFloat, opacity: Double) {
        let k: Double
        if phase < 0.55 { k = 0 }
        else if phase < 0.72 { k = SmartSortEasing.easeInOut((phase - 0.55) / 0.17) }
        else { k = 1 - SmartSortEasing.easeInOut((phase - 0.72) / 0.28) }
        return (CGFloat(0.85 + 0.15 * k), 0.35 + 0.65 * k)
    }

    private struct Particle {
        /// Top leading corner and size, in points on an 18pt icon.
        let x: CGFloat, y: CGFloat, size: CGFloat
        /// Seconds after the burst starts.
        let delay: TimeInterval
    }

    private static let particles: [Particle] = [
        Particle(x: -7, y: -6, size: 7, delay: 0.9),
        Particle(x: 16, y: -9, size: 9, delay: 1.05),
        Particle(x: -5, y: 15, size: 6, delay: 1.2),
        Particle(x: 20, y: 14, size: 5, delay: 1.35),
    ]

    /// `alm-spark` lasts 6s per cycle; only its first 16% shows.
    private static let sparkCycle: TimeInterval = 6
    private static let sparkVisible: TimeInterval = sparkCycle * 0.16

    /// Seconds into this particle's visible flash, or nil when it isn't showing. Repeating bursts
    /// follow the design's staggered 6s cycle; a triggered burst plays once, starting now.
    private func burstElapsed(for spec: Particle, at date: Date) -> TimeInterval? {
        if let triggeredBurst {
            let elapsed = date.timeIntervalSince(triggeredBurst) - (spec.delay - Self.particles[0].delay)
            if elapsed >= 0 && elapsed < Self.sparkVisible { return elapsed }
        }
        guard let interval = configuration.twinkleInterval, let burstsStart else { return nil }
        let local = date.timeIntervalSince(burstsStart) - (configuration.initialDelay - Self.particles[0].delay) - spec.delay
        guard local >= 0 else { return nil }
        let inCycle = local.truncatingRemainder(dividingBy: interval)
        return inCycle < Self.sparkVisible ? inCycle : nil
    }

    /// `alm-spark`: 0% hidden; 6% full size, 45°; 16% faded out at 0.2×, 90°. Eased out.
    private static func particleState(_ elapsed: TimeInterval) -> (scale: CGFloat, rotation: Double, opacity: Double) {
        let progress = elapsed / sparkCycle
        if progress < 0.06 {
            let t = SmartSortEasing.easeOut(progress / 0.06)
            return (CGFloat(t), 45 * t, t)
        }
        let t = SmartSortEasing.easeOut(min((progress - 0.06) / 0.10, 1))
        return (CGFloat(1 - 0.8 * t), 45 + 45 * t, 1 - t)
    }
}

// MARK: - Shapes and easing

/// The burst's filled four-point star: `M5 0 C5.4 3.6 6.4 4.6 10 5 …` on a 10×10 box.
struct BurstStar: Shape {
    func path(in rect: CGRect) -> Path {
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + rect.width * x / 10, y: rect.minY + rect.height * y / 10)
        }
        var path = Path()
        path.move(to: p(5, 0))
        path.addCurve(to: p(10, 5), control1: p(5.4, 3.6), control2: p(6.4, 4.6))
        path.addCurve(to: p(5, 10), control1: p(6.4, 5.4), control2: p(5.4, 6.4))
        path.addCurve(to: p(0, 5), control1: p(4.6, 6.4), control2: p(3.6, 5.4))
        path.addCurve(to: p(5, 0), control1: p(3.6, 4.6), control2: p(4.6, 3.6))
        path.closeSubpath()
        return path
    }
}

/// The CSS timing curves used by the Smart Sort design.
/// The Rivi sparkle's four-point star (Lucide "sparkles"), on a 24×24 grid: straight sides, tips
/// rounded with r 0.5 and inner corners with r 2.
struct RiviSparkleStar: Shape {
    func path(in rect: CGRect) -> Path {
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + rect.width * x / 24, y: rect.minY + rect.height * y / 24)
        }
        var path = Path()
        path.move(to: p(9.937, 15.5))
        path.addQuadCurve(to: p(8.5, 14.063), control: p(9.643, 14.358))
        path.addLine(to: p(2.365, 12.481))
        path.addCurve(to: p(2.365, 11.519), control1: p(1.7, 12.481), control2: p(1.7, 11.519))
        path.addLine(to: p(8.5, 9.936))
        path.addQuadCurve(to: p(9.937, 8.5), control: p(9.643, 9.642))
        path.addLine(to: p(11.519, 2.365))
        path.addCurve(to: p(12.482, 2.365), control1: p(11.519, 1.7), control2: p(12.482, 1.7))
        path.addLine(to: p(14.063, 8.5))
        path.addQuadCurve(to: p(15.5, 9.937), control: p(14.358, 9.643))
        path.addLine(to: p(21.635, 11.518))
        path.addCurve(to: p(21.635, 12.482), control1: p(22.3, 11.518), control2: p(22.3, 12.482))
        path.addLine(to: p(15.5, 14.063))
        path.addQuadCurve(to: p(14.063, 15.5), control: p(14.358, 14.358))
        path.addLine(to: p(12.482, 21.635))
        path.addCurve(to: p(11.519, 21.635), control1: p(12.482, 22.3), control2: p(11.519, 22.3))
        path.closeSubpath()
        return path
    }
}

/// A "+" on the 24×24 grid: arms of `arm` around `center` (stroke it).
struct RiviSparklePlus: Shape {
    let center: CGPoint
    let arm: CGFloat

    func path(in rect: CGRect) -> Path {
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + rect.width * x / 24, y: rect.minY + rect.height * y / 24)
        }
        var path = Path()
        path.move(to: p(center.x, center.y - arm))
        path.addLine(to: p(center.x, center.y + arm))
        path.move(to: p(center.x - arm, center.y))
        path.addLine(to: p(center.x + arm, center.y))
        return path
    }
}

enum SmartSortEasing {
    /// `ease-in-out`.
    static func easeInOut(_ x: Double) -> Double { cubicBezier(0.42, 0, 0.58, 1, x) }
    /// `ease-out`.
    static func easeOut(_ x: Double) -> Double { cubicBezier(0, 0, 0.58, 1, x) }
    /// `cubic-bezier(.45,0,.55,1)`: the text shimmer.
    static func shimmer(_ x: Double) -> Double { cubicBezier(0.45, 0, 0.55, 1, x) }
    /// `cubic-bezier(.33,1,.68,1)`: the sparkle pop.
    static func pop(_ x: Double) -> Double { cubicBezier(0.33, 1, 0.68, 1, x) }

    /// The y of a CSS cubic-bezier at x, solved by bisection.
    static func cubicBezier(_ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double, _ x: Double) -> Double {
        let x = min(max(x, 0), 1)
        func bezier(_ a: Double, _ b: Double, _ t: Double) -> Double {
            let u = 1 - t
            return 3 * u * u * t * a + 3 * u * t * t * b + t * t * t
        }
        var low = 0.0, high = 1.0, t = x
        for _ in 0..<20 {
            t = (low + high) / 2
            if bezier(x1, x2, t) < x { low = t } else { high = t }
        }
        return bezier(y1, y2, t)
    }
}
