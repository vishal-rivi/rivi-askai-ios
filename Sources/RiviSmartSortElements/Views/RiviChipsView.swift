import SwiftUI

/// A customizable horizontal chips view component with removal capability
public struct RiviChipsView: View {
    // MARK: - Configuration
    
    /// Configuration options for the RiviChipsView
    public struct Configuration {
        /// The font to use for the chip text
        public var font: Font
        /// The corner radius of the chips
        public var cornerRadius: CGFloat
        /// The padding inside the chips
        public var chipPadding: EdgeInsets
        /// The spacing between chips
        public var spacing: CGFloat
        /// The size of the remove (X) icon
        public var removeIconSize: CGFloat
        /// The spacing between the text and remove icon
        public var textIconSpacing: CGFloat
        /// Whether to show the trailing "Clear all" button above the chips
        public var showClearAllButton: Bool
        /// The "Clear all" button text
        public var clearAllText: String
        /// The font for the "Clear all" button
        public var clearAllFont: Font
        /// The vertical spacing between the "Clear all" row and the chips row
        public var clearAllSpacing: CGFloat
        /// Optional image shown before each chip's text, e.g. `SmartSortSparkle.image`. Template
        /// images and SF Symbols take `iconColor`. nil (the default) shows no icon.
        public var icon: Image?
        /// Shows `icon` before each chip's text. false (the default) keeps the icon hidden.
        public var showsIcon: Bool
        /// The icon's width and height
        public var iconSize: CGFloat
        /// Optional font for a label's key: in "Departure: Before 12PM", "Departure:" takes this
        /// font and the rest takes `font`. nil (the default) shows the label in `font` alone.
        public var keyFont: Font?
        /// Fades the chip row's edges while more chips are scrolled out of view past them.
        public var fadesEdges: Bool
        /// The width of each edge fade
        public var edgeFadeWidth: CGFloat
        /// Space inside the scrolling row, before the first chip and after the last. With a
        /// negative outer padding it lets the row scroll edge to edge while the chips line up with
        /// the content around it. Zero by default.
        public var contentPadding: EdgeInsets
        /// Width and height of the remove (X) button's tap area, with the icon centered in it.
        /// nil (the default) sizes the button to the icon.
        public var removeButtonSize: CGFloat?
        /// Chips fade and scale in (0.9 to 1, 0.2s ease-out) as they appear, each 0.06s after the
        /// one before. Still with Reduce Motion. false (the default) shows them at once.
        public var animatesEntrance: Bool = false

        // MARK: - Theme Properties

        /// Background color for the chips
        public var chipBackgroundColor: Color
        /// Border color for the chips
        public var chipBorderColor: Color
        /// Text color for the chips
        public var chipTextColor: Color
        /// Remove icon color
        public var removeIconColor: Color
        /// Color for the "Clear all" button text
        public var clearAllColor: Color
        /// Icon color. nil uses `chipTextColor`.
        public var iconColor: Color?

        /// Create a default configuration
        public static var `default`: Configuration {
            Configuration(
                font: .system(size: 14, weight: .regular),
                cornerRadius: 8,
                chipPadding: EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12),
                spacing: 8,
                removeIconSize: 14,
                textIconSpacing: 6,
                showClearAllButton: true,
                clearAllText: "chips_clear_all_button".localized(),
                clearAllFont: .system(size: 14, weight: .semibold),
                clearAllSpacing: 8,
                chipBackgroundColor: AppColor.cards,
                chipBorderColor: Color(light: "#7B3AEC", dark: "#7B3AEC"),
                chipTextColor: Color(light: "#7B3AEC", dark: "#7B3AEC"),
                removeIconColor: Color(light: "#7B3AEC", dark: "#7B3AEC"),
                clearAllColor: Color(light: "#7B3AEC", dark: "#7B3AEC")
            )
        }

        public init(
            font: Font,
            cornerRadius: CGFloat,
            chipPadding: EdgeInsets,
            spacing: CGFloat,
            removeIconSize: CGFloat,
            textIconSpacing: CGFloat,
            showClearAllButton: Bool,
            clearAllText: String,
            clearAllFont: Font,
            clearAllSpacing: CGFloat,
            chipBackgroundColor: Color,
            chipBorderColor: Color,
            chipTextColor: Color,
            removeIconColor: Color,
            clearAllColor: Color,
            icon: Image? = nil,
            showsIcon: Bool = false,
            iconSize: CGFloat = 14,
            iconColor: Color? = nil,
            keyFont: Font? = nil,
            fadesEdges: Bool = false,
            edgeFadeWidth: CGFloat = 28,
            contentPadding: EdgeInsets = EdgeInsets(),
            removeButtonSize: CGFloat? = nil
        ) {
            self.font = font
            self.cornerRadius = cornerRadius
            self.chipPadding = chipPadding
            self.spacing = spacing
            self.removeIconSize = removeIconSize
            self.textIconSpacing = textIconSpacing
            self.showClearAllButton = showClearAllButton
            self.clearAllText = clearAllText
            self.clearAllFont = clearAllFont
            self.clearAllSpacing = clearAllSpacing
            self.chipBackgroundColor = chipBackgroundColor
            self.chipBorderColor = chipBorderColor
            self.chipTextColor = chipTextColor
            self.removeIconColor = removeIconColor
            self.clearAllColor = clearAllColor
            self.icon = icon
            self.showsIcon = showsIcon
            self.iconSize = iconSize
            self.iconColor = iconColor
            self.keyFont = keyFont
            self.fadesEdges = fadesEdges
            self.edgeFadeWidth = edgeFadeWidth
            self.contentPadding = contentPadding
            self.removeButtonSize = removeButtonSize
        }
    }
    
    // MARK: - Properties

    /// The configuration for this chips view
    private let configuration: Configuration

    /// The set of strings to display as chips
    @Binding private var chips: Set<String>

    /// The chips in display order, when given as a list. nil shows `chips` in set order.
    private let order: [String]?

    /// The action to perform when a chip is removed
    private let onRemove: ((String) -> Void)

    /// Optional action invoked after the user taps "Clear all".
    /// The chips set is emptied first, then this callback fires.
    private let onClearAll: (() -> Void)?

    /// The chips' frame in the scroll view's space, and the scroll view's width: together they say
    /// whether chips are hidden past either edge.
    @State private var contentFrame: CGRect = .zero
    @State private var viewportWidth: CGFloat = 0
    private let scrollSpace = "RiviChipsView.scroll"

    // MARK: - Initialization

    /// Initialize with a configuration, chips binding, and optional removal action
    /// - Parameters:
    ///   - configuration: The configuration for the chips view
    ///   - chips: Binding to the set of chip strings
    ///   - onRemove: Callback when a single chip is removed
    ///   - onClearAll: Optional callback when the user taps "Clear all" (fires after the chips set is emptied)
    public init(
        configuration: RiviChipsView.Configuration = .default,
        chips: Binding<Set<String>>,
        onRemove: @escaping ((String) -> Void),
        onClearAll: (() -> Void)? = nil
    ) {
        self.configuration = configuration
        self._chips = chips
        self.order = nil
        self.onRemove = onRemove
        self.onClearAll = onClearAll
    }

    /// Initialize with chips in a fixed order (e.g. the order of the query's preferences). The
    /// owner removes a chip from its list in `onRemove`; this view doesn't mutate it.
    /// - Parameters:
    ///   - configuration: The configuration for the chips view
    ///   - chips: The chip strings, in display order
    ///   - onRemove: Callback when a single chip is removed
    ///   - onClearAll: Optional callback when the user taps "Clear all"
    public init(
        configuration: Configuration = .default,
        orderedChips chips: [String],
        onRemove: @escaping ((String) -> Void),
        onClearAll: (() -> Void)? = nil
    ) {
        self.configuration = configuration
        self._chips = .constant(Set(chips))
        self.order = chips
        self.onRemove = onRemove
        self.onClearAll = onClearAll
    }

    /// The chips to show, in display order.
    private var displayedChips: [String] {
        order ?? Array(chips)
    }

    // MARK: - Body

    public var body: some View {
        VStack(alignment: .trailing, spacing: configuration.clearAllSpacing) {
            if configuration.showClearAllButton && !displayedChips.isEmpty {
                Button {
                    chips.removeAll()
                    onClearAll?()
                } label: {
                    Text(configuration.clearAllText)
                        .font(configuration.clearAllFont)
                        .foregroundStyle(configuration.clearAllColor)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: configuration.spacing) {
                    ForEach(Array(displayedChips.enumerated()), id: \.element) { index, chip in
                        chipView(for: chip)
                            .modifier(RiviChipEntrance(isEnabled: configuration.animatesEntrance,
                                                       delay: Double(index) * 0.06))
                    }
                }
                .padding(configuration.contentPadding)
                .background(GeometryReader { proxy in
                    let frame = proxy.frame(in: .named(scrollSpace))
                    Color.clear
                        .onAppear { contentFrame = frame }
                        .onChange(of: frame) { contentFrame = $0 }
                })
            }
            .coordinateSpace(name: scrollSpace)
            .background(GeometryReader { proxy in
                Color.clear
                    .onAppear { viewportWidth = proxy.size.width }
                    .onChange(of: proxy.size.width) { viewportWidth = $0 }
            })
            .mask { if configuration.fadesEdges { edgeFadeMask } else { Rectangle() } }
        }
        .environment(\.layoutDirection, RiviSmartSortConfiguration.shared.language.layoutDirection)
    }
    
    // MARK: - Helper Views

    /// Opaque in the middle; each edge fades out only while chips are hidden past it. The frames
    /// are measured left to right in both layout directions, so the mask is built by physical edge.
    private var edgeFadeMask: some View {
        let fadeLeft = contentFrame.minX < -2
        let fadeRight = contentFrame.maxX > viewportWidth + 2
        return HStack(spacing: 0) {
            LinearGradient(colors: [.black.opacity(fadeLeft ? 0 : 1), .black], startPoint: .leading, endPoint: .trailing)
                .frame(width: configuration.edgeFadeWidth)
            Rectangle()
            LinearGradient(colors: [.black, .black.opacity(fadeRight ? 0 : 1)], startPoint: .leading, endPoint: .trailing)
                .frame(width: configuration.edgeFadeWidth)
        }
        .environment(\.layoutDirection, .leftToRight)
        .animation(.easeOut(duration: 0.15), value: fadeLeft)
        .animation(.easeOut(duration: 0.15), value: fadeRight)
    }
    
    private func chipView(for text: String) -> some View {
        HStack(spacing: configuration.textIconSpacing) {
            if configuration.showsIcon, let icon = configuration.icon {
                icon
                    .resizable()
                    .renderingMode(.template)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: configuration.iconSize, height: configuration.iconSize)
                    .foregroundStyle(configuration.iconColor ?? configuration.chipTextColor)
                    .accessibilityHidden(true)
            }
            label(for: text)
                .foregroundStyle(configuration.chipTextColor)
            
            Button(action: {
                removeChip(text)
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: configuration.removeIconSize))
                    .foregroundStyle(configuration.removeIconColor)
                    .frame(width: configuration.removeButtonSize, height: configuration.removeButtonSize)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(Text("Remove \(text)"))
        }
        .padding(configuration.chipPadding)
        .background(configuration.chipBackgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: configuration.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: configuration.cornerRadius)
                .stroke(configuration.chipBorderColor, lineWidth: 1)
        )
        .padding(1)
    }
    
    /// The label, with its key ("Departure:") in `keyFont` when one is set and the label has one.
    private func label(for text: String) -> Text {
        guard let keyFont = configuration.keyFont, let colon = text.range(of: ": ") else {
            return Text(text).font(configuration.font)
        }
        let key = String(text[..<colon.lowerBound]) + ":"
        let value = String(text[colon.upperBound...])
        return Text(key).font(keyFont) + Text(" " + value).font(configuration.font)
    }

    // MARK: - Methods
    
    private func removeChip(_ chip: String) {
        chips.remove(chip)
        onRemove(chip)
    }
}

/// A chip's entrance: fades and scales from 0.9 to 1 over 0.2s (cubic ease-out) after `delay`.
private struct RiviChipEntrance: ViewModifier {
    let isEnabled: Bool
    let delay: TimeInterval

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isShown = false

    func body(content: Content) -> some View {
        let shown = isShown || !isEnabled
        content
            .opacity(shown ? 1 : 0)
            .scaleEffect(shown ? 1 : 0.9)
            .onAppear {
                guard isEnabled, !isShown else { return }
                if reduceMotion {
                    isShown = true
                } else {
                    withAnimation(.timingCurve(0.33, 1, 0.68, 1, duration: 0.2).delay(delay)) { isShown = true }
                }
            }
    }
}
