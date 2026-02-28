import XCTest
@testable import mlink

final class MarkdownRendererTests: XCTestCase {
    func testRendersHeadingsAndParagraph() {
        let renderer = MarkdownRenderer()
        let markdown = "# Title\n\nHello **world**"

        let html = renderer.renderHTML(from: markdown)

        XCTAssertTrue(html.contains("<h1>Title</h1>"))
        XCTAssertTrue(html.contains("<p>Hello <strong>world</strong></p>"))
    }

    func testRendersListAndCodeBlock() {
        let renderer = MarkdownRenderer()
        let markdown = "- a\n- b\n\n```\nlet x = 1\n```"

        let html = renderer.renderHTML(from: markdown)

        XCTAssertTrue(html.contains("<ul>"))
        XCTAssertTrue(html.contains("<li>a</li>"))
        XCTAssertTrue(html.contains("<pre><code>"))
        XCTAssertTrue(html.contains("let x = 1"))
    }

    func testEscapesHTML() {
        let renderer = MarkdownRenderer()
        let markdown = "<script>alert(1)</script>"

        let html = renderer.renderHTML(from: markdown)

        XCTAssertTrue(html.contains("&lt;script&gt;alert(1)&lt;/script&gt;"))
    }
}
