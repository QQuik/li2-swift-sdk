import Foundation

/// The resolved outcome of one `/track/open` call.
/// Switch on this and navigate — the SDK never navigates for you.
public enum Li2DeepLinkOutcome: Sendable {

    /// Server matched a link. `destination` has the `li2_cid` param stripped.
    /// Route on `destination` only; `clickId` is for analytics logging.
    case matched(destination: URL, clickId: String)

    /// Server responded but found no matching link.
    /// `reason` mirrors `missReason`; handle every miss the same way in navigation.
    case missed(reason: String?)

    /// Network, HTTP, decode error, or unparsable server destination.
    /// Pattern-match `error as? TrackOpenError` for HTTP details.
    case failed(Error)
}
