import XCTest
@testable import mlink

final class QuickAccessStoreTests: XCTestCase {
    func testRecentIsOrderedByLatestAndDeduplicated() {
        let suiteName = "mlink.quickaccess.tests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Failed to create test defaults suite")
            return
        }
        defaults.removePersistentDomain(forName: suiteName)

        let store = QuickAccessStore(defaults: defaults, maxRecentCount: 3)
        let a = URL(fileURLWithPath: "/tmp/a.md")
        let b = URL(fileURLWithPath: "/tmp/b.md")
        let c = URL(fileURLWithPath: "/tmp/c.md")
        let d = URL(fileURLWithPath: "/tmp/d.md")

        store.addRecent(a)
        store.addRecent(b)
        store.addRecent(c)
        store.addRecent(b)
        store.addRecent(d)

        XCTAssertEqual(store.recentURLs.map(\.path), [d.path, b.path, c.path])
    }

    func testToggleFavorite() {
        let suiteName = "mlink.quickaccess.tests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Failed to create test defaults suite")
            return
        }
        defaults.removePersistentDomain(forName: suiteName)

        let store = QuickAccessStore(defaults: defaults)
        let fileURL = URL(fileURLWithPath: "/tmp/fav.md")

        XCTAssertFalse(store.isFavorite(url: fileURL))
        XCTAssertTrue(store.toggleFavorite(url: fileURL))
        XCTAssertTrue(store.isFavorite(url: fileURL))
        XCTAssertFalse(store.toggleFavorite(url: fileURL))
        XCTAssertFalse(store.isFavorite(url: fileURL))
    }
}
