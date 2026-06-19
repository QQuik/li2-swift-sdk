import XCTest
@testable import Li2SDK

// MARK: - ConversionClient — clickId resolution + no-network pre-throw tests

final class ConversionClientTests: XCTestCase {

    // A stub ConversionCalling that fails the test if called (proves no network hit)
    private struct NeverCalledClient: ConversionCalling {
        func lead(_ request: LeadRequest) async throws -> LeadData {
            XCTFail("ConversionClient must NOT be called when clickId is nil")
            throw Li2ConversionError.noClickIdAvailable
        }
        func sale(_ request: SaleRequest) async throws -> SaleData {
            XCTFail("ConversionClient must NOT be called when clickId is nil")
            throw Li2ConversionError.noClickIdAvailable
        }
    }

    // A stub that records the last request received
    private actor RecordingClient: ConversionCalling {
        var lastLead: LeadRequest?
        var lastSale: SaleRequest?
        var leadResult: LeadData = LeadData(success: true, customerId: "cust_test")
        var saleResult: SaleData = SaleData(success: true, saleEventId: "sale_test", customerId: "cust_test")

        func lead(_ request: LeadRequest) async throws -> LeadData {
            lastLead = request
            return leadResult
        }
        func sale(_ request: SaleRequest) async throws -> SaleData {
            lastSale = request
            return saleResult
        }
    }

    private func makeConfig() -> Li2Config {
        Li2Config(
            publishableKey: "li2_pk_test",
            apiBaseURL: "https://api.li2.ai/api/v1",
            deepLinkDomains: ["deep.li2.link"]
        )
    }

    // MARK: - trackDirectLead — always click_id="", never reads lastClickId

    func testDirectLeadSendsEmptyClickId() async throws {
        let recorder = RecordingClient()
        let config = makeConfig()
        let result = try await Li2.trackDirectLead(
            externalId: "u_42",
            eventName: "signup",
            email: nil,
            name: nil,
            phone: nil,
            metadata: nil,
            config: config,
            client: recorder
        )
        let sent = await recorder.lastLead
        XCTAssertEqual(sent?.clickId, "", "Direct lead must always send click_id = empty string")
        XCTAssertEqual(sent?.externalId, "u_42")
        XCTAssertEqual(result.customerId, "cust_test")
    }

    func testDirectLeadDoesNotReadLastClickId() async throws {
        // Even if lastClickId is set, direct lead hard-codes ""
        let store = ClickIdStore(defaults: UserDefaults(suiteName: "test.direct.lead.\(UUID().uuidString)")!)
        store.persist(clickId: "some_click_id", expiryDays: 30)
        let recorder = RecordingClient()
        let config = makeConfig()
        _ = try await Li2.trackDirectLead(
            externalId: "u_42",
            eventName: "signup",
            email: nil, name: nil, phone: nil, metadata: nil,
            config: config,
            client: recorder
        )
        let sent = await recorder.lastLead
        XCTAssertEqual(sent?.clickId, "", "Direct lead must ignore lastClickId and always send empty string")
    }

    // MARK: - trackDirectSale — always click_id=""

    func testDirectSaleSendsEmptyClickId() async throws {
        let recorder = RecordingClient()
        let config = makeConfig()
        let result = try await Li2.trackDirectSale(
            externalId: "u_42",
            amount: 4999,
            currency: nil,
            eventName: nil,
            paymentProcessor: nil,
            invoiceId: nil,
            email: nil, name: nil, phone: nil, avatarUrl: nil, metadata: nil,
            config: config,
            client: recorder
        )
        let sent = await recorder.lastSale
        XCTAssertEqual(sent?.clickId, "")
        XCTAssertEqual(sent?.amount, 4999)
        XCTAssertEqual(result.saleEventId, "sale_test")
    }

    // MARK: - trackAnonymousLead — explicit clickId or lastClickId; nil → throw before network

    func testAnonymousLeadThrowsNoClickIdWhenNilAndNoLastClickId() async {
        // No lastClickId in store, no explicit clickId → throw before network
        let neverClient = NeverCalledClient()
        let config = makeConfig()
        do {
            _ = try await Li2.trackAnonymousLead(
                eventName: "viewed_pricing",
                clickId: nil,
                email: nil, name: nil, phone: nil, metadata: nil,
                config: config,
                client: neverClient,
                clickIdStore: ClickIdStore(defaults: UserDefaults(suiteName: "test.anon.nil.\(UUID().uuidString)")!)
            )
            XCTFail("Expected noClickIdAvailable")
        } catch Li2ConversionError.noClickIdAvailable {
            // expected — no network call made (NeverCalledClient would have failed the test)
        } catch {
            XCTFail("Wrong error: \(error)")
        }
    }

    func testAnonymousLeadUsesExplicitClickId() async throws {
        let recorder = RecordingClient()
        let config = makeConfig()
        _ = try await Li2.trackAnonymousLead(
            eventName: "viewed_pricing",
            clickId: "explicit_click",
            email: nil, name: nil, phone: nil, metadata: nil,
            config: config,
            client: recorder,
            clickIdStore: ClickIdStore(defaults: UserDefaults(suiteName: "test.anon.explicit.\(UUID().uuidString)")!)
        )
        let sent = await recorder.lastLead
        XCTAssertEqual(sent?.clickId, "explicit_click")
        XCTAssertNil(sent?.externalId, "Anonymous lead must not send external_id")
    }

    func testAnonymousLeadFallsBackToLastClickId() async throws {
        let suite = UserDefaults(suiteName: "test.anon.fallback.\(UUID().uuidString)")!
        let store = ClickIdStore(defaults: suite)
        store.persist(clickId: "stored_click", expiryDays: 30)
        let recorder = RecordingClient()
        let config = makeConfig()
        _ = try await Li2.trackAnonymousLead(
            eventName: "viewed_pricing",
            clickId: nil,
            email: nil, name: nil, phone: nil, metadata: nil,
            config: config,
            client: recorder,
            clickIdStore: store
        )
        let sent = await recorder.lastLead
        XCTAssertEqual(sent?.clickId, "stored_click", "Should fall back to stored lastClickId")
    }

    // MARK: - trackAttributedLead — clickId + externalId required, nil → throw before network

    func testAttributedLeadThrowsNoClickIdWhenNil() async {
        let neverClient = NeverCalledClient()
        let config = makeConfig()
        do {
            _ = try await Li2.trackAttributedLead(
                externalId: "u_42",
                eventName: "signup",
                clickId: nil,
                email: nil, name: nil, phone: nil, metadata: nil,
                config: config,
                client: neverClient,
                clickIdStore: ClickIdStore(defaults: UserDefaults(suiteName: "test.attr.nil.\(UUID().uuidString)")!)
            )
            XCTFail("Expected noClickIdAvailable")
        } catch Li2ConversionError.noClickIdAvailable {
            // correct
        } catch {
            XCTFail("Wrong error: \(error)")
        }
    }

    func testAttributedLeadSendsBothClickIdAndExternalId() async throws {
        let recorder = RecordingClient()
        let config = makeConfig()
        _ = try await Li2.trackAttributedLead(
            externalId: "u_42",
            eventName: "signup",
            clickId: "abc123",
            email: nil, name: nil, phone: nil, metadata: nil,
            config: config,
            client: recorder,
            clickIdStore: ClickIdStore(defaults: UserDefaults(suiteName: "test.attr.both.\(UUID().uuidString)")!)
        )
        let sent = await recorder.lastLead
        XCTAssertEqual(sent?.clickId, "abc123")
        XCTAssertEqual(sent?.externalId, "u_42")
    }

    // MARK: - trackAttributedSale — clickId required, nil → throw before network

    func testAttributedSaleThrowsNoClickIdWhenNil() async {
        let neverClient = NeverCalledClient()
        let config = makeConfig()
        do {
            _ = try await Li2.trackAttributedSale(
                externalId: "u_42",
                amount: 4999,
                clickId: nil,
                currency: nil,
                eventName: nil, paymentProcessor: nil, invoiceId: nil,
                email: nil, name: nil, phone: nil, avatarUrl: nil, metadata: nil,
                config: config,
                client: neverClient,
                clickIdStore: ClickIdStore(defaults: UserDefaults(suiteName: "test.sale.nil.\(UUID().uuidString)")!)
            )
            XCTFail("Expected noClickIdAvailable")
        } catch Li2ConversionError.noClickIdAvailable {
            // correct
        } catch {
            XCTFail("Wrong error: \(error)")
        }
    }

    func testAttributedSaleFallsBackToLastClickId() async throws {
        let suite = UserDefaults(suiteName: "test.sale.fallback.\(UUID().uuidString)")!
        let store = ClickIdStore(defaults: suite)
        store.persist(clickId: "sale_click", expiryDays: 30)
        let recorder = RecordingClient()
        let config = makeConfig()
        _ = try await Li2.trackAttributedSale(
            externalId: "u_42",
            amount: 4999,
            clickId: nil,
            currency: nil,
            eventName: nil, paymentProcessor: nil, invoiceId: nil,
            email: nil, name: nil, phone: nil, avatarUrl: nil, metadata: nil,
            config: config,
            client: recorder,
            clickIdStore: store
        )
        let sent = await recorder.lastSale
        XCTAssertEqual(sent?.clickId, "sale_click")
        XCTAssertEqual(sent?.amount, 4999)
    }

    // MARK: - identify — sugar over attributed lead with __identify__ sentinel

    func testIdentifyThrowsMissingExternalIdWhenEmpty() async {
        let neverClient = NeverCalledClient()
        let config = makeConfig()
        do {
            _ = try await Li2.identify(
                externalId: "",
                email: "a@b.com",
                name: nil,
                clickId: "id_click",
                config: config,
                client: neverClient,
                clickIdStore: ClickIdStore(defaults: UserDefaults(suiteName: "test.identify.empty.\(UUID().uuidString)")!)
            )
            XCTFail("Expected missingExternalId")
        } catch Li2ConversionError.missingExternalId {
            // correct — guard fires before any network call (NeverCalledClient unused)
        } catch {
            XCTFail("Wrong error: \(error)")
        }
    }

    func testIdentifyThrowsNoClickIdWhenNil() async {
        let neverClient = NeverCalledClient()
        let config = makeConfig()
        do {
            _ = try await Li2.identify(
                externalId: "u_42",
                email: "a@b.com",
                name: nil,
                clickId: nil,
                config: config,
                client: neverClient,
                clickIdStore: ClickIdStore(defaults: UserDefaults(suiteName: "test.identify.nil.\(UUID().uuidString)")!)
            )
            XCTFail("Expected noClickIdAvailable")
        } catch Li2ConversionError.noClickIdAvailable {
            // correct
        } catch {
            XCTFail("Wrong error: \(error)")
        }
    }

    func testIdentifyEncodesIdentifySentinelEventName() async throws {
        let recorder = RecordingClient()
        let config = makeConfig()
        _ = try await Li2.identify(
            externalId: "u_42",
            email: "a@b.com",
            name: nil,
            clickId: "id_click",
            config: config,
            client: recorder,
            clickIdStore: ClickIdStore(defaults: UserDefaults(suiteName: "test.identify.sentinel.\(UUID().uuidString)")!)
        )
        let sent = await recorder.lastLead
        XCTAssertEqual(sent?.eventName, "__identify__", "identify must use __identify__ as event_name")
        XCTAssertEqual(sent?.clickId, "id_click")
        XCTAssertEqual(sent?.externalId, "u_42")
    }

    func testIdentifyEncodesMetadata() async throws {
        let recorder = RecordingClient()
        let config = makeConfig()
        _ = try await Li2.identify(
            externalId: "u_42",
            email: "a@b.com",
            name: nil,
            clickId: "id_click",
            config: config,
            client: recorder,
            clickIdStore: ClickIdStore(defaults: UserDefaults(suiteName: "test.identify.meta.\(UUID().uuidString)")!)
        )
        let sent = await recorder.lastLead
        XCTAssertEqual(sent?.metadata?["type"], "identify")
        XCTAssertEqual(sent?.metadata?["anonymous_click_id"], "id_click")
    }
}
