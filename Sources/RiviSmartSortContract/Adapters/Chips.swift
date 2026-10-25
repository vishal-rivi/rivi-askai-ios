// The chip rule engine over data/rules.json (spec 6.4; web: src/adapters/chips.ts, rules.ts).

public struct ChipRule: Sendable, Equatable {
    public enum Shape: String, Sendable {
        case list, scalar, join, flag
    }

    public var key: String
    public var shape: Shape
    /// nil: the value is the label.
    public var labelKey: String?
    /// The plural argument name, e.g. `n` for `chip.stops`.
    public var pluralArgument: String?
    /// Another key of the entity record holding a currency for this value, e.g. `budget_currency`
    /// for `flight_budget`: "Budget: 500 USD". nil: no currency.
    public var currencyKey: String?
    public var group: String

    public init(key: String, shape: Shape, labelKey: String?, pluralArgument: String? = nil,
                currencyKey: String? = nil, group: String) {
        self.key = key
        self.shape = shape
        self.labelKey = labelKey
        self.pluralArgument = pluralArgument
        self.currencyKey = currencyKey
        self.group = group
    }
}

public struct ChipRules: Sendable, Equatable {
    public var rulesVersion: Int
    public var flight: [ChipRule]
    public var hotel: [ChipRule]

    public func rules(for product: Product) -> [ChipRule] {
        product == .flight ? flight : hotel
    }

    /// Every labelKey the rules reference, deduplicated, in rule order.
    public var labelKeys: [String] {
        var seen = Set<String>()
        return (flight + hotel).compactMap(\.labelKey).filter { seen.insert($0).inserted }
    }

    public init(json: JSONValue) throws {
        guard let o = json.objectValue, let version = o["rulesVersion"]?.numberValue else {
            throw ContractDecodingError("not a rules file")
        }
        func decode(_ key: String) throws -> [ChipRule] {
            try (o[key]?.arrayValue ?? []).map { value in
                guard let rule = value.objectValue, let ruleKey = rule["key"]?.stringValue,
                      let shape = rule["shape"]?.stringValue.flatMap(ChipRule.Shape.init(rawValue:)),
                      let group = rule["group"]?.stringValue else {
                    throw ContractDecodingError("invalid chip rule in \(key)")
                }
                return ChipRule(
                    key: ruleKey,
                    shape: shape,
                    labelKey: rule["labelKey"]?.stringValue,
                    pluralArgument: rule["format"]?["plural"]?.stringValue,
                    currencyKey: rule["currencyKey"]?.stringValue,
                    group: group
                )
            }
        }
        rulesVersion = Int(version)
        flight = try decode("flight")
        hotel = try decode("hotel")
    }
}

private func isEmptyValue(_ value: JSONValue) -> Bool {
    switch value {
    case .null: return true
    case .string(let text): return text.trimmingWhitespace() == ""
    case .array(let items): return items.isEmpty
    default: return false
    }
}

/// A primitive as label text; anything else has no label.
private func text(_ value: JSONValue) -> String? {
    switch value {
    case .string(let raw):
        let trimmed = raw.trimmingWhitespace()
        return trimmed == "" ? nil : trimmed
    case .number(let number) where number.isFinite:
        return jsNumberString(number)
    default:
        return nil
    }
}

private func asList(_ value: JSONValue) -> [JSONValue] {
    value.arrayValue ?? [value]
}

private func toCount(_ value: JSONValue) -> Double? {
    switch value {
    case .number(let number) where number.isFinite: return number
    case .string(let raw):
        // /^\s*\d+(\.\d+)?\s*$/
        let trimmed = raw.trimmingWhitespace()
        let parts = trimmed.split(separator: ".", omittingEmptySubsequences: false)
        let isDigits: (Substring) -> Bool = { !$0.isEmpty && $0.allSatisfy { ("0"..."9").contains($0) } }
        guard (parts.count == 1 && isDigits(parts[0])) || (parts.count == 2 && isDigits(parts[0]) && isDigits(parts[1])) else {
            return nil
        }
        return Double(trimmed)
    default: return nil
    }
}

private func label(_ rule: ChipRule, _ value: JSONValue, _ i18n: RiviI18n) -> String? {
    if let plural = rule.pluralArgument {
        guard let n = toCount(value), let labelKey = rule.labelKey else { return text(value) }
        return i18n.t(labelKey, [plural: .number(n)])
    }
    guard let shown = text(value) else { return nil }
    guard let labelKey = rule.labelKey else { return shown }
    return i18n.t(labelKey, ["value": .string(shown)])
}

/// The value with the record's currency after it ("500" + "USD" → "500 USD"), for rules with a
/// `currencyKey`. Left as is when there is no currency, or the value already names it.
private func withCurrency(_ rule: ChipRule, _ value: JSONValue, _ record: Entities) -> JSONValue {
    guard let currencyKey = rule.currencyKey,
          let currency = record[currencyKey].flatMap(text),
          let shown = text(value),
          !shown.localizedCaseInsensitiveContains(currency) else { return value }
    return .string("\(shown) \(currency)")
}

private func project(_ rule: ChipRule, _ value: JSONValue, _ i18n: RiviI18n, record: Entities = Entities()) -> [Chip] {
    func chip(_ id: String, _ label: String?) -> [Chip] {
        guard let label else { return [] }
        return [Chip(id: id, label: label, group: rule.group)]
    }
    switch rule.shape {
    case .flag:
        guard value == .bool(true), let labelKey = rule.labelKey else { return [] }
        return chip(stableId(rule.key, .bool(true)), i18n.t(labelKey))
    case .list:
        return asList(value)
            .filter { !isEmptyValue($0) }
            .flatMap { item in chip(stableId(rule.key, item), label(rule, item, i18n)) }
    case .join:
        let items = asList(value).compactMap(text)
        if items.isEmpty { return [] }
        let joined = i18n.list(items)
        let id = stableId(rule.key, .array(items.map { .string($0) }))
        guard let labelKey = rule.labelKey else { return chip(id, joined) }
        return chip(id, i18n.t(labelKey, ["value": .string(joined)]))
    case .scalar:
        if let array = value.arrayValue {
            let items = array.compactMap(text)
            if items.isEmpty { return [] }
            return chip(stableId(rule.key, .array(items.map { .string($0) })), label(rule, .string(i18n.list(items)), i18n))
        }
        // The id stays the value's, so adding or changing the currency doesn't make a new chip.
        return chip(stableId(rule.key, value), label(rule, withCurrency(rule, value, record), i18n))
    }
}

/// Chips follow the entity record's key order, as the web SDK does. Keys without a rule are
/// ignored. A chip whose id or label is already present is dropped, so the same preference never
/// shows twice.
public func toChips(_ entities: Entities, product: Product, i18n: RiviI18n, rules: ChipRules = BundledData.rules) -> [Chip] {
    var byKey: [String: ChipRule] = [:]
    for rule in rules.rules(for: product) { byKey[rule.key] = rule }
    var ids = Set<String>()
    var labels = Set<String>()
    var chips: [Chip] = []
    for key in entities.jsKeys {
        guard let rule = byKey[key], let value = entities[key], !isEmptyValue(value) else { continue }
        for chip in project(rule, value, i18n, record: entities) where !ids.contains(chip.id) && !labels.contains(chip.label) {
            ids.insert(chip.id)
            labels.insert(chip.label)
            chips.append(chip)
        }
    }
    return chips
}
