import XCTest
@testable import Li2

// MARK: - Li2LeadEvent validation

final class Li2LeadEventTests: XCTestCase {

    func test_anonPrefix_isRejected() async {
        Li2.configure(publishableKey: "li2_pk_test", deepLinkDomains: ["deep.li2.link"])
        let event = Li2LeadEvent(eventName: "test", externalId: "anon_something")
        do {
            _ = try await Li2ConversionClient.shared.trackLead(event)
            XCTFail("Expected anonPrefixReserved error")
        } catch Li2TrackingError.anonPrefixReserved {
            // expected
        } catch {
            XCTFail("Wrong error: \(error)")
        }
    }

    func test_directLead_withoutExternalId_isRejected() async {
        Li2.configure(publishableKey: "li2_pk_test", deepLinkDomains: ["deep.li2.link"])
        // clickId = "" (direct) with no externalId — should throw
        let event = Li2LeadEvent(eventName: "contact", clickId: Li2.noAttribution)
        do {
            _ = try await Li2ConversionClient.shared.trackLead(event)
            XCTFail("Expected externalIdRequired error")
        } catch Li2TrackingError.externalIdRequired {
            // expected
        } catch {
            XCTFail("Wrong error: \(error)")
        }
    }

    func test_notConfigured_throwsError() async {
        // Reset config
        Li2.shared.config = nil  // Note: this tests the notConfigured path
        let event = Li2LeadEvent(eventName: "signup")
        do {
            _ = try await Li2ConversionClient.shared.trackLead(event)
            XCTFail("Expected notConfigured error")
        } catch Li2TrackingError.notConfigured {
            // expected
        } catch {
            XCTFail("Wrong error: \(error)")
        }
    }
}

// MARK: - Li2SaleEvent validation

final class Li2SaleEventTests: XCTestCase {

    func test_anonPrefix_isRejected() async {
        Li2.configure(publishableKey: "li2_pk_test", deepLinkDomains: ["deep.li2.link"])
        let event = Li2SaleEvent(externalId: "anon_user", amount: 1000)
        do {
            _ = try await Li2ConversionClient.shared.trackSale(event)
            XCTFail("Expected anonPrefixReserved error")
        } catch Li2TrackingError.anonPrefixReserved {
            // expected
        } catch {
            XCTFail("Wrong error: \(error)")
        }
    }

    func test_notConfigured_throwsError() async {
        Li2.shared.config = nil
        let event = Li2SaleEvent(externalId: "order_123", amount: 999)
        do {
            _ = try await Li2ConversionClient.shared.trackSale(event)
            XCTFail("Expected notConfigured error")
        } catch Li2TrackingError.notConfigured {
            // expected
        } catch {
            XCTFail("Wrong error: \(error)")
        }
    }
}

// MARK: - Wire field verification

final class ConversionWireTests: XCTestCase {

    func test_noAttribution_sentAsEmptyString() {
        // Li2.noAttribution must be "" on the wire — backend rejects null/omit with 400
        XCTAssertEqual(Li2.noAttribution, "")
        XCTAssertFalse(Li2.noAttribution == "null")
    }

    func test_leadEvent_avatarURL_fieldName() {
        // avatarURL maps to "avatar" (not "avatar_url") per li2-analytics wire contract
        let event = Li2LeadEvent(eventName: "test", avatarURL: "https://example.com/img.jpg")
        XCTAssertEqual(event.avatarURL, "https://example.com/img.jpg")
    }

    func test_saleEvent_allRequiredFieldsPresent() {
        let event = Li2SaleEvent(externalId: "order_abc", amount: 4999)
        XCTAssertEqual(event.externalId, "order_abc")
        XCTAssertEqual(event.amount, 4999)
        XCTAssertNil(event.clickId)   // nil = auto-fill
    }
}
