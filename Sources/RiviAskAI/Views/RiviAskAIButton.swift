import SwiftUI

/// A customizable Ask AI button that displays a popup with suggestions and a text input field.
public struct RiviAskAIButton: View {
    @StateObject private var viewModel: RiviAskAIViewModel
    
    /// Initialize an Ask AI button with custom configuration
    /// - Parameters:
    ///   - buttonLabel: Text to display on the main button
    ///   - theme: Theme to customize the appearance
    ///   - filterSearchParams: Parameters for filter search
    ///   - onEvent: Closure called when SSE events are received
    ///   - onChipsExtracted: Closure called when chips are extracted from the filterSearch API
    public init(
        buttonLabel: String = "Ask AI",
        theme: RiviAskAITheme = .default,
        filterSearchParams: FilterSearchParams? = nil,
        onEvent: @escaping ((RiviAskAIEvent) -> Void),
        onChipsExtracted: ((Set<String>) -> Void)? = nil
    ) {
        _viewModel = StateObject(
            wrappedValue: RiviAskAIViewModel(
                apiService: RiviAskAIService(baseURL: "http://34.48.22.18:9000/api/v1"),
                filterSearchParams: filterSearchParams,
                onEvent: { event in
                    // Handle chip extraction separately
                    if case let .chipsExtracted(extractedChips) = event, let onChipsExtracted = onChipsExtracted {
                        onChipsExtracted(extractedChips)
                    }
                    
                    // Forward all events to the original handler
                    onEvent(event)
                }
            )
        )
        self.buttonLabel = buttonLabel
        self.theme = theme
    }
    
    private let buttonLabel: String
    private let theme: RiviAskAITheme
    @State private var popupContentHeight: CGFloat = 0
    
    public var body: some View {
        Button {
            viewModel.togglePopup()
        } label: {
            HStack(spacing: 8) {
                Image("ic_sparkle", bundle: .module)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 22, height: 22)
                    .foregroundColor(theme.accentColor)
                
                Text(buttonLabel)
                    .font(theme.bodyFont())
                    .foregroundColor(theme.accentColor)
                
                Image(systemName: viewModel.isPopupVisible ? "chevron.up" : "chevron.down")
                    .font(.system(size: 12))
                    .foregroundColor(theme.accentColor)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(theme.buttonBackgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(theme.inputBorderColor, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $viewModel.isPopupVisible) {
            if #available(iOS 16.0, *) {
                popupContent
                    .padding()
                    .readSize(onChange: { size in
                        popupContentHeight = size.height
                    })
                    .presentationDetents([.height(popupContentHeight)])
                    .presentationDragIndicator(.hidden)
                    .background(theme.popupBackgroundColor)
            } else {
                // Fallback on earlier versions
                popupContent
                    .padding()
                    .background(theme.popupBackgroundColor)
            }
        }
        // .popover(isPresented: $viewModel.isPopupVisible) {
        //     popupContent
        //         .padding()
        //         .presentationCompactAdaptation(.popover)
        // }
    }
    
    private var popupContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image("ic_sparkle", bundle: .module)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                    .foregroundStyle(theme.accentColor)
                
                Text("Ask AI")
                    .font(theme.titleFont())
                    .foregroundColor(theme.popupHeaderTextColor)
                
                Spacer()
                
                Button {
                    viewModel.togglePopup()
                } label: {
                    Image(systemName: "xmark")
                        .foregroundColor(theme.closeButtonColor)
                }
            }
            
            // Text input
            if #available(iOS 16.0, *) {
                TextField(
                    "e.g. Flights under $400 with morning arrival",
                    text: $viewModel.inputText,
                    axis: .vertical
                )
                .tint(theme.accentColor)
                .font(theme.bodyFont())
                .foregroundColor(theme.inputTextColor)
                .lineLimit(4, reservesSpace: true)
                .padding()
                .foregroundColor(theme.inputTextColor)
                .background(theme.inputBackgroundColor)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(theme.inputBorderColor, lineWidth: 1)
                )
            } else {
                // Fallback on earlier versions
                TextField(
                    "e.g. Flights under $400 with morning arrival",
                    text: $viewModel.inputText
                )
                .tint(theme.accentColor)
                .font(theme.bodyFont())
                .foregroundColor(theme.inputTextColor)
                .lineLimit(4)
                .padding()
                .foregroundColor(theme.inputTextColor)
                .background(theme.inputBackgroundColor)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(theme.inputBorderColor, lineWidth: 1)
                )
            }
            
            Button {
                viewModel.improveResults()
            } label: {
                Text("Improve Results")
                    .font(theme.buttonFont())
                    .foregroundStyle(theme.accentColor)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .frame(height: 46)
            .background(theme.buttonBackgroundColor)
            .clipShape(Capsule())
            
            if #available(iOS 16.0, *) {
                
            } else {
                // Fallback on earlier versions
                Spacer()
            }
        }
    }
}
