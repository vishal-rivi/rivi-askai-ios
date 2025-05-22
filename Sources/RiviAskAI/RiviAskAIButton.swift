import SwiftUI

/// A customizable Ask AI button that displays a popup with suggestions and a text input field.
public struct RiviAskAIButton: View {
    @StateObject private var viewModel: RiviAskAIViewModel
    
    /// Initialize an Ask AI button with custom configuration
    /// - Parameters:
    ///   - buttonLabel: Text to display on the main button
    ///   - accentColor: Color for the AI icon and button accents
    ///   - baseURL: Base URL for the SSE API
    ///   - onEvent: Closure called when SSE events are received
    public init(
        buttonLabel: String = "Ask AI",
        accentColor: Color = .blue,
        baseURL: String = "https://filter-gateway-service.rivi.co/api/v1",
        filterSearchParams: FilterSearchParams,
        onEvent: ((RiviAskAIEvent) -> Void)?
    ) {
        _viewModel = StateObject(
            wrappedValue: RiviAskAIViewModel(
                baseURL: baseURL,
                filterSearchParams: filterSearchParams,
                onEvent: onEvent
            )
        )
        self.buttonLabel = buttonLabel
        self.accentColor = accentColor
    }
    
    private let buttonLabel: String
    private let accentColor: Color
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
                    .frame(width: 20, height: 20)
                    .foregroundStyle(accentColor)
                
                Text(buttonLabel)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(accentColor)
                
                Image(systemName: viewModel.isPopupVisible ? "chevron.up" : "chevron.down")
                    .font(.system(size: 12))
                    .foregroundColor(accentColor.opacity(0.7))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(accentColor.opacity(0.12))
            .cornerRadius(20)
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
            } else {
                // Fallback on earlier versions
                popupContent
                    .padding()
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
                    .foregroundStyle(accentColor)
                
                Text("Ask AI")
                    .font(.headline)
                
                Spacer()
                
                Button {
                    viewModel.togglePopup()
                } label: {
                    Image(systemName: "xmark")
                        .foregroundColor(.gray)
                }
            }
            
            // Text input
            if #available(iOS 16.0, *) {
                TextField(
                    "e.g. Hotels with pool near the beach",
                    text: $viewModel.inputText,
                    axis: .vertical
                )
                .lineLimit(4, reservesSpace: true)
                .padding()
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
            } else {
                // Fallback on earlier versions
                TextField(
                    "e.g. Hotels with pool near the beach",
                    text: $viewModel.inputText
                )
                .lineLimit(4)
                .padding()
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
            }
            
            Button {
                viewModel.improveResults()
            } label: {
                Text("Improve Results")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(accentColor)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .frame(height: 46)
            .background(accentColor.opacity(0.12))
            .clipShape(Capsule())
            
            if #available(iOS 16.0, *) {
                
            } else {
                // Fallback on earlier versions
                Spacer()
            }
        }
    }
}
