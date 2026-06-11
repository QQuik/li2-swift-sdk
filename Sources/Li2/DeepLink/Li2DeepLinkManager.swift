import SwiftUI
import Combine

// File-level constants: no actor isolation, accessible from nonisolated methods.
private let _firstLaunchRanKey = "ai.li2.firstLaunchRan"
private let _clickIdKey = "ai.li2.lastClickId"
private let _clickIdExpiresAtKey = "ai.li2.lastClickIdExpiresAt"

/// The deep link attribution engine. All public methods are safe to call from
/// either the `.li2DeepLink {}` SwiftUI modifier or directly (UIKit / AppDelegate).
///
/// Access via `Li2DeepLinkManager.shared` after calling `Li2.configure(...)`.
@MainActor
public final class Li2DeepLinkManager: ObservableObject {

    // MARK: - Singleton

    public static let shared = Li2DeepLinkManager()

    // MARK: - Public state

    /// `true` while the first-launch consent sheet should be presented.
    /// Bind to `.fullScreenCover(isPresented: $manager.isConsentPending)`.
    @Published public private(set) var isConsentPending = false

    /// `true` while a `/track/open` network call is in flight.
    @Published public private(set) var isResolving = false

    /// The most recent outcome delivered by the SDK. Observe with `.onChange` or
    /// Combine to react to deep link resolutions.
    @Published public private(set) var lastOutcome: Li2DeepLinkOutcome?

    // MARK: - Private

    /// Set the moment a Universal Link arrives — prevents the deferred consent
    /// gate from firing when both arrive on the same launch.
    private var didReceiveURL = false

    private var config: Li2Config? { Li2.shared.config }

    // MARK: - Immediate path (Universal Link / custom scheme)

    /// Call from `.onOpenURL`, `.onContinueUserActivity`, or `AppDelegate`.
    /// Fires `/track/open` with the incoming URL immediately and cancels any
    /// pending first-launch consent prompt.
    public func handleUniversalLink(_ url: URL) {
        didReceiveURL = true
        isConsentPending = false
        Task { await call(TrackOpenRequest(deepLink: url.absoluteString)) }
    }

    // MARK: - Deferred path (first-launch install)

    /// Fire-and-forget. Waits `config.firstLaunchGraceNanoseconds` then calls
    /// `requestFirstLaunchConsent()`. Wire once from `.task { }` in your App or
    /// AppDelegate `applicationDidBecomeActive`.
    ///
    /// The grace period lets Universal Links (which arrive asynchronously) win
    /// over the clipboard deferred path on the same launch.
    public func requestFirstLaunchConsentAfterGrace() {
        Task {
            let ns = config?.firstLaunchGraceNanoseconds ?? 250_000_000
            try? await Task.sleep(nanoseconds: ns)
            requestFirstLaunchConsent()
        }
    }

    /// Shows the consent gate immediately (no grace). Prefer
    /// `requestFirstLaunchConsentAfterGrace()` for app startup.
    public func requestFirstLaunchConsent() {
        guard !didReceiveURL else { return }
        guard !UserDefaults.standard.bool(forKey: _firstLaunchRanKey) else { return }
        isConsentPending = true
    }

    // MARK: - Consent outcomes (call from Li2ConsentView or custom UI)

    /// Call from `Li2PasteButton`'s `onPaste` callback. The tap itself is consent.
    public func submitPasteControlResult(_ raw: String?) {
        markConsentResolved()
        let trimmed = (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        Task { await routeOptInClipboard(trimmed: trimmed) }
    }

    /// Call when the user taps "Skip" / "Not now" on the consent screen.
    public func submitOptOut() {
        markConsentResolved()
        guard let domains = config?.deepLinkDomains else { return }
        Task {
            await call(TrackOpenRequest(
                li2Domains: domains,
                clipboardStatus: .optout
            ))
        }
    }

    /// Alternative to `Li2PasteButton` — reads `UIPasteboard.general.string`
    /// directly, which shows an OS "Allow Paste" dialog on iOS 16+ or a passive
    /// banner on iOS 14–15. Prefer `Li2PasteButton` (Mode A/B) when possible.
    public func beginRawProbeOptIn() {
        markConsentResolved()
        Task { await runRawProbeOptIn() }
    }

    // MARK: - Bindings (for UIKit / manual SwiftUI wiring)

    /// A `Binding<Bool>` for `isConsentPending` suitable for `fullScreenCover`.
    /// The setter is a no-op — the sheet is dismissed internally by `submitOptOut()`
    /// or `submitPasteControlResult(_:)`, never by the SwiftUI gesture.
    public var isConsentPendingBinding: Binding<Bool> {
        Binding(get: { self.isConsentPending }, set: { _ in })
    }

    // MARK: - clickId persistence (for trackLead / trackSale auto-fill)

    /// Returns the persisted `clickId` if still within its TTL, otherwise `""`.
    /// `nonisolated` — only reads UserDefaults, no MainActor state.
    nonisolated func resolvedClickId(explicitValue: String?) -> String {
        // Explicit value always wins (including Li2.noAttribution = "")
        if let explicit = explicitValue { return explicit }

        // Auto-fill from UserDefaults
        guard
            let stored = UserDefaults.standard.string(forKey: _clickIdKey),
            let expiry = UserDefaults.standard.object(forKey: _clickIdExpiresAtKey) as? Date,
            Date() < expiry
        else { return "" }
        return stored
    }

    func persistClickId(_ clickId: String) {
        let days = config?.clickIdExpiryDays ?? 30
        let expiry = Date().addingTimeInterval(TimeInterval(days * 86400))
        UserDefaults.standard.set(clickId, forKey: _clickIdKey)
        UserDefaults.standard.set(expiry, forKey: _clickIdExpiresAtKey)
    }

    // MARK: - Private helpers

    private func markConsentResolved() {
        UserDefaults.standard.set(true, forKey: _firstLaunchRanKey)
        isConsentPending = false
    }

    private func runRawProbeOptIn() async {
        guard let domains = config?.deepLinkDomains else { return }
        let hadContent = ClipboardProber.hasContent()
        let trimmed = ClipboardProber.readString() ?? ""

        if trimmed.isEmpty {
            await call(TrackOpenRequest(li2Domains: domains, clipboardStatus: hadContent ? .denied : .empty))
            return
        }
        await routeOptInClipboard(trimmed: trimmed)
    }

    private func routeOptInClipboard(trimmed: String) async {
        guard let domains = config?.deepLinkDomains else { return }
        let request: TrackOpenRequest
        if trimmed.isEmpty {
            request = TrackOpenRequest(li2Domains: domains, clipboardStatus: .empty)
        } else if let li2URL = Li2DeepLinkURL.parseLi2DeferredURL(trimmed) {
            request = TrackOpenRequest(deepLink: li2URL.absoluteString, clipboardStatus: .read)
        } else {
            request = TrackOpenRequest(li2Domains: domains, clipboardStatus: .read)
        }
        await call(request)
    }

    private func call(_ request: TrackOpenRequest) async {
        guard let c = config else { return }
        let client = TrackOpenClient(baseURL: c.apiBaseURL, publishableKey: c.publishableKey)
        isResolving = true
        defer { isResolving = false }
        do {
            let response = try await client.open(request)
            if let raw = response.link?.url,
               let dest = Li2DeepLinkURL.sanitizedDestination(raw) {
                let clickId = response.clickId
                persistClickId(clickId)
                deliver(.matched(destination: dest, clickId: clickId))
            } else {
                deliver(.missed(reason: response.missReason))
            }
        } catch {
            deliver(.failed(error))
        }
    }

    private func deliver(_ outcome: Li2DeepLinkOutcome) {
        lastOutcome = outcome
    }
}
