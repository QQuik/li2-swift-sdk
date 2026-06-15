import Foundation
#if canImport(Combine)
import Combine
#endif

/// Orchestrates the deep-link resolution flow for one app session.
///
/// Place one instance in your app root and wire it with the `.li2DeepLink(using:)` modifier
/// (task 4.3).  The resolver calls your `onOutcome` closure with the result of every
/// `/track/open` call; **the resolver never navigates — you do.**
@MainActor
public final class Li2DeepLinkResolver {

    // MARK: - Public state

    /// Bind to your consent sheet.  Becomes `true` after the grace window when no
    /// Universal Link arrived and the install hasn't been asked before.
    ///
    /// On Apple platforms this is `@Published` (ObservableObject); on Linux the
    /// property exists without synthesis so tests can read it directly.
#if canImport(Combine)
    @Published public private(set) var isConsentPending = false
#else
    public private(set) var isConsentPending = false
#endif

    // MARK: - Private

    /// First-launch consent gate key. `internal` (not `private`) only so
    /// `Li2.resetFirstLaunchConsent()` can clear it; never exposed publicly —
    /// the key name is an implementation detail, the reset *behavior* is the API.
    /// `nonisolated`: a constant string with no actor state, so the nonisolated
    /// `Li2` facade can read it without hopping to the MainActor.
    nonisolated static let firstLaunchRanKey = "ai.li2.firstLaunchRan"

    private let config: Li2Config
    private let client: any TrackOpenCalling
    private let pasteboard: any PasteboardReading
    private let clickIdStore: ClickIdStore
    private let defaults: UserDefaults
    private let onOutcome: @MainActor (Li2DeepLinkOutcome) -> Void

    /// Set when a Li2-domain Universal Link arrives this launch; suppresses the
    /// deferred-clipboard gate.
    private var didReceiveURL = false

    // MARK: - Init

    /// Public convenience initialiser — reads global config set by `Li2.configure`.
    /// Crashes with a clear message if `configure` was not called.
    public convenience init(
        onOutcome: @escaping @MainActor (Li2DeepLinkOutcome) -> Void
    ) {
        let config = Li2.config
        let client = TrackOpenClient(
            baseURL: config.apiBaseURL,
            publishableKey: config.publishableKey
        )
        // Real pasteboard on UIKit (raw-probe / iOS 15 path); NoOp on Linux so
        // Core stays buildable there. NoOp would make `beginRawProbeOptIn`
        // always report `empty`.
        let pasteboard: any PasteboardReading
        #if canImport(UIKit)
        pasteboard = UIPasteboardReader()
        #else
        pasteboard = NoOpPasteboard()
        #endif
        self.init(
            config: config,
            client: client,
            pasteboard: pasteboard,
            clickIdStore: .shared,
            defaults: .standard,
            onOutcome: onOutcome
        )
    }

    /// Internal designated initialiser — accepts injected collaborators for testing.
    init(
        config: Li2Config,
        client: any TrackOpenCalling,
        pasteboard: any PasteboardReading,
        clickIdStore: ClickIdStore,
        defaults: UserDefaults,
        onOutcome: @escaping @MainActor (Li2DeepLinkOutcome) -> Void
    ) {
        self.config = config
        self.client = client
        self.pasteboard = pasteboard
        self.clickIdStore = clickIdStore
        self.defaults = defaults
        self.onOutcome = onOutcome
    }

    // MARK: - Entry point 1: immediate Universal Link

    /// Call from `.onOpenURL` and `.onContinueUserActivity(NSUserActivityTypeBrowsingWeb)`.
    ///
    /// **D-6a**: if `url.host` is not in `config.deepLinkDomains` the call is a no-op —
    /// OAuth callbacks and other URLs must not POST or suppress the consent gate.
    ///
    /// **D-6b**: a matching Li2-domain URL also sets `firstLaunchRan` so the clipboard
    /// consent gate never re-appears on launch 2 for an already-attributed install.
    public func handle(url: URL) {
        guard let host = url.host, config.deepLinkDomains.contains(host) else {
            return   // foreign URL (OAuth, widget, etc.) — ignore
        }
        didReceiveURL = true
        isConsentPending = false
        // D-6b: consume the first-launch gate so deferred doesn't run on launch 2.
        defaults.set(true, forKey: Self.firstLaunchRanKey)
        Task { await postAndDeliver(TrackOpenRequest(deepLink: url.absoluteString)) }
    }

    // MARK: - Entry point 2: first-launch deferred gate

    /// Wire once from your app's `.task {}`.  Waits `config.firstLaunchGraceNanoseconds`
    /// so an immediate Universal Link can arrive first, then opens the consent gate.
    public func requestFirstLaunchConsentAfterGrace() {
        Task {
            try? await Task.sleep(nanoseconds: config.firstLaunchGraceNanoseconds)
            openConsentGateIfNeeded()
        }
    }

    /// Synchronous gate decision (no grace sleep). `internal` so gate-logic tests assert
    /// it deterministically; the grace timing race (UL-wins-during-grace) is Mac-only (4.4 scenario 8).
    func openConsentGateIfNeeded() {
        if didReceiveURL { return }
        if defaults.bool(forKey: Self.firstLaunchRanKey) { return }
        isConsentPending = true
    }

    /// Marks the consent gate consumed.  Called at the start of every `submit…` /
    /// `beginRawProbeOptIn` — **before** the network call — so a client throw still
    /// consumes the gate (force-quit after response, not before prompt, re-prompts).
    private func consumeGate() {
        defaults.set(true, forKey: Self.firstLaunchRanKey)
        isConsentPending = false
    }

    // MARK: - Entry point 3: clipboard outcomes

    /// Call from `Li2PasteButton.onPaste`. The OS already granted access.
    public func submitPasteControlResult(_ raw: String?) {
        consumeGate()
        let trimmed = (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        Task { await routeOptInClipboard(trimmed: trimmed) }
    }

    /// Call when the paste button was shown but nothing was pasteable.
    public func submitPasteControlEmpty() {
        consumeGate()
        Task { await routeOptInClipboard(trimmed: "") }
    }

    /// Call when the user dismisses the consent UI (taps "Skip").
    /// Sends `li2Domains + clipboardStatus=optout`.
    public func submitOptOut() {
        consumeGate()
        Task {
            await postAndDeliver(TrackOpenRequest(
                li2Domains: config.deepLinkDomains,
                clipboardStatus: ClipboardStatus.optout.rawValue
            ))
        }
    }

    /// iOS 15+ alternative to the paste button: triggers the OS paste alert (16+) or
    /// a passive banner (15), reads the result, and routes accordingly.
    ///
    /// **D-6c**: `nil` read with `hasContent=true` → `denied`; non-nil that trims to
    /// empty → `empty` (the kit misreported whitespace-only clipboards as denials).
    public func beginRawProbeOptIn() {
        consumeGate()
        let hasContent = pasteboard.hasContent
        let raw = pasteboard.readString()
        Task { await routeRawProbe(hasContent: hasContent, raw: raw) }
    }

    // MARK: - Routing helpers

    private func routeRawProbe(hasContent: Bool, raw: String?) async {
        // D-6c: nil read means OS blocked the access iff there was content to read.
        guard let nonNilRaw = raw else {
            let status: ClipboardStatus = hasContent ? .denied : .empty
            await postAndDeliver(TrackOpenRequest(
                li2Domains: config.deepLinkDomains,
                clipboardStatus: status.rawValue
            ))
            return
        }
        let trimmed = nonNilRaw.trimmingCharacters(in: .whitespacesAndNewlines)
        await routeOptInClipboard(trimmed: trimmed)
    }

    private func routeOptInClipboard(trimmed: String) async {
        let request: TrackOpenRequest
        if trimmed.isEmpty {
            request = TrackOpenRequest(
                li2Domains: config.deepLinkDomains,
                clipboardStatus: ClipboardStatus.empty.rawValue
            )
        } else if let li2URL = Li2DeepLinkURL.parseLi2DeferredURL(trimmed) {
            request = TrackOpenRequest(
                deepLink: li2URL.absoluteString,
                clipboardStatus: ClipboardStatus.read.rawValue
            )
        } else {
            request = TrackOpenRequest(
                li2Domains: config.deepLinkDomains,
                clipboardStatus: ClipboardStatus.read.rawValue
            )
        }
        await postAndDeliver(request)
    }

    // MARK: - Network → outcome

    private func postAndDeliver(_ request: TrackOpenRequest) async {
        do {
            let result = try await client.open(request)
            let response = result.response

            if let linkDTO = response.link {
                // Matched response — parse the destination URL.
                guard let dest = Li2DeepLinkURL.sanitizedDestination(linkDTO.url) else {
                    // D-6 / architecture §Wire contract: unparsable → .failed, not .missed
                    onOutcome(.failed(Li2Error.unparsableDestination(raw: linkDTO.url)))
                    return
                }
                // Persist clickId before delivering outcome.
                clickIdStore.persist(clickId: response.clickId, expiryDays: config.clickIdExpiryDays)
                onOutcome(.matched(destination: dest, clickId: response.clickId))
            } else {
                onOutcome(.missed(reason: response.missReason))
            }
        } catch {
            onOutcome(.failed(error))
        }
    }
}

// MARK: - ObservableObject conformance (Apple platforms only)

#if canImport(Combine)
extension Li2DeepLinkResolver: ObservableObject {}
#endif

// MARK: - No-op pasteboard for the public init on Linux

/// Linux-only fallback so the public `init` compiles where there is no
/// `UIPasteboard`. On UIKit platforms the public init uses `UIPasteboardReader`
/// (UI/UIPasteboardReader.swift) instead, so the raw-probe path works.
private struct NoOpPasteboard: PasteboardReading {
    var hasContent: Bool { false }
    func readString() -> String? { nil }
}
