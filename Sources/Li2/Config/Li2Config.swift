import Foundation

/// SDK configuration. Create once at app startup and pass to `Li2.configure(_:)`.
public struct Li2Config {

    /// Your Li2 publishable key (`li2_pk_...`). Found in the Li2 dashboard.
    public let publishableKey: String

    /// The deep link domains associated with your Li2 account (e.g. `["deep.li2.link"]`).
    /// Used to validate pasted clipboard URLs and as the `li2Domains` field in
    /// `/track/open` requests for server-side IP-fallback lookup.
    public let deepLinkDomains: [String]

    /// Base URL for the Li2 API. Override for self-hosted or staging environments.
    public var apiBaseURL: String

    /// How long (days) to persist a resolved `clickId` in UserDefaults for
    /// auto-filling `trackLead`/`trackSale` calls. Mirrors the backend `click:`
    /// Redis key TTL — change only if you've tuned the server-side TTL.
    public var clickIdExpiryDays: Int

    /// Grace period before the first-launch consent sheet is shown. Gives
    /// Universal Links (which arrive asynchronously) a chance to win over the
    /// deferred clipboard path. Only change if you observe race conditions on
    /// specific device/OS combinations.
    public var firstLaunchGraceNanoseconds: UInt64

    public init(
        publishableKey: String,
        deepLinkDomains: [String],
        apiBaseURL: String = "https://api.li2.ai/api/v1",
        clickIdExpiryDays: Int = 30,
        firstLaunchGraceNanoseconds: UInt64 = 250_000_000
    ) {
        self.publishableKey = publishableKey
        self.deepLinkDomains = deepLinkDomains
        self.apiBaseURL = apiBaseURL
        self.clickIdExpiryDays = clickIdExpiryDays
        self.firstLaunchGraceNanoseconds = firstLaunchGraceNanoseconds
    }
}
