import SwiftUI

/// A view that combines sort and search functionality in a single UI component
public struct RiviSortSearchView: View {
    @Binding private var selectedSortOption: String
    @State private var chips: Set<String> = []
    @StateObject private var viewModel: RiviAskAIViewModel
    
    private let sortOptions: [String]
    private let theme: RiviAskAITheme
    private let onSortSelection: ((String) -> Void)?
    private let originalOnAskAIEvent: ((RiviAskAIEvent) -> Void)
    private let onChipRemoved: ((String) -> Void)?
    private let filterSearchParams: FilterSearchParams?
    
    /// Initialize a Sort & Search view with custom configuration
    /// - Parameters:
    ///   - sortOptions: Available sorting options
    ///   - selectedSortOption: Currently selected sort option
    ///   - theme: Theme to customize the appearance
    ///   - filterSearchParams: Parameters for flight search API
    ///   - onSortSelection: Closure called when a sort option is selected
    ///   - onAskAIEvent: Closure called when SSE events are received from Ask AI
    ///   - onChipRemoved: Closure called when a chip is removed
    public init(
        sortOptions: [String],
        selectedSortOption: Binding<String>,
        theme: RiviAskAITheme = .default,
        filterSearchParams: FilterSearchParams? = nil,
        onSortSelection: ((String) -> Void)? = nil,
        onAskAIEvent: @escaping ((RiviAskAIEvent) -> Void),
        onChipRemoved: ((String) -> Void)? = nil
    ) {
        self.sortOptions = sortOptions
        self._selectedSortOption = selectedSortOption
        self.theme = theme
        self.onSortSelection = onSortSelection
        self.onChipRemoved = onChipRemoved
        self.originalOnAskAIEvent = onAskAIEvent
        self.filterSearchParams = filterSearchParams
        
        // Create the view model and store reference to it for event handling
        let vm = RiviAskAIViewModel(
            apiService: RiviAskAIService(baseURL: "http://34.48.22.18:9000/api/v1"),
            filterSearchParams: filterSearchParams,
            onEvent: onAskAIEvent // Forward events directly to the provided handler
        )
        _viewModel = StateObject(wrappedValue: vm)
    }
    
    /// Wrapper for the onAskAIEvent closure that handles chip extraction
    /// This is only used for the RiviAskAIButton within this view
    private func handleAskAIEvent(_ event: RiviAskAIEvent) {
        // Handle the chips extraction event
        if case let .chipsExtracted(extractedChips) = event {
            // Update the chips
            DispatchQueue.main.async {
                self.chips = extractedChips
            }
        }
        
        // Handle flight response
        if case .flightResponse(_) = event {
            print("===== FLIGHT RESPONSE RECEIVED IN RIVISORTSEARCHVIEW =====")
            print("Flight response fetched successfully")
            print("======================================================")
        }
        
        // Forward the event to the original handler
        originalOnAskAIEvent(event)
    }
    
    /// Handle chip removal and trigger improve results
    private func handleChipRemoved(_ chip: String) {
        // Call the user's chip removal handler if provided
        onChipRemoved?(chip)
        
        // Trigger improve results API call with remaining chips
        if !chips.isEmpty {
            let query = chips.joined(separator: ", ")
            viewModel.inputText = query
            // Use the method that doesn't hide the popup
            viewModel.callFilterSearchWithCurrentText()
        }
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Title
            Text("Find Flights")
                .font(theme.titleFont())
                .foregroundColor(theme.popupHeaderTextColor)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
            
            Divider()
                .padding(.horizontal, 0)
                .background(theme.inputBorderColor)
            
            // Buttons container
            HStack(spacing: 12) {
                // Sort By button
                RiviSortByButton(
                    buttonLabel: "Sort By",
                    options: sortOptions,
                    selectedOption: $selectedSortOption,
                    theme: theme,
                    onSelection: onSortSelection
                )
                .frame(maxWidth: .infinity)
                
                // Ask AI button
                RiviAskAIButton(
                    buttonLabel: "Ask AI",
                    theme: theme,
                    filterSearchParams: filterSearchParams,
                    onEvent: { event in
                        // Process the event in our component first
                        self.handleAskAIEvent(event)
                    }
                )
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            
            // Chips view (conditionally shown)
            if !chips.isEmpty {
                Divider()
                    .padding(.horizontal, 0)
                    .background(theme.inputBorderColor)
                
                RiviChipsView(
                    chips: $chips,
                    theme: theme,
                    onRemoveChip: handleChipRemoved
                )
                .padding(.vertical, 8)
            }
        }
        .background(Color.RiviAskAI.Popup.background)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(theme.inputBorderColor, lineWidth: 1)
        )
        // Sync extracted chips from viewModel with our binding
        .onReceive(viewModel.$chips) { newChips in
            if !newChips.isEmpty {
                chips = newChips
            }
        }
    }
} 
