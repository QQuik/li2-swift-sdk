import Foundation

/// Entry point for the Li2 SDK.  Call `Li2.configure(…)` once at app startup
/// before creating any `Li2DeepLinkResolver`.
public enum Li2: Sendable {

    // MARK: - Configuration

    nonisolated(unsafe) private static var _config: Li2Config?

    /// Configure the SDK.  Must be called before any resolver is created.
    public static func configure(
        publishableKey: String,
        deepLinkDomains: [String],
        apiBaseURL: String = "https://api.li2.ai/api/v1",
        clickIdExpiryDays: Int = 30,
        firstLaunchGraceNanoseconds: UInt64 = 250_000_000
    ) {
        _config = Li2Config(
            publishableKey: publishableKey,
            apiBaseURL: apiBaseURL,
            deepLinkDomains: deepLinkDomains,
            clickIdExpiryDays: clickIdExpiryDays,
            firstLaunchGraceNanoseconds: firstLaunchGraceNanoseconds
        )
    }

    /// The resolved config; crashes fast if `configure` was not called.
    static var config: Li2Config {
        guard let c = _config else {
            fatalError("Li2: call Li2.configure(…) before using the SDK.")
        }
        return c
    }

    // MARK: - Attribution handoff

    /// The most-recently matched `clickId`, or `nil` if none / expired.
    /// Expose to conversion calls until the conversion module ships.
    public static var lastClickId: String? {
        ClickIdStore.shared.currentClickId
    }

    // MARK: - Consent reset

    /// Clears the first-launch consent gate so the next launch re-asks (or a
    /// fresh `requestFirstLaunchConsentAfterGrace()` re-opens it this session).
    ///
    /// Intended for QA / a "re-ask deferred-link permission" settings affordance.
    /// The gate's storage key is an SDK implementation detail — this method is
    /// the supported way to clear it; do not write `UserDefaults` directly.
    public static func resetFirstLaunchConsent() {
        UserDefaults.standard.removeObject(forKey: Li2DeepLinkResolver.firstLaunchRanKey)
    }
}
