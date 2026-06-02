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
                chipBackgroundColor: Color(light: "#FFFFFF", dark: "#FFFFFF"),
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
            clearAllColor: Color
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
        }
    }
    
    // MARK: - Properties

    /// The configuration for this chips view
    private let configuration: Configuration

    /// The set of strings to display as chips
    @Binding private var chips: Set<String>

    /// The action to perform when a chip is removed
    private let onRemove: ((String) -> Void)

    /// Optional action invoked after the user taps "Clear all".
    /// The chips set is emptied first, then this callback fires.
    private let onClearAll: (() -> Void)?

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
        self.onRemove = onRemove
        self.onClearAll = onClearAll
    }

    // MARK: - Body

    public var body: some View {
        VStack(alignment: .trailing, spacing: configuration.clearAllSpacing) {
            if configuration.showClearAllButton && !chips.isEmpty {
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
                    ForEach(Array(chips), id: \.self) { chip in
                        chipView(for: chip)
                    }
                }
            }
        }
        .environment(\.layoutDirection, RiviAskAIConfiguration.shared.language.layoutDirection)
    }
    
    // MARK: - Helper Views
    
    private func chipView(for text: String) -> some View {
        HStack(spacing: configuration.textIconSpacing) {
            Text(text)
                .font(configuration.font)
                .foregroundStyle(configuration.chipTextColor)
            
            Button(action: {
                removeChip(text)
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: configuration.removeIconSize))
                    .foregroundStyle(configuration.removeIconColor)
            }
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
    
    // MARK: - Methods
    
    private func removeChip(_ chip: String) {
        chips.remove(chip)
        onRemove(chip)
    }
}
