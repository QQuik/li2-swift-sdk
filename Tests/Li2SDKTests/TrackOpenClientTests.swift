import XCTest
@testable import Li2SDK

final class TrackOpenClientTests: XCTestCase {

    // MARK: - Wire encoding — key names MUST be camelCase

    func testEncodesDeepLinkKey() throws {
        let req = TrackOpenRequest(deepLink: "https://deep.li2.link/abc")
        let data = try JSONEncoder().encode(req)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertEqual(json["deepLink"] as? String, "https://deep.li2.link/abc",
                       "Key must be camelCase 'deepLink', not 'deep_link'")
        XCTAssertNil(json["li2Domains"])
        XCTAssertNil(json["clipboardStatus"])
    }

    func testEncodesDeferredClipboardRequest() throws {
        let req = TrackOpenRequest(
            deepLink: "https://deep.li2.link/abc?li2_cid=XYZ",
            clipboardStatus: ClipboardStatus.read.rawValue
        )
        let data = try JSONEncoder().encode(req)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertEqual(json["deepLink"] as? String, "https://deep.li2.link/abc?li2_cid=XYZ")
        XCTAssertEqual(json["clipboardStatus"] as? String, "read")
        XCTAssertNil(json["li2Domains"])
    }

    func testEncodesOptOutRequest() throws {
        let req = TrackOpenRequest(
            li2Domains: ["deep.li2.link"],
            clipboardStatus: ClipboardStatus.optout.rawValue
        )
        let data = try JSONEncoder().encode(req)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertEqual(json["li2Domains"] as? [String], ["deep.li2.link"],
                       "Key must be camelCase 'li2Domains'")
        XCTAssertEqual(json["clipboardStatus"] as? String, "optout")
        XCTAssertNil(json["deepLink"])
    }

    func testEncodesDeniedStatus() throws {
        let req = TrackOpenRequest(
            li2Domains: ["deep.li2.link"],
            clipboardStatus: ClipboardStatus.denied.rawValue
        )
        let data = try JSONEncoder().encode(req)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertEqual(json["clipboardStatus"] as? String, "denied")
    }

    func testEncodesEmptyStatus() throws {
        let req = TrackOpenRequest(
            li2Domains: ["deep.li2.link"],
            clipboardStatus: ClipboardStatus.empty.rawValue
        )
        let data = try JSONEncoder().encode(req)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertEqual(json["clipboardStatus"] as? String, "empty")
    }

    // MARK: - emptyRequest validation (client-side, no network)

    func testThrowsEmptyRequestWhenNeitherFieldSet() async {
        let client = TrackOpenClient(baseURL: "https://example.com", publishableKey: "pk")
        let req = TrackOpenRequest()
        do {
            _ = try await client.open(req)
            XCTFail("Expected emptyRequest error")
        } catch TrackOpenError.emptyRequest {
            // expected
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    func testThrowsEmptyRequestWhenLi2DomainsEmpty() async {
        let client = TrackOpenClient(baseURL: "https://example.com", publishableKey: "pk")
        let req = TrackOpenRequest(li2Domains: [])
        do {
            _ = try await client.open(req)
            XCTFail("Expected emptyRequest error")
        } catch TrackOpenError.emptyRequest {
            // expected
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    // MARK: - JSON decoding of server response

    func testDecodesMatchedResponse() throws {
        let json = """
        {
            "clickId": "click_abc",
            "link": { "id": "link1", "domain": "deep.li2.link", "key": "abc", "url": "https://example.com/article" },
            "matchMethod": "clipboard",
            "platform": "ios"
        }
        """.data(using: .utf8)!
        let resp = try JSONDecoder().decode(TrackOpenResponse.self, from: json)
        XCTAssertEqual(resp.clickId, "click_abc")
        XCTAssertEqual(resp.link?.url, "https://example.com/article")
        XCTAssertEqual(resp.matchMethod, "clipboard")
        XCTAssertNil(resp.missReason)
    }

    func testDecodesMissedResponse() throws {
        let json = """
        { "clickId": "click_xyz", "missReason": "no_candidate" }
        """.data(using: .utf8)!
        let resp = try JSONDecoder().decode(TrackOpenResponse.self, from: json)
        XCTAssertEqual(resp.missReason, "no_candidate")
        XCTAssertNil(resp.link)
    }

    // MARK: - trimmingTrailingSlashes helper

    func testTrimsTrailingSlashes() {
        XCTAssertEqual("https://api.li2.ai/api/v1//".trimmingTrailingSlashes(),
                       "https://api.li2.ai/api/v1")
    }

    func testNoOpWhenNoTrailingSlash() {
        let s = "https://api.li2.ai/api/v1"
        XCTAssertEqual(s.trimmingTrailingSlashes(), s)
    }
}
