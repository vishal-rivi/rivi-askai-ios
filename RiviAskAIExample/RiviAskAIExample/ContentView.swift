import SwiftUI
import RiviAskAI

struct ContentView: View {
    @State private var selectedFlow = 0
    @State private var showAskAISheet = false
    @State private var isAskAIButtonEnabled = false
    @State private var filterChips: Set<String> = []
    @State private var userQuery: String = ""
    @State private var parameterChangeNotice: String? = nil
    @State private var showAlert = false
    
    // Custom UI states
    @State private var showCustomSheet = false
    
    // SSE subscription states
    @State private var isSubscribed = false
    @State private var sseEvents: [String] = []
    
    // Query type selection
    @State private var selectedQueryType: QueryType = .hotel
    @State private var selectedLanguage: Language = .english
    
    // Constants for API calls
    private let searchId = "[Search ID]"
    private let authToken = "[Auth Token]"
    
    var body: some View {
        NavigationView {
            ScrollView(.vertical) {
                VStack {
                    Picker("Select Flow", selection: $selectedFlow) {
                        Text("Package UI").tag(0)
                        Text("Custom UI").tag(1)
                        Text("SSE Demo").tag(2)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding()
                    
                    if selectedFlow == 0 {
                        packageUIFlow
                    } else if selectedFlow == 1 {
                        customUIFlow
                    } else {
                        sseSubscriptionFlow
                    }
                    
                    Spacer()
                }
            }
            .navigationTitle("RiviAskAI Demo")
            .padding()
            .overlay {
                if showAlert {
                    RiviAlertDialog(isPresented: $showAlert) {
                        print("Alert dismissed")
                    }
                }
            }
        }
    }
    
    // MARK: - Package UI Flow
    
    private var packageUIFlow: some View {
        VStack(spacing: 24) {
            Text("Using Package UI Components")
                .font(.headline)
            
            // Query type and language selection
            VStack(spacing: 12) {
                HStack {
                    Text("Query Type:")
                        .font(.subheadline)
                    Picker("Query Type", selection: $selectedQueryType) {
                        Text("Hotel").tag(QueryType.hotel)
                        Text("Flight").tag(QueryType.flight)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                HStack {
                    Text("Language:")
                        .font(.subheadline)
                    Picker("Language", selection: $selectedLanguage) {
                        Text("English").tag(Language.english)
                        Text("Arabic").tag(Language.arabic)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
            }
            .padding(.bottom, 8)
            
            // 1. Show the chips view
            VStack(alignment: .leading) {
                Text("1. RiviChipsView:")
                    .font(.subheadline)
                    .bold()
                
                RiviChipsView(chips: $filterChips) { removedChip in
                    print("Removed chip: \(removedChip)")
                    processQuery(filterChips.joined(separator: ", "))
                }
                .frame(height: 50)
            }
            
            // 2. Show the info banner
            if !filterChips.isEmpty {
                VStack(alignment: .leading) {
                    Text("2. RiviInfoBanner:")
                        .font(.subheadline)
                        .bold()
                    
                    RiviInfoBanner()
                }
            }
            
            // 3. Show the Ask AI button
            VStack(alignment: .leading) {
                Text("3. RiviAskAIButton:")
                    .font(.subheadline)
                    .bold()
                
                HStack {
                    RiviAskAIButton(isEnabled: $isAskAIButtonEnabled) {
                        showAskAISheet = true
                    }
                    
                    Spacer()
                    
                    Toggle("Enable", isOn: $isAskAIButtonEnabled)
                        .labelsHidden()
                }
            }
            
            // 3. Show the Ask AI Sheet (when button is tapped)
            if !userQuery.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("User Query:")
                        .font(.subheadline)
                        .bold()
                    
                    Text(userQuery)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                }
            }
            
            // Demo controls
            HStack(spacing: 12) {
                Button("Reset Demo") {
                    filterChips = []
                    userQuery = ""
                    parameterChangeNotice = nil
                }
                
                Button("Sort Best") {
                    performSortBest()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.top, 20)
        }
        .sheet(isPresented: $showAskAISheet) {
            RiviAskAISheet(
                isPresented: $showAskAISheet,
                queryType: selectedQueryType,
                userQuery: userQuery,
                parameterChangeNotice: parameterChangeNotice
            ) { query in
                processQuery(query)
            }
        }
    }
    
    // MARK: - Custom UI Flow
    
    private var customUIFlow: some View {
        VStack(spacing: 24) {
            Text("Using Custom UI with Package Logic")
                .font(.headline)
            
            // 1. Custom chips view
            VStack(alignment: .leading) {
                Text("1. Custom Chips View:")
                    .font(.subheadline)
                    .bold()
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(filterChips), id: \.self) { chip in
                            customChipView(for: chip)
                        }
                    }
                }
                .frame(height: 50)
            }
            
            // 2. Custom info banner
            if !filterChips.isEmpty {
                VStack(alignment: .leading) {
                    Text("2. Custom Info Banner:")
                        .font(.subheadline)
                        .bold()
                    
                    customInfoBanner
                }
            }
            
            // 3. Custom Ask AI button
            VStack(alignment: .leading) {
                Text("3. Custom Ask AI Button:")
                    .font(.subheadline)
                    .bold()
                
                HStack {
                    Button {
                        showCustomSheet = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "sparkles")
                            Text("Custom Ask AI")
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(20)
                    }
                    .disabled(!isAskAIButtonEnabled)
                    .opacity(isAskAIButtonEnabled ? 1.0 : 0.5)
                    
                    Spacer()
                    
                    Toggle("Enable", isOn: $isAskAIButtonEnabled)
                        .labelsHidden()
                }
            }
            
            // 3. Display query result
            if !userQuery.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("User Query:")
                        .font(.subheadline)
                        .bold()
                    
                    Text(userQuery)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                }
            }
            
            // Demo controls
            Button("Reset Demo") {
                filterChips = []
                userQuery = ""
                parameterChangeNotice = nil
            }
            .padding(.top, 20)
            
            // Test alert button
            Button("Test Alert Dialog") {
                withAnimation(.easeInOut) {
                    showAlert = true
                }
            }
            .padding(.top, 8)
        }
        .sheet(isPresented: $showCustomSheet) {
            customSheetView
        }
    }
    
    // MARK: - SSE Subscription Flow
    
    private var sseSubscriptionFlow: some View {
        VStack(spacing: 24) {
            Text("SSE Subscription Demo")
                .font(.headline)
            
            // Subscription controls
            HStack {
                Button(isSubscribed ? "Unsubscribe" : "Subscribe to Events") {
                    if isSubscribed {
                        unsubscribeFromEvents()
                    } else {
                        subscribeToEvents()
                    }
                }
                .padding()
                .background(isSubscribed ? Color.red : Color.green)
                .foregroundColor(.white)
                .cornerRadius(8)
                
                Button("Clear Events") {
                    sseEvents.removeAll()
                }
                .padding()
                .background(Color.gray)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            
            // Events list
            VStack(alignment: .leading) {
                Text("Received Events:")
                    .font(.subheadline)
                    .bold()
                
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(sseEvents.indices, id: \.self) { index in
                            Text(sseEvents[index])
                                .font(.system(size: 12, design: .monospaced))
                                .padding(8)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }
                }
                .frame(height: 300)
                .background(Color.gray.opacity(0.05))
                .cornerRadius(8)
            }
        }
    }
    
    // MARK: - Custom info banner
    
    private var customInfoBanner: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 18))
                .foregroundColor(.orange)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Custom Info Banner")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.orange)
                
                Text("This is a custom styled info banner using your own UI design.")
                    .font(.system(size: 12))
                    .foregroundColor(.orange.opacity(0.8))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }
    
    // MARK: - Custom chip view
    
    private func customChipView(for text: String) -> some View {
        HStack(spacing: 4) {
            Text(text)
                .font(.system(size: 14))
            
            Button(action: {
                filterChips.remove(text)
                processQuery(filterChips.joined(separator: ", "))
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 12))
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(Color.blue.opacity(0.1))
        .foregroundColor(.blue)
        .cornerRadius(16)
    }
    
    // MARK: - Custom sheet view
    
    private var customSheetView: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Custom Ask AI")
                    .font(.headline)
                
                Spacer()
                
                Button(action: {
                    showCustomSheet = false
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.gray)
                }
            }
            .padding()
            
            VStack(alignment: .leading) {
                Text("Enter your query:")
                    .font(.subheadline)
                
                TextEditor(text: $userQuery)
                    .padding(8)
                    .frame(height: 150)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
            }
            .padding(.horizontal)
            
            Button(action: {
                processQuery(userQuery)
                showCustomSheet = false
            }) {
                Text("Submit Query")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .padding(.top)
    }
    
    // MARK: - Business Logic
    
    // Package UI Flow - Process query using AskAIService
    private func processQuery(_ query: String) {
        userQuery = query
        
        Task {
            do {
                // Create sample dates for demonstration
                let calendar = Calendar.current
                let checkinDate = calendar.date(byAdding: .day, value: 7, to: Date())
                let checkoutDate = calendar.date(byAdding: .day, value: 9, to: Date())
                
                let response = try await RiviAskAI.performAskAIRequest(
                    query: userQuery,
                    searchId: searchId,
                    isRound: false,
                    queryType: selectedQueryType,
                    language: selectedLanguage,
                    currency: "SAR",
                    checkin: checkinDate,
                    checkout: checkoutDate,
                    destination: selectedQueryType == .hotel ? "Singapore" : "Dubai",
                    origin: "Riyadh",
                    authToken: authToken
                )
                
                filterChips = response.chips
                parameterChangeNotice = response.parameterChangeNotice
                
                // Show alert if there's a parameter change notice
                if !(response.parameterChangeNotice?.isEmpty ?? true) {
                    withAnimation(.easeInOut) {
                        showAlert = true
                    }
                }
            } catch {
                print("Error: \(error)")
            }
        }
    }
    
    // SSE Subscription Flow - Subscribe to events
    private func subscribeToEvents() {
        RiviAskAI.subscribeToEvents(
            searchId: searchId,
            authToken: authToken,
            onEvent: { eventData in
                // Limit the number of displayed events to avoid memory issues
                if self.sseEvents.count > 100 {
                    self.sseEvents.removeFirst(50)
                }
                self.sseEvents.append(eventData)
                self.isSubscribed = true
            },
            onError: { error in
                self.sseEvents.append("ERROR: \(error.localizedDescription)")
                self.isSubscribed = false
            }
        )
        isSubscribed = true
    }
    
    // SSE Subscription Flow - Unsubscribe from events
    private func unsubscribeFromEvents() {
        RiviAskAI.disconnect()
        isSubscribed = false
        sseEvents.append("Disconnected from SSE stream")
    }
    
    // Sort Best - Automatic sorting without query
    private func performSortBest() {
        Task {
            do {
                // Create sample dates for demonstration
                let calendar = Calendar.current
                let checkinDate = calendar.date(byAdding: .day, value: 7, to: Date())
                let checkoutDate = calendar.date(byAdding: .day, value: 9, to: Date())
                
                let response = try await RiviAskAI.performSortBestRequest(
                    searchId: searchId,
                    isRound: false,
                    queryType: selectedQueryType,
                    language: selectedLanguage,
                    currency: "SAR",
                    checkin: checkinDate,
                    checkout: checkoutDate,
                    destination: selectedQueryType == .hotel ? "Singapore" : "Dubai",
                    origin: "Riyadh",
                    authToken: authToken
                )
                
                filterChips = response.chips
                parameterChangeNotice = response.parameterChangeNotice
                
                // Access raw response if needed
                if let entity = response.entity {
                    // Access any field from the entity
                    if let starRating = entity["star_rating"] as? [String] {
                        // starRating value
                    }
                }
                
                // Show alert if there's a parameter change notice
                if response.parameterChangeNotice != nil && !response.parameterChangeNotice!.isEmpty {
                    showAlert = true
                }
            } catch {
                print("Error: \(error)")
            }
        }
    }
}
