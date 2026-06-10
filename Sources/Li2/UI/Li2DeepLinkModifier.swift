import SwiftUI

/// Apply `.li2DeepLink { outcome in }` to your root view to wire deep link
/// handling automatically. This is a thin convenience wrapper around
/// `Li2DeepLinkManager` — for UIKit or custom flows, call the manager directly.
struct Li2DeepLinkModifier: ViewModifier {
    let onOutcome: (Li2DeepLinkOutcome) -> Void

    @ObservedObject private var manager = Li2DeepLinkManager.shared

    func body(content: Content) -> some View {
        content
            .onOpenURL { url in
                manager.handleUniversalLink(url)
            }
            .onContinueUserActivity("NSUserActivityTypeBrowsingWeb") { activity in
                if let url = activity.webpageURL {
                    manager.handleUniversalLink(url)
                }
            }
            .task {
                manager.requestFirstLaunchConsentAfterGrace()
            }
            .fullScreenCover(isPresented: $manager.isConsentPending) {
                Li2ConsentView()
            }
            .onChange(of: manager.lastOutcome) { outcome in
                if let outcome { onOutcome(outcome) }
            }
    }
}

public extension View {
    /// Wire Li2 deep link handling to this view. Call on your root `WindowGroup` content.
    ///
    /// ```swift
    /// @main struct MyApp: App {
    ///     var body: some Scene {
    ///         WindowGroup {
    ///             ContentView()
    ///                 .li2DeepLink { outcome in
    ///                     switch outcome {
    ///                     case .matched(let dest, _): navigate(to: dest)
    ///                     case .missed, .failed: break
    ///                     }
    ///                 }
    ///         }
    ///     }
    /// }
    /// ```
    func li2DeepLink(onOutcome: @escaping (Li2DeepLinkOutcome) -> Void) -> some View {
        modifier(Li2DeepLinkModifier(onOutcome: onOutcome))
    }
}
