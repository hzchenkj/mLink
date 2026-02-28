import AppKit
import WebKit

@MainActor
final class MainWindowController: NSWindowController {
    private let documentStore = DocumentStore()
    private let markdownRenderer = MarkdownRenderer()
    private let highlighter = EditorHighlighter()
    private let splitLayoutStore = SplitLayoutStore()

    private var splitView: NSSplitView!
    private var scrollView: NSScrollView!
    private var textView: NSTextView!
    private var previewWebView: WKWebView!

    private var currentURL: URL?
    private var isDirty = false
    private var isLoadingDocument = false
    private var debounceWorkItem: DispatchWorkItem?

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1320, height: 860),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "mLink"
        window.minSize = NSSize(width: 980, height: 640)
        window.center()

        super.init(window: window)

        setupContentView()
        window.makeKeyAndOrderFront(nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupContentView() {
        guard let window else { return }

        let containerBounds = window.contentView?.bounds ?? NSRect(x: 0, y: 0, width: 1320, height: 860)
        splitView = NSSplitView(frame: containerBounds)
        splitView.isVertical = true
        splitView.dividerStyle = .thin
        splitView.autoresizingMask = [.width, .height]
        splitView.delegate = self

        // 左侧编辑器
        let leftWidth = containerBounds.width * CGFloat(splitLayoutStore.ratio)
        let editorView = NSView(frame: NSRect(x: 0, y: 0, width: leftWidth, height: containerBounds.height))
        editorView.autoresizingMask = [.width, .height]

        scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: leftWidth, height: containerBounds.height))
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = true
        scrollView.backgroundColor = Theme.editorBackgroundColor

        // 监听滚动
        scrollView.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(editorDidScroll(_:)),
            name: NSView.boundsDidChangeNotification,
            object: scrollView.contentView
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(splitViewDidResize(_:)),
            name: NSSplitView.didResizeSubviewsNotification,
            object: splitView
        )

        textView = NSTextView(frame: NSRect(x: 0, y: 0, width: leftWidth, height: containerBounds.height))
        textView.autoresizingMask = [.width, .height]
        textView.delegate = self
        textView.font = Theme.editorFont
        textView.textColor = Theme.editorTextColor
        textView.backgroundColor = Theme.editorBackgroundColor
        textView.insertionPointColor = Theme.editorTextColor
        textView.drawsBackground = true
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.textContainerInset = NSSize(width: 8, height: 10)
        textView.textContainer?.lineFragmentPadding = 6

        // 确保可以接收粘贴
        textView.usesFontPanel = false
        textView.usesRuler = false

        scrollView.documentView = textView
        editorView.addSubview(scrollView)

        // 右侧预览
        let rightWidth = containerBounds.width - leftWidth - splitView.dividerThickness
        let previewView = NSView(frame: NSRect(x: 0, y: 0, width: rightWidth, height: containerBounds.height))
        previewView.autoresizingMask = [.width, .height]
        previewView.wantsLayer = true
        previewView.layer?.backgroundColor = NSColor(calibratedRed: 0.97, green: 0.98, blue: 0.99, alpha: 1.0).cgColor

        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        previewWebView = WKWebView(frame: previewView.bounds, configuration: config)
        previewWebView.autoresizingMask = [.width, .height]
        previewWebView.navigationDelegate = self
        previewView.addSubview(previewWebView)

        splitView.addSubview(editorView)
        splitView.addSubview(previewView)
        window.contentView = splitView
        splitView.adjustSubviews()
        applyStoredSplitRatio()
    }

    @objc private func editorDidScroll(_ notification: Notification) {
        syncPreviewScroll()
    }

    private func syncPreviewScroll() {
        let documentHeight = textView.frame.height
        let visibleHeight = scrollView.bounds.height
        let scrollPosition = scrollView.contentView.bounds.origin.y

        let maxScroll = max(1, documentHeight - visibleHeight)
        let scrollRatio = min(1, max(0, scrollPosition / maxScroll))

        let js = """
        (function() {
            var docHeight = document.documentElement.scrollHeight;
            var viewHeight = window.innerHeight;
            var maxScroll = Math.max(1, docHeight - viewHeight);
            var targetScroll = \(scrollRatio) * maxScroll;
            window.scrollTo(0, targetScroll);
        })();
        """
        previewWebView.evaluateJavaScript(js, completionHandler: nil)
    }

    override func windowDidLoad() {
        super.windowDidLoad()
        applyStoredSplitRatio()
        loadDocument(text: "# Hello\n\nStart typing...", url: nil)
    }

    private func applyStoredSplitRatio() {
        guard let splitView, splitView.subviews.count >= 2 else { return }
        let totalWidth = splitView.bounds.width - splitView.dividerThickness
        guard totalWidth > 0 else { return }
        let leftWidth = CGFloat(splitLayoutStore.ratio) * totalWidth
        splitView.setPosition(leftWidth, ofDividerAt: 0)
    }

    @objc private func splitViewDidResize(_ notification: Notification) {
        guard splitView.subviews.count >= 2 else { return }
        let totalWidth = splitView.bounds.width - splitView.dividerThickness
        guard totalWidth > 0 else { return }
        let leftWidth = splitView.subviews[0].frame.width
        splitLayoutStore.ratio = Double(leftWidth / totalWidth)
        splitLayoutStore.markUserAdjusted()
    }

    private func loadDocument(text: String, url: URL?) {
        isLoadingDocument = true

        // 设置文本并应用语法高亮
        let attributedString = NSAttributedString(
            string: text,
            attributes: [
                .font: Theme.editorFont,
                .foregroundColor: Theme.editorTextColor
            ]
        )
        textView.textStorage?.setAttributedString(attributedString)
        highlighter.highlight(textStorage: textView.textStorage, editedRange: nil)

        updatePreview(text: text)
        currentURL = url
        isDirty = false
        isLoadingDocument = false
        updateTitle()
    }

    private func applyHighlight() {
        highlighter.highlight(textStorage: textView.textStorage, editedRange: nil)
        textView.typingAttributes = [
            .font: Theme.editorFont,
            .foregroundColor: Theme.editorTextColor
        ]
    }

    private func updatePreview(text: String) {
        let body = markdownRenderer.renderHTML(from: text)
        let html = """
        <!doctype html>
        <html>
        <head>
          <meta charset="utf-8" />
          <meta name="viewport" content="width=device-width, initial-scale=1" />
          <style>
            :root { color-scheme: light; }
            body { margin: 0; padding: 20px; background: #f7fafc; color: #1f2937; font: 15px/1.6 -apple-system, BlinkMacSystemFont, "PingFang SC", sans-serif; }
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
        previewWebView.loadHTMLString(html, baseURL: nil)
    }

    private func updateTitle() {
        let baseName = currentURL?.lastPathComponent ?? "Untitled.md"
        let marker = isDirty ? " •" : ""
        window?.title = "\(baseName)\(marker) - mLink"
    }

    func newDocument() {
        loadDocument(text: "", url: nil)
    }

    func openDocument() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.plainText, .text]

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let text = try documentStore.open(url: url)
            loadDocument(text: text, url: url)
        } catch {
            let alert = NSAlert(error: error)
            alert.runModal()
        }
    }

    @discardableResult
    func saveDocument() -> Bool {
        if currentURL == nil {
            return saveDocumentAs()
        }
        guard let url = currentURL else { return false }

        do {
            try documentStore.save(text: textView.string, to: url)
            isDirty = false
            updateTitle()
            return true
        } catch {
            let alert = NSAlert(error: error)
            alert.runModal()
            return false
        }
    }

    @discardableResult
    func saveDocumentAs() -> Bool {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = currentURL?.lastPathComponent ?? "Untitled.md"
        panel.allowedContentTypes = [.plainText]

        guard panel.runModal() == .OK, let url = panel.url else { return false }

        do {
            try documentStore.save(text: textView.string, to: url)
            currentURL = url
            isDirty = false
            updateTitle()
            return true
        } catch {
            let alert = NSAlert(error: error)
            alert.runModal()
            return false
        }
    }

}

extension MainWindowController: NSSplitViewDelegate {
    func splitView(_ splitView: NSSplitView, constrainSplitPosition proposedPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
        let totalWidth = splitView.bounds.width - splitView.dividerThickness
        let minPosition = totalWidth * 0.2
        let maxPosition = totalWidth * 0.8
        return min(max(proposedPosition, minPosition), maxPosition)
    }
}

extension MainWindowController: NSTextViewDelegate {
    nonisolated func textDidChange(_ notification: Notification) {
        Task { @MainActor in
            guard !isLoadingDocument else { return }

            debounceWorkItem?.cancel()
            let work = DispatchWorkItem { [weak self] in
                guard let self else { return }
                self.applyHighlight()
                self.updatePreview(text: self.textView.string)
            }
            debounceWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: work)

            isDirty = true
            updateTitle()
        }
    }
}

extension MainWindowController: WKNavigationDelegate {
    nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Task { @MainActor in
            syncPreviewScroll()
        }
    }
}
