import SwiftUI

/// Text that types itself out, by character or by word. Style it like a `Text`, with `.font`,
/// `.foregroundStyle` and `.multilineTextAlignment`.
///
/// The reveal runs on the clock, not on a task: each text remembers when its reveal started, and
/// what is on screen is worked out from the time. So nothing SwiftUI does to the view (cancelling
/// its tasks, rebuilding it in a lazy list, hiding it behind another tab) can stall it short of
/// the end; a rebuilt view shows exactly where the reveal has got to, and a text already revealed
/// never types out again.
///
/// A `text` that extends an earlier one (a cumulative snapshot) carries on from where that one
/// was; any other text types out from the start. With Reduce Motion on, or `isAnimated` false,
/// the text appears at once.
public struct SmartSortStreamingText: View {
    /// How much each step reveals.
    public enum Unit {
        case character
        /// The next word, with the spaces before it.
        case word
    }

    private let text: String
    private let unit: Unit
    private let interval: TimeInterval
    private let isAnimated: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Bumped once the reveal is due to finish, so the timeline stops ticking.
    @State private var finished = 0

    /// - Parameters:
    ///   - text: The full text so far.
    ///   - unit: Reveal a character or a word per step.
    ///   - interval: Seconds between steps.
    ///   - isAnimated: false shows the text at once.
    public init(_ text: String, unit: Unit = .character, interval: TimeInterval = 0.02, isAnimated: Bool = true) {
        self.text = text
        self.unit = unit
        self.interval = max(interval, 0.001)
        self.isAnimated = isAnimated
    }

    public var body: some View {
        let reveal = isAnimated && !reduceMotion && !text.isEmpty
            ? StreamingProgress.reveal(for: text, unit: unit, interval: interval)
            : nil
        let isDone = reveal.map { shown(by: $0, at: Date()) >= text.count } ?? true
        TimelineView(.animation(minimumInterval: interval, paused: isDone)) { context in
            let count = reveal.map { shown(by: $0, at: context.date) } ?? text.count
            Text(String(text.prefix(count)))
                // Eased so the container grows smoothly when the text wraps onto a new line.
                .animation(.easeOut(duration: 0.18), value: count)
        }
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(text)) // VoiceOver reads the whole text, not the partial reveal
        .task(id: text) {
            // Pause the timeline once the reveal is due to finish. If this is cancelled the
            // timeline just keeps ticking; the text is still right.
            guard let reveal, !isDone else { return }
            let remaining = reveal.duration(of: text, unit: unit, interval: interval) - Date().timeIntervalSince(reveal.start)
            try? await Task.sleep(nanoseconds: UInt64(max(remaining, 0) * 1_000_000_000) + 50_000_000)
            if !Task.isCancelled { finished += 1 }
        }
    }

    private func shown(by reveal: StreamingProgress.Reveal, at date: Date) -> Int {
        reveal.shown(of: text, unit: unit, interval: interval, at: date)
    }
}

/// When each recent text's reveal started, shared by every `SmartSortStreamingText`, so a rebuilt
/// view carries on (or shows the text whole) instead of typing out again. Keeps the last few texts.
@MainActor
enum StreamingProgress {
    /// At `start`, `from` characters of the text were showing; one more step each interval after.
    struct Reveal {
        var start: Date
        var from: Int

        func shown(of text: String, unit: SmartSortStreamingText.Unit, interval: TimeInterval, at date: Date) -> Int {
            let steps = Int(max(date.timeIntervalSince(start), 0) / interval)
            return Self.advance(Array(text), from: min(from, text.count), steps: steps, unit: unit)
        }

        /// Seconds from `start` until all of `text` shows.
        func duration(of text: String, unit: SmartSortStreamingText.Unit, interval: TimeInterval) -> TimeInterval {
            let characters = Array(text)
            var index = min(from, characters.count)
            var steps = 0
            while index < characters.count {
                index = Self.advance(characters, from: index, steps: 1, unit: unit)
                steps += 1
            }
            return Double(steps) * interval
        }

        /// Steps one character, or one word with the spaces before it, at a time.
        static func advance(_ characters: [Character], from: Int, steps: Int, unit: SmartSortStreamingText.Unit) -> Int {
            if unit == .character { return min(from + steps, characters.count) }
            var index = from
            var taken = 0
            while taken < steps && index < characters.count {
                while index < characters.count && characters[index].isWhitespace { index += 1 }
                while index < characters.count && !characters[index].isWhitespace { index += 1 }
                taken += 1
            }
            return index
        }
    }

    private static var reveals: [String: Reveal] = [:]
    private static var recent: [String] = []
    private static let limit = 16

    /// The reveal for `text`: its own, or one that carries on from the longest earlier snapshot it
    /// extends, or a new one from the start.
    static func reveal(for text: String, unit: SmartSortStreamingText.Unit, interval: TimeInterval) -> Reveal {
        if let reveal = reveals[text] { return reveal }
        let now = Date()
        let from = recent.filter { text.hasPrefix($0) }
            .compactMap { prefix in reveals[prefix].map { $0.shown(of: prefix, unit: unit, interval: interval, at: now) } }
            .max() ?? 0
        let reveal = Reveal(start: now, from: from)
        reveals[text] = reveal
        recent.append(text)
        if recent.count > limit { reveals[recent.removeFirst()] = nil }
        return reveal
    }
}
