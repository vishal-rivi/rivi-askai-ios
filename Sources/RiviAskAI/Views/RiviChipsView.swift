import SwiftUI

/// A view that displays a collection of chips (filters/tags) in a horizontal scrollable list
public struct RiviChipsView: View {
    @Binding private var chips: Set<String>
    private let theme: RiviAskAITheme
    private let onRemoveChip: ((String) -> Void)?
    
    /// Initialize a chips view with custom configuration
    /// - Parameters:
    ///   - chips: The collection of chips to display
    ///   - theme: Theme to customize the appearance
    ///   - onRemoveChip: Closure called when a chip is removed
    public init(
        chips: Binding<Set<String>>,
        theme: RiviAskAITheme = .default,
        onRemoveChip: ((String) -> Void)? = nil
    ) {
        self._chips = chips
        self.theme = theme
        self.onRemoveChip = onRemoveChip
    }
    
    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(chips), id: \.self) { chip in
                    ChipView(
                        title: chip,
                        theme: theme,
                        onRemove: {
                            removeChip(chip)
                        }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .frame(height: chips.isEmpty ? 0 : 44)
        .animation(.easeInOut, value: chips)
    }
    
    private func removeChip(_ chip: String) {
        chips.remove(chip)
        onRemoveChip?(chip)
    }
}

/// A single chip view representing a filter or tag
private struct ChipView: View {
    let title: String
    let theme: RiviAskAITheme
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 6) {
            Text(title)
                .font(theme.bodyFont())
                .foregroundColor(theme.textColor)
                .lineLimit(1)
            
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(theme.textColor.opacity(0.6))
                    .padding(2)
            }
        }
        .padding(.vertical, 6)
        .padding(.leading, 12)
        .padding(.trailing, 8)
        .background(theme.buttonBackgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(theme.inputBorderColor, lineWidth: 1)
        )
    }
} 