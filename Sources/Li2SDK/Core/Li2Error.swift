import Foundation

/// SDK-level errors distinct from network/HTTP errors (those use `TrackOpenError`).
public enum Li2Error: Error, LocalizedError, Sendable {
    /// Server returned a matched link but `link.url` couldn't be parsed into a URL.
    case unparsableDestination(raw: String)

    public var errorDescription: String? {
        switch self {
        case .unparsableDestination(let raw):
            return "Li2: server returned unparsable destination URL: \"\(raw)\""
        }
    }
}
