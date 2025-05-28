import SwiftUI

/// A customizable Sort By button that displays a menu with sorting options.
public struct RiviSortByButton: View {
    @StateObject private var viewModel: RiviSortByViewModel
    @Binding private var selectedOption: String
    
    /// Initialize a Sort By button with custom configuration
    /// - Parameters:
    ///   - buttonLabel: Text to display on the main button
    ///   - options: Available sorting options
    ///   - selectedOption: Currently selected option
    ///   - theme: Theme to customize the appearance
    ///   - onSelection: Closure called when a selection is made
    public init(
        buttonLabel: String = "Sort By",
        options: [String],
        selectedOption: Binding<String>,
        theme: RiviAskAITheme = .default,
        onSelection: ((String) -> Void)? = nil
    ) {
        _viewModel = StateObject(
            wrappedValue: RiviSortByViewModel(
                options: options,
                onSelection: onSelection
            )
        )
        self._selectedOption = selectedOption
        self.buttonLabel = buttonLabel
        self.theme = theme
    }
    
    private let buttonLabel: String
    private let theme: RiviAskAITheme
    
    public var body: some View {
        Menu {
            ForEach(viewModel.options, id: \.self) { option in
                Button(action: {
                    selectedOption = option
                    viewModel.selectOption(option)
                }) {
                    HStack {
                        Text(option)
                            .foregroundColor(theme.textColor)
                        
                        Spacer()
                        
                        if option == selectedOption {
                            Image(systemName: "checkmark")
                                .foregroundColor(theme.accentColor)
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 8) {
                Text("\(buttonLabel): \(selectedOption)")
                    .font(theme.bodyFont())
                    .foregroundColor(theme.textColor)
                
                Image(systemName: "chevron.down")
                    .font(.system(size: 12))
                    .foregroundColor(theme.textColor.opacity(0.7))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.RiviAskAI.Input.background)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(theme.inputBorderColor, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
} 