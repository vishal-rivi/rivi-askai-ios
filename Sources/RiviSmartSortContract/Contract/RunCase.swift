// The conformance harness (CONTRACT.md "Running the corpus"; web: src/contract/runCase.ts).

public struct ConformanceCase: Sendable {
    public var name: String
    /// Rule numbers (1–17) this case pins. Empty for mechanism cases.
    public var rules: [Int]
    /// Applied as SetSearch before `setup`. nil puts the first SetSearch under test.
    public var search: RiviSearch?
    /// Applied as PoolChanged before `search`, the order the facade uses (R3).
    public var pool: PoolFact?
    public var config: RiviConfig
    /// Applied after pool and search. Commands are discarded.
    public var setup: [Input]
    /// The inputs under test. Commands are collected in order.
    public var inputs: [Input]
    /// Each listed key must deep-equal. Unlisted keys are not checked.
    public var expectState: JSONObject?
    /// Exactly this list, in this order.
    public var expectCommands: [Command]?
    /// Each listed selector's value on the final state must deep-equal.
    public var expectSelect: [(SelectorName, JSONValue)]

    public init(json: JSONValue) throws {
        guard let o = json.objectValue else { throw ContractDecodingError("case is not an object") }
        guard let name = o["name"]?.stringValue else { throw ContractDecodingError("case without a name") }
        self.name = name
        do {
            rules = (o["rules"]?.arrayValue ?? []).compactMap { $0.numberValue.map { Int($0) } }
            search = try o["search"].map(RiviSearch.init(json:))
            pool = try o["pool"].map(PoolFact.init(json:))
            config = try RiviConfig(partialJSON: o["config"])
            setup = try (o["setup"]?.arrayValue ?? []).map(Input.init(json:))
            inputs = try (o["inputs"]?.arrayValue ?? []).map(Input.init(json:))
            let expect = o["expect"]?.objectValue ?? JSONObject()
            expectState = expect["state"]?.objectValue
            expectCommands = try expect["commands"]?.arrayValue.map { try $0.map(Command.init(json:)) }
            expectSelect = try (expect["select"]?.objectValue ?? JSONObject()).map { pair in
                guard let selector = SelectorName(rawValue: pair.key) else {
                    throw ContractDecodingError("unknown selector \"\(pair.key)\"")
                }
                return (selector, pair.value)
            }
        } catch {
            throw ContractDecodingError("case \"\(name)\": \(error)")
        }
    }

    /// The inputs `runCase` applies before `setup`: PoolChanged, then SetSearch.
    public var preamble: [Input] {
        var pre: [Input] = []
        if let pool { pre.append(.poolChanged(pool)) }
        if let search { pre.append(.setSearch(search)) }
        return pre
    }
}

public struct ConformanceCorpus: Sendable {
    public var contractVersion: Int
    public var cases: [ConformanceCase]

    public init(json: JSONValue) throws {
        guard let o = json.objectValue, let version = o["contractVersion"]?.numberValue,
              let cases = o["cases"]?.arrayValue else {
            throw ContractDecodingError("not a cases file")
        }
        contractVersion = Int(version)
        self.cases = try cases.map(ConformanceCase.init(json:))
    }
}

public func runCase(_ c: ConformanceCase) -> (state: RiviState, commands: [Command]) {
    var state = initialState(c.config)
    for input in c.preamble + c.setup { state = reconcile(state, input).state }
    var commands: [Command] = []
    for input in c.inputs {
        let (next, cmds) = reconcile(state, input)
        state = next
        commands += cmds
    }
    return (state, commands)
}

/// One mismatch between a final state and a case's expectations.
public struct ConformanceMismatch: Sendable, CustomStringConvertible {
    public var path: String
    public var expected: JSONValue
    public var actual: JSONValue
    public var description: String { "\(path): expected \(expected.serialized()), got \(actual.serialized())" }
}

/// Checks `expect.state`, `expect.commands` and `expect.select` against a result.
public func verify(_ c: ConformanceCase, state: RiviState, commands: [Command]?) -> [ConformanceMismatch] {
    var mismatches: [ConformanceMismatch] = []
    let actualState = state.json
    for (key, expected) in c.expectState ?? JSONObject() {
        let actual = actualState[key] ?? .null
        if actual != expected { mismatches.append(.init(path: "state.\(key)", expected: expected, actual: actual)) }
    }
    if let expected = c.expectCommands, let commands {
        let lhs = JSONValue.array(expected.map(\.json))
        let rhs = JSONValue.array(commands.map(\.json))
        if lhs != rhs { mismatches.append(.init(path: "commands", expected: lhs, actual: rhs)) }
    }
    for (selector, expected) in c.expectSelect {
        let actual = selector.evaluate(state)
        if actual != expected { mismatches.append(.init(path: "select.\(selector.rawValue)", expected: expected, actual: actual)) }
    }
    return mismatches
}
