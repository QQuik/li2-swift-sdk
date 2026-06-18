import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - Protocol (enables Linux-testable injection)

/// Abstraction over the conversion HTTP calls — mirrors `TrackOpenCalling`.
/// The `RecordingClient` and `NeverCalledClient` test stubs conform to this.
public protocol ConversionCalling: Sendable {
    func lead(_ request: LeadRequest) async throws -> LeadData
    func sale(_ request: SaleRequest) async throws -> SaleData
}

// MARK: - Production client

/// Thin async HTTP client for `/track/lead` and `/track/sale`.
/// Stateless struct — mirrors `TrackOpenClient` exactly for setup.
///
/// Wire dialect: snake_case keys (pinned in CodingKeys), enveloped response.
/// SEPARATE encoder/decoder from TrackOpenClient — never share them.
public struct ConversionClient: ConversionCalling {

    public let baseURL: String
    public let publishableKey: String

    public init(baseURL: String, publishableKey: String) {
        self.baseURL = baseURL
        self.publishableKey = publishableKey
    }

    // Plain encoder — never convertToSnakeCase. Keys are pinned in CodingKeys.
    private static let encoder = JSONEncoder()
    private static let decoder = JSONDecoder()

    private static let leadEndpoint = "/track/lead"
    private static let saleEndpoint = "/track/sale"

    // MARK: lead

    public func lead(_ request: LeadRequest) async throws -> LeadData {
        let result = try await post(path: Self.leadEndpoint, body: request)
        return try decode(LeadData.self, from: result)
    }

    // MARK: sale

    public func sale(_ request: SaleRequest) async throws -> SaleData {
        let result = try await post(path: Self.saleEndpoint, body: request)
        return try decode(SaleData.self, from: result)
    }

    // MARK: - Shared request builder

    private func post<B: Encodable>(path: String, body: B) async throws -> (Data, Int) {
        let trimmed = baseURL.trimmingTrailingSlashes()
        guard let url = URL(string: "\(trimmed)\(path)") else {
            throw Li2ConversionError.invalidURL
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 15
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(publishableKey, forHTTPHeaderField: "X-Li2-Key")

        do {
            req.httpBody = try Self.encoder.encode(body)
        } catch {
            throw Li2ConversionError.network(error)
        }

        let (responseData, urlResponse): (Data, URLResponse)
        do {
            (responseData, urlResponse) = try await URLSession.shared.data(for: req)
        } catch {
            throw Li2ConversionError.network(error)
        }

        guard let http = urlResponse as? HTTPURLResponse else {
            throw Li2ConversionError.network(URLError(.badServerResponse))
        }

        return (responseData, http.statusCode)
    }

    // MARK: - Envelope unwrap

    private func decode<T: Decodable>(_ type: T.Type, from result: (Data, Int)) throws -> T {
        let (data, statusCode) = result
        let raw = String(data: data, encoding: .utf8) ?? ""

        // Decode the envelope regardless of status to get the message field
        let envelope: Envelope<T>
        do {
            envelope = try Self.decoder.decode(Envelope<T>.self, from: data)
        } catch {
            if !(200..<300).contains(statusCode) {
                throw Li2ConversionError.httpError(statusCode, raw)
            }
            throw Li2ConversionError.decodeError(error.localizedDescription, raw)
        }

        guard (200..<300).contains(statusCode) else {
            // On error: data is null; message is the top-level field
            throw Li2ConversionError.httpError(statusCode, envelope.message)
        }

        guard let payload = envelope.data else {
            throw Li2ConversionError.decodeError("Envelope data was null on success", raw)
        }

        return payload
    }
}
