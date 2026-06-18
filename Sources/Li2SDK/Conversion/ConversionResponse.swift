import Foundation

// MARK: - Envelope

/// Conversion endpoints return `{code, message, data}` (DIFFERENT from /track/open's flat body).
/// `data` is `null` on error responses — T? handles both cases.
/// On error: read top-level `message`. Do NOT look in `data.message`.
public struct Envelope<T: Decodable>: Decodable {
    public let code: Int
    public let message: String
    public let data: T?
}

// MARK: - Lead success data

/// `data` payload from a successful `POST /track/lead` response.
public struct LeadData: Decodable, Sendable {
    public let success: Bool
    public let customerId: String?

    enum CodingKeys: String, CodingKey {
        case success
        case customerId = "customer_id"
    }
}

// MARK: - Sale success data

/// `data` payload from a successful `POST /track/sale` response.
public struct SaleData: Decodable, Sendable {
    public let success: Bool
    public let saleEventId: String?
    public let customerId: String?

    enum CodingKeys: String, CodingKey {
        case success
        case saleEventId  = "sale_event_id"
        case customerId   = "customer_id"
    }
}
