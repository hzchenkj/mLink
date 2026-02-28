import AppKit
import WebKit

final class PreviewViewController: NSViewController {
    private let webView: WKWebView = {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = false
        return WKWebView(frame: .zero, configuration: config)
    }()

    private let renderer = MarkdownRenderer()

    override func loadView() {
        view = NSView(frame: .zero)

        webView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)

        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    func updateMarkdown(_ markdown: String) {
        let body = renderer.renderHTML(from: markdown)
        let html = """
        <!doctype html>
        <html>
        <head>
          <meta charset=\"utf-8\" />
          <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\" />
          <style>
            :root { color-scheme: light; }
            body { margin: 0; padding: 20px; background: #f7fafc; color: #1f2937; font: 15px/1.6 -apple-system, BlinkMacSystemFont, \"PingFang SC\", sans-serif; }
            h1, h2, h3, h4, h5, h6 { margin-top: 1.2em; margin-bottom: 0.4em; color: #0f172a; }
            p { margin: 0.6em 0; }
            pre { background: #e2e8f0; border-radius: 8px; padding: 12px; overflow-x: auto; }
            code { background: #e2e8f0; border-radius: 4px; padding: 0.12em 0.3em; font-family: Menlo, ui-monospace, monospace; }
            pre code { background: transparent; padding: 0; }
            blockquote { margin: 0.8em 0; padding: 0.1em 0.8em; border-left: 4px solid #94a3b8; color: #334155; }
            a { color: #0369a1; text-decoration: none; }
            ul, ol { padding-left: 1.4em; }
          </style>
        </head>
        <body>
        \(body)
        </body>
        </html>
        """

        webView.loadHTMLString(html, baseURL: nil)
    }
}
