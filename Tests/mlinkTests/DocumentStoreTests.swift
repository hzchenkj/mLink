import XCTest
@testable import mlink

final class DocumentStoreTests: XCTestCase {
    func testOpenAndSaveUTF8Document() throws {
        let store = DocumentStore()
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
        let fileURL = directory.appendingPathComponent("mlink-test-\(UUID().uuidString).md")
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let input = "# 标题\n\nHello"
        try store.save(text: input, to: fileURL)

        let output = try store.open(url: fileURL)
        XCTAssertEqual(output, input)
    }
}
