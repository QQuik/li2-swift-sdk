import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - Wire types

/// Request body for `POST /track/open`.
/// Keys are camelCase — the encoder must NOT use convertToSnakeCase.
public struct TrackOpenRequest: Encodable, Sendable {
    public let deepLink: String?
    public let li2Domains: [String]?
    public let clipboardStatus: String?

    public init(deepLink: String? = nil, li2Domains: [String]? = nil, clipboardStatus: String? = nil) {
        self.deepLink = deepLink
        self.li2Domains = li2Domains
        self.clipboardStatus = clipboardStatus
    }
}

/// Response body for `POST /track/open`.  Flat (no envelope) on success.
public struct TrackOpenResponse: Codable, Sendable {
    public let clickId: String
    public let link: LinkDTO?
    public let matchMethod: String?
    public let missReason: String?
    public let platform: String?

    public struct LinkDTO: Codable, Sendable {
        public let id: String
        public let domain: String
        public let key: String
        public let url: String
    }
}

/// Errors thrown by `TrackOpenClient.open(_:)`.
public enum TrackOpenError: Error, LocalizedError, Sendable {
    case invalidURL
    case emptyRequest
    case httpError(Int, String)
    case decodeError(String, String)

    public var errorDescription: String? {
        switch self {
        case .invalidURL:        return "Invalid API base URL"
        case .emptyRequest:      return "Request must include deepLink or li2Domains"
        case .httpError(let c, _): return "HTTP \(c)"
        case .decodeError(let m, _): return "Decode error: \(m)"
        }
    }
}

// MARK: - Client

/// Thin async HTTP client for the deep-link resolution endpoint.
/// Stateless struct — create per call or hold one instance; either is fine.
public struct TrackOpenClient: Sendable {
    public let baseURL: String
    public let publishableKey: String

    public init(baseURL: String, publishableKey: String) {
        self.baseURL = baseURL
        self.publishableKey = publishableKey
    }

    // Plain encoder — never set convertToSnakeCase (that was v1's fatal bug).
    private static let encoder = JSONEncoder()
    private static let decoder = JSONDecoder()
    private static let openEndpoint = "/track/open"

    public struct OpenResult: Sendable {
        public let response: TrackOpenResponse
        public let statusCode: Int
    }

    public func open(_ request: TrackOpenRequest) async throws -> OpenResult {
        guard request.deepLink != nil || !(request.li2Domains?.isEmpty ?? true) else {
            throw TrackOpenError.emptyRequest
        }

        let trimmed = baseURL.trimmingTrailingSlashes()
        guard let url = URL(string: "\(trimmed)\(Self.openEndpoint)") else {
            throw TrackOpenError.invalidURL
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 15
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(publishableKey, forHTTPHeaderField: "X-Li2-Key")
        req.httpBody = try Self.encoder.encode(request)

        let (data, urlResponse) = try await URLSession.shared.data(for: req)
        guard let http = urlResponse as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        let rawBody = String(data: data, encoding: .utf8) ?? ""

        guard (200..<300).contains(http.statusCode) else {
            throw TrackOpenError.httpError(http.statusCode, rawBody)
        }

        do {
            let decoded = try Self.decoder.decode(TrackOpenResponse.self, from: data)
            return OpenResult(response: decoded, statusCode: http.statusCode)
        } catch {
            throw TrackOpenError.decodeError(error.localizedDescription, rawBody)
        }
    }
}

// MARK: - Helpers

extension String {
    func trimmingTrailingSlashes() -> String {
        var s = self
        while s.hasSuffix("/") { s.removeLast() }
        return s
    }
}
