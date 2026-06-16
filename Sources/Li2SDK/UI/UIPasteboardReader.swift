//
//  UIPasteboardReader.swift
//  Li2
//
//  Production `PasteboardReading` backed by `UIPasteboard.general`, used by the
//  raw-probe deferred path (`beginRawProbeOptIn` — the iOS 15 path and the
//  iOS 16+ alternative to `Li2PasteButton`).
//
//  UIKit-only: on Linux the resolver's public init falls back to `NoOpPasteboard`
//  so Core stays buildable/testable there. This file is therefore verified on
//  Mac only (the WSL gate compiles the `#else` branch instead).
//

#if canImport(UIKit)
import UIKit

/// Reads `UIPasteboard.general` for the raw-probe consent path.
///
/// `hasContent` uses `hasStrings`/`hasURLs`, which report presence **without**
/// triggering the iOS paste alert — that presence check is what lets the
/// resolver tell a denial (`nil` read with content present) apart from a
/// genuinely empty clipboard (D-6c). `readString()` then reads `.string`, which
/// shows the "Allow Paste" alert on iOS 16+ (a passive banner on iOS 15).
struct UIPasteboardReader: PasteboardReading {
    var hasContent: Bool {
        UIPasteboard.general.hasStrings || UIPasteboard.general.hasURLs
    }

    func readString() -> String? {
        UIPasteboard.general.string
    }
}
#endif
