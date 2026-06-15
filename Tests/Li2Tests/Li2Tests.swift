import XCTest
@testable import Li2

/// Tests for the top-level `Li2` facade. Kept separate from the resolver's
/// injected-defaults tests because these methods operate on `.standard`.
@MainActor
final class Li2Tests: XCTestCase {

    private let key = Li2DeepLinkResolver.firstLaunchRanKey

    /// `resetFirstLaunchConsent()` clears the gate so the next launch re-asks.
    /// `async` because Linux XCTest crashes on synchronous `@MainActor` test
    /// methods (cast `@MainActor () -> ()` → `() -> ()` fails).
    func testResetFirstLaunchConsent_clearsGateKey() async {
        let prior = UserDefaults.standard.object(forKey: key)
        defer {
            if let prior { UserDefaults.standard.set(prior, forKey: key) }
            else { UserDefaults.standard.removeObject(forKey: key) }
        }

        UserDefaults.standard.set(true, forKey: key)
        XCTAssertTrue(UserDefaults.standard.bool(forKey: key))

        Li2.resetFirstLaunchConsent()

        XCTAssertFalse(UserDefaults.standard.bool(forKey: key),
                       "Gate key must be cleared so first-launch consent re-asks")
    }
}
