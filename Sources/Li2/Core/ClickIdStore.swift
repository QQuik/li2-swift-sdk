import Foundation

/// Persists the most-recently matched `clickId` with an expiry TTL.
/// Matches the key names from v1/kit so upgrades don't lose attribution.
public final class ClickIdStore: @unchecked Sendable {

    public static let shared = ClickIdStore()

    private static let clickIdKey     = "ai.li2.lastClickId"
    private static let expiresAtKey   = "ai.li2.lastClickIdExpiresAt"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Persist a matched click ID for `expiryDays` days.
    func persist(clickId: String, expiryDays: Int) {
        let expiresAt = Date().addingTimeInterval(TimeInterval(expiryDays * 86400))
        defaults.set(clickId, forKey: Self.clickIdKey)
        defaults.set(expiresAt.timeIntervalSince1970, forKey: Self.expiresAtKey)
    }

    /// The stored click ID if present and not expired, else `nil`.
    public var currentClickId: String? {
        guard let id = defaults.string(forKey: Self.clickIdKey) else { return nil }
        let expiresAt = defaults.double(forKey: Self.expiresAtKey)
        guard expiresAt > 0, Date().timeIntervalSince1970 < expiresAt else { return nil }
        return id
    }

    /// Remove the stored click ID (for testing / logout flows).
    func clear() {
        defaults.removeObject(forKey: Self.clickIdKey)
        defaults.removeObject(forKey: Self.expiresAtKey)
    }
}
