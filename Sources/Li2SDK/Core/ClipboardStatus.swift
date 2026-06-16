import Foundation

/// Wire values for the `clipboardStatus` field on `/track/open`.
/// Distinct from each other so the server can separate user choices from
/// system permission outcomes.
public enum ClipboardStatus: String, Sendable {
    /// User opted in (paste tap / raw probe) and content arrived.
    case read
    /// User opted in but clipboard was genuinely empty.
    case empty
    /// User opted in via raw probe on iOS 16+; OS blocked the read ("Don't Allow").
    /// Unreachable on iOS 15 (no blocking alert).
    case denied
    /// User tapped Skip — distinct from `denied`, never collapse these.
    case optout
}