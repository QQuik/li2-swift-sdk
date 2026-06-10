import UIKit

/// Silent clipboard presence probe — checks whether the clipboard has pasteable
/// content without triggering the iOS "Allow Paste" alert or the iOS 14+ banner.
/// Use this to decide whether to show a `Li2PasteButton` vs a plain Continue button.
enum ClipboardProber {

    /// Returns `true` if the clipboard reports having strings or URLs.
    /// This uses `hasStrings`/`hasURLs` which are read-permission-free on all
    /// supported iOS versions.
    static func hasContent() -> Bool {
        UIPasteboard.general.hasStrings || UIPasteboard.general.hasURLs
    }

    /// Reads the clipboard string, triggering:
    /// - iOS 16+: the "Allow Paste / Don't Allow" blocking alert (use `Li2PasteButton` instead)
    /// - iOS 14–15: a passive top-of-screen banner, non-blocking
    /// - iOS < 14: silent, no notification
    ///
    /// Returns `nil` if the user denied access (iOS 16+) or the clipboard was empty.
    static func readString() -> String? {
        let raw = UIPasteboard.general.string
        let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed?.isEmpty == false ? trimmed : nil
    }
}
