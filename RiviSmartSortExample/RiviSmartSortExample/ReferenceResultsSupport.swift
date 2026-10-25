import SwiftUI
import RiviSmartSortElements
import RiviSmartSortSandbox

// The parts of the reference results screen that belong to the app, not to Smart Sort: its flight
// data, its filters, its flight card and its filter sheet. In the real app these already exist;
// what matters for Smart Sort is in ReferenceSmartSortView.swift.

// MARK: - Flight data

/// One flight in the results list.
///
/// In the real app this comes from your own search. Here, the staging sandbox only gives us
/// the result ids it ranks, so each id gets made-up (but stable) details. Smart Sort itself only
/// ever deals in ids.
struct ExampleFlight: Identifiable, Equatable {
    let id: String
    let airline: String
    let airlineCode: String
    let tileColor: Color
    let stops: Int
    let via: [String]
    /// Minutes after midnight.
    let departure: Int
    let durationMinutes: Int
    let price: Int

    private static let airlines: [(name: String, code: String, color: Color)] = [
        ("Saudia", "SV", Color(red: 0, green: 0.42, blue: 0.21)),
        ("flynas", "XY", Color(red: 0.72, green: 0.64, blue: 0)),
        ("flyadeal", "F3", Color(red: 0, green: 0.64, blue: 0.63)),
        ("EgyptAir", "MS", Color(red: 0.04, green: 0.17, blue: 0.43)),
        ("Emirates", "EK", Color(red: 0.84, green: 0.1, blue: 0.13)),
    ]
    static var airlineNames: [String] { airlines.map(\.name) }

    init(id: String) {
        let hash = stableHash(id)
        // Staging ids carry the real departure time and airline (`…T09:20XY…`): use them so the
        // cards agree with Rivi's explanation. Everything else is made up.
        let parsed = Self.parse(id)
        let airline = parsed.flatMap { code in Self.airlines.first { $0.code == code.airline } }
            ?? Self.airlines[Int(hash % 5)]
        self.id = id
        self.airline = airline.name
        self.airlineCode = airline.code
        self.tileColor = airline.color
        self.stops = [0, 0, 0, 1, 1, 2][Int((hash >> 8) % 6)]
        self.via = Array(["JED", "MED"].prefix(stops))
        self.departure = parsed?.departure ?? Int((hash >> 16) % 96) * 15
        self.durationMinutes = 160 + stops * 110 + Int((hash >> 24) % 50)
        self.price = 214 + Int((hash >> 32) % 90) * 10 + (stops == 0 ? 120 : 0)
    }

    /// The departure (minutes after midnight) and airline code in a staging id, if it has them.
    private static func parse(_ id: String) -> (departure: Int, airline: String)? {
        guard let match = id.range(of: #"T\d{2}:\d{2}[A-Z0-9]{2}"#, options: .regularExpression) else { return nil }
        let text = Array(id[match])
        guard let hours = Int(String(text[1...2])), let minutes = Int(String(text[4...5])) else { return nil }
        return (hours * 60 + minutes, String(text[6...7]))
    }

    var arrival: Int { departure + durationMinutes - 60 } // Cairo is an hour behind Riyadh
    var period: ExampleDayPeriod { ExampleDayPeriod(minutes: departure) }

    static func time(_ minutes: Int) -> String {
        let m = ((minutes % 1440) + 1440) % 1440
        return String(format: "%02d:%02d", m / 60, m % 60)
    }
}

/// FNV-1a: stable across launches, unlike Swift's `hashValue`.
func stableHash(_ text: String) -> UInt64 {
    var hash: UInt64 = 1_469_598_103_934_665_603
    for byte in text.utf8 { hash = (hash ^ UInt64(byte)) &* 1_099_511_628_211 }
    return hash
}

/// One hotel in the results list. Like `ExampleFlight`, made up from Rivi's id: the real app uses
/// its own hotel data.
struct ExampleHotel: Identifiable, Equatable {
    let id: String
    let name: String
    let area: String
    let stars: Int
    /// Guest rating out of 10.
    let rating: Double
    let reviews: Int
    let pricePerNight: Int
    let amenities: [String]

    static let amenityNames = ["Free breakfast", "Pool", "Gym", "Free parking", "Spa"]
    private static let names = [
        ("Four Seasons Nile Plaza", "Garden City"), ("Kempinski Nile Hotel", "Garden City"),
        ("Steigenberger El Tahrir", "Downtown"), ("Marriott Mena House", "Giza"),
        ("Sofitel Nile El Gezirah", "Zamalek"), ("Novotel Cairo Airport", "Heliopolis"),
        ("Hilton Cairo Zamalek", "Zamalek"), ("Fairmont Nile City", "Boulaq"),
    ]

    init(id: String) {
        let hash = stableHash(id)
        let place = Self.names[Int(hash % UInt64(Self.names.count))]
        self.id = id
        self.name = place.0
        self.area = place.1
        self.stars = 3 + Int((hash >> 8) % 3)
        self.rating = Double(70 + Int((hash >> 12) % 27)) / 10
        self.reviews = 200 + Int((hash >> 20) % 3000)
        self.pricePerNight = 280 + (stars - 3) * 450 + Int((hash >> 28) % 60) * 10
        self.amenities = Self.amenityNames.enumerated().filter { (hash >> (36 + UInt64($0.offset))) & 1 == 1 }.map(\.element)
    }
}

enum ExampleDayPeriod: String, CaseIterable, Identifiable {
    case morning, afternoon, evening, night
    var id: String { rawValue }
    var title: String { rawValue.capitalized }

    init(minutes: Int) {
        switch minutes / 60 {
        case 6..<12: self = .morning
        case 12..<18: self = .afternoon
        case 18..<24: self = .evening
        default: self = .night
        }
    }
}

// MARK: - Filters

/// The app's filters. The app filters its list with `matches`; Smart Sort receives `json` and sends
/// it with the next ask (a filter change alone makes no request).
struct ExampleFilters: Equatable {
    var stops: Set<Int> = []
    var departure: Set<ExampleDayPeriod> = []
    var airlines: Set<String> = []

    var count: Int { stops.count + departure.count + airlines.count }
    var isEmpty: Bool { count == 0 }

    func matches(_ flight: ExampleFlight) -> Bool {
        (stops.isEmpty || stops.contains(min(flight.stops, 2)))
            && (departure.isEmpty || departure.contains(flight.period))
            && (airlines.isEmpty || airlines.contains(flight.airline))
    }

    /// What `smartSort.filters` receives: any JSON. nil means no filters.
    /// The filters in words, for the Smart Sort sheet's "Your filters (…)" note.
    var labels: [String] {
        stops.sorted().map { ["Nonstop", "1 stop", "2+ stops"][$0] }
            + ExampleDayPeriod.allCases.filter(departure.contains).map(\.title)
            + airlines.sorted()
    }

    var json: JSONValue? {
        var pairs: [(String, JSONValue)] = []
        if !stops.isEmpty { pairs.append(("stops", .array(stops.sorted().map { .number(Double($0)) }))) }
        if !departure.isEmpty { pairs.append(("departure", .array(departure.map(\.rawValue).sorted().map { .string($0) }))) }
        if !airlines.isEmpty { pairs.append(("airlines", .array(airlines.sorted().map { .string($0) }))) }
        return pairs.isEmpty ? nil : .object(JSONObject(pairs))
    }
}

/// The app's hotel filters, reported the same way.
struct ExampleHotelFilters: Equatable {
    var stars: Set<Int> = []
    var amenities: Set<String> = []

    var count: Int { stars.count + amenities.count }
    var isEmpty: Bool { count == 0 }

    func matches(_ hotel: ExampleHotel) -> Bool {
        (stars.isEmpty || stars.contains(hotel.stars))
            && amenities.allSatisfy(hotel.amenities.contains)
    }

    /// The filters in words, for the Smart Sort sheet's "Your filters (…)" note.
    var labels: [String] {
        stars.sorted(by: >).map { "\($0)-star" } + amenities.sorted()
    }

    var json: JSONValue? {
        var pairs: [(String, JSONValue)] = []
        if !stars.isEmpty { pairs.append(("stars", .array(stars.sorted().map { .number(Double($0)) }))) }
        if !amenities.isEmpty { pairs.append(("amenities", .array(amenities.sorted().map { .string($0) }))) }
        return pairs.isEmpty ? nil : .object(JSONObject(pairs))
    }
}

// MARK: - Sort tabs

/// The app's sort options. Only Best is Smart Sort's; the others report `.other`.
enum ExampleSortTab: String, CaseIterable, Identifiable {
    case best, cheapest, fastest, topRated
    var id: String { rawValue }
    var title: String { self == .topRated ? "Top rated" : rawValue.capitalized }

    static func tabs(for product: QueryType) -> [ExampleSortTab] {
        product == .hotel ? [.best, .cheapest, .topRated] : [.best, .cheapest, .fastest]
    }
}

// MARK: - Colors

enum ExampleColor {
    static let accent = Color(red: 0.48, green: 0.25, blue: 0.89)        // #7B3FE4
    static let tint = Color(red: 0.94, green: 0.91, blue: 0.99)          // #EFE9FD
    static let screen = Color(red: 0.97, green: 0.97, blue: 0.98)
    static let border = Color(red: 0.93, green: 0.93, blue: 0.94)
    static let green = Color(red: 0.18, green: 0.62, blue: 0.31)
}

// MARK: - Flight card

struct ExampleFlightCard: View {
    let flight: ExampleFlight
    /// "BEST MATCH" and the like, above the card.
    let topTag: String?
    /// Smart Sort's localized tags for this result (`smartSort.tags(for:)`).
    let tags: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let topTag {
                Text(topTag)
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundStyle(ExampleColor.accent)
                    .padding(.horizontal, 8)
                    .frame(height: 20)
                    .background(Capsule().fill(ExampleColor.tint))
            }
            HStack(alignment: .top, spacing: 10) {
                Text(flight.airlineCode)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(flight.tileColor))
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(ExampleFlight.time(flight.departure))
                        Image(systemName: "airplane").font(.system(size: 11)).foregroundStyle(.secondary)
                        Text(ExampleFlight.time(flight.arrival))
                        if flight.arrival >= 1440 {
                            Text("+1").font(.system(size: 11, weight: .semibold)).foregroundStyle(.red)
                        }
                    }
                    .font(.system(size: 17, weight: .semibold))
                    Text((["RUH"] + flight.via + ["CAI"]).joined(separator: " - "))
                        .font(.system(size: 13))
                    Text(flight.airline)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 4) {
                    Text("SAR \(flight.price)")
                        .font(.system(size: 17, weight: .bold))
                    Text("+ \(flight.price * 12 / 10) points")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(ExampleColor.green)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(ExampleColor.green.opacity(0.1)))
                }
            }
            HStack {
                Text("\(flight.durationMinutes / 60)h \(flight.durationMinutes % 60)m • "
                     + (flight.stops == 0 ? "Direct" : "\(flight.stops) Stop\(flight.stops > 1 ? "s" : "")"))
                    .font(.system(size: 13))
                Spacer()
                Text("Baggage info ›").font(.system(size: 13)).foregroundStyle(.secondary)
            }
            if !tags.isEmpty {
                HStack(spacing: 6) {
                    ForEach(tags, id: \.self) { tag in
                        Text(tag)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(ExampleColor.accent)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(RoundedRectangle(cornerRadius: 6).fill(ExampleColor.tint))
                    }
                }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.systemBackground)))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(ExampleColor.border, lineWidth: 1))
    }
}

// MARK: - Filter sheet

/// The app's filter sheet, with Smart Sort's `SmartSortPromptFilterCard` at the top.
struct ExampleFilterSheet: View {
    @Binding var isPresented: Bool
    /// The applied filters. The sheet edits a draft and applies it with "Show N flights".
    @Binding var applied: ExampleFilters
    /// The flights before filtering, to count and price each option.
    let flights: [ExampleFlight]
    /// "Try Smart Sort": applies the draft, then the screen opens the Smart Sort sheet.
    let onTrySmartSort: () -> Void

    @State private var draft = ExampleFilters()

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Filter").font(.system(size: 18, weight: .bold))
                Spacer()
                if !draft.isEmpty {
                    Button("Clear all") { draft = ExampleFilters() }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(ExampleColor.accent)
                }
                ExampleCloseButton { isPresented = false }
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 8)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // Smart Sort's entry point in the filter sheet: outlined (and its sparkle pops)
                    // once the user has picked 4 or more filters.
                    SmartSortPromptFilterCard(queryType: .flight, isHighlighted: draft.count >= 4) {
                        applied = draft
                        onTrySmartSort()
                    }

                    section("Stops") {
                        ForEach([(0, "Nonstop"), (1, "1 stop"), (2, "2+ stops")], id: \.0) { value, title in
                            checkRow(title, isOn: draft.stops.contains(value), detail: priceFrom { min($0.stops, 2) == value }) {
                                draft.stops.formSymmetricDifference([value])
                            }
                        }
                    }
                    section("Departure time") {
                        HStack(spacing: 8) {
                            ForEach(ExampleDayPeriod.allCases) { period in
                                let isOn = draft.departure.contains(period)
                                Button(period.title) { draft.departure.formSymmetricDifference([period]) }
                                    .font(.system(size: 14))
                                    .foregroundStyle(isOn ? ExampleColor.accent : .primary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Capsule().fill(isOn ? ExampleColor.tint : .clear))
                                    .overlay(Capsule().stroke(isOn ? ExampleColor.accent : ExampleColor.border, lineWidth: 1))
                            }
                        }
                    }
                    section("Airlines") {
                        ForEach(ExampleFlight.airlineNames, id: \.self) { airline in
                            checkRow(airline, isOn: draft.airlines.contains(airline), detail: priceFrom { $0.airline == airline }) {
                                draft.airlines.formSymmetricDifference([airline])
                            }
                        }
                    }
                }
                .padding(16)
            }

            let count = flights.filter(draft.matches).count
            Button {
                applied = draft
                isPresented = false
            } label: {
                Text("Show \(count) flight\(count == 1 ? "" : "s")")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Capsule().fill(count == 0 ? ExampleColor.accent.opacity(0.4) : ExampleColor.accent))
            }
            .disabled(count == 0)
            .padding(16)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onAppear { draft = applied }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 16, weight: .semibold))
            content()
        }
    }

    private func checkRow(_ title: String, isOn: Bool, detail: String, toggle: @escaping () -> Void) -> some View {
        Button(action: toggle) {
            HStack(spacing: 12) {
                Image(systemName: isOn ? "checkmark.square.fill" : "square")
                    .font(.system(size: 20))
                    .foregroundStyle(isOn ? ExampleColor.accent : .secondary)
                Text(title).foregroundStyle(.primary)
                Spacer()
                Text(detail).font(.system(size: 13)).foregroundStyle(.secondary)
            }
            .frame(height: 40)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func priceFrom(_ match: (ExampleFlight) -> Bool) -> String {
        guard let cheapest = flights.filter(match).map(\.price).min() else { return "No flights" }
        return "from SAR \(cheapest)"
    }
}

// MARK: - Shared

struct ExampleCloseButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 32, height: 32)
                .background(Circle().fill(Color(.secondarySystemBackground)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Close")
    }
}

// MARK: - Hotel card

struct ExampleHotelCard: View {
    let hotel: ExampleHotel
    let topTag: String?
    let tags: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let topTag {
                Text(topTag)
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundStyle(ExampleColor.accent)
                    .padding(.horizontal, 8)
                    .frame(height: 20)
                    .background(Capsule().fill(ExampleColor.tint))
            }
            HStack(alignment: .top, spacing: 12) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(ExampleColor.tint)
                    .frame(width: 64, height: 64)
                    .overlay(Image(systemName: "building.2").font(.system(size: 22)).foregroundStyle(ExampleColor.accent))
                VStack(alignment: .leading, spacing: 3) {
                    Text(hotel.name)
                        .font(.system(size: 16, weight: .semibold))
                        .lineLimit(1)
                    Text(String(repeating: "★", count: hotel.stars) + " · " + hotel.area)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    HStack(spacing: 6) {
                        Text(String(format: "%.1f", hotel.rating))
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(RoundedRectangle(cornerRadius: 5).fill(ExampleColor.accent))
                        Text("\(hotel.reviews) reviews").font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 2) {
                    Text("SAR \(hotel.pricePerNight)").font(.system(size: 17, weight: .bold))
                    Text("per night").font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
            if !hotel.amenities.isEmpty {
                Text(hotel.amenities.joined(separator: " · "))
                    .font(.system(size: 12))
                    .foregroundStyle(ExampleColor.green)
            }
            if !tags.isEmpty {
                HStack(spacing: 6) {
                    ForEach(tags, id: \.self) { tag in
                        Text(tag)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(ExampleColor.accent)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(RoundedRectangle(cornerRadius: 6).fill(ExampleColor.tint))
                    }
                }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.systemBackground)))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(ExampleColor.border, lineWidth: 1))
    }
}

// MARK: - Hotel filter sheet

/// The app's hotel filter sheet, with the same Smart Sort prompt card (hotel wording).
struct ExampleHotelFilterSheet: View {
    @Binding var isPresented: Bool
    @Binding var applied: ExampleHotelFilters
    let hotels: [ExampleHotel]
    let onTrySmartSort: () -> Void

    @State private var draft = ExampleHotelFilters()

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Filter").font(.system(size: 18, weight: .bold))
                Spacer()
                if !draft.isEmpty {
                    Button("Clear all") { draft = ExampleHotelFilters() }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(ExampleColor.accent)
                }
                ExampleCloseButton { isPresented = false }
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 8)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    SmartSortPromptFilterCard(queryType: .hotel, isHighlighted: draft.count >= 4) {
                        applied = draft
                        onTrySmartSort()
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Star rating").font(.system(size: 16, weight: .semibold))
                        HStack(spacing: 8) {
                            ForEach([3, 4, 5], id: \.self) { stars in
                                let isOn = draft.stars.contains(stars)
                                Button("\(stars) ★") { draft.stars.formSymmetricDifference([stars]) }
                                    .font(.system(size: 14))
                                    .foregroundStyle(isOn ? ExampleColor.accent : .primary)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(Capsule().fill(isOn ? ExampleColor.tint : .clear))
                                    .overlay(Capsule().stroke(isOn ? ExampleColor.accent : ExampleColor.border, lineWidth: 1))
                            }
                        }
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Amenities").font(.system(size: 16, weight: .semibold))
                        ForEach(ExampleHotel.amenityNames, id: \.self) { amenity in
                            let isOn = draft.amenities.contains(amenity)
                            Button { draft.amenities.formSymmetricDifference([amenity]) } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: isOn ? "checkmark.square.fill" : "square")
                                        .font(.system(size: 20))
                                        .foregroundStyle(isOn ? ExampleColor.accent : .secondary)
                                    Text(amenity).foregroundStyle(.primary)
                                    Spacer()
                                    Text("\(hotels.filter { $0.amenities.contains(amenity) }.count)")
                                        .font(.system(size: 13)).foregroundStyle(.secondary)
                                }
                                .frame(height: 40)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(16)
            }

            let count = hotels.filter(draft.matches).count
            Button {
                applied = draft
                isPresented = false
            } label: {
                Text("Show \(count) hotel\(count == 1 ? "" : "s")")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Capsule().fill(count == 0 ? ExampleColor.accent.opacity(0.4) : ExampleColor.accent))
            }
            .disabled(count == 0)
            .padding(16)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onAppear { draft = applied }
    }
}
