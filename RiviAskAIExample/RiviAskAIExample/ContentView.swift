import SwiftUI
import RiviAskAI

struct ContentView: View {
    @State private var selectedFlow = 0
    @State private var showAskAISheet = false
    @State private var isAskAIButtonEnabled = false
    @State private var filterChips: Set<String> = []
    @State private var userQuery: String = ""
    @State private var parameterChangeNotice: String? = nil
    @State private var explainContent: String? = nil
    @State private var showAlert = false
    @State private var showConfirmationDialog = false
    @State private var showAlmatarAskAISheet = false
    @State private var isProcessing: Bool = false

    // First-time onboarding banner customization
    @State private var coachmarkNotchEdge: RiviAskAIFirstTimeBannerNotchEdge = .top
    @State private var coachmarkIconAlignTop: Bool = true
    @State private var coachmarkIconPlacement: RiviAskAIFirstTimeBannerIconPlacement = .top
    /// Bumped whenever the user replays onboarding — re-mounts the `RiviAskAIButton`
    /// via `.id(...)` so its first-appearance coachmark fires again with the latest config.
    @State private var coachmarkResetCounter: Int = 0
    
    // Custom UI states
    @State private var showCustomSheet = false
    
    // SSE subscription states
    @State private var isSubscribed = false
    @State private var sseEvents: [String] = []
    
    // Query type selection
    @State private var selectedQueryType: QueryType = .hotel
    @State private var selectedLanguage: Language = .english
    
    // Layout direction based on language
    @State private var layoutDirection: LayoutDirection = .leftToRight
    
    // Constants for API calls
    private let searchId = UUID().uuidString
 
    init() {
        RiviAskAI.initialize(
            environment: .staging,
            authToken: "",
            language: .english
        )
    }

    private func registerExplainHandlers() {
        RiviAskAIConfiguration.shared.onExplainContent = { partial in
            explainContent = partial
        }
        RiviAskAIConfiguration.shared.onExplainError = { error in
            print("Explain-AI error: \(error)")
        }
    }
    
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
                .padding()
            }
            .navigationTitle("RiviAskAI Demo")
            .overlay {
                if showAlert {
                    RiviAlertDialog(isPresented: $showAlert) {
                        print("Alert dismissed")
                    }
                }
                
                if showConfirmationDialog {
                    RiviConfirmationDialog(
                        isPresented: $showConfirmationDialog,
                        onCancel: {
                            print("Confirmation cancelled")
                        },
                        onConfirm: {
                            print("Confirmation confirmed - clearing query")
                            filterChips = []
                            userQuery = ""
                        }
                    )
                }
            }
            .onAppear {
                registerExplainHandlers()
            }
            .onChange(of: selectedLanguage) { _, newValue in
                // Reinitialize RiviAskAI with new language
                RiviAskAI.initialize(
                    environment: .staging,
                    authToken: "",
                    language: newValue
                )
                
                // Update layout direction
                withAnimation {
                    layoutDirection = RiviAskAIConfiguration.shared.language.layoutDirection
                }
                
                print("Language changed to: \(newValue == .english ? "English" : "Arabic")")
            }
        }
        .environment(\.layoutDirection, layoutDirection)
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
            
            // 2. Show the info banner (shimmer while a request is in flight)
            if !filterChips.isEmpty || isProcessing {
                VStack(alignment: .leading) {
                    Text("2. RiviInfoBanner:")
                        .font(.subheadline)
                        .bold()

                    RiviInfoBanner(
                        configuration: infoBannerConfiguration,
                        isLoading: isProcessing
                    )
                }
            }
            
            // 3. Show the Ask AI button
            VStack(alignment: .leading, spacing: 8) {
                Text("3. RiviAskAIButton:")
                    .font(.subheadline)
                    .bold()

                // First-time onboarding banner customization controls
                VStack(alignment: .leading, spacing: 6) {
                    Text("First-time banner:")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Button {
                                coachmarkNotchEdge = (coachmarkNotchEdge == .top) ? .bottom : .top
                            } label: {
                                Label(
                                    "Notch: \(coachmarkNotchEdge == .top ? "Top" : "Bottom")",
                                    systemImage: coachmarkNotchEdge == .top ? "arrow.up" : "arrow.down"
                                )
                                .font(.caption)
                            }
                            .buttonStyle(.bordered)

                            Button {
                                coachmarkIconAlignTop.toggle()
                            } label: {
                                Label(
                                    "Align: \(coachmarkIconAlignTop ? "Top" : "Center")",
                                    systemImage: coachmarkIconAlignTop ? "arrow.up.to.line" : "minus"
                                )
                                .font(.caption)
                            }
                            .buttonStyle(.bordered)
                            .disabled(coachmarkIconPlacement == .top)
                        }

                        HStack(spacing: 8) {
                            Button {
                                coachmarkIconPlacement = (coachmarkIconPlacement == .leading) ? .top : .leading
                            } label: {
                                Label(
                                    "Icon: \(coachmarkIconPlacement == .leading ? "Leading" : "Above text")",
                                    systemImage: coachmarkIconPlacement == .leading
                                        ? "rectangle.lefthalf.inset.filled"
                                        : "rectangle.tophalf.inset.filled"
                                )
                                .font(.caption)
                            }
                            .buttonStyle(.bordered)

                            Button {
                                RiviAskAIFirstTimeBannerStorage.reset()
                                coachmarkResetCounter += 1
                            } label: {
                                Label("Replay", systemImage: "arrow.counterclockwise")
                                    .font(.caption)
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                }

                HStack {
                    RiviAskAIButton(
                        configuration: askAIButtonConfiguration,
                        isEnabled: $isAskAIButtonEnabled
                    ) {
                        showAskAISheet = true
                    }
                    .id(coachmarkResetCounter)

                    RiviAskAIButton(
                        configuration: askAIButtonConfiguration,
                        isEnabled: $isAskAIButtonEnabled
                    ) {
                        showAlmatarAskAISheet = true
                    }
                    .id(coachmarkResetCounter)
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
                    explainContent = nil
                    RiviAskAIFirstTimeBannerStorage.reset()
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
                parameterChangeNotice: parameterChangeNotice,
                onSubmit: { query in
                    processQuery(query)
                },
                onClear: {
                    filterChips = []
                    userQuery = ""
                    parameterChangeNotice = nil
                    explainContent = nil
                }
            )
        }
        .sheet(isPresented: $showAlmatarAskAISheet) {
            SmartSortBottomSheet(
                isPresented: $showAlmatarAskAISheet,
                queryType: selectedQueryType,
                userQuery: userQuery,
                parameterChangeNotice: parameterChangeNotice,
                onSubmit: { query in
                    processQuery(query)
                },
                onClear: {
                    filterChips = []
                    userQuery = ""
                    parameterChangeNotice = nil
                    explainContent = nil
                }
            )
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
                    // Same logic as the built-in RiviAskAIButton: the coachmark fires on
                    // the first appearance regardless of the button's enabled state,
                    // gated only by `RiviAskAIFirstTimeBannerStorage`.
                    .riviAskAIFirstTimeCoachmark(
                        onCTA: { showCustomSheet = true }
                    )

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
            
            // Test dialogs buttons
            HStack(spacing: 12) {
                Button("Test Alert Dialog") {
                    withAnimation(.easeInOut) {
                        showAlert = true
                    }
                }
                
                Button("Test Confirmation Dialog") {
                    withAnimation(.easeInOut) {
                        showConfirmationDialog = true
                    }
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
                
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(sseEvents.indices, id: \.self) { index in
                        Text(sseEvents[index])
                            .font(.system(size: 12, design: .monospaced))
                            .padding(8)
                            .background(Color.gray.opacity(0.1))
                            .lineLimit(10)
                            .cornerRadius(4)
                    }
                }
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
    
    // MARK: - Info banner configuration

    private var infoBannerConfiguration: RiviInfoBanner.Configuration {
        var config = RiviInfoBanner.Configuration.default
        if let content = explainContent, !content.isEmpty {
            config.descriptionText = content
        }
        return config
    }

    // MARK: - First-time coachmark configuration

    /// Builds a `RiviAskAIButton.Configuration` whose embedded first-time banner reflects
    /// the current `coachmarkNotchEdge` / `coachmarkIconAlignTop` toggles.
    private var askAIButtonConfiguration: RiviAskAIButton.Configuration {
        var banner = RiviAskAIFirstTimeBanner.Configuration.default
        banner.notchEdge = coachmarkNotchEdge
        banner.iconAlignment = coachmarkIconAlignTop ? .top : .center
        banner.iconPlacement = coachmarkIconPlacement

        var btn = RiviAskAIButton.Configuration.default
        btn.firstTimeBanner = banner
        return btn
    }

    // MARK: - Business Logic

    // Package UI Flow - Process query using AskAIService.
    // Note: with `onExplainContent` registered on RiviAskAIConfiguration, the SDK auto-fires
    // explain-ai for every non-empty query; the streamed content lands in `explainContent`.
    private func processQuery(_ query: String) {
        userQuery = query
        explainContent = nil

        Task {
            withAnimation { isProcessing = true }
            defer { Task { @MainActor in withAnimation { isProcessing = false } } }

            do {
                let calendar = Calendar.current
                let checkinDate = calendar.date(byAdding: .day, value: 7, to: Date())
                let checkoutDate = calendar.date(byAdding: .day, value: 9, to: Date())

                let response = try await RiviAskAI.performAskAIRequest(
                    query: userQuery,
                    searchId: searchId,
                    isRound: false,
                    queryType: selectedQueryType,
                    currency: "SAR",
                    checkin: checkinDate,
                    checkout: checkoutDate,
                    destination: selectedQueryType == .hotel ? "Singapore" : "Dubai",
                    origin: "Riyadh"
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
    
    // Sort Best - subscribe to SSE first, then call sort-best when the channel is connected
    // so the gateway can stream ranked results back through the open SSE.
    private func performSortBest() {
        let calendar = Calendar.current
        let checkinDate = calendar.date(byAdding: .day, value: 7, to: Date())
        let checkoutDate = calendar.date(byAdding: .day, value: 9, to: Date())
        let queryType = selectedQueryType
        let destination = queryType == .hotel ? "Singapore" : "DXB"
        let origin = queryType == .hotel ? "Riyadh" : "RUH"

        // 1) Kill any existing SSE so we don't pile connections on the same searchId
        RiviAskAI.disconnect()

        // Surface the skeleton on the info banner while sort-best is in flight
        withAnimation { isProcessing = true }

        // 2) Subscribe; when SSE state == .connected, fire sort-best
        RiviAskAI.subscribeToEvents(
            searchId: searchId,
            onState: { state in
                guard case .connected = state else { return }
                Task {
                    defer { Task { @MainActor in withAnimation { isProcessing = false } } }
                    do {
                        let response = try await RiviAskAI.performSortBestRequest(
                            searchId: searchId,
                            isRound: false,
                            queryType: queryType,
                            currency: "USD",
                            checkin: queryType == .hotel ? checkinDate : nil,
                            checkout: queryType == .hotel ? checkoutDate : nil,
                            departureDate: queryType == .flight ? checkinDate : nil,
                            returnDate: nil,
                            adults: 1,
                            children: 0,
                            infant: 0,
                            rooms: 1,
                            cabinType: "Economy",
                            destination: destination,
                            origin: origin
                        )
                        print("Sort-best successful; results will arrive via SSE chunks")
                        await MainActor.run {
                            filterChips = response.chips
                            parameterChangeNotice = response.parameterChangeNotice
                            if !(response.parameterChangeNotice?.isEmpty ?? true) {
                                withAnimation(.easeInOut) { showAlert = true }
                            }
                        }
                    } catch {
                        print("Sort-best failed: \(error)")
                    }
                }
            },
            onEvent: { eventData in
                if sseEvents.count > 100 { sseEvents.removeFirst(50) }
                sseEvents.append(eventData)
            },
            onError: { error in
                if (error as? URLError)?.code == .cancelled { return }
                print("Sort Best SSE error: \(error)")
            }
        )
    }
}
