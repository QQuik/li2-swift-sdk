# Li2 SDK for iOS

Deep linking and deferred deep linking for iOS — immediate Universal Links plus
clipboard-based deferred attribution with a privacy-first consent tap. **No
fingerprinting, no IDFA, no ATT prompt.**

- **iOS 15+** · Swift Package Manager · SwiftUI **and** UIKit
- One import: `import Li2SDK`
- The SDK **never navigates** — it hands you a resolved destination and your app routes.

> Scope: this release does deep-link resolution only. Conversion tracking
> (`trackLead`/`trackSale`) ships in a later module; until then,
> `Li2.lastClickId` gives you the click id for manual attribution.

---

## Install

In Xcode: **File ▸ Add Package Dependencies…** and enter the repo URL:

```
https://github.com/QQuik/li2-swift-sdk
```

Pin to **Up to Next Major Version** from `0.1.0`. Then add the **`Li2SDK`**
library product to your app target.

Or in `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/QQuik/li2-swift-sdk", from: "0.1.0")
],
targets: [
    .target(name: "YourApp", dependencies: [
        .product(name: "Li2SDK", package: "li2-swift-sdk")
    ])
]
```

**Requirements:** iOS 15.0+, Xcode 15+. The `UIPasteControl`-based consent button
requires iOS 16; iOS 15 automatically falls back to the raw-clipboard path (see
[Concepts](#concepts)).

---

## Prerequisites (Li2 dashboard)

1. **A verified deep-link domain** in your Li2 dashboard (e.g. `app.example.com`).
2. **A publishable key** (`li2_pk_…`). This is *non-secret* and safe to ship in
   your binary — it must be in the app, because a Universal Link can cold-launch
   your app where scheme/env vars don't exist. (Do **not** use a server API key;
   that returns 401 here — see [Troubleshooting](#troubleshooting).)
3. **Associated Domains entitlement** for Universal Links. Add an
   `applinks:` entry for your deep-link domain:

   ```
   applinks:app.example.com
   ```

   > **AASA caching gotcha:** Apple's CDN caches your domain's
   > `apple-app-site-association` file and can serve a stale copy for ~24h after
   > you change it. If Universal Links don't open your app right after setup,
   > this is usually why — wait it out or bump your origin cache headers.

---

## Quick start (SwiftUI — the 90% path)

### 1. Configure once at launch

```swift
import SwiftUI
import Li2SDK

@main
struct MyApp: App {
    init() {
        Li2.configure(
            publishableKey: "li2_pk_your_key",
            deepLinkDomains: ["app.example.com"]
        )
    }

    @StateObject private var deepLinks = DeepLinkModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(deepLinks)
                .li2DeepLink(using: deepLinks.resolver)   // wires UL + deferred grace
                .fullScreenCover(isPresented: $deepLinks.showConsent) {
                    ConsentSheet(resolver: deepLinks.resolver)
                }
        }
    }
}
```

### 2. Own one resolver; route on its outcome

The resolver calls your `onOutcome` closure for every result. **You navigate** —
the SDK doesn't.

```swift
import SwiftUI
import Combine
import Li2SDK

@MainActor
final class DeepLinkModel: ObservableObject {
    @Published var route: URL?
    @Published var showConsent = false

    private(set) lazy var resolver = Li2DeepLinkResolver { [weak self] outcome in
        switch outcome {
        case let .matched(destination, clickId):
            // Route your app. `destination` already has li2_cid stripped.
            self?.route = destination
            print("Li2 matched clickId=\(clickId)")
        case let .missed(reason):
            // No deep link to restore — show your normal home screen.
            print("Li2 miss: \(reason ?? "no match")")
        case let .failed(error):
            print("Li2 failed: \(error.localizedDescription)")
        }
    }

    private var bag = Set<AnyCancellable>()
    init() {
        // Mirror the SDK's consent flag to drive your sheet.
        resolver.$isConsentPending
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.showConsent = $0 }
            .store(in: &bag)
    }
}
```

### 3. The consent sheet (copy-paste — device-verified)

This is the deferred-attribution UI. It is **yours to own** (the SDK ships no
prebuilt screen), but here is the complete, working pattern. Two details below
are not optional — they are bugs waiting to happen if you drop them.

```swift
import SwiftUI
import UIKit
import Li2SDK

struct ConsentSheet: View {
    let resolver: Li2DeepLinkResolver
    @Environment(\.scenePhase) private var scenePhase

    /// nil = still probing, true/false = whether the clipboard has content.
    @State private var clipboardHasContent: Bool?

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("Welcome").font(.largeTitle.bold())
            Text("You arrived from a shared link. Continue to pick up where it pointed.")
                .multilineTextAlignment(.center)
            Spacer()

            primaryButton

            Button("Not now") { resolver.submitOptOut() }
        }
        .padding(24)
        .onAppear(perform: probeClipboard)
        // (b) Re-probe on foreground: a user may background the app, copy a
        // link, and return. Without this the affordance is stale.
        .onChange(of: scenePhase) { phase in
            if phase == .active { probeClipboard() }
        }
    }

    // Presence-only — hasStrings/hasURLs never trigger the iOS paste alert.
    private func probeClipboard() {
        clipboardHasContent = UIPasteboard.general.hasStrings
            || UIPasteboard.general.hasURLs
    }

    @ViewBuilder
    private var primaryButton: some View {
        if #available(iOS 16.0, *), clipboardHasContent != false {
            // The user's tap on the system Paste button IS the consent —
            // no "Allow Paste" alert appears.
            Li2PasteButton { raw in
                resolver.submitPasteControlResult(raw)
            }
            .frame(height: 52)
        } else if clipboardHasContent == false {
            // (a) Empty clipboard: a disabled UIPasteControl can't be tapped,
            // so you MUST offer an explicit "continue empty" path — otherwise
            // the `empty` outcome is unreachable.
            Button("Continue") { resolver.submitPasteControlEmpty() }
        } else {
            // iOS 15 (no UIPasteControl): raw probe. iOS shows a paste banner.
            Button("Continue") { resolver.beginRawProbeOptIn() }
        }
    }
}
```

**Why the two marked patterns matter:**
- **(a) the empty-clipboard affordance** — `Li2PasteButton` is a system control
  that *disables itself* when the clipboard is empty, so it can't be tapped. The
  view-side presence probe lets you show a plain "Continue" that calls
  `submitPasteControlEmpty()`. Without it, a user with an empty clipboard is
  stuck and the `empty` outcome never fires.
- **(b) the `scenePhase` re-probe** — the clipboard can change while your sheet
  is open (user switches to Safari, copies the link, comes back). Probing only in
  `onAppear` shows a stale state.

---

## UIKit integration

The `.li2DeepLink(using:)` modifier is a SwiftUI `View` extension — it does **not**
exist for UIKit. The SDK is **not** SwiftUI-only, though: the modifier is just
convenience wiring you do by hand. Three public calls, from your scene delegate:

```swift
import UIKit
import Li2SDK

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    let resolver = Li2DeepLinkResolver { outcome in
        // route on outcome (same switch as the SwiftUI example)
    }

    // Universal Link cold launch / continuation
    func scene(_ scene: UIScene,
               continue userActivity: NSUserActivity) {
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
              let url = userActivity.webpageURL else { return }
        resolver.handle(url: url)
    }

    // Universal Link / custom scheme while running
    func scene(_ scene: UIScene,
               openURLContexts contexts: Set<UIOpenURLContext>) {
        for ctx in contexts { resolver.handle(url: ctx.url) }
    }

    // First-launch deferred gate — call once, after the grace window.
    func sceneDidBecomeActive(_ scene: UIScene) {
        resolver.requestFirstLaunchConsentAfterGrace()
    }
}
```

Present your consent UI by observing `resolver.isConsentPending` (it's
`@Published`, so KVO/Combine both work), then call the same
`submitPasteControlResult` / `submitPasteControlEmpty` / `beginRawProbeOptIn` /
`submitOptOut` methods.

> **There is intentionally no zero-grace entry point.** If you want to defer the
> prompt (e.g. until after onboarding), simply call
> `requestFirstLaunchConsentAfterGrace()` *later* — the internal guards keep a
> late call correct, and a Universal Link handled in the meantime suppresses the
> prompt automatically.

---

## Concepts

**Immediate vs deferred.** If your app is *installed*, a tapped Universal Link
opens it and `handle(url:)` resolves immediately. If it's *not* installed, the
link sends the user to the App Store; after install there's no UL to replay — so
on **first launch** the SDK offers to read the link the user copied (the deferred
path). An immediate UL always wins over the deferred prompt (that's what the grace
window protects).

**Why a clipboard + a tap?** It's the privacy-respecting way to do deferred
attribution: no device fingerprinting, no IDFA, **no ATT prompt**. With
`Li2PasteButton` (iOS 16+) the user's tap on the system Paste control *is* the
consent, so iOS shows no permission alert at all.

**The app owns navigation.** Outcomes are data, not actions:

| Outcome | Meaning |
|---|---|
| `.matched(destination, clickId)` | a link resolved; route to `destination` (already cleaned of `li2_cid`) |
| `.missed(reason)` | server found no match; show your normal home |
| `.failed(error)` | network/HTTP/parse error; degrade gracefully |

**`Li2.lastClickId`.** After a match the click id is persisted (default 30 days).
Read `Li2.lastClickId` to attribute a conversion manually until the conversion
module ships.

---

## API reference

```swift
// Setup
Li2.configure(
    publishableKey: String,
    deepLinkDomains: [String],
    apiBaseURL: String = "https://api.li2.ai/api/v1",
    clickIdExpiryDays: Int = 30,
    firstLaunchGraceNanoseconds: UInt64 = 250_000_000
)
Li2.lastClickId: String?              // most recent matched click id (or nil/expired)
Li2.resetFirstLaunchConsent()         // clear the gate (QA / "re-ask" affordance)

// Orchestration
@MainActor final class Li2DeepLinkResolver: ObservableObject {
    init(onOutcome: @escaping @MainActor (Li2DeepLinkOutcome) -> Void)
    @Published private(set) var isConsentPending: Bool
    func handle(url: URL)                        // .onOpenURL / userActivity
    func requestFirstLaunchConsentAfterGrace()   // call once at launch
    func submitPasteControlResult(_ raw: String?)// from Li2PasteButton
    func submitPasteControlEmpty()               // empty-clipboard opt-in
    func submitOptOut()                          // user tapped "Not now"
    func beginRawProbeOptIn()                    // iOS 15 path / alternative
}

enum Li2DeepLinkOutcome {
    case matched(destination: URL, clickId: String)
    case missed(reason: String?)
    case failed(Error)
}

// UI
@available(iOS 16.0, *)
struct Li2PasteButton: UIViewRepresentable {
    init(backgroundColor: UIColor = .tintColor,
         foregroundColor: UIColor = .white,
         onPaste: @escaping (String?) -> Void)
}
extension View {
    func li2DeepLink(using: Li2DeepLinkResolver) -> some View   // SwiftUI only
}
```

### Config options

| Param | Default | Notes |
|---|---|---|
| `publishableKey` | — (required) | `li2_pk_…`; non-secret, ships in the binary |
| `deepLinkDomains` | — (required) | domains you handle; foreign URLs are ignored |
| `apiBaseURL` | Li2 production | leave as default unless Li2 gives you a specific endpoint |
| `clickIdExpiryDays` | 30 | mirrors the backend click TTL |
| `firstLaunchGraceNanoseconds` | 250 ms | delay before the deferred gate opens |

### Errors

- **`TrackOpenError`** — network/HTTP/decode: `.invalidURL`, `.emptyRequest`,
  `.httpError(Int, String)`, `.decodeError(String, String)`. Pattern-match in
  `.failed` for HTTP status + body.
- **`Li2Error.unparsableDestination(raw:)`** — the server matched a link but its
  URL couldn't be parsed (delivered as `.failed`, not silently dropped).

### Troubleshooting

| Symptom | Cause / fix |
|---|---|
| **401 on every call** | Wrong key type. Use a **publishable** key (`li2_pk_…`), not a server API key. |
| **Universal Links don't open the app** | AASA CDN cache (~24h) or a missing `applinks:` entitlement. Verify the domain in your dashboard. |
| **`Li2PasteButton` is always disabled** | Only happens if you build your *own* paste host without setting the control's `target`. The SDK's button sets it correctly. |
| **Consent sheet re-appears after a UL** | Expected if you call `requestFirstLaunchConsentAfterGrace()` *and* a UL arrives — the UL wins and the sheet dismisses. |

---

## License

MIT — © 2026 Li2.ai. See [LICENSE](LICENSE).
