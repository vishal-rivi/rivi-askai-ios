import SwiftUI
import RiviSmartSortElements
import RiviSmartSortSandbox
/// Smart Sort 2.0 demo.
///
/// The app never calls sort-best / ask / explain / subscribe or keeps chips in sync. It tells Smart Sort a few facts (the search, the sort tab, the leg, the filters)
/// and the package views update themselves.
struct SmartSortV2DemoView: View {
    @StateObject private var smartSort = RiviSmartSort(
        tenant: RiviTenant(name: "rivi", tier: "basic"), // the sandbox tenant, as in tenants/sandbox.json
        environment: .staging,
        locale: "en",
        currency: "USD",
        auth: { ExampleConfig.stagingToken },
        logLevel: .debug // requests, responses, stream frames and every rule step, in the Xcode console
    )
    @State private var queryType: QueryType = .flight
    @State private var language: Language = .english
    /// Generated; you can also paste one from a real search.
    @State private var searchId = UUID().uuidString
    @State private var roundTrip = false
    @State private var filtersActive = false
    @State private var showAskSheet = false
    @State private var showClassicSheet = false
    @State private var showV2Sheet = false
    /// Set when the result card opens the V2 sheet: the sheet's placeholder starts on its example.
    @State private var v2StartingExample: String?
    @State private var v2FocusesInput = false
    @State private var resultCardDismissed = false
    @State private var pickedFilterCount = 0
    @State private var results: [RankingEntry] = []
    @State private var log: [String] = []

    var body: some View {
        NavigationView {
            ScrollView(.vertical) {
                VStack(spacing: 24) {
                    intro
                    pickers
                    startSearch
                    askButtonSection
                    chipsSection
                    bannerSection
                    smartSortV2Section
                    promptCardsSection
                    dynamicBannerSection
                    sortTabsSection
                    resultsSection
                    advancedSection
                    eventLogSection

                    Button("Reset Demo") { smartSort.clearAll() }
                }
                .padding()
            }
            .navigationTitle("Smart Sort 2.0 Demo")
            .riviSmartSortConfirmation(smartSort)
        }
        .environment(\.layoutDirection, language.layoutDirection)
        .sheet(isPresented: $showAskSheet) {
            RiviSmartSortAskSheet(smartSort, isPresented: $showAskSheet)
        }
        .sheet(isPresented: $showClassicSheet) {
            RiviSmartSortBottomSheet(smartSort, isPresented: $showClassicSheet)
        }
        .sheet(isPresented: $showV2Sheet, onDismiss: { v2StartingExample = nil; v2FocusesInput = false }) {
            RiviSmartSortV2BottomSheet(smartSort, isPresented: $showV2Sheet,
                                       focusesInputOnAppear: v2FocusesInput, startingExample: v2StartingExample)
        }
        .onAppear {
            smartSort.onEvent = handle
            if smartSort.search == nil { reportSearch() } // Sort Best on open
        }
        .onChange(of: language) { newValue in smartSort.setLocale(newValue.rawValue) }
        .onChange(of: queryType) { _ in newSearch() }
    }

    // MARK: - Header

    private var intro: some View {
        Text("Your app only reports the search, the sort tab and its filters. The package views below update themselves.")
            .font(.footnote)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
    }

    private var pickers: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Query Type:").font(.subheadline)
                Picker("Query Type", selection: $queryType) {
                    Text("Hotel").tag(QueryType.hotel)
                    Text("Flight").tag(QueryType.flight)
                }
                .pickerStyle(SegmentedPickerStyle())
            }
            HStack {
                Text("Language:").font(.subheadline)
                Picker("Language", selection: $language) {
                    Text("English").tag(Language.english)
                    Text("Arabic").tag(Language.arabic)
                }
                .pickerStyle(SegmentedPickerStyle())
            }
        }
    }

    private var startSearch: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Search ID:").font(.subheadline).bold()
            TextField("searchId", text: $searchId)
                .textFieldStyle(.roundedBorder)
                .font(.footnote.monospaced())
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            HStack {
                Button("Sort Best") { newSearch() }
                    .buttonStyle(.borderedProminent)
                Button("Use this ID") { reportSearch() }
                    .buttonStyle(.bordered)
                    .disabled(searchId.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            Text("Sort Best starts a new search with a fresh ID; Smart Sort ranks it by itself. Logs are in the Xcode console.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 1–3: the package views

    private var askButtonSection: some View {
        section("1. RiviAskButton:", caption: smartSort.isAvailable
            ? "Opens the ask sheet. The second button opens the classic Smart Sort sheet."
            : "Disabled until a search is reported (and on the return leg).") {
            HStack {
                RiviSmartSortAskButton(smartSort) { showAskSheet = true }
                RiviSmartSortAskButton(smartSort) { showClassicSheet = true }
                Spacer()
            }
        }
    }

    private var chipsSection: some View {
        section("2. RiviChipsView:", caption: smartSort.chips.isEmpty
            ? "Ask something to see chips. Removing a chip re-asks by itself."
            : "Tap ✕ to remove a chip, or Clear all.") {
            RiviSmartSortChips(smartSort)
        }
    }

    private var bannerSection: some View {
        section("3. RiviInfoBanner:", caption: bannerCaption) {
            RiviSmartSortBanner(smartSort)
        }
    }

    private var bannerCaption: String {
        switch smartSort.banner {
        case .hidden: return "Appears after you ask."
        case .loading: return "Waiting for the explanation…"
        case .explanation, .refreshing: return "Rivi's explanation of the new order."
        case .fallback: return "No explanation: some results don't match everything you asked."
        case .conflict: return "None of the results shown match your query."
        }
    }

    // MARK: - 6: Smart Sort V2

    private var smartSortV2Section: some View {
        section("6. Smart Sort V2:", caption: "The label shows the active preference count and stops animating while Smart Sort is active. "
            + "Improve Results closes the sheet; the banner in section 8 shows the ranking's progress and any error.") {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 24) {
                    SmartSortSparkle(size: 20)
                    SmartSortSparkle(size: 32)
                    SmartSortSparkle(size: 56)
                    SmartSortSparkle(size: 32, isAnimating: false)
                }
                .padding(.vertical, 8)

                HStack(spacing: 12) {
                    Button { if smartSort.isAvailable { showV2Sheet = true } } label: {
                        SmartSortTwinkleText(count: smartSort.chips.count)
                    }
                    .buttonStyle(.plain)
                    .disabled(!smartSort.isAvailable)
                    SmartSortTwinkleText(count: 2) // the active look, for comparison
                }
            }
        }
    }

    /// Opens the live V2 sheet with the keyboard up, as the prompt cards do.
    private func openV2Sheet(startingExample: String? = nil) {
        guard smartSort.isAvailable else { return }
        v2StartingExample = startingExample
        v2FocusesInput = true
        showV2Sheet = true
    }

    // MARK: - 7: prompt cards

    private var promptCardsSection: some View {
        section("7. Prompt cards:", caption: "The result card goes in your results list while Smart Sort is off; tapping it opens the sheet "
            + "with its placeholder starting on the example on screen. The filter card goes at the top of your filter sheet; it outlines itself from 4 picked filters.") {
            VStack(alignment: .leading, spacing: 16) {
                if smartSort.chips.isEmpty && !resultCardDismissed {
                    SmartSortPromptResultCard(
                        queryType: queryType,
                        onTap: { example in openV2Sheet(startingExample: example) },
                        onDismiss: { resultCardDismissed = true }
                    )
                } else {
                    Button("Show the result card again") { resultCardDismissed = false; smartSort.clearAll() }
                        .font(.footnote)
                }

                SmartSortPromptFilterCard(queryType: queryType, isHighlighted: pickedFilterCount >= 4) {
                    openV2Sheet()
                }
                Stepper("Filters picked: \(pickedFilterCount)", value: $pickedFilterCount, in: 0...6)
                    .font(.footnote)
            }
        }
    }

    // MARK: - 8: dynamic banner

    private var dynamicBannerSection: some View {
        section("8. SmartSortV2DynamicBanner:", caption: "Live: appears once you ask; Edit reopens the V2 sheet, ✕ clears, a chip's ✕ re-asks without it. "
            + "Ask, then turn your filters on to see the filter notice. "
            + "Simulated: Stream sends the explanation in growing snapshots; Filters and Clash show the two notices.") {
            VStack(alignment: .leading, spacing: 16) {
                RiviSmartSortV2Banner(smartSort, onEdit: { openV2Sheet() }, onClearFilters: { setFilters(false) })
                Toggle("My app's filters are on", isOn: Binding(get: { filtersActive }, set: { setFilters($0) }))
                    .font(.footnote)
                SimulatedV2Banner()
            }
        }
    }

    // MARK: - 4–5: what your app owns

    private var sortTabsSection: some View {
        section("4. Your sort tabs:", caption: "Leaving Best with a query asks for confirmation first.") {
            Picker("Sort", selection: Binding(get: { smartSort.sort }, set: { smartSort.sort = $0 })) {
                Text("Best").tag(SortMode.best)
                Text("Cheapest").tag(SortMode.other) // any of your own tabs reports .other
            }
            .pickerStyle(SegmentedPickerStyle())
        }
    }

    private var resultsSection: some View {
        section("5. Your results list:", caption: resultsCaption) {
            VStack(spacing: 6) {
                ForEach(results.prefix(10)) { entry in
                    HStack(spacing: 8) {
                        Text("\(entry.rank + 1)")
                            .font(.caption.bold())
                            .frame(width: 22)
                        Text(shortId(entry.id))
                            .font(.footnote.monospaced())
                            .lineLimit(1)
                        Spacer()
                        ForEach(entry.tags, id: \.self) { tag(Text($0), color: .blue) }
                        if !entry.matchesAllPreferences { tag(Text("Partial match"), color: .orange) }
                    }
                    .padding(8)
                    .background(Color.gray.opacity(0.08))
                    .cornerRadius(8)
                }
                if results.count > 10 {
                    Text("+ \(results.count - 10) more").font(.caption).foregroundColor(.secondary)
                }
            }
        }
    }

    private var resultsCaption: String {
        if smartSort.sort != .best { return "Off Best: your app uses its own order." }
        if results.isEmpty { return smartSort.search == nil ? "Report a search to start." : "Waiting for Rivi's ranking…" }
        return smartSort.rankingStatus == .final ? "Ordered by Rivi." : "Ordered by Rivi (still updating)."
    }

    // MARK: - Advanced

    private var advancedSection: some View {
        DisclosureGroup("More scenarios") {
            VStack(alignment: .leading, spacing: 12) {
                Toggle("My app's filters are on", isOn: Binding(get: { filtersActive }, set: { setFilters($0) }))
                Text("Filters are applied by your app. Changing them makes no request; the next ask sends them.")
                    .font(.caption).foregroundColor(.secondary)

                if queryType == .flight {
                    Toggle("Round trip", isOn: Binding(get: { roundTrip }, set: { roundTrip = $0; newSearch() }))
                    if roundTrip {
                        Picker("Leg", selection: Binding(get: { smartSort.stage }, set: { smartSort.stage = $0 })) {
                            Text("Onward").tag(Stage.onward)
                            Text("Return").tag(Stage.return)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        Text("Smart Sort hides itself on the return leg.")
                            .font(.caption).foregroundColor(.secondary)
                    }
                }
            }
            .padding(.top, 8)
        }
        .font(.subheadline)
    }

    private var eventLogSection: some View {
        DisclosureGroup("What Smart Sort told the app (\(log.count))") {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(log.enumerated()), id: \.offset) { _, line in
                    Text(line).font(.caption.monospaced()).foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.top, 8)
        }
        .font(.subheadline)
    }

    // MARK: - Facts and events

    /// Your app's filters: no request now; the next ask carries them.
    private func setFilters(_ active: Bool) {
        filtersActive = active
        smartSort.filters = active ? ["stops": [0]] : nil
    }

    /// A fresh search id, then Sort Best.
    private func newSearch() {
        searchId = UUID().uuidString
        results = []
        reportSearch()
    }

    /// Reports the search, dated a week from today.
    private func reportSearch() {
        let id = searchId.trimmingCharacters(in: .whitespaces)
        guard !id.isEmpty else { return }
        let calendar = Calendar.current
        let departure = calendar.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        let back = calendar.date(byAdding: .day, value: 9, to: Date()) ?? Date()
        switch queryType {
        case .flight:
            smartSort.search = .flight(FlightSearch(
                searchId: id, tripType: roundTrip ? .round : .oneway, origin: "RUH", destination: "DXB",
                departureDate: RiviDate.string(from: departure), returnDate: roundTrip ? RiviDate.string(from: back) : nil,
                cabin: .economy, pax: .init(adults: 1)
            ))
        case .hotel:
            smartSort.search = .hotel(HotelSearch(
                searchId: id, destination: "Singapore", checkin: RiviDate.string(from: departure),
                checkout: RiviDate.string(from: back), rooms: 1, pax: .init(adults: 1)
            ))
        }
        append("Reported search \(id.prefix(8))… (\(queryType.rawValue))")
    }

    private func handle(_ event: RiviSmartSortEvent) {
        switch event {
        case let .ranking(ranking, _, status):
            results = ranking
            append("New order: \(ranking.count) results (\(status.rawValue))")
        case .rankingCleared:
            results = []
            append("Query cleared: use your own order")
        case .confirmSortChange(let sort):
            append("Asking before switching to \(sort.rawValue)")
        case .sortChanged(let sort):
            append("Set your sort tab to \(sort.rawValue)")
        case .error(let error):
            append("Error: \(error.message)")
        case .showHidden(let ids):
            append("Show hidden results: \(ids.count)")
        }
    }

    private func append(_ line: String) {
        log.insert(line, at: 0)
        if log.count > 30 { log.removeLast() }
    }

    // MARK: - Helpers

    private func section<Content: View>(_ title: String, caption: String,
                                         @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.subheadline).bold()
            content()
            Text(caption).font(.caption).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func tag(_ text: Text, color: Color) -> some View {
        text.font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.12))
            .foregroundColor(color)
            .cornerRadius(4)
    }

    /// Itinerary ids are `<searchId>__<suffix>`: show the suffix.
    private func shortId(_ id: String) -> String {
        guard let range = id.range(of: "__", options: .backwards) else { return id }
        return String(id[range.upperBound...])
    }
}

/// `SmartSortV2DynamicBanner` with fake data: a streamed explanation, loading and an error.
private struct SimulatedV2Banner: View {
    private static let explanation = "Results sorted based on your preferences. Flights departing after 6 PM are ranked higher in these results. "
        + "Some results may not match all your preferences."

    private static let sampleChips: Set<String> = ["Departure: Before 12PM", "Stops: Direct", "Airline: Saudia"]

    @State private var chips = Self.sampleChips
    @State private var text = Self.explanation
    @State private var isLoading = false
    @State private var isShowingError = false
    @State private var filterNotice: SmartSortV2DynamicBanner.FilterNotice?
    @State private var streamTask: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SmartSortV2DynamicBanner(
                chips: $chips,
                explanation: text,
                isLoading: isLoading,
                isShowingError: isShowingError,
                filterNotice: filterNotice,
                onEdit: {},
                onClear: { chips = []; text = "" },
                onRemoveChip: { _ in },
                onRetry: { isShowingError = false; stream() },
                onDismissError: { isShowingError = false },
                onClearFilters: { filterNotice = nil }
            )
            HStack {
                Button("Stream") { stream() }
                Button("Loading") { streamTask?.cancel(); isLoading.toggle() }
                Button("Error") { isShowingError.toggle() }
                Button("Reset") {
                    streamTask?.cancel(); chips = Self.sampleChips; text = Self.explanation
                    isLoading = false; isShowingError = false; filterNotice = nil
                }
            }
            HStack {
                Button("Filters") { filterNotice = filterNotice?.tone == .info ? nil : .hidingRecommended(.flight) }
                Button("Clash") { filterNotice = filterNotice?.tone == .warning ? nil : .hidingMatches(.flight) }
            }
            .buttonStyle(.bordered)
            .font(.caption)
        }
    }

    /// Loading for a beat, then the explanation in cumulative snapshots of a few words each.
    private func stream() {
        streamTask?.cancel()
        streamTask = Task { @MainActor in
            text = ""
            isLoading = true
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            isLoading = false
            let words = Self.explanation.split(separator: " ")
            var count = 0
            while count < words.count && !Task.isCancelled {
                count = min(count + 4, words.count)
                text = words.prefix(count).joined(separator: " ")
                try? await Task.sleep(nanoseconds: 250_000_000)
            }
        }
    }
}
