import Foundation

/// Configuration for the Li2 SDK. Build once via `Li2.configure(…)` at app startup.
public struct Li2Config: Sendable {

    /// Your publishable key, e.g. `"li2_pk_..."`.  Non-secret — safe in the binary.
    public let publishableKey: String

    /// API base URL **including** `/api/v1`. Defaults to Li2 production.
    public let apiBaseURL: String

    /// Deep-link domains your app handles, e.g. `["deep.li2.link"]`.
    /// Sent on deferred miss/opt-out calls (`li2Domains`). At least one required.
    public let deepLinkDomains: [String]

    /// How long (days) a stored `clickId` stays valid. Mirrors the backend Redis TTL.
    /// Default: 30.
    public let clickIdExpiryDays: Int

    /// Delay (nanoseconds) after launch before the first-launch deferred gate fires.
    /// Gives `.onOpenURL` / `.onContinueUserActivity` time to arrive so an
    /// immediate Universal Link wins. Default: 250 ms.
    public let firstLaunchGraceNanoseconds: UInt64

    public init(
        publishableKey: String,
        apiBaseURL: String = "https://api.li2.ai/api/v1",
        deepLinkDomains: [String],
        clickIdExpiryDays: Int = 30,
        firstLaunchGraceNanoseconds: UInt64 = 250_000_000
    ) {
        self.publishableKey = publishableKey
        self.apiBaseURL = apiBaseURL
        self.deepLinkDomains = deepLinkDomains
        self.clickIdExpiryDays = clickIdExpiryDays
        self.firstLaunchGraceNanoseconds = firstLaunchGraceNanoseconds
    }
}
