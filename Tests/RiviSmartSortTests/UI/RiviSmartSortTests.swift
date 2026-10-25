import XCTest
import RiviSmartSortElements
import RiviSmartSortContract
@testable import RiviSmartSortRuntime
@testable import RiviSmartSortUI

@MainActor
final class RiviSmartSortFacadeTests: XCTestCase {
    private var transport: FakeTransport!
    private var events: [RiviSmartSortEvent] = []

    override func setUp() async throws {
        transport = FakeTransport()
        transport.onSortBest = { _ in .json("{}") }
        events = []
    }

    private func model(locale: String = "en") -> RiviSmartSort {
        let model = RiviSmartSort(
            tenant: RiviTenant(name: "sandbox", tier: "gold"),
            environment: .custom(baseURL: "https://gw.test"),
            locale: locale,
            currency: "SAR",
            auth: { World.token },
            logLevel: RiviLogLevel.none,
            transport: transport,
            clock: ManualClock()
        )
        model.onEvent = { [weak self] in self?.events.append($0) }
        return model
    }

    func testFactsAreDispatchedOnlyWhenTheyChange() async {
        let model = model()
        model.search = World.flight
        model.search = World.flight
        _ = await waitUntil { self.transport.requests(.sortBest).count == 1 }
        await settle()
        XCTAssertEqual(transport.requests(.sortBest).count, 1, "an unchanged search is not a new search")
        XCTAssertTrue(model.isAvailable)
        model.destroy()
    }

    func testAPoolReportedWithANewSearchIsInPlaceFirst() async {
        let model = model()
        model.update(search: World.flight, pool: PoolFact(size: 0, complete: false))
        await settle()
        XCTAssertTrue(transport.requests(.sortBest).isEmpty, "an empty pool is never ranked (rule 1)")
        model.pool = PoolFact(size: 20, complete: false)
        let ranked = await waitUntil { self.transport.requests(.sortBest).count == 1 }
        XCTAssertTrue(ranked)
        model.destroy()
    }

    func testAskRemoveChipByLabelAndClearAll() async {
        transport.onAsk = { _ in .json(#"{"message":{"entities":[{"preferred_airlines":["Emirates","Qatar Airways"]}]}}"#) }
        let model = model()
        model.search = World.flight
        model.ask("Emirates or Qatar")
        _ = await waitUntil { model.chips.count == 2 }
        XCTAssertEqual(model.chipLabels, ["Emirates", "Qatar Airways"])
        XCTAssertEqual(model.inputValue.text, "Emirates or Qatar")

        model.removeChip(label: "Emirates")
        XCTAssertEqual(model.state.query, "Qatar Airways", "the re-ask uses the remaining labels")
        _ = await waitUntil { self.transport.requests(.ask).count == 2 }

        model.clearAll()
        XCTAssertTrue(model.chips.isEmpty)
        _ = await waitUntil { self.events.contains(.rankingCleared) }
        XCTAssertTrue(events.contains(.rankingCleared))
        model.destroy()
    }

    func testLeavingBestWithAQueryAsksFirstAndDecliningPutsTheTabBack() async {
        transport.onAsk = { _ in .json(#"{"message":{"entities":[{"stops_preference":["0"]}]}}"#) }
        let model = model()
        model.search = World.flight
        model.ask("non-stop")
        _ = await waitUntil { !model.chips.isEmpty }

        model.sort = .other
        _ = await waitUntil { model.isConfirmingSortChange }
        XCTAssertEqual(model.state.sort, .best, "the sort waits for the answer (rule 10)")
        XCTAssertTrue(events.contains(.confirmSortChange(.other)))

        model.resolveSortConfirmation(accepted: false)
        _ = await waitUntil { self.events.contains(.sortChanged(.best)) }
        XCTAssertEqual(model.state.sort, .best)
        XCTAssertFalse(model.isConfirmingSortChange)

        model.sort = .other
        _ = await waitUntil { model.isConfirmingSortChange }
        model.resolveSortConfirmation(accepted: true)
        XCTAssertEqual(model.state.sort, .other)
        XCTAssertEqual(model.state.query, "")
        XCTAssertTrue(model.chips.isEmpty, "chips show on Best only (rule 6)")
        model.destroy()
    }

    func testAnAskSendsTheReportedFilters() async {
        transport.onAsk = { _ in .never }
        let model = model()
        model.search = World.flight
        model.filters = ["stops": [0]]
        model.ask("morning")
        _ = await waitUntil { self.transport.requests(.ask).count == 1 }
        let body = transport.requests(.ask).first?.body.flatMap { try? JSONValue.parse(String(decoding: $0, as: UTF8.self)) }
        XCTAssertEqual(body?["filters"], ["stops": [0]]) // rule 2
        XCTAssertEqual(model.filters, ["stops": [0]], "the filters stay")
        model.destroy()
    }

    func testAnAskWithFiltersSendsThoseFilters() async {
        transport.onAsk = { _ in .never }
        let model = model()
        model.search = World.flight
        model.filters = ["stops": [0]]
        model.ask("morning", filters: ["airlines": ["SV"]])
        _ = await waitUntil { self.transport.requests(.ask).count == 1 }
        let body = transport.requests(.ask).first?.body.flatMap { try? JSONValue.parse(String(decoding: $0, as: UTF8.self)) }
        XCTAssertEqual(body?["filters"], ["airlines": ["SV"]], "the sheet's filters win")
        XCTAssertEqual(model.filters, ["airlines": ["SV"]], "and become the reported ones")
        model.destroy()
    }

    func testChangingFiltersMakesNoRequest() async {
        let model = model()
        model.search = World.flight
        let epoch = model.state.epoch
        let sortBest = transport.requests(.sortBest).count
        model.filters = ["maxPrice": 500, "stops": [0]]
        model.filters = ["stops": [1]]
        model.filters = nil
        XCTAssertEqual(model.state.epoch, epoch, "filter changes don't re-rank")
        XCTAssertNil(model.state.filters, "nothing reaches the contract")
        XCTAssertEqual(transport.requests(.sortBest).count, sortBest, "no sort-best for a filter change")
        XCTAssertNil(model.filters)
        model.destroy()
    }

    func testRankingEventsCarryTheOrder() async {
        let body = FakeBody()
        transport.onSubscribe = { _ in .respond(status: 200, body: body) }
        let model = model()
        model.search = World.flight
        _ = await waitUntil { self.transport.requests(.subscribe).count == 1 }
        body.send(World.rankingLine(["B", "A"]))
        let delivered = await waitUntil {
            self.events.contains { if case .ranking(let ranking, _, _) = $0 { return ranking.map(\.id) == ["B", "A"] }; return false }
        }
        XCTAssertTrue(delivered)
        XCTAssertEqual(model.matchesAllPreferences(id: "A"), true)
        XCTAssertNil(model.matchesAllPreferences(id: "Z"))
        model.destroy()
    }

    func testTheReturnLegTurnsSmartSortOff() {
        let model = model()
        model.search = World.flight
        model.stage = .return
        XCTAssertFalse(model.isAvailable) // rule 16
        model.stage = .onward
        XCTAssertTrue(model.isAvailable)
        model.destroy()
    }

    func testLocaleDrivesTheElementsAndChipLabels() {
        let model = model(locale: "ar")
        XCTAssertEqual(RiviSmartSortConfiguration.shared.language, .arabic)
        XCTAssertEqual(model.text("explain.fallback"), BundledData.strings(for: "ar").messages["explain.fallback"])
        model.setLocale("en")
        XCTAssertEqual(RiviSmartSortConfiguration.shared.language, .english)
        model.destroy()
    }

    // MARK: - Tenant builds

    private let build = RiviTenantBuild(
        tenant: RiviTenant(name: "almatar", tier: "basic"),
        stagingBaseURL: "https://staging.test",
        productionBaseURL: "https://production.test",
        token: { $0 == .production ? "PROD-TOKEN" : "STAGING-TOKEN" }
    )

    private func tenantModel(_ environment: RiviTenantBuild.Environment,
                             auth: (@Sendable () async throws -> String)? = nil) -> RiviSmartSort {
        RiviSmartSort(build: build, environment: environment, currency: "SAR", auth: auth,
                      logLevel: RiviLogLevel.none, transport: transport, clock: ManualClock())
    }

    func testATenantBuildUsesItsBundledGatewayAndTokenPerEnvironment() async throws {
        for (environment, host, token) in [(RiviTenantBuild.Environment.production, "production.test", "PROD-TOKEN"),
                                           (.staging, "staging.test", "STAGING-TOKEN")] {
            transport = FakeTransport()
            transport.onSortBest = { _ in .json("{}") }
            let model = tenantModel(environment)
            model.search = World.flight
            _ = await waitUntil { self.transport.requests(.sortBest).count == 1 }
            let post = try XCTUnwrap(transport.requests(.sortBest).first)
            XCTAssertEqual(post.url.host, host)
            XCTAssertEqual(post.headers["authorization"], token)
            XCTAssertEqual(post.headers["tenant-name"], "almatar")
            XCTAssertEqual(post.headers["tenant-tier"], "basic")
            model.destroy()
        }
    }

    func testAuthOverridesTheBundledToken() async throws {
        let model = tenantModel(.production, auth: { "ROTATED" })
        model.search = World.flight
        _ = await waitUntil { self.transport.requests(.sortBest).count == 1 }
        XCTAssertEqual(transport.requests(.sortBest).first?.headers["authorization"], "ROTATED")
        model.destroy()
    }
}
