import SwiftUI
import RiviAskAI

struct ContentView: View {
    @State private var selectedFlow = 0
    @State private var showAskAISheet = false
    @State private var isAskAIButtonEnabled = false
    @State private var filterChips: Set<String> = []
    @State private var userQuery: String = ""
    
    // Custom UI states
    @State private var showCustomSheet = false
    
    // SSE subscription states
    @State private var isSubscribed = false
    @State private var sseEvents: [String] = []
    
    // Constants for API calls
    private let searchId = "682c4f4e8b9a1305495cb861"
    private let authToken = "99d477cbcb65dcf06a992bb808061362ba2f2050c217ee488acbd708610b4012"
    
    var body: some View {
        NavigationView {
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
            .navigationTitle("RiviAskAI Demo")
            .padding()
        }
    }
    
    // MARK: - Package UI Flow
    
    private var packageUIFlow: some View {
        VStack(spacing: 24) {
            Text("Using Package UI Components")
                .font(.headline)
            
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
            
            // 2. Show the Ask AI button
            VStack(alignment: .leading) {
                Text("2. RiviAskAIButton:")
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
            Button("Reset Demo") {
                filterChips = []
                userQuery = ""
            }
            .padding(.top, 20)
        }
        .sheet(isPresented: $showAskAISheet) {
            RiviAskAISheet(isPresented: $showAskAISheet) { query in
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
            
            // 2. Custom Ask AI button
            VStack(alignment: .leading) {
                Text("2. Custom Ask AI Button:")
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
            }
            .padding(.top, 20)
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
                filterChips = try await RiviAskAI.performAskAIRequest(
                    query: userQuery,
                    searchId: searchId,
                    isRound: false,
                    authToken: authToken
                )
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
}
