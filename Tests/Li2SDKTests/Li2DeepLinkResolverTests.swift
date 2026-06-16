import XCTest
@testable import Li2SDK

// MARK: - Test doubles

/// Injected pasteboard double. Drives all PasteboardReading paths without UIKit.
final class MockPasteboard: PasteboardReading, @unchecked Sendable {
    var hasContent: Bool
    var stringToReturn: String?   // nil = read blocked (simulates "Don't Allow")

    init(hasContent: Bool = false, stringToReturn: String? = nil) {
        self.hasContent = hasContent
        self.stringToReturn = stringToReturn
    }

    func readString() -> String? { stringToReturn }
}

/// Injected HTTP client double.  Records every call and returns a canned result.
final class MockTrackOpenCalling: TrackOpenCalling, @unchecked Sendable {
    var calls: [TrackOpenRequest] = []
    var resultToReturn: Result<TrackOpenClient.OpenResult, Error>

    init(result: Result<TrackOpenClient.OpenResult, Error>) {
        self.resultToReturn = result
    }

    func open(_ request: TrackOpenRequest) async throws -> TrackOpenClient.OpenResult {
        calls.append(request)
        switch resultToReturn {
        case .success(let r): return r
        case .failure(let e): throw e
        }
    }
}

// MARK: - Helpers

private func makeResult(
    clickId: String = "ck_test",
    linkURL: String? = nil,
    missReason: String? = nil
) -> TrackOpenClient.OpenResult {
    let link: TrackOpenResponse.LinkDTO? = linkURL.map {
        .init(id: "l1", domain: "deep.li2.link", key: "abc", url: $0)
    }
    let response = TrackOpenResponse(
        clickId: clickId,
        link: link,
        matchMethod: link != nil ? "immediate" : nil,
        missReason: missReason,
        platform: nil
    )
    return TrackOpenClient.OpenResult(response: response, statusCode: 200)
}

/// Builds a resolver wired to mock collaborators and an isolated UserDefaults suite.
@MainActor
private func makeResolver(
    domains: [String] = ["deep.li2.link"],
    client: MockTrackOpenCalling,
    pasteboard: MockPasteboard = MockPasteboard(),
    graceNs: UInt64 = 0,
    defaults: UserDefaults,
    onOutcome: @escaping @MainActor (Li2DeepLinkOutcome) -> Void = { _ in }
) -> Li2DeepLinkResolver {
    let config = Li2Config(
        publishableKey: "li2_pk_test",
        apiBaseURL: "https://api.test.li2.ai/api/v1",
        deepLinkDomains: domains,
        clickIdExpiryDays: 30,
        firstLaunchGraceNanoseconds: graceNs
    )
    let store = ClickIdStore(defaults: defaults)
    return Li2DeepLinkResolver(
        config: config,
        client: client,
        pasteboard: pasteboard,
        clickIdStore: store,
        defaults: defaults,
        onOutcome: onOutcome
    )
}

/// Yield enough scheduler turns for spawned Tasks (sleep+callback) to complete.
/// `requestFirstLaunchConsentAfterGrace` spawns a Task that sleeps then sets state —
/// at least two async hops — so a single Task.yield() is not enough.
private func drainTasks() async {
    for _ in 0..<20 { await Task.yield() }
}

/// Returns a fresh UserDefaults suite isolated per test.
private func freshDefaults(name: String) -> UserDefaults {
    UserDefaults().removePersistentDomain(forName: name)
    let d = UserDefaults(suiteName: name)!
    d.removePersistentDomain(forName: name)
    return d
}

// MARK: - Tests

@MainActor
final class Li2DeepLinkResolverTests: XCTestCase {

    // MARK: 1. Li2-domain UL on launch

    /// A Li2-domain Universal Link:
    ///   • fires POST with {deepLink} only (no clipboardStatus)
    ///   • sets didReceiveURL so the consent gate never opens
    ///   • sets firstLaunchRan so launch-2 doesn't re-prompt
    func testULOnLaunch_postsDeepLink_setsGate() async throws {
        let defaults = freshDefaults(name: #function)
        let client = MockTrackOpenCalling(result: .success(makeResult(
            clickId: "ck1",
            linkURL: "https://deep.li2.link/abc"
        )))
        var outcome: Li2DeepLinkOutcome?
        let resolver = await makeResolver(client: client, defaults: defaults) { outcome = $0 }

        let ul = URL(string: "https://deep.li2.link/abc123")!
        await resolver.handle(url: ul)
        await drainTasks()

        // One POST fired
        XCTAssertEqual(client.calls.count, 1)
        let req = client.calls[0]
        XCTAssertEqual(req.deepLink, "https://deep.li2.link/abc123")
        XCTAssertNil(req.clipboardStatus)
        XCTAssertNil(req.li2Domains)

        // firstLaunchRan consumed (D-6b — no re-prompt on launch 2)
        XCTAssertTrue(defaults.bool(forKey: "ai.li2.firstLaunchRan"))

        // Consent gate stays closed
        await MainActor.run { XCTAssertFalse(resolver.isConsentPending) }

        // Outcome delivered
        if case .matched(_, let cid) = outcome { XCTAssertEqual(cid, "ck1") }
        else { XCTFail("Expected .matched, got \(String(describing: outcome))") }
    }

    // MARK: 2. Foreign URL — no POST, gate still opens

    func testForeignURL_noPOST_gateStillOpens() async throws {
        let defaults = freshDefaults(name: #function)
        let client = MockTrackOpenCalling(result: .success(makeResult()))
        let resolver = await makeResolver(
            domains: ["deep.li2.link"],
            client: client,
            graceNs: 0,
            defaults: defaults
        )

        // Foreign URL during grace window
        let foreign = URL(string: "https://auth.example.com/callback?code=abc")!
        await resolver.handle(url: foreign)

        // No POST
        XCTAssertEqual(client.calls.count, 0)

        // Gate STILL opens (foreign URL must not suppress it); call the sync decision
        // directly — the grace sleep is wall-clock and untestable on Linux (4.4 scenario 8).
        await resolver.openConsentGateIfNeeded()
        let pending = resolver.isConsentPending
        XCTAssertTrue(pending, "Foreign URL during grace must not suppress the consent gate")
    }

    // MARK: 3. First launch → gate opens; second launch → stays closed

    func testFirstLaunch_gateOpens_secondLaunch_gateClosed() async throws {
        let defaults = freshDefaults(name: #function)
        let client = MockTrackOpenCalling(result: .success(makeResult()))

        let r1 = await makeResolver(client: client, graceNs: 0, defaults: defaults)
        await r1.openConsentGateIfNeeded()
        XCTAssertTrue(r1.isConsentPending)

        // Simulate response (consume gate)
        await r1.submitOptOut()
        await drainTasks()

        // Second launch: new resolver instance, same defaults → gate stays closed
        let r2 = await makeResolver(client: client, graceNs: 0, defaults: defaults)
        await r2.openConsentGateIfNeeded()
        XCTAssertFalse(r2.isConsentPending)
    }

    // MARK: 4. Gate shown but no response → flag NOT set → re-prompts next launch

    func testGateShownNoResponse_flagNotSet_reprompts() async throws {
        let defaults = freshDefaults(name: #function)
        let client = MockTrackOpenCalling(result: .success(makeResult()))

        let r1 = await makeResolver(client: client, graceNs: 0, defaults: defaults)
        await r1.openConsentGateIfNeeded()
        XCTAssertTrue(r1.isConsentPending)

        // No submit — flag must NOT be set (simulates force-quit mid-sheet)
        XCTAssertFalse(defaults.bool(forKey: "ai.li2.firstLaunchRan"))

        // New resolver (next launch) → gate re-opens
        let r2 = await makeResolver(client: client, graceNs: 0, defaults: defaults)
        await r2.openConsentGateIfNeeded()
        XCTAssertTrue(r2.isConsentPending)
    }

    // MARK: 4b. Flag is set when client throws (consume-on-response semantics)

    func testFlagSetEvenWhenClientThrows() async throws {
        let defaults = freshDefaults(name: #function)
        let error = URLError(.notConnectedToInternet)
        let client = MockTrackOpenCalling(result: .failure(error))

        let r1 = await makeResolver(client: client, graceNs: 0, defaults: defaults)
        await r1.requestFirstLaunchConsentAfterGrace()
        await drainTasks()

        await r1.submitOptOut()   // consume even though client will throw
        await drainTasks()

        XCTAssertTrue(defaults.bool(forKey: "ai.li2.firstLaunchRan"))
    }

    // MARK: 5. Paste with Li2 URL

    func testPasteWithLi2URL_sendsDeepLinkRead() async throws {
        let defaults = freshDefaults(name: #function)
        let client = MockTrackOpenCalling(result: .success(makeResult(
            linkURL: "https://deep.li2.link/abc?li2_cid=XYZ"
        )))
        let resolver = await makeResolver(client: client, graceNs: 0, defaults: defaults)
        await resolver.requestFirstLaunchConsentAfterGrace()
        await drainTasks()

        let li2Url = "https://deep.li2.link/abc?li2_cid=XYZ"
        await resolver.submitPasteControlResult(li2Url)
        await drainTasks()

        XCTAssertEqual(client.calls.count, 1)
        let req = client.calls[0]
        XCTAssertEqual(req.deepLink, li2Url)
        XCTAssertEqual(req.clipboardStatus, "read")
        XCTAssertNil(req.li2Domains)
    }

    // MARK: 5b. Paste with non-Li2 text

    func testPasteWithNonLi2Text_sendsDomainsRead() async throws {
        let defaults = freshDefaults(name: #function)
        let client = MockTrackOpenCalling(result: .success(makeResult()))
        let resolver = await makeResolver(client: client, graceNs: 0, defaults: defaults)
        await resolver.requestFirstLaunchConsentAfterGrace()
        await drainTasks()

        await resolver.submitPasteControlResult("hello world")
        await drainTasks()

        let req = client.calls[0]
        XCTAssertNil(req.deepLink)
        XCTAssertEqual(req.li2Domains, ["deep.li2.link"])
        XCTAssertEqual(req.clipboardStatus, "read")
    }

    // MARK: 5c. Paste with empty clipboard

    func testPasteWithEmpty_sendsDomainsEmpty() async throws {
        let defaults = freshDefaults(name: #function)
        let client = MockTrackOpenCalling(result: .success(makeResult()))
        let resolver = await makeResolver(client: client, graceNs: 0, defaults: defaults)
        await resolver.requestFirstLaunchConsentAfterGrace()
        await drainTasks()

        await resolver.submitPasteControlResult(nil)
        await drainTasks()

        let req = client.calls[0]
        XCTAssertNil(req.deepLink)
        XCTAssertEqual(req.li2Domains, ["deep.li2.link"])
        XCTAssertEqual(req.clipboardStatus, "empty")
    }

    // MARK: 6. Raw probe: content + nil read → denied (D-6c)

    func testRawProbe_contentNilRead_denied() async throws {
        let defaults = freshDefaults(name: #function)
        let client = MockTrackOpenCalling(result: .success(makeResult()))
        let pb = MockPasteboard(hasContent: true, stringToReturn: nil)
        let resolver = await makeResolver(client: client, pasteboard: pb, graceNs: 0, defaults: defaults)
        await resolver.requestFirstLaunchConsentAfterGrace()
        await drainTasks()

        await resolver.beginRawProbeOptIn()
        await drainTasks()

        let req = client.calls[0]
        XCTAssertEqual(req.clipboardStatus, "denied")
        XCTAssertNil(req.deepLink)
    }

    // MARK: 6b. Raw probe: content + whitespace-only read → empty (D-6c, NOT denied)

    func testRawProbe_contentWhitespaceRead_empty() async throws {
        let defaults = freshDefaults(name: #function)
        let client = MockTrackOpenCalling(result: .success(makeResult()))
        let pb = MockPasteboard(hasContent: true, stringToReturn: "   \n")
        let resolver = await makeResolver(client: client, pasteboard: pb, graceNs: 0, defaults: defaults)
        await resolver.requestFirstLaunchConsentAfterGrace()
        await drainTasks()

        await resolver.beginRawProbeOptIn()
        await drainTasks()

        let req = client.calls[0]
        XCTAssertEqual(req.clipboardStatus, "empty", "Whitespace-only clipboard is empty, not denied")
    }

    // MARK: 6c. Raw probe: no content → empty

    func testRawProbe_noContent_empty() async throws {
        let defaults = freshDefaults(name: #function)
        let client = MockTrackOpenCalling(result: .success(makeResult()))
        let pb = MockPasteboard(hasContent: false, stringToReturn: nil)
        let resolver = await makeResolver(client: client, pasteboard: pb, graceNs: 0, defaults: defaults)
        await resolver.requestFirstLaunchConsentAfterGrace()
        await drainTasks()

        await resolver.beginRawProbeOptIn()
        await drainTasks()

        let req = client.calls[0]
        XCTAssertEqual(req.clipboardStatus, "empty")
    }

    // MARK: 7. Opt-out → {li2Domains, optout}

    func testOptOut_sendsDomainsOptout() async throws {
        let defaults = freshDefaults(name: #function)
        let client = MockTrackOpenCalling(result: .success(makeResult()))
        let resolver = await makeResolver(client: client, graceNs: 0, defaults: defaults)
        await resolver.requestFirstLaunchConsentAfterGrace()
        await drainTasks()

        await resolver.submitOptOut()
        await drainTasks()

        let req = client.calls[0]
        XCTAssertNil(req.deepLink)
        XCTAssertEqual(req.li2Domains, ["deep.li2.link"])
        XCTAssertEqual(req.clipboardStatus, "optout")
    }

    // MARK: 8. matched → clickId persisted + outcome delivered

    func testMatched_clickIdPersistedAndOutcomeDelivered() async throws {
        let defaults = freshDefaults(name: #function)
        let client = MockTrackOpenCalling(result: .success(makeResult(
            clickId: "ck_abc",
            linkURL: "https://app.example.com/article/42"
        )))
        var outcome: Li2DeepLinkOutcome?
        let store = ClickIdStore(defaults: defaults)
        let config = Li2Config(
            publishableKey: "li2_pk_test",
            apiBaseURL: "https://api.test.li2.ai/api/v1",
            deepLinkDomains: ["deep.li2.link"]
        )
        let resolver = await Li2DeepLinkResolver(
            config: config,
            client: client,
            pasteboard: MockPasteboard(),
            clickIdStore: store,
            defaults: defaults,
            onOutcome: { outcome = $0 }
        )
        await resolver.handle(url: URL(string: "https://deep.li2.link/abc")!)
        await drainTasks()

        // clickId stored
        XCTAssertEqual(store.currentClickId, "ck_abc")

        // outcome = .matched with clean destination (li2_cid stripped)
        if case .matched(let dest, let cid) = outcome {
            XCTAssertEqual(cid, "ck_abc")
            XCTAssertEqual(dest.absoluteString, "https://app.example.com/article/42")
        } else {
            XCTFail("Expected .matched, got \(String(describing: outcome))")
        }
    }

    // MARK: 8b. miss/failed → no clickId persist

    func testMissed_noClickIdPersisted() async throws {
        let defaults = freshDefaults(name: #function)
        let client = MockTrackOpenCalling(result: .success(makeResult(missReason: "no_candidate")))
        let store = ClickIdStore(defaults: defaults)
        let config = Li2Config(
            publishableKey: "li2_pk_test",
            apiBaseURL: "https://api.test.li2.ai/api/v1",
            deepLinkDomains: ["deep.li2.link"]
        )
        let resolver = await Li2DeepLinkResolver(
            config: config,
            client: client,
            pasteboard: MockPasteboard(),
            clickIdStore: store,
            defaults: defaults,
            onOutcome: { _ in }
        )
        await resolver.handle(url: URL(string: "https://deep.li2.link/abc")!)
        await drainTasks()

        XCTAssertNil(store.currentClickId)
    }

    func testFailed_noClickIdPersisted() async throws {
        let defaults = freshDefaults(name: #function)
        let client = MockTrackOpenCalling(result: .failure(URLError(.notConnectedToInternet)))
        let store = ClickIdStore(defaults: defaults)
        let config = Li2Config(
            publishableKey: "li2_pk_test",
            apiBaseURL: "https://api.test.li2.ai/api/v1",
            deepLinkDomains: ["deep.li2.link"]
        )
        let resolver = await Li2DeepLinkResolver(
            config: config,
            client: client,
            pasteboard: MockPasteboard(),
            clickIdStore: store,
            defaults: defaults,
            onOutcome: { _ in }
        )
        await resolver.handle(url: URL(string: "https://deep.li2.link/abc")!)
        await drainTasks()

        XCTAssertNil(store.currentClickId)
    }

    // MARK: 9. matched with unparsable link.url → .failed(.unparsableDestination)

    func testUnparsableDestination_failedOutcome_noClickIdPersist() async throws {
        let defaults = freshDefaults(name: #function)
        let client = MockTrackOpenCalling(result: .success(makeResult(
            clickId: "ck_bad",
            linkURL: "not a url ://\u{00}"   // unparsable
        )))
        var outcome: Li2DeepLinkOutcome?
        let store = ClickIdStore(defaults: defaults)
        let config = Li2Config(
            publishableKey: "li2_pk_test",
            apiBaseURL: "https://api.test.li2.ai/api/v1",
            deepLinkDomains: ["deep.li2.link"]
        )
        let resolver = await Li2DeepLinkResolver(
            config: config,
            client: client,
            pasteboard: MockPasteboard(),
            clickIdStore: store,
            defaults: defaults,
            onOutcome: { outcome = $0 }
        )
        await resolver.handle(url: URL(string: "https://deep.li2.link/abc")!)
        await drainTasks()

        // No clickId stored
        XCTAssertNil(store.currentClickId)

        // Outcome = .failed with Li2Error.unparsableDestination
        if case .failed(let err) = outcome {
            XCTAssertTrue(err is Li2Error, "Expected Li2Error, got \(type(of: err))")
        } else {
            XCTFail("Expected .failed, got \(String(describing: outcome))")
        }
    }
}
