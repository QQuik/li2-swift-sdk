import Foundation

// MARK: - Lead request

/// Wire type for `POST /track/lead`.
/// Keys are snake_case — CodingKeys are PINNED. Never use convertToSnakeCase.
/// This is a DIFFERENT dialect from TrackOpenRequest (camelCase).
public struct LeadRequest: Encodable, Sendable {

    /// Always `""` for Direct; a valid clickId for Anonymous/Attributed.
    /// `nil` is NEVER sent — the server returns 400 if click_id is absent.
    public let clickId: String

    /// Present for Attributed and Direct; omitted for Anonymous.
    public let externalId: String?

    public let eventName: String?
    public let email: String?
    public let name: String?
    public let phone: String?
    public let metadata: [String: String]?

    public init(
        clickId: String,
        externalId: String? = nil,
        eventName: String? = nil,
        email: String? = nil,
        name: String? = nil,
        phone: String? = nil,
        metadata: [String: String]? = nil
    ) {
        self.clickId = clickId
        self.externalId = externalId
        self.eventName = eventName
        self.email = email
        self.name = name
        self.phone = phone
        self.metadata = metadata
    }

    enum CodingKeys: String, CodingKey {
        case clickId      = "click_id"
        case externalId   = "external_id"
        case eventName    = "event_name"
        case email
        case name
        case phone
        case metadata
    }
}

// MARK: - Sale request

/// Wire type for `POST /track/sale`.
/// Same snake_case dialect as LeadRequest.
public struct SaleRequest: Encodable, Sendable {

    public let clickId: String
    public let externalId: String
    /// Minor units (cents). `binding:"required"` on server — 0 is rejected.
    public let amount: Int
    /// Omitted when nil so the server uses the org default (D-13).
    public let currency: String?
    public let eventName: String?
    public let paymentProcessor: String?
    public let invoiceId: String?
    public let email: String?
    public let name: String?
    public let phone: String?
    public let avatarUrl: String?
    public let metadata: [String: String]?

    public init(
        clickId: String,
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
        metadata: [String: String]? = nil
    ) {
        self.clickId = clickId
        self.externalId = externalId
        self.amount = amount
        self.currency = currency
        self.eventName = eventName
        self.paymentProcessor = paymentProcessor
        self.invoiceId = invoiceId
        self.email = email
        self.name = name
        self.phone = phone
        self.avatarUrl = avatarUrl
        self.metadata = metadata
    }

    enum CodingKeys: String, CodingKey {
        case clickId          = "click_id"
        case externalId       = "external_id"
        case amount
        case currency
        case eventName        = "event_name"
        case paymentProcessor = "payment_processor"
        case invoiceId        = "invoice_id"
        case email
        case name
        case phone
        case avatarUrl        = "avatar_url"
        case metadata
    }
}
