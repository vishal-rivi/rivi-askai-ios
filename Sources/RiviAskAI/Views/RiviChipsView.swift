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
        
        // MARK: - Theme Properties
        
        /// Background color for the chips
        public var chipBackgroundColor: Color
        /// Border color for the chips
        public var chipBorderColor: Color
        /// Text color for the chips
        public var chipTextColor: Color
        /// Remove icon color
        public var removeIconColor: Color
        
        /// Create a default configuration
        public static var `default`: Configuration {
            Configuration(
                font: .system(size: 14, weight: .regular),
                cornerRadius: 8,
                chipPadding: EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12),
                spacing: 8,
                removeIconSize: 14,
                textIconSpacing: 6,
                chipBackgroundColor: Color(light: "#FFFFFF", dark: "#FFFFFF"),
                chipBorderColor: Color(light: "#7B3AEC", dark: "#7B3AEC"),
                chipTextColor: Color(light: "#7B3AEC", dark: "#7B3AEC"),
                removeIconColor: Color(light: "#7B3AEC", dark: "#7B3AEC")
            )
        }
        
        public init(
            font: Font,
            cornerRadius: CGFloat,
            chipPadding: EdgeInsets,
            spacing: CGFloat,
            removeIconSize: CGFloat,
            textIconSpacing: CGFloat,
            chipBackgroundColor: Color,
            chipBorderColor: Color,
            chipTextColor: Color,
            removeIconColor: Color
        ) {
            self.font = font
            self.cornerRadius = cornerRadius
            self.chipPadding = chipPadding
            self.spacing = spacing
            self.removeIconSize = removeIconSize
            self.textIconSpacing = textIconSpacing
            self.chipBackgroundColor = chipBackgroundColor
            self.chipBorderColor = chipBorderColor
            self.chipTextColor = chipTextColor
            self.removeIconColor = removeIconColor
        }
    }
    
    // MARK: - Properties
    
    /// The configuration for this chips view
    private let configuration: Configuration
    
    /// The set of strings to display as chips
    @Binding private var chips: Set<String>
    
    /// The action to perform when a chip is removed
    private let onRemove: ((String) -> Void)
    
    // MARK: - Initialization
    
    /// Initialize with a configuration, chips binding, and optional removal action
    public init(
        configuration: RiviChipsView.Configuration = .default,
        chips: Binding<Set<String>>,
        onRemove: @escaping ((String) -> Void)
    ) {
        self.configuration = configuration
        self._chips = chips
        self.onRemove = onRemove
    }
    
    // MARK: - Body
    
    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: configuration.spacing) {
                ForEach(Array(chips), id: \.self) { chip in
                    chipView(for: chip)
                }
            }
        }
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
