import Foundation

// MARK: - Result types

public struct Li2LeadResult {
    public let customerId: String?
    public let leadEventId: String?
    public let duplicate: Bool
}

public struct Li2SaleResult {
    public let saleEventId: String?
    public let customerId: String?
    public let duplicate: Bool
}

// MARK: - Error

public enum Li2TrackingError: Error, LocalizedError {
    /// `Li2.configure(...)` was not called before tracking.
    case notConfigured
    /// `externalId` starts with `"anon_"` — reserved for server-generated anonymous profiles.
    case anonPrefixReserved
    /// `externalId` is required for direct conversions (`clickId == ""`).
    case externalIdRequired
    case httpError(Int, String)
    case decodeError(String, String)

    public var errorDescription: String? {
        switch self {
        case .notConfigured:       return "Call Li2.configure(...) before tracking events"
        case .anonPrefixReserved:  return "externalId must not start with \"anon_\" — reserved prefix"
        case .externalIdRequired:  return "externalId is required for direct conversions (clickId = \"\")"
        case .httpError(let c, _): return "HTTP \(c)"
        case .decodeError(let m, _): return "Decode error: \(m)"
        }
    }
}

// MARK: - Wire response shapes

private struct LeadResponseDTO: Decodable {
    let success: Bool
    let customerId: String?
    let leadEventId: String?
    let duplicate: Bool?
    let message: String?
}

private struct SaleResponseDTO: Decodable {
    let success: Bool
    let saleEventId: String?
    let customerId: String?
    let duplicate: Bool?
    let message: String?
}

// MARK: - Client

final class Li2ConversionClient {

    static let shared = Li2ConversionClient()
    private init() {}

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.keyEncodingStrategy = .convertToSnakeCase
        return e
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    // MARK: - trackLead

    func trackLead(_ event: Li2LeadEvent) async throws -> Li2LeadResult {
        guard let config = Li2.shared.config else { throw Li2TrackingError.notConfigured }

        // Guard reserved prefix
        if let eid = event.externalId, eid.hasPrefix("anon_") {
            throw Li2TrackingError.anonPrefixReserved
        }

        // Resolve clickId — explicit (including Li2.noAttribution "") wins; otherwise auto-fill
        let wireClickId = Li2DeepLinkManager.shared.resolvedClickId(explicitValue: event.clickId)

        // Direct lead requires externalId
        if wireClickId.isEmpty && (event.externalId?.isEmpty ?? true) {
            throw Li2TrackingError.externalIdRequired
        }

        var body: [String: Any] = [
            "click_id": wireClickId,
            "event_name": event.eventName,
            "event_id": UUID().uuidString
        ]
        if let v = event.externalId,  !v.isEmpty { body["external_id"] = v }
        if let v = event.email,        !v.isEmpty { body["email"] = v }
        if let v = event.phone,        !v.isEmpty { body["phone"] = v }
        if let v = event.name,         !v.isEmpty { body["name"] = v }
        if let v = event.avatarURL,    !v.isEmpty { body["avatar"] = v }
        if let v = event.metadata                 { body["metadata"] = v }

        let dto: LeadResponseDTO = try await post(path: "/track/lead", body: body, config: config)
        return Li2LeadResult(
            customerId: dto.customerId,
            leadEventId: dto.leadEventId,
            duplicate: dto.duplicate ?? false
        )
    }

    // MARK: - trackSale

    func trackSale(_ event: Li2SaleEvent) async throws -> Li2SaleResult {
        guard let config = Li2.shared.config else { throw Li2TrackingError.notConfigured }

        if event.externalId.hasPrefix("anon_") {
            throw Li2TrackingError.anonPrefixReserved
        }

        let wireClickId = Li2DeepLinkManager.shared.resolvedClickId(explicitValue: event.clickId)

        var body: [String: Any] = [
            "external_id": event.externalId,
            "amount": event.amount,
            "click_id": wireClickId,
            "event_id": UUID().uuidString
        ]
        if let v = event.currency,        !v.isEmpty { body["currency"] = v }
        if let v = event.eventName,       !v.isEmpty { body["event_name"] = v }
        if let v = event.paymentProcessor,!v.isEmpty { body["payment_processor"] = v }
        if let v = event.invoiceId,       !v.isEmpty { body["invoice_id"] = v }
        if let v = event.email,           !v.isEmpty { body["email"] = v }
        if let v = event.phone,           !v.isEmpty { body["phone"] = v }
        if let v = event.name,            !v.isEmpty { body["name"] = v }
        if let v = event.avatarURL,       !v.isEmpty { body["avatar_url"] = v }
        if let v = event.metadata                    { body["metadata"] = v }

        let dto: SaleResponseDTO = try await post(path: "/track/sale", body: body, config: config)
        return Li2SaleResult(
            saleEventId: dto.saleEventId,
            customerId: dto.customerId,
            duplicate: dto.duplicate ?? false
        )
    }

    // MARK: - Shared HTTP

    private func post<T: Decodable>(path: String, body: [String: Any], config: Li2Config) async throws -> T {
        let base = config.apiBaseURL.trimmingTrailingSlashes()
        guard let url = URL(string: base + path) else { throw Li2TrackingError.httpError(0, "Invalid URL") }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 15
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(config.publishableKey, forHTTPHeaderField: "X-Li2-Key")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, urlResponse) = try await URLSession.shared.data(for: req)
        guard let http = urlResponse as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        let raw = String(data: data, encoding: .utf8) ?? ""

        guard (200..<300).contains(http.statusCode) else {
            throw Li2TrackingError.httpError(http.statusCode, raw)
        }
        do {
            return try Self.decoder.decode(T.self, from: data)
        } catch {
            throw Li2TrackingError.decodeError(error.localizedDescription, raw)
        }
    }
}

private extension String {
    func trimmingTrailingSlashes() -> String {
        var s = self; while s.hasSuffix("/") { s.removeLast() }; return s
    }
}
