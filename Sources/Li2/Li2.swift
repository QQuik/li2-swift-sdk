import Foundation

/// Top-level SDK namespace. Call `Li2.configure(...)` once at app startup.
public final class Li2 {

    // MARK: - Singleton

    public static let shared = Li2()
    private init() {}

    // MARK: - Configuration

    internal(set) var config: Li2Config?

    public static func configure(_ config: Li2Config) {
        shared.config = config
    }

    public static func configure(
        publishableKey: String,
        deepLinkDomains: [String]
    ) {
        configure(Li2Config(
            publishableKey: publishableKey,
            deepLinkDomains: deepLinkDomains
        ))
    }

    // MARK: - Conversion tracking

    /// Track a lead event. Three types depending on `clickId` and `externalId`:
    /// - **Attributed identified**: `clickId` resolved, `externalId` provided
    /// - **Attributed anonymous**: `clickId` resolved, `externalId` omitted
    /// - **Direct**: `clickId = Li2.noAttribution ("")`, `externalId` required
    @discardableResult
    public static func trackLead(_ event: Li2LeadEvent) async throws -> Li2LeadResult {
        try await Li2ConversionClient.shared.trackLead(event)
    }

    /// Track a sale event. Two types:
    /// - **Attributed**: `clickId` resolved, `externalId` required
    /// - **Direct**: `clickId = Li2.noAttribution ("")`, `externalId` required
    @discardableResult
    public static func trackSale(_ event: Li2SaleEvent) async throws -> Li2SaleResult {
        try await Li2ConversionClient.shared.trackSale(event)
    }

    // MARK: - Sentinels

    /// Pass as `clickId` in `Li2LeadEvent` or `Li2SaleEvent` to explicitly record
    /// an unattributed (direct) conversion with no deep link click association.
    ///
    /// Sends `"click_id": ""` on the wire. The backend requires the field to always
    /// be present — never omit it or pass `nil` directly (that returns HTTP 400).
    public static let noAttribution: String = ""
}
