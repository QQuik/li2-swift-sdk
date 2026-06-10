import XCTest
@testable import Li2

// MARK: - URL Helpers

final class Li2DeepLinkURLTests: XCTestCase {

    func test_parse_returnsURL_whenLi2CidPresent() {
        let raw = "https://deep.li2.link/sale?li2_cid=Ab3xK9pQ2mN7vR1t"
        XCTAssertEqual(Li2DeepLinkURL.parseLi2DeferredURL(raw)?.absoluteString, raw)
    }

    func test_parse_returnsNil_whenNoLi2Cid() {
        XCTAssertNil(Li2DeepLinkURL.parseLi2DeferredURL("https://deep.li2.link/sale"))
    }

    func test_parse_returnsNil_whenLi2CidEmpty() {
        XCTAssertNil(Li2DeepLinkURL.parseLi2DeferredURL("https://deep.li2.link/sale?li2_cid="))
    }

    func test_parse_returnsNil_whenNotAURL() {
        XCTAssertNil(Li2DeepLinkURL.parseLi2DeferredURL("just some clipboard text"))
    }

    func test_parse_returnsNil_whenEmptyString() {
        XCTAssertNil(Li2DeepLinkURL.parseLi2DeferredURL(""))
    }

    func test_parse_findsLi2Cid_amongOtherParams() {
        let raw = "https://deep.li2.link/sale?utm_source=ig&li2_cid=Ab3xK9pQ2mN7vR1t&x=1"
        XCTAssertEqual(Li2DeepLinkURL.parseLi2DeferredURL(raw)?.absoluteString, raw)
    }

    func test_sanitize_stripsLi2Cid_keepsOtherParams() {
        let raw = "https://shop.example.com/sale?li2_cid=Ab3xK9pQ2mN7vR1t&ref=home"
        let out = Li2DeepLinkURL.sanitizedDestination(raw)?.absoluteString
        XCTAssertEqual(out, "https://shop.example.com/sale?ref=home")
    }

    func test_sanitize_dropsQuery_whenLi2CidWasOnlyParam() {
        let raw = "https://shop.example.com/sale?li2_cid=Ab3xK9pQ2mN7vR1t"
        let out = Li2DeepLinkURL.sanitizedDestination(raw)?.absoluteString
        XCTAssertEqual(out, "https://shop.example.com/sale")
    }

    func test_sanitize_leavesURLUntouched_whenNoLi2Cid() {
        let raw = "https://shop.example.com/sale?ref=home"
        XCTAssertEqual(Li2DeepLinkURL.sanitizedDestination(raw)?.absoluteString, raw)
    }

}

// MARK: - TrackOpen wire types

final class TrackOpenModelTests: XCTestCase {

    func test_request_encodesOnlyProvidedFields() throws {
        let req = TrackOpenRequest(deepLink: "https://deep.li2.link/sale")
        let json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(req)) as? [String: Any]
        XCTAssertEqual(json?["deepLink"] as? String, "https://deep.li2.link/sale")
        XCTAssertNil(json?["li2Domains"])
        XCTAssertNil(json?["clipboardStatus"])
    }

    func test_response_decodesMatchedShape() throws {
        let body = """
        {"click_id":"Ab3xK9pQ2mN7vR1t",
         "link":{"id":"0e7c9b12","domain":"deep.li2.link","key":"sale",
                 "url":"https://shop.example.com/sale"},
         "match_method":"clipboard","platform":"ios"}
        """.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let res = try decoder.decode(TrackOpenResponse.self, from: body)
        XCTAssertEqual(res.clickId, "Ab3xK9pQ2mN7vR1t")
        XCTAssertEqual(res.link?.url, "https://shop.example.com/sale")
        XCTAssertEqual(res.matchMethod, "clipboard")
        XCTAssertNil(res.missReason)
    }

    func test_response_decodesMissShape() throws {
        let body = """
        {"click_id":"f0e1d2c3b4a59687","link":null,
         "match_method":"","miss_reason":"clipboard_empty","platform":"ios"}
        """.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let res = try decoder.decode(TrackOpenResponse.self, from: body)
        XCTAssertNil(res.link)
        XCTAssertEqual(res.missReason, "clipboard_empty")
    }
}

// MARK: - clickId persistence

final class ClickIdPersistenceTests: XCTestCase {

    private let defaults = UserDefaults(suiteName: "li2.tests.clickId")!

    override func setUp() {
        super.setUp()
        defaults.removeObject(forKey: "ai.li2.lastClickId")
        defaults.removeObject(forKey: "ai.li2.lastClickIdExpiresAt")
    }

    func test_resolvedClickId_returnsExplicitValue_whenProvided() {
        // Even if UserDefaults has a stored value, explicit wins
        let manager = Li2DeepLinkManager.shared
        XCTAssertEqual(manager.resolvedClickId(explicitValue: "explicit_abc"), "explicit_abc")
    }

    func test_resolvedClickId_returnsNoAttribution_forExplicitEmpty() {
        let manager = Li2DeepLinkManager.shared
        XCTAssertEqual(manager.resolvedClickId(explicitValue: Li2.noAttribution), "")
    }

    func test_noAttribution_isEmptyString() {
        XCTAssertEqual(Li2.noAttribution, "")
    }
}
