//
//  Li2DeepLinkModifier.swift
//  Li2
//
//  One-line integration: attach `.li2DeepLink(using: resolver)` to your root
//  view and the SDK wires up Universal Links, user activity continuation, and
//  the first-launch consent grace window automatically.
//

#if canImport(UIKit)
import SwiftUI

private struct Li2DeepLinkModifier: ViewModifier {
    let resolver: Li2DeepLinkResolver

    func body(content: Content) -> some View {
        content
            .onOpenURL { url in
                resolver.handle(url: url)
            }
            .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                guard let url = activity.webpageURL else { return }
                resolver.handle(url: url)
            }
            .task {
                resolver.requestFirstLaunchConsentAfterGrace()
            }
    }
}

public extension View {
    /// Wires Universal Link handling and the first-launch deferred-attribution
    /// flow into this view. Apply once to your root view:
    ///
    /// ```swift
    /// ContentView()
    ///     .li2DeepLink(using: resolver)
    /// ```
    func li2DeepLink(using resolver: Li2DeepLinkResolver) -> some View {
        modifier(Li2DeepLinkModifier(resolver: resolver))
    }
}
#endif
