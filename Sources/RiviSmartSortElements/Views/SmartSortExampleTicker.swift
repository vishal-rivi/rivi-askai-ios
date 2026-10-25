import SwiftUI

/// Timing for example queries that type themselves out (the prompt card's input and the
/// V2 sheet's placeholder).
public struct SmartSortExampleAnimation {
    /// Seconds between steps while an example types out (a word, or a character with
    /// `unit: .character`).
    public var wordInterval: TimeInterval
    /// Seconds a complete example stays on screen.
    public var holdDuration: TimeInterval
    /// Seconds the example takes to fade out.
    public var fadeDuration: TimeInterval
    /// Seconds each example stays on screen, in full, with Reduce Motion on.
    public var reducedMotionDuration: TimeInterval
    /// How much each step reveals. `.word` by default.
    public var unit: SmartSortStreamingText.Unit

    /// The Smart Sort design: a word every 55ms, held 2.5s, faded in 150ms.
    public static var `default`: SmartSortExampleAnimation {
        SmartSortExampleAnimation(wordInterval: 0.055, holdDuration: 2.5, fadeDuration: 0.15, reducedMotionDuration: 3.5)
    }

    /// Streams like the explanation banner (`SmartSortStreamingText` with the banner's defaults):
    /// a character every 20ms, each step eased; held 2.5s, faded in 150ms.
    public static var streaming: SmartSortExampleAnimation {
        SmartSortExampleAnimation(wordInterval: 0.02, holdDuration: 2.5, fadeDuration: 0.15, reducedMotionDuration: 3.5, unit: .character)
    }

    public init(wordInterval: TimeInterval, holdDuration: TimeInterval, fadeDuration: TimeInterval, reducedMotionDuration: TimeInterval,
                unit: SmartSortStreamingText.Unit = .word) {
        self.wordInterval = wordInterval
        self.holdDuration = holdDuration
        self.fadeDuration = fadeDuration
        self.reducedMotionDuration = reducedMotionDuration
        self.unit = unit
    }
}

/// Examples that type out (word by word, or character by character like the explanation banner),
/// hold, fade, and move to the next, while `isRunning`.
/// Shown as `prefix` + example ("e.g. …"), or, with a `cursorColor`, in quotes with a blinking
/// cursor after the typed words ("“Leave after work|”"). `index` is the example on screen, so
/// the owner can read or seed it.
struct SmartSortExampleTicker: View {
    let examples: [String]
    let prefix: String
    let animation: SmartSortExampleAnimation
    let isRunning: Bool
    @Binding var index: Int
    /// Non-nil: show the example in quotes with a blinking cursor of this color, without `prefix`.
    var cursorColor: Color? = nil
    /// Lines the example may wrap onto.
    var lineLimit: Int = 1

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Characters of the current example on screen.
    @State private var shown = 0
    @State private var opacity: Double = 1

    var body: some View {
        content
            .task(id: isRunning) {
                guard isRunning else { return }
                await cycle()
            }
    }

    @ViewBuilder
    private var content: some View {
        if let cursorColor {
            // One Text, so the quoted example wraps naturally; the cursor blinks about twice a second.
            TimelineView(.periodic(from: .now, by: 0.53)) { timeline in
                let isCursorOn = reduceMotion || Int(timeline.date.timeIntervalSinceReferenceDate / 0.53) % 2 == 0
                (Text("\u{201C}") + Text(streamed)
                    + Text("|").fontWeight(.light).foregroundColor(cursorColor.opacity(isCursorOn ? 1 : 0))
                    + Text("\u{201D}"))
                    .lineLimit(lineLimit)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .opacity(opacity)
        } else {
            HStack(spacing: 0) {
                Text(prefix)
                    .fixedSize()
                Text(streamed)
                    .lineLimit(lineLimit)
                    .truncationMode(.tail)
                    .opacity(opacity)
            }
        }
    }

    private var current: String {
        examples.isEmpty ? "" : examples[index % examples.count]
    }

    private var streamed: String {
        String(current.prefix(shown))
    }

    /// Where the next step ends: one character on, or the end of the next word (as in
    /// `SmartSortStreamingText`).
    private func nextStop(after count: Int) -> Int {
        let characters = Array(current)
        guard count < characters.count else { return characters.count }
        if animation.unit == .character { return count + 1 }
        var index = count
        while index < characters.count && characters[index].isWhitespace { index += 1 }
        while index < characters.count && !characters[index].isWhitespace { index += 1 }
        return index
    }

    /// Types out, holds and fades each example in turn, until `isRunning` turns off.
    private func cycle() async {
        guard !examples.isEmpty else { return }
        func sleep(_ seconds: TimeInterval) async {
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
        }
        while !Task.isCancelled {
            let length = current.count
            opacity = 1
            if reduceMotion {
                shown = length
                await sleep(animation.reducedMotionDuration)
            } else {
                while shown < length && !Task.isCancelled {
                    await sleep(animation.wordInterval)
                    guard !Task.isCancelled else { return }
                    if animation.unit == .character {
                        // Eased like the explanation banner's reveal.
                        withAnimation(.easeOut(duration: 0.18)) { shown = nextStop(after: shown) }
                    } else {
                        shown = nextStop(after: shown)
                    }
                }
                await sleep(animation.holdDuration)
                guard !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: animation.fadeDuration)) { opacity = 0 }
                await sleep(animation.fadeDuration + 0.03)
            }
            guard !Task.isCancelled else { return }
            index = (index + 1) % examples.count
            shown = 0
            opacity = 1
        }
    }
}
