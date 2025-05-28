import SwiftUI

/// Example view demonstrating how to use the RiviAskAI API for flight filtering
public struct FlightFilterExampleView: View {
    @StateObject private var viewModel: RiviAskAIViewModel
    @State private var events: [String] = []
    @State private var chips: Set<String> = []
    @State private var selectedSortOption: String = "Price"
    
    /// Initialize the example view
    public init() {
        // Create filter search parameters for flight
        let params = FilterSearchParams(
            searchId: "682c4f4e8b9a1305495cb861",
            isRound: false,
            authToken: "99d477cbcb65dcf06a992bb808061362ba2f2050c217ee488acbd708610b4012"
        )
        
        // Event handler function
        let eventHandler: (RiviAskAIEvent) -> Void = { event in
            // We'll handle events in onAppear since we need access to self
            // This initial handler is just a placeholder
            print("Event received in init: \(event)")
        }
        
        // Create the view model with our event handler
        _viewModel = StateObject(wrappedValue: RiviAskAIViewModel(
            filterSearchParams: params,
            onEvent: eventHandler
        ))
    }
    
    public var body: some View {
        VStack(spacing: 16) {
            // Title
            Text("Flight Filter Example")
                .font(.title)
                .padding(.top)
            
            // Sort and Search component
            RiviSortSearchView(
                sortOptions: ["Price", "Duration", "Departure", "Arrival"],
                selectedSortOption: $selectedSortOption,
                theme: .default,
                filterSearchParams: FilterSearchParams(
                    searchId: "682c4f4e8b9a1305495cb861",
                    isRound: false,
                    authToken: "99d477cbcb65dcf06a992bb808061362ba2f2050c217ee488acbd708610b4012"
                ),
                onSortSelection: { option in
                    addEvent("Sort option selected: \(option)")
                },
                onAskAIEvent: { event in
                    handleAskAIEvent(event)
                },
                onChipRemoved: { chip in
                    addEvent("Chip removed: \(chip)")
                }
            )
            .padding(.horizontal)
            
            // Input field
            HStack {
                TextField("Enter filter query", text: $viewModel.inputText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                
                Button("Search") {
                    viewModel.improveResults()
                }
                .padding(.trailing)
            }
            
            // Chips view
            if !chips.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(chips), id: \.self) { chip in
                            Text(chip)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(Color.blue.opacity(0.1))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .strokeBorder(Color.blue.opacity(0.3), lineWidth: 1)
                                )
                        }
                    }
                    .padding(.horizontal)
                }
                .frame(height: 40)
            }
            
            // Events list
            List {
                ForEach(events, id: \.self) { event in
                    Text(event)
                        .font(.footnote)
                        .padding(8)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                }
            }
            .frame(maxHeight: .infinity)
        }
        .padding()
        .onAppear {
            setupEventHandling()
        }
    }
    
    private func handleAskAIEvent(_ event: RiviAskAIEvent) {
        switch event {
        case .data(let data):
            let truncatedData = data.count > 50 ? String(data.prefix(50)) + "..." : data
            addEvent("📡 Data received: \(truncatedData)")
            
        case .error(let error):
            addEvent("❌ Error: \(error.localizedDescription)")
            
        case .disconnected:
            addEvent("🔌 Disconnected")
            
        case .filterSearchCompleted:
            addEvent("✅ Filter search completed")
            
        case .chipsExtracted(let extractedChips):
            self.chips = extractedChips
            addEvent("🏷 \(extractedChips.count) chips extracted")
            
        case .flightResponse(let response):
            addEvent("✈️ Flight response fetched successfully")
            print("===== FLIGHT RESPONSE RECEIVED IN EXAMPLE VIEW =====")
            print("Request ID: \(response.requestID)")
            print("Status: \(response.status)")
            print("Client ID: \(response.clientID)")
            print("Available Itineraries: \(response.data.availableItineraries)")
            print("Flight response fetched successfully")
            print("================================================")
            
            // Show alert to visually confirm receipt
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                print("⚠️⚠️⚠️ ALERT: Flight response fetched successfully ⚠️⚠️⚠️")
            }
        }
    }
    
    private func setupEventHandling() {
        // Since we can't assign to onEvent (it's a let constant),
        // we'll use a mirror object to capture and process events
        let eventMirror = EventHandlerMirror()
        eventMirror.onEventReceived = { event in
            // No weak self needed since FlightFilterExampleView is a struct
            handleAskAIEvent(event)
        }
        
        // Store the mirror as a global instance to keep it alive
        EventHandlerRegistry.shared.register(mirror: eventMirror)
    }
    
    private func addEvent(_ event: String) {
        DispatchQueue.main.async {
            events.insert(event, at: 0)
            
            // Limit the number of displayed events
            if events.count > 20 {
                events = Array(events.prefix(20))
            }
        }
    }
}

/// Helper class to handle events since we can't reassign viewModel.onEvent
class EventHandlerMirror {
    var onEventReceived: ((RiviAskAIEvent) -> Void)?
}

/// Singleton to keep event handler mirrors alive
class EventHandlerRegistry {
    static let shared = EventHandlerRegistry()
    private var mirrors: [EventHandlerMirror] = []
    
    func register(mirror: EventHandlerMirror) {
        mirrors.append(mirror)
    }
}

#Preview {
    FlightFilterExampleView()
} 