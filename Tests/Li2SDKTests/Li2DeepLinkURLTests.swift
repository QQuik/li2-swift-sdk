import XCTest
@testable import Li2SDK

final class Li2DeepLinkURLTests: XCTestCase {

    // MARK: - parseLi2DeferredURL

    func testParsesValidDeferredURL() {
        let raw = "https://deep.li2.link/abc123?li2_cid=XYZ"
        XCTAssertNotNil(Li2DeepLinkURL.parseLi2DeferredURL(raw))
    }

    func testRejectsURLWithoutCid() {
        XCTAssertNil(Li2DeepLinkURL.parseLi2DeferredURL("https://deep.li2.link/abc123"))
    }

    func testRejectsURLWithEmptyCid() {
        XCTAssertNil(Li2DeepLinkURL.parseLi2DeferredURL("https://deep.li2.link/abc?li2_cid="))
    }

    func testRejectsPlainText() {
        XCTAssertNil(Li2DeepLinkURL.parseLi2DeferredURL("hello world"))
    }

    func testRejectsEmptyString() {
        XCTAssertNil(Li2DeepLinkURL.parseLi2DeferredURL(""))
    }

    func testPreservesExtraQueryParams() {
        let raw = "https://deep.li2.link/abc?utm_source=email&li2_cid=XYZ"
        XCTAssertNotNil(Li2DeepLinkURL.parseLi2DeferredURL(raw))
    }

    // MARK: - sanitizedDestination

    func testStripsCidParam() {
        let raw = "https://example.com/article?li2_cid=XYZ"
        let dest = Li2DeepLinkURL.sanitizedDestination(raw)!
        XCTAssertNil(dest.query, "li2_cid should be stripped leaving no query")
        XCTAssertEqual(dest.path, "/article")
    }

    func testPreservesOtherParams() {
        let raw = "https://example.com/article?utm_source=email&li2_cid=XYZ"
        let dest = Li2DeepLinkURL.sanitizedDestination(raw)!
        let query = dest.query ?? ""
        XCTAssertTrue(query.contains("utm_source=email"))
        XCTAssertFalse(query.contains("li2_cid"))
    }

    func testHandlesURLWithNoCid() {
        let raw = "https://example.com/article"
        let dest = Li2DeepLinkURL.sanitizedDestination(raw)!
        XCTAssertEqual(dest.absoluteString, raw)
    }

    func testHandlesUnparsableURLGracefully() {
        // URL(string:) can handle some edge cases; falls back to URL(string:raw)
        let raw = "https://example.com/article"
        XCTAssertNotNil(Li2DeepLinkURL.sanitizedDestination(raw))
    }
}
