import RiviSmartSortElements
import RiviSmartSortContract
import RiviSmartSortRuntime

/// A tenant's bundled configuration: who it is, its gateways, and its tokens (spec D10).
///
/// A tenant build (`scripts/build-tenant.sh <tenant>`) compiles one of these into the tenant's own
/// package as `RiviTenantBuild.bundled`, from `tenants/<tenant>.json` and the CI secrets
/// `RIVI_TOKEN_<TENANT>_STAGING` / `_PRODUCTION`. The tenant app then needs neither a token nor
/// an endpoint. No build contains another tenant's configuration or token.
public struct RiviTenantBuild: Sendable {
    /// The two gateways a tenant build knows.
    public enum Environment: String, Sendable, CaseIterable {
        case staging, production
    }

    public var tenant: RiviTenant
    private let baseURLs: [Environment: String]
    private let token: @Sendable (Environment) -> String

    public init(tenant: RiviTenant, stagingBaseURL: String, productionBaseURL: String,
                token: @escaping @Sendable (Environment) -> String) {
        self.tenant = tenant
        baseURLs = [.staging: stagingBaseURL, .production: productionBaseURL]
        self.token = token
    }

    public func baseURL(_ environment: Environment) -> String { baseURLs[environment] ?? "" }

    func bundledToken(_ environment: Environment) -> String { token(environment) }
}

extension RiviSmartSort {
    /// A session for a tenant build. The tenant, the gateway and the token come from `build`.
    ///
    /// - Parameter auth: Optional override of the bundled token, e.g. to bridge a rotated token
    ///   before the rebuilt package ships. Resolved per request.
    public convenience init(
        build: RiviTenantBuild,
        environment: RiviTenantBuild.Environment = .production,
        locale: String = "en",
        currency: String,
        metadata: [String: String] = [:],
        strings: StringOverrides = [:],
        auth: (@Sendable () async throws -> String)? = nil,
        logLevel: RiviLogLevel = .info,
        logger: RiviLogger? = nil,
        transport: RiviTransport = URLSessionTransport(),
        clock: RiviClock = SystemClock()
    ) {
        let bundled = build.bundledToken(environment)
        self.init(
            tenant: build.tenant,
            environment: .custom(baseURL: build.baseURL(environment)),
            locale: locale,
            currency: currency,
            metadata: metadata,
            strings: strings,
            auth: auth ?? { bundled },
            logLevel: logLevel,
            logger: logger,
            transport: transport,
            clock: clock
        )
    }
}
