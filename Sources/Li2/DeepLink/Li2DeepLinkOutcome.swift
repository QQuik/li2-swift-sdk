import Foundation

/// The resolved outcome of a `/track/open` call. Switch on this and navigate.
public enum Li2DeepLinkOutcome: Equatable {

    /// The server matched a link. `destination` is the target URL with the
    /// `li2_cid` tracking parameter stripped. `clickId` is for analytics only —
    /// pass it to `trackLead`/`trackSale` or let the SDK auto-fill it.
    ///
    /// - Important: Route on `destination` alone; do not branch on `clickId`.
    case matched(destination: URL, clickId: String)

    /// The server responded but found no matching link. `reason` mirrors the
    /// server's `missReason` and is for logging only.
    case missed(reason: String?)

    /// A network, HTTP (non-2xx), or decode error occurred.
    /// Pattern-match `error as? Li2TrackOpenError` for details.
    case failed(Error)

    public static func == (lhs: Li2DeepLinkOutcome, rhs: Li2DeepLinkOutcome) -> Bool {
        switch (lhs, rhs) {
        case (.matched(let d1, let c1), .matched(let d2, let c2)):
            return d1 == d2 && c1 == c2
        case (.missed(let r1), .missed(let r2)):
            return r1 == r2
        case (.failed, .failed):
            return true
        default:
            return false
        }
    }
}
