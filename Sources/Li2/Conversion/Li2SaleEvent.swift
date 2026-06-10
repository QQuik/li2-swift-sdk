import Foundation

/// A sale event to send via `Li2.trackSale(_:)`.
///
/// Two types based on `clickId`:
///
/// **Attributed sale** — `clickId` auto-filled (or explicit):
/// ```swift
/// Li2SaleEvent(externalId: "order_123", amount: 4999, currency: "USD")
/// ```
///
/// **Direct sale** — no deep link attribution:
/// ```swift
/// Li2SaleEvent(externalId: "order_456", amount: 1999, clickId: Li2.noAttribution)
/// ```
public struct Li2SaleEvent {

    /// Your system's order/transaction identifier. Required.
    /// Must **not** start with `"anon_"` — that prefix is reserved.
    public let externalId: String

    /// Sale amount in the smallest currency unit (e.g. cents for USD). Required.
    public let amount: Int

    /// Attribution click ID.
    /// - `nil`: SDK auto-fills the last persisted `clickId`, or `""` if none/expired.
    /// - `Li2.noAttribution` (`""`): explicit direct sale.
    public var clickId: String?

    /// ISO 4217 currency code. Defaults to `"usd"` on the backend if omitted.
    public var currency: String?

    /// Event name. Defaults to `"Purchase"` on the backend if omitted.
    public var eventName: String?

    /// Payment processor name (e.g. `"stripe"`, `"paypal"`). Defaults to `"custom"`.
    public var paymentProcessor: String?

    /// Your invoice ID — stored as-is, not deduplicated at the DB level.
    public var invoiceId: String?

    public var email: String?
    public var phone: String?
    public var name: String?
    public var avatarURL: String?
    public var metadata: [String: Any]?

    public init(
        externalId: String,
        amount: Int,
        clickId: String? = nil,
        currency: String? = nil,
        eventName: String? = nil,
        paymentProcessor: String? = nil,
        invoiceId: String? = nil,
        email: String? = nil,
        phone: String? = nil,
        name: String? = nil,
        avatarURL: String? = nil,
        metadata: [String: Any]? = nil
    ) {
        self.externalId = externalId
        self.amount = amount
        self.clickId = clickId
        self.currency = currency
        self.eventName = eventName
        self.paymentProcessor = paymentProcessor
        self.invoiceId = invoiceId
        self.email = email
        self.phone = phone
        self.name = name
        self.avatarURL = avatarURL
        self.metadata = metadata
    }
}
