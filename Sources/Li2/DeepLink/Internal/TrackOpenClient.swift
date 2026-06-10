import Foundation

struct TrackOpenRequest: Encodable {
    let deepLink: String?
    let li2Domains: [String]?
    let clipboardStatus: String?

    init(
        deepLink: String? = nil,
        li2Domains: [String]? = nil,
        clipboardStatus: String? = nil
    ) {
        self.deepLink = deepLink
        self.li2Domains = li2Domains
        self.clipboardStatus = clipboardStatus
    }
}

struct TrackOpenResponse: Codable {
    let clickId: String
    let link: LinkDTO?
    let matchMethod: String?
    let missReason: String?
    let platform: String?

    struct LinkDTO: Codable {
        let id: String
        let domain: String
        let key: String
        let url: String
    }
}

public enum Li2TrackOpenError: Error, LocalizedError {
    case invalidURL
    case emptyRequest
    case httpError(Int, String)
    case decodeError(String, String)

    public var errorDescription: String? {
        switch self {
        case .invalidURL:           return "Invalid API base URL"
        case .emptyRequest:         return "Request must include deepLink or li2Domains"
        case .httpError(let c, _):  return "HTTP \(c)"
        case .decodeError(let m, _): return "Decode error: \(m)"
        }
    }
}

struct TrackOpenClient {
    let baseURL: String
    let publishableKey: String

    private static let encoder = JSONEncoder()
    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    func open(_ request: TrackOpenRequest) async throws -> TrackOpenResponse {
        guard request.deepLink != nil || (request.li2Domains?.isEmpty == false) else {
            throw Li2TrackOpenError.emptyRequest
        }
        guard let url = URL(string: baseURL.trimmingTrailingSlashes() + "/track/open") else {
            throw Li2TrackOpenError.invalidURL
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 15
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(publishableKey, forHTTPHeaderField: "X-Li2-Key")
        req.httpBody = try Self.encoder.encode(request)

        let (data, urlResponse) = try await URLSession.shared.data(for: req)
        guard let http = urlResponse as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        let raw = String(data: data, encoding: .utf8) ?? ""
        guard (200..<300).contains(http.statusCode) else {
            throw Li2TrackOpenError.httpError(http.statusCode, raw)
        }
        do {
            return try Self.decoder.decode(TrackOpenResponse.self, from: data)
        } catch {
            throw Li2TrackOpenError.decodeError(error.localizedDescription, raw)
        }
    }
}

private extension String {
    func trimmingTrailingSlashes() -> String {
        var s = self; while s.hasSuffix("/") { s.removeLast() }; return s
    }
}
