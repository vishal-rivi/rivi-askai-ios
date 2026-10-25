// Stream frames and ask responses (web: src/adapters/frames.ts, askResponse.ts). Pure.

public typealias Warn = @Sendable (String) -> Void

/// Splits an entity record into the entities proper and `parameter_change_notice`. Shared by the
/// ask response (`message.entities[0]`) and the stream's entity frame (`content.entities[0]`).
public func splitEntities(_ record: JSONValue?) -> (entities: Entities, notice: String?) {
    guard var entities = record?.objectValue else { return (Entities(), nil) }
    let raw = entities["parameter_change_notice"]
    entities["parameter_change_notice"] = nil
    if let text = raw?.stringValue, text.trimmingWhitespace() != "" { return (entities, text) }
    return (entities, nil)
}

/// `POST /api/v1/askai` response: `{ message: { entities: [ { ... } ] } }`.
public func fromAskResponse(_ json: JSONValue) -> (entities: Entities, notice: String?) {
    splitEntities(json["message"]?["entities"]?.arrayValue?.first)
}

public enum FrameResult: Sendable, Equatable {
    case ranking([RankingEntry])
    case entities(Entities, notice: String?)
    case error(message: String)
    case ignore
}

/// Ids are strings on the wire; a numeric id is accepted and stringified. Never the index.
private func toId(_ value: JSONValue?) -> String? {
    switch value {
    case .string(let text)? where text.trimmingWhitespace() != "": return text
    case .number(let number)? where number.isFinite: return jsNumberString(number)
    default: return nil
    }
}

private func tagsOf(_ value: JSONObject) -> [String] {
    var tags: [String] = []
    for tag in value["recommendationTagList"]?.arrayValue ?? [] {
        if let text = tag.stringValue, text != "", !tags.contains(text) { tags.append(text) }
    }
    if let single = value["recommendationTag"]?.stringValue, single != "", !tags.contains(single) {
        tags.append(single)
    }
    return tags
}

private struct Candidate {
    var id: JSONValue?
    var value: JSONValue
    var item: Bool
}

private func entries(_ scope: Scope, _ candidates: [Candidate], _ warn: Warn) -> [RankingEntry] {
    var seen = Set<String>()
    var out: [RankingEntry] = []
    for candidate in candidates {
        guard let id = toId(candidate.id) else {
            warn("[smart-sort] dropped an entry without an id (scope \(scope.rawValue))")
            continue
        }
        if seen.contains(id) {
            warn("[smart-sort] dropped a duplicate entry \(id) (scope \(scope.rawValue))")
            continue
        }
        seen.insert(id)
        let value = candidate.value.objectValue ?? JSONObject()
        out.append(RankingEntry(
            id: id,
            scope: scope,
            rank: out.count,
            matchesAllPreferences: value["allPreferencesMet"] != .bool(false),
            tags: tagsOf(value),
            item: candidate.item ? candidate.value : nil
        ))
    }
    return out
}

private func byKey(_ list: [JSONValue], _ key: String, item: Bool) -> [Candidate] {
    list.map { Candidate(id: $0.objectValue?[key], value: $0, item: item) }
}

private func byFlightId(_ list: [JSONValue]) -> [Candidate] {
    list.map { value in
        let object = value.objectValue
        let itineraryId = toId(object?["itineraryId"]).map(JSONValue.string)
        return Candidate(id: itineraryId ?? object?["id"], value: value, item: true)
    }
}

private func isIntegerLike(_ key: String) -> Bool {
    guard let first = key.utf8.first else { return false }
    if key == "0" { return true }
    return first != UInt8(ascii: "0") && key.utf8.allSatisfy { (UInt8(ascii: "0")...UInt8(ascii: "9")).contains($0) }
}

private func compact(_ data: JSONObject, _ warn: Warn) -> [RankingEntry]? {
    if let itineraries = data["itineraries"]?.objectValue {
        // JS key order, as the web reads it: integer-like keys move first (Q10 asks the backend
        // for an array).
        let keys = itineraries.jsKeys
        if !keys.isEmpty && keys.allSatisfy(isIntegerLike) {
            warn("[smart-sort] data.itineraries has only integer-like keys; their order is not the ranking")
        }
        return entries(.itinerary, keys.map { Candidate(id: .string($0), value: itineraries[$0]!, item: false) }, warn)
    }
    let onward = data["onwardLegs"]?.arrayValue
    let back = data["returnLegs"]?.arrayValue
    if onward != nil || back != nil {
        return entries(.onward, byKey(onward ?? [], "legId", item: false), warn)
            + entries(.return, byKey(back ?? [], "legId", item: false), warn)
    }
    if let hotels = data["ht"]?.arrayValue { return entries(.hotel, byKey(hotels, "hi", item: false), warn) }
    return nil
}

private let onwardKeys = ["onwardFlightList", "onwardFlightsList", "onwardFlightListList"]
private let returnKeys = ["returnFlightList", "returnFlightsList", "returnFlightListList"]

private func firstArray(_ record: JSONObject, _ keys: [String]) -> [JSONValue]? {
    for key in keys { if let list = record[key]?.arrayValue { return list } }
    return nil
}

private func full(_ frame: JSONObject, _ product: Product, _ warn: Warn) -> [RankingEntry]? {
    if let onward = firstArray(frame, onwardKeys) {
        let back = firstArray(frame, returnKeys) ?? []
        if back.isEmpty { return entries(.itinerary, byFlightId(onward), warn) }
        return entries(.onward, byFlightId(onward), warn) + entries(.return, byFlightId(back), warn)
    }
    if let data = frame["data"]?.arrayValue {
        return product == .hotel
            ? entries(.hotel, byKey(data, "id", item: true), warn)
            : entries(.itinerary, byFlightId(data), warn)
    }
    if let list = frame["dataList"]?.arrayValue { return entries(.hotel, byKey(list, "id", item: true), warn) }
    return nil
}

/// One parsed ranking-stream frame (spec 6.3). Shapes are tried in the spec's order: compact
/// (`data.itineraries`, `data.onwardLegs`/`returnLegs`, `data.ht`), then full objects.
public func fromFrame(_ json: JSONValue, product: Product, warn: Warn = { _ in }) -> FrameResult {
    guard let frame = json.objectValue else { return .ignore }
    if frame["error"] == .bool(true) { return .error(message: frame["message"]?.stringValue ?? "") }
    let ranking = frame["data"]?.objectValue.flatMap { compact($0, warn) } ?? full(frame, product, warn)
    if let ranking {
        if ranking.isEmpty {
            warn("[smart-sort] ignored a result frame with no rankable entries")
            return .ignore
        }
        return .ranking(ranking)
    }
    if let first = frame["content"]?["entities"]?.arrayValue?.first, first.objectValue != nil {
        let (entities, notice) = splitEntities(first)
        return .entities(entities, notice: notice)
    }
    return .ignore
}

public enum ExplainFrameResult: Sendable, Equatable {
    case text(String)
    case end
    case ignore
}

/// One parsed explain-stream frame. Frames are cumulative (`{ content }` replaces the text).
/// The gateway ends the stream by closing it; `{ done: true }` or `{ end: true }` is accepted too.
public func fromExplainFrame(_ json: JSONValue) -> ExplainFrameResult {
    guard let frame = json.objectValue else { return .ignore }
    if let content = frame["content"]?.stringValue, content != "" { return .text(content) }
    if frame["done"] == .bool(true) || frame["end"] == .bool(true) { return .end }
    return .ignore
}
