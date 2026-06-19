import Foundation

/// Errors thrown by the Li2 conversion API methods.
public enum Li2ConversionError: Error, LocalizedError, Sendable {

    /// The API base URL could not be formed into a valid URL.
    case invalidURL

    /// The call requires a `clickId` (attributed/anonymous/identify) but
    /// `Li2.lastClickId` is nil and no explicit clickId was supplied.
    /// Thrown **before** any network call.
    case noClickIdAvailable

    /// `identify` requires a non-empty `externalId` to promote the anonymous
    /// profile to an identified one. An empty id would land a `__identify__`
    /// lead that promotes nothing (silent no-op). Thrown **before** any
    /// network call. Mirrors the JS SDK's `customerExternalId is required` guard.
    case missingExternalId

    /// The server returned a non-2xx status. `code` is the HTTP status;
    /// `message` is the top-level envelope `message` field.
    case httpError(Int, String)

    /// The response body could not be decoded. `detail` is the decode error;
    /// `raw` is the raw response string for debugging.
    case decodeError(String, String)

    /// An underlying network transport error.
    case network(Error)

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid conversion API URL"
        case .noClickIdAvailable:
            return "No clickId available. Ensure Li2.lastClickId is set (a deep-link match persists it) or supply an explicit clickId."
        case .missingExternalId:
            return "externalId is required for identify. Provide the user's stable identifier to promote the anonymous profile."
        case .httpError(let code, let msg):
            return "HTTP \(code): \(msg)"
        case .decodeError(let detail, let raw):
            let snippet = raw.prefix(256)
            return snippet.isEmpty
                ? "Decode error: \(detail)"
                : "Decode error: \(detail) — body: \(snippet)"
        case .network(let err):
            return "Network error: \(err.localizedDescription)"
        }
    }
}
