import Foundation

/// Testability seam over `UIPasteboard.general`.
/// Production implementation lives behind `#if canImport(UIKit)` in UI/.
/// Tests inject `MockPasteboard` so the resolver state machine runs on Linux.
public protocol PasteboardReading: Sendable {
    /// `true` if the pasteboard reports string or URL content (no OS alert).
    var hasContent: Bool { get }
    /// Read the pasteboard string. May return `nil` if the OS blocked access ("Don't Allow").
    /// Returns `""` (not `nil`) for a genuinely empty read that was allowed.
    func readString() -> String?
}
