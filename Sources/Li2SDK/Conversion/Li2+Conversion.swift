import Foundation

// MARK: - Public result types

/// Result of a successful `trackLead` / `identify` call.
public struct Li2LeadResult: Sendable {
    public let customerId: String?
}

/// Result of a successful `trackSale` call.
public struct Li2SaleResult: Sendable {
    public let saleEventId: String?
    public let customerId: String?
}

// MARK: - Conversion statics on Li2

extension Li2 {

    // MARK: Lead — 3 types (D-9)

    /// Direct lead: no deep-link attribution. `click_id` is always `""` (required by server).
    /// `externalId` is required. No clickId is read from `Li2.lastClickId`.
    public static func trackDirectLead(
        externalId: String,
        eventName: String? = nil,
        email: String? = nil,
        name: String? = nil,
        phone: String? = nil,
        metadata: [String: String]? = nil,
        config: Li2Config? = nil,
        client: ConversionCalling? = nil,
        clickIdStore: ClickIdStore? = nil
    ) async throws -> Li2LeadResult {
        let cfg = config ?? Li2.config
        let c = client ?? ConversionClient(baseURL: cfg.apiBaseURL, publishableKey: cfg.publishableKey)
        let req = LeadRequest(
            clickId: "",
            externalId: externalId,
            eventName: eventName,
            email: email,
            name: name,
            phone: phone,
            metadata: metadata
        )
        let data = try await c.lead(req)
        return Li2LeadResult(customerId: data.customerId)
    }

    /// Anonymous lead: attributed to a click but no known user identity.
    /// `clickId` defaults to `Li2.lastClickId`; throws `.noClickIdAvailable` if nil.
    /// No `external_id` is sent — the server auto-generates `anon_<clickId>`.
    public static func trackAnonymousLead(
        eventName: String? = nil,
        clickId explicitClickId: String? = nil,
        email: String? = nil,
        name: String? = nil,
        phone: String? = nil,
        metadata: [String: String]? = nil,
        config: Li2Config? = nil,
        client: ConversionCalling? = nil,
        clickIdStore: ClickIdStore? = nil
    ) async throws -> Li2LeadResult {
        let cfg = config ?? Li2.config
        let store = clickIdStore ?? ClickIdStore.shared
        guard let cid = explicitClickId ?? store.currentClickId else {
            throw Li2ConversionError.noClickIdAvailable
        }
        let c = client ?? ConversionClient(baseURL: cfg.apiBaseURL, publishableKey: cfg.publishableKey)
        let req = LeadRequest(
            clickId: cid,
            externalId: nil,
            eventName: eventName,
            email: email,
            name: name,
            phone: phone,
            metadata: metadata
        )
        let data = try await c.lead(req)
        return Li2LeadResult(customerId: data.customerId)
    }

    /// Attributed lead: ties a known user identity to a deep-link click.
    /// `clickId` defaults to `Li2.lastClickId`; throws `.noClickIdAvailable` if nil.
    public static func trackAttributedLead(
        externalId: String,
        eventName: String? = nil,
        clickId explicitClickId: String? = nil,
        email: String? = nil,
        name: String? = nil,
        phone: String? = nil,
        metadata: [String: String]? = nil,
        config: Li2Config? = nil,
        client: ConversionCalling? = nil,
        clickIdStore: ClickIdStore? = nil
    ) async throws -> Li2LeadResult {
        let cfg = config ?? Li2.config
        let store = clickIdStore ?? ClickIdStore.shared
        guard let cid = explicitClickId ?? store.currentClickId else {
            throw Li2ConversionError.noClickIdAvailable
        }
        let c = client ?? ConversionClient(baseURL: cfg.apiBaseURL, publishableKey: cfg.publishableKey)
        let req = LeadRequest(
            clickId: cid,
            externalId: externalId,
            eventName: eventName,
            email: email,
            name: name,
            phone: phone,
            metadata: metadata
        )
        let data = try await c.lead(req)
        return Li2LeadResult(customerId: data.customerId)
    }

    // MARK: Sale — 2 types (D-9)

    /// Direct sale: no deep-link attribution. `click_id` is always `""`.
    public static func trackDirectSale(
        externalId: String,
        amount: Int,
        currency: String? = nil,
        eventName: String? = nil,
        paymentProcessor: String? = nil,
        invoiceId: String? = nil,
        email: String? = nil,
        name: String? = nil,
        phone: String? = nil,
        avatarUrl: String? = nil,
        metadata: [String: String]? = nil,
        config: Li2Config? = nil,
        client: ConversionCalling? = nil,
        clickIdStore: ClickIdStore? = nil
    ) async throws -> Li2SaleResult {
        let cfg = config ?? Li2.config
        let c = client ?? ConversionClient(baseURL: cfg.apiBaseURL, publishableKey: cfg.publishableKey)
        let req = SaleRequest(
            clickId: "",
            externalId: externalId,
            amount: amount,
            currency: currency,
            eventName: eventName,
            paymentProcessor: paymentProcessor,
            invoiceId: invoiceId,
            email: email,
            name: name,
            phone: phone,
            avatarUrl: avatarUrl,
            metadata: metadata
        )
        let data = try await c.sale(req)
        return Li2SaleResult(saleEventId: data.saleEventId, customerId: data.customerId)
    }

    /// Attributed sale: ties a sale to a deep-link click.
    /// `clickId` defaults to `Li2.lastClickId`; throws `.noClickIdAvailable` if nil.
    public static func trackAttributedSale(
        externalId: String,
        amount: Int,
        clickId explicitClickId: String? = nil,
        currency: String? = nil,
        eventName: String? = nil,
        paymentProcessor: String? = nil,
        invoiceId: String? = nil,
        email: String? = nil,
        name: String? = nil,
        phone: String? = nil,
        avatarUrl: String? = nil,
        metadata: [String: String]? = nil,
        config: Li2Config? = nil,
        client: ConversionCalling? = nil,
        clickIdStore: ClickIdStore? = nil
    ) async throws -> Li2SaleResult {
        let cfg = config ?? Li2.config
        let store = clickIdStore ?? ClickIdStore.shared
        guard let cid = explicitClickId ?? store.currentClickId else {
            throw Li2ConversionError.noClickIdAvailable
        }
        let c = client ?? ConversionClient(baseURL: cfg.apiBaseURL, publishableKey: cfg.publishableKey)
        let req = SaleRequest(
            clickId: cid,
            externalId: externalId,
            amount: amount,
            currency: currency,
            eventName: eventName,
            paymentProcessor: paymentProcessor,
            invoiceId: invoiceId,
            email: email,
            name: name,
            phone: phone,
            avatarUrl: avatarUrl,
            metadata: metadata
        )
        let data = try await c.sale(req)
        return Li2SaleResult(saleEventId: data.saleEventId, customerId: data.customerId)
    }

    // MARK: Identify (D-14)

    /// Promotes an anonymous profile (`anon_<clickId>`) to an identified user,
    /// so a subsequent `trackAttributedSale` can find the right customer.
    ///
    /// This is NOT redundant sugar: `TrackSale` has no anonymous-merge path.
    /// Without `identify`, an `anon_<clickId>` lead followed by an attributed sale
    /// creates two split customer profiles (D-14 in README).
    ///
    /// Implemented as `trackAttributedLead(eventName:"__identify__", metadata:{type,anonymous_click_id})`.
    /// The `__identify__` lead writes a real conversion_events row and increments
    /// `lead_count` — accepted behavior, no backend filter exists (out of scope).
    ///
    /// `clickId` defaults to `Li2.lastClickId`; throws `.noClickIdAvailable` if nil.
    public static func identify(
        externalId: String,
        email: String? = nil,
        name: String? = nil,
        clickId explicitClickId: String? = nil,
        config: Li2Config? = nil,
        client: ConversionCalling? = nil,
        clickIdStore: ClickIdStore? = nil
    ) async throws -> Li2LeadResult {
        let cfg = config ?? Li2.config
        let store = clickIdStore ?? ClickIdStore.shared
        guard let cid = explicitClickId ?? store.currentClickId else {
            throw Li2ConversionError.noClickIdAvailable
        }
        let c = client ?? ConversionClient(baseURL: cfg.apiBaseURL, publishableKey: cfg.publishableKey)
        let req = LeadRequest(
            clickId: cid,
            externalId: externalId,
            eventName: "__identify__",
            email: email,
            name: name,
            phone: nil,
            metadata: [
                "type": "identify",
                "anonymous_click_id": cid
            ]
        )
        let data = try await c.lead(req)
        return Li2LeadResult(customerId: data.customerId)
    }
}
