import XCTest
@testable import mlink

final class SplitLayoutStoreTests: XCTestCase {
    func testDefaultRatioIsHalf() {
        let suiteName = UUID().uuidString
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = SplitLayoutStore(defaults: defaults)
        XCTAssertEqual(store.ratio, 0.5)
    }

    func testRatioClamp() {
        let suiteName = UUID().uuidString
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = SplitLayoutStore(defaults: defaults)
        store.ratio = 0.95
        XCTAssertEqual(store.ratio, 0.8)

        store.ratio = 0.01
        XCTAssertEqual(store.ratio, 0.2)
    }
}
