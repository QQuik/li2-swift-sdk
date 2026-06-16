import XCTest
@testable import Li2SDK

final class ClickIdStoreTests: XCTestCase {

    private func makeStore() -> ClickIdStore {
        // Use a fresh in-memory suite per test so tests are isolated.
        let suite = UserDefaults(suiteName: "test.\(UUID().uuidString)")!
        return ClickIdStore(defaults: suite)
    }

    func testPersistAndRecall() {
        let store = makeStore()
        store.persist(clickId: "click_abc", expiryDays: 30)
        XCTAssertEqual(store.currentClickId, "click_abc")
    }

    func testExpiredClickIdReturnsNil() {
        let store = makeStore()
        // Persist with -1 day expiry → already expired.
        store.persist(clickId: "click_old", expiryDays: -1)
        XCTAssertNil(store.currentClickId)
    }

    func testClearRemovesClickId() {
        let store = makeStore()
        store.persist(clickId: "click_abc", expiryDays: 30)
        store.clear()
        XCTAssertNil(store.currentClickId)
    }

    func testNilWhenNothingStored() {
        let store = makeStore()
        XCTAssertNil(store.currentClickId)
    }

    func testOverwriteUpdatesValue() {
        let store = makeStore()
        store.persist(clickId: "click_first", expiryDays: 30)
        store.persist(clickId: "click_second", expiryDays: 30)
        XCTAssertEqual(store.currentClickId, "click_second")
    }
}
