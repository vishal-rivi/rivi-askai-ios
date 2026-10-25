import SwiftUI
import RiviSmartSortElements
import RiviSmartSortSandbox

/// A reference results screen (flights and hotels) wired to Smart Sort V2, as a reference for the team.
///
/// Read it in the order of the numbered steps:
///   1. Create one `RiviSmartSort` session for the screen.
///   2. Report the search: a flight search or a hotel search.
///   3. Listen to events and order the list by Rivi's ranking while on Best.
///   4. Report your sort tab, your filters and the results you show.
///   5. Place the V2 views: the banner, the result prompt card, the Smart Sort button,
///      the filter sheet's prompt card, and the Smart Sort sheet.
///
/// Flights and hotels are wired the same way: the SDK picks its flight or hotel wording from the
/// search you report. Everything else (asking, streaming, chips, the explanation, errors, the
/// "leave Best?" confirmation) is handled by the SDK. The result details, the filters and the
/// filter sheets are the app's own (see ReferenceResultsSupport.swift).
struct ReferenceSmartSortView: View {
    // MARK: 1. The session

    /// One per results screen. A tenant app uses its tenant package instead:
    /// `RiviSmartSort(build: .bundled, environment: .production, locale: "ar", currency: "SAR")`.
    @StateObject private var smartSort = RiviSmartSort(
        tenant: RiviTenant(name: "rivi", tier: "basic"), // the staging sandbox tenant
        environment: .staging,
        locale: "en",
        currency: "SAR",
        auth: { ExampleConfig.stagingToken },
        logLevel: .debug
    )

    // MARK: The screen's own state

    @State private var product: QueryType = .flight
    @State private var language: Language = .english
    /// Every result Rivi has for this search (the `all` of each ranking event).
    @State private var entries: [RankingEntry] = []
    /// Rivi's order while on Best (the `ranking` of each ranking event). Empty off Best.
    @State private var bestOrder: [String] = []
    @State private var sortTab: ExampleSortTab = .best
    @State private var flightFilters = ExampleFilters()
    @State private var hotelFilters = ExampleHotelFilters()

    @State private var showSmartSort = false
    @State private var smartSortFocusesInput = false
    @State private var smartSortStartingExample: String?
    @State private var showFilters = false
    /// Set by "Try Smart Sort" in a filter sheet: open Smart Sort once that sheet is gone.
    @State private var opensSmartSortAfterFilters = false
    @State private var resultCardDismissed = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                results
                bottomBar
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            }
            .background(ExampleColor.screen)
            .navigationTitle("Reference")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
        }
        .environment(\.layoutDirection, language.layoutDirection)
        // The SDK's "Leaving Best will clear your preferences" dialog (step 4, sort tabs).
        .riviSmartSortConfirmation(smartSort)
        // 5e. The Smart Sort sheet. It stays open while it ranks and closes itself when done.
        .sheet(isPresented: $showSmartSort, onDismiss: {
            smartSortStartingExample = nil
            smartSortFocusesInput = false
        }) {
            RiviSmartSortV2BottomSheet(
                smartSort,
                isPresented: $showSmartSort,
                // Turns on the filters note (off by default), see `smartSortSheetConfiguration`.
                configuration: smartSortSheetConfiguration,
                focusesInputOnAppear: smartSortFocusesInput,
                startingExample: smartSortStartingExample,
                // The ask carries the filters on screen (already reported above; shown here explicitly).
                filters: product == .flight ? flightFilters.json : hotelFilters.json,
                // The same filters in words: "Your filters (Nonstop, Morning) will now be used to rank flights."
                filterLabels: product == .flight ? flightFilters.labels : hotelFilters.labels
            )
        }
        // 5d. The app's filter sheet, with Smart Sort's prompt card inside.
        .sheet(isPresented: $showFilters, onDismiss: {
            if opensSmartSortAfterFilters {
                opensSmartSortAfterFilters = false
                openSmartSort(focusingInput: true)
            }
        }) {
            filterSheet
        }
        .onAppear {
            smartSort.onEvent = handle // step 3
            if smartSort.search == nil { newSearch() } // step 2
        }
        // 4. Report your filters. You filter the list yourself, so this makes no request; the next ask
        // carries them, and the banner uses them to say when they hide recommended results.
        .onChange(of: flightFilters) { _ in reportFilters() }
        .onChange(of: hotelFilters) { _ in reportFilters() }
        // 4. Report the results you actually show, so Smart Sort knows what your filters hide.
        .onChange(of: shownIds) { ids in
            if !entries.isEmpty { smartSort.visible = ids }
        }
        .onChange(of: product) { _ in newSearch() }
        .onChange(of: language) { smartSort.setLocale($0.rawValue) }
    }

    // MARK: 2. Report the search

    /// Every new search: a new id, then the route and dates (flights) or the city and stay (hotels).
    private func newSearch() {
        entries = []
        bestOrder = []
        flightFilters = ExampleFilters()
        hotelFilters = ExampleHotelFilters()
        select(.best)
        resultCardDismissed = false
        let searchId = UUID().uuidString // your app: the search id of the results on screen
        let calendar = Calendar.current
        let start = calendar.date(byAdding: .day, value: 14, to: Date()) ?? Date()
        switch product {
        case .flight:
            smartSort.search = .flight(FlightSearch(
                searchId: searchId, tripType: .oneway, origin: "RUH", destination: "CAI",
                departureDate: RiviDate.string(from: start),
                cabin: .economy, pax: .init(adults: 1)
            ))
        case .hotel:
            let end = calendar.date(byAdding: .day, value: 3, to: start) ?? start
            smartSort.search = .hotel(HotelSearch(
                searchId: searchId, destination: "Cairo",
                checkin: RiviDate.string(from: start), checkout: RiviDate.string(from: end),
                rooms: 1, pax: .init(adults: 2)
            ))
        }
    }

    // MARK: 3. Events: apply the ranking

    private func handle(_ event: RiviSmartSortEvent) {
        switch event {
        case let .ranking(ranking, all, _):
            entries = all                      // every result (this demo's items come only from Rivi)
            bestOrder = ranking.map(\.id)      // empty off Best: use your own order
        case .rankingCleared:
            bestOrder = []                     // the query was cleared: back to your order until Rivi re-ranks
        case .sortChanged(let sort):
            if sort == .best { sortTab = .best } // e.g. the user kept their query in the confirmation
        case .confirmSortChange:
            break                              // `.riviSmartSortConfirmation` shows the dialog
        case .showHidden:
            clearFilters()                     // "Show matches": the simplest reveal is clearing filters
        case .error(let error):
            print("Smart Sort error: \(error.message)") // the views show the error state themselves
        }
    }

    // MARK: 4. Sort tabs and filters

    /// Only Best is Smart Sort's; any other tab is `.other`. Leaving Best with an active query
    /// asks first; if the user stays, `.sortChanged(.best)` moves the tab back.
    private func select(_ tab: ExampleSortTab) {
        sortTab = tab
        smartSort.sort = tab == .best ? .best : .other
    }

    /// Your filters as any JSON; nil when none are on. Sent with the next ask, never on their own.
    private func reportFilters() {
        smartSort.filters = product == .flight ? flightFilters.json : hotelFilters.json
    }

    private func clearFilters() {
        flightFilters = ExampleFilters()
        hotelFilters = ExampleHotelFilters()
    }

    private var filterCount: Int { product == .flight ? flightFilters.count : hotelFilters.count }

    // MARK: The list

    /// Rivi's order on Best; the app's own order on its other tabs.
    private func ordered<Item: Identifiable>(_ items: [Item], by ownOrder: (Item, Item) -> Bool) -> [Item] where Item.ID == String {
        guard sortTab == .best else { return items.sorted(by: ownOrder) }
        guard !bestOrder.isEmpty else { return items }
        let rank = Dictionary(bestOrder.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })
        return items.sorted { (rank[$0.id] ?? .max) < (rank[$1.id] ?? .max) }
    }

    private var orderedFlights: [ExampleFlight] {
        ordered(entries.map { ExampleFlight(id: $0.id) }) { a, b in
            sortTab == .fastest
                ? (a.durationMinutes, a.price) < (b.durationMinutes, b.price)
                : (a.price, a.durationMinutes) < (b.price, b.durationMinutes)
        }
    }

    private var orderedHotels: [ExampleHotel] {
        ordered(entries.map { ExampleHotel(id: $0.id) }) { a, b in
            sortTab == .topRated ? (a.rating, -a.pricePerNight) > (b.rating, -b.pricePerNight) : a.pricePerNight < b.pricePerNight
        }
    }

    private var shownFlights: [ExampleFlight] { orderedFlights.filter(flightFilters.matches) }
    private var shownHotels: [ExampleHotel] { orderedHotels.filter(hotelFilters.matches) }
    private var shownIds: [String] { product == .flight ? shownFlights.map(\.id) : shownHotels.map(\.id) }

    private var hasQuery: Bool { !smartSort.state.query.isEmpty }

    private var results: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                header

                // 5a. The banner: chips, the streamed explanation, loading, errors, and the
                // filter notice when your filters hide recommended results. Hidden until the user asks.
                RiviSmartSortV2Banner(
                    smartSort,
                    onEdit: { openSmartSort(focusingInput: false) },
                    onClearFilters: clearFilters
                )

                let ids = shownIds
                if entries.isEmpty {
                    ProgressView(product == .flight ? "Loading flights…" : "Loading hotels…")
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                } else if ids.isEmpty {
                    Text("Nothing matches these filters.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                }

                switch product {
                case .flight:
                    ForEach(Array(shownFlights.enumerated()), id: \.element.id) { index, flight in
                        ExampleFlightCard(flight: flight, topTag: topTag(at: index), tags: tags(for: flight.id))
                        resultPromptCard(after: index, of: ids.count)
                    }
                case .hotel:
                    ForEach(Array(shownHotels.enumerated()), id: \.element.id) { index, hotel in
                        ExampleHotelCard(hotel: hotel, topTag: topTag(at: index), tags: tags(for: hotel.id))
                        resultPromptCard(after: index, of: ids.count)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 96) // room for the bottom bar
        }
    }

    /// 5b. The result prompt card, after the 4th result while Smart Sort is off.
    @ViewBuilder
    private func resultPromptCard(after index: Int, of count: Int) -> some View {
        if index == 3 && !hasQuery && !resultCardDismissed && count >= 6 {
            SmartSortPromptResultCard(
                queryType: product,
                onTap: { example in openSmartSort(focusingInput: true, startingExample: example) },
                onDismiss: { resultCardDismissed = true }
            )
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Product", selection: $product) {
                Text("Flights").tag(QueryType.flight)
                Text("Hotels").tag(QueryType.hotel)
            }
            .pickerStyle(.segmented)

            Text("\(shownIds.count) \(product == .flight ? "Flights" : "Hotels")")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Group {
                if product == .flight {
                    HStack(spacing: 6) {
                        Text("Riyadh")
                        Image(systemName: "arrow.right").font(.system(size: 16, weight: .semibold))
                        Text("Cairo")
                    }
                } else {
                    Text("Hotels in Cairo · 3 nights")
                }
            }
            .font(.system(size: 22, weight: .bold))
            Text("Sorted by \(sortTab.title)" + (smartSort.rankingStatus == .provisional && sortTab == .best ? " · updating…" : ""))
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
    }

    /// "BEST MATCH" on the top result while a query is active, or "BEST IN YOUR FILTERS" when
    /// your filters are on (the top match may be hidden).
    private func topTag(at index: Int) -> String? {
        guard index == 0, hasQuery, sortTab == .best else { return nil }
        return filterCount == 0 ? "BEST MATCH" : "BEST IN YOUR FILTERS"
    }

    /// Smart Sort's localized tags for a result, while a query is active.
    private func tags(for id: String) -> [String] {
        hasQuery ? smartSort.tags(for: id) : []
    }

    // MARK: 5c. The bottom bar

    private var bottomBar: some View {
        HStack(spacing: 0) {
            // Smart Sort, with the active preference count. Disabled where Smart Sort isn't
            // available (multi-city, the return leg).
            Button { openSmartSort(focusingInput: false) } label: {
                SmartSortTwinkleText(count: smartSort.chips.count)
            }
            .buttonStyle(.plain)
            .disabled(!smartSort.isAvailable)
            .opacity(smartSort.isAvailable ? 1 : 0.5)
            .fixedSize() // never truncate "Smart Sort"; Sort and Filter share the rest

            divider

            Menu {
                ForEach(ExampleSortTab.tabs(for: product)) { tab in
                    Button { select(tab) } label: {
                        if tab == sortTab { Label(tab.title, systemImage: "checkmark") } else { Text(tab.title) }
                    }
                }
            } label: {
                Label("Sort", systemImage: "arrow.up.arrow.down")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(ExampleColor.accent)
                    .frame(maxWidth: .infinity)
            }

            divider

            Button { showFilters = true } label: {
                HStack(spacing: 5) {
                    Image(systemName: "line.3.horizontal.decrease")
                    Text("Filter")
                    if filterCount > 0 {
                        Text("\(filterCount)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(minWidth: 18, minHeight: 18)
                            .background(Circle().fill(ExampleColor.accent))
                    }
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(ExampleColor.accent)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
        }
        .padding(6)
        .background(Capsule().fill(Color(.systemBackground)).shadow(color: .black.opacity(0.12), radius: 12, y: 4))
    }

    private var divider: some View {
        Rectangle().fill(ExampleColor.border).frame(width: 1, height: 24)
    }

    // MARK: 5d. Filter sheets

    @ViewBuilder
    private var filterSheet: some View {
        // "Try Smart Sort" applies the picked filters, closes the sheet, then opens Smart Sort.
        let trySmartSort = {
            opensSmartSortAfterFilters = true
            showFilters = false
        }
        switch product {
        case .flight:
            ExampleFilterSheet(isPresented: $showFilters, applied: $flightFilters, flights: orderedFlights, onTrySmartSort: trySmartSort)
        case .hotel:
            ExampleHotelFilterSheet(isPresented: $showFilters, applied: $hotelFilters, hotels: orderedHotels, onTrySmartSort: trySmartSort)
        }
    }

    // MARK: Opening Smart Sort

    /// The sheet's defaults, plus the filters note: off by default, this screen opts in.
    private var smartSortSheetConfiguration: SmartSortV2BottomSheet.Configuration {
        var configuration = SmartSortV2BottomSheet.Configuration.default
        configuration.showsFiltersNote = true
        return configuration
    }

    /// The Smart Sort button and "Edit" open it as is; the prompt cards open it with the
    /// keyboard up, the result card starting on the example it was showing.
    private func openSmartSort(focusingInput: Bool, startingExample: String? = nil) {
        guard smartSort.isAvailable else { return }
        smartSortFocusesInput = focusingInput
        smartSortStartingExample = startingExample
        showSmartSort = true
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button("New search", action: newSearch)
        }
        ToolbarItem(placement: .topBarTrailing) {
            Picker("Language", selection: $language) {
                Text("EN").tag(Language.english)
                Text("AR").tag(Language.arabic)
            }
            .pickerStyle(.segmented)
            .frame(width: 96)
        }
    }
}
