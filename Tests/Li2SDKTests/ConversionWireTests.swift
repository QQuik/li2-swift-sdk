import XCTest
@testable import Li2SDK

// MARK: - Wire encoding (byte-level snake_case net — the v1-bug guard for conversion endpoints)

final class ConversionWireTests: XCTestCase {

    private let encoder = JSONEncoder()

    // Helpers
    private func json(_ data: Data) throws -> [String: Any] {
        try JSONSerialization.jsonObject(with: data) as! [String: Any]
    }

    // MARK: Lead encoding

    func testDirectLeadEncoding() throws {
        let req = LeadRequest(
            clickId: "",
            externalId: "u_42",
            eventName: "signup",
            email: "a@b.com",
            name: nil,
            phone: nil,
            metadata: nil
        )
        let j = try json(encoder.encode(req))
        // snake_case keys
        XCTAssertEqual(j["click_id"] as? String, "", "Direct must send click_id = empty string, not omit it")
        XCTAssertEqual(j["external_id"] as? String, "u_42", "Key must be snake_case 'external_id'")
        XCTAssertEqual(j["event_name"] as? String, "signup", "Key must be snake_case 'event_name'")
        XCTAssertEqual(j["email"] as? String, "a@b.com")
        // nil identity fields omitted
        XCTAssertNil(j["name"], "nil name must be omitted, not null")
        XCTAssertNil(j["phone"], "nil phone must be omitted, not null")
        XCTAssertNil(j["metadata"], "nil metadata must be omitted, not null")
        // camelCase must NOT appear
        XCTAssertNil(j["clickId"], "camelCase 'clickId' must not appear in conversion wire")
        XCTAssertNil(j["externalId"], "camelCase 'externalId' must not appear in conversion wire")
        XCTAssertNil(j["eventName"], "camelCase 'eventName' must not appear in conversion wire")
    }

    func testAnonymousLeadEncoding() throws {
        let req = LeadRequest(
            clickId: "abc123",
            externalId: nil,
            eventName: "viewed_pricing",
            email: nil,
            name: nil,
            phone: nil,
            metadata: nil
        )
        let j = try json(encoder.encode(req))
        XCTAssertEqual(j["click_id"] as? String, "abc123")
        XCTAssertNil(j["external_id"], "Anonymous lead must NOT include external_id")
        XCTAssertEqual(j["event_name"] as? String, "viewed_pricing")
    }

    func testAttributedLeadEncoding() throws {
        let req = LeadRequest(
            clickId: "abc123",
            externalId: "u_42",
            eventName: "signup",
            email: nil,
            name: nil,
            phone: nil,
            metadata: nil
        )
        let j = try json(encoder.encode(req))
        XCTAssertEqual(j["click_id"] as? String, "abc123")
        XCTAssertEqual(j["external_id"] as? String, "u_42")
        XCTAssertEqual(j["event_name"] as? String, "signup")
    }

    // MARK: Sale encoding

    func testDirectSaleEncoding() throws {
        let req = SaleRequest(
            clickId: "",
            externalId: "u_42",
            amount: 4999,
            currency: nil,
            eventName: nil,
            paymentProcessor: nil,
            invoiceId: nil,
            email: nil,
            name: nil,
            phone: nil,
            avatarUrl: nil,
            metadata: nil
        )
        let j = try json(encoder.encode(req))
        XCTAssertEqual(j["click_id"] as? String, "")
        XCTAssertEqual(j["external_id"] as? String, "u_42")
        // amount encodes as a JSON number (Int, not String)
        XCTAssertEqual(j["amount"] as? Int, 4999, "amount must be a JSON number")
        // currency omitted when not supplied (D-13)
        XCTAssertNil(j["currency"], "currency must be omitted when caller doesn't supply it (D-13)")
        // other optional sale keys omitted
        XCTAssertNil(j["event_name"])
        XCTAssertNil(j["payment_processor"], "Key must be snake_case 'payment_processor'")
        XCTAssertNil(j["invoice_id"], "Key must be snake_case 'invoice_id'")
        XCTAssertNil(j["avatar_url"], "Key must be snake_case 'avatar_url'")
        // camelCase must NOT appear
        XCTAssertNil(j["paymentProcessor"])
        XCTAssertNil(j["invoiceId"])
        XCTAssertNil(j["avatarUrl"])
    }

    func testAttributedSaleEncodingWithCurrency() throws {
        let req = SaleRequest(
            clickId: "abc123",
            externalId: "u_42",
            amount: 4999,
            currency: "vnd",
            eventName: nil,
            paymentProcessor: "stripe",
            invoiceId: "inv_001",
            email: nil,
            name: nil,
            phone: nil,
            avatarUrl: "https://example.com/avatar.png",
            metadata: nil
        )
        let j = try json(encoder.encode(req))
        XCTAssertEqual(j["click_id"] as? String, "abc123")
        XCTAssertEqual(j["currency"] as? String, "vnd", "currency must be present when caller supplies it")
        XCTAssertEqual(j["payment_processor"] as? String, "stripe")
        XCTAssertEqual(j["invoice_id"] as? String, "inv_001")
        XCTAssertEqual(j["avatar_url"] as? String, "https://example.com/avatar.png")
    }

    // MARK: Response decoding

    func testLeadSuccessEnvelopeUnwrap() throws {
        let json = """
        { "code": 200, "message": "ok", "data": { "success": true, "customer_id": "cust_abc" } }
        """.data(using: .utf8)!
        let env = try JSONDecoder().decode(Envelope<LeadData>.self, from: json)
        XCTAssertNotNil(env.data)
        XCTAssertEqual(env.data?.customerId, "cust_abc")
        XCTAssertTrue(env.data?.success == true)
    }

    func testSaleSuccessEnvelopeUnwrap() throws {
        let json = """
        { "code": 200, "message": "ok", "data": { "success": true, "sale_event_id": "sale_xyz", "customer_id": "cust_abc" } }
        """.data(using: .utf8)!
        let env = try JSONDecoder().decode(Envelope<SaleData>.self, from: json)
        XCTAssertEqual(env.data?.saleEventId, "sale_xyz")
        XCTAssertEqual(env.data?.customerId, "cust_abc")
    }

    func testErrorEnvelopeWithNullData() throws {
        // Non-2xx: data is null, message is top-level — decoder must NOT look in data.message
        let json = """
        { "code": 400, "message": "click_id is required", "data": null, "error_code": "INVALID_REQUEST" }
        """.data(using: .utf8)!
        let env = try JSONDecoder().decode(Envelope<LeadData>.self, from: json)
        XCTAssertNil(env.data, "data must be nil on error responses")
        XCTAssertEqual(env.code, 400)
        XCTAssertEqual(env.message, "click_id is required", "message must be the top-level field")
    }
}
