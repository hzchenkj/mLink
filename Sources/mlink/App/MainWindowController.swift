import AppKit
import WebKit

@MainActor
final class MainWindowController: NSWindowController {
    private final class EditorTab {
        let id: UUID
        var text: String
        var url: URL?
        var isDirty: Bool

        init(text: String, url: URL?, isDirty: Bool = false) {
            self.id = UUID()
            self.text = text
            self.url = url
            self.isDirty = isDirty
        }

        var title: String {
            let baseName = url?.lastPathComponent ?? "Untitled.md"
            return isDirty ? "\(baseName) •" : baseName
        }
    }

    private let documentStore = DocumentStore()
    private let markdownRenderer = MarkdownRenderer()
    private let highlighter = EditorHighlighter()
    private let splitLayoutStore = SplitLayoutStore()
    private let quickAccessStore = QuickAccessStore()

    private var rootView: NSView!
    private var topBarView: NSView!
    private var tabsScrollView: NSScrollView!
    private var tabsStackView: NSStackView!
    private var recentPopupButton: NSPopUpButton!
    private var favoritesPopupButton: NSPopUpButton!
    private var favoriteToggleButton: NSButton!
    private var splitView: NSSplitView!
    private var scrollView: NSScrollView!
    private var textView: NSTextView!
    private var lineNumberView: LineNumberView!
    private var previewWebView: WKWebView!

    private var tabs: [EditorTab] = []
    private var currentTabID: UUID?
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

        // Root view
        rootView = NSView(frame: containerBounds)
        rootView.autoresizingMask = [.width, .height]
        window.contentView = rootView

        // Top bar with tabs and controls
        topBarView = NSView(frame: NSRect(x: 0, y: containerBounds.height - 42, width: containerBounds.width, height: 42))
        topBarView.autoresizingMask = [.width, .minYMargin]
        topBarView.wantsLayer = true
        topBarView.layer?.backgroundColor = NSColor(calibratedWhite: 0.98, alpha: 1.0).cgColor
        rootView.addSubview(topBarView)

        setupTopBarControls()

        // Split view for editor and preview
        splitView = NSSplitView(frame: NSRect(x: 0, y: 0, width: containerBounds.width, height: containerBounds.height - 42))
        splitView.isVertical = true
        splitView.dividerStyle = .thin
        splitView.autoresizingMask = [.width, .height]
        splitView.delegate = self
        rootView.addSubview(splitView)

        // Left editor with line numbers
        let leftWidth = containerBounds.width * CGFloat(splitLayoutStore.ratio)
        let editorView = NSView(frame: NSRect(x: 0, y: 0, width: leftWidth, height: containerBounds.height - 42))
        editorView.autoresizingMask = [.width, .height]

        // Line number view
        let lineNumberWidth: CGFloat = 50
        let lineNumberView = LineNumberView(frame: NSRect(x: 0, y: 0, width: lineNumberWidth, height: containerBounds.height - 42))
        lineNumberView.autoresizingMask = [.height]
        editorView.addSubview(lineNumberView)

        // Scroll view for text
        scrollView = NSScrollView(frame: NSRect(x: lineNumberWidth, y: 0, width: leftWidth - lineNumberWidth, height: containerBounds.height - 42))
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = true
        scrollView.backgroundColor = Theme.editorBackgroundColor

        // Listen for scroll
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

        textView = NSTextView(frame: NSRect(x: 0, y: 0, width: leftWidth, height: containerBounds.height - 42))
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

        textView.usesFontPanel = false
        textView.usesRuler = false

        scrollView.documentView = textView
        editorView.addSubview(scrollView)

        // Connect line number view
        self.lineNumberView = lineNumberView
        lineNumberView.textView = textView
        lineNumberView.scrollView = scrollView

        // Right preview
        let rightWidth = containerBounds.width - leftWidth - splitView.dividerThickness
        let previewView = NSView(frame: NSRect(x: 0, y: 0, width: rightWidth, height: containerBounds.height - 42))
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
        splitView.adjustSubviews()
        applyStoredSplitRatio()
    }

    private func setupTopBarControls() {
        // Tabs stack view
        tabsStackView = NSStackView()
        tabsStackView.orientation = .horizontal
        tabsStackView.spacing = 8
        tabsStackView.edgeInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)

        tabsScrollView = NSScrollView(frame: .zero)
        tabsScrollView.borderType = .noBorder
        tabsScrollView.drawsBackground = false
        tabsScrollView.hasHorizontalScroller = true
        tabsScrollView.hasVerticalScroller = false
        tabsScrollView.autohidesScrollers = true
        tabsScrollView.documentView = tabsStackView
        topBarView.addSubview(tabsScrollView)

        // Recent files popup
        recentPopupButton = NSPopUpButton(frame: .zero, pullsDown: false)
        recentPopupButton.target = self
        recentPopupButton.action = #selector(openFromRecent(_:))
        topBarView.addSubview(recentPopupButton)

        // Favorites popup
        favoritesPopupButton = NSPopUpButton(frame: .zero, pullsDown: false)
        favoritesPopupButton.target = self
        favoritesPopupButton.action = #selector(openFromFavorites(_:))
        topBarView.addSubview(favoritesPopupButton)

        // Favorite toggle button
        favoriteToggleButton = NSButton(title: "☆", target: self, action: #selector(toggleFavoriteButtonClicked(_:)))
        favoriteToggleButton.bezelStyle = .rounded
        topBarView.addSubview(favoriteToggleButton)

        refreshQuickAccessUI()
        layoutTopBarControls()
    }

    private func layoutTopBarControls() {
        let inset: CGFloat = 10
        let controlHeight: CGFloat = 28
        let y: CGFloat = (topBarView.bounds.height - controlHeight) / 2

        var right = topBarView.bounds.width - inset

        favoriteToggleButton.frame = NSRect(x: right - 36, y: y, width: 36, height: controlHeight)
        right -= 44

        favoritesPopupButton.frame = NSRect(x: right - 180, y: y, width: 180, height: controlHeight)
        right -= 188

        recentPopupButton.frame = NSRect(x: right - 180, y: y, width: 180, height: controlHeight)
        right -= 188

        tabsScrollView.frame = NSRect(x: inset, y: y, width: max(160, right - inset), height: controlHeight)
        tabsStackView.frame = NSRect(x: 0, y: 0, width: tabsStackView.fittingSize.width, height: controlHeight)
    }

    @objc private func windowDidResize(_ notification: Notification) {
        guard notification.object as? NSWindow === window else { return }
        layoutTopBarControls()
        applyStoredSplitRatio()
    }

    private var currentTab: EditorTab? {
        guard let currentTabID else { return nil }
        return tabs.first(where: { $0.id == currentTabID })
    }

    private func addTab(text: String, url: URL?, shouldSelect: Bool, trackRecent: Bool = true) {
        // If URL already open, switch to it
        if let url, let index = tabs.firstIndex(where: { $0.url?.standardizedFileURL == url.standardizedFileURL }) {
            if shouldSelect {
                currentTabID = tabs[index].id
                renderCurrentTab()
            }
            if trackRecent {
                quickAccessStore.addRecent(url)
                refreshQuickAccessUI()
            }
            return
        }

        let tab = EditorTab(text: text, url: url, isDirty: false)
        tabs.append(tab)
        if shouldSelect {
            currentTabID = tab.id
            renderCurrentTab()
        } else {
            refreshTabUI()
            updateWindowTitle()
        }
        if let url, trackRecent {
            quickAccessStore.addRecent(url)
            refreshQuickAccessUI()
        }
    }

    private func renderCurrentTab() {
        guard let tab = currentTab else { return }
        isLoadingDocument = true

        let attributedString = NSAttributedString(
            string: tab.text,
            attributes: [
                .font: Theme.editorFont,
                .foregroundColor: Theme.editorTextColor
            ]
        )
        textView.textStorage?.setAttributedString(attributedString)
        highlighter.highlight(textStorage: textView.textStorage, editedRange: nil)

        updatePreview(text: tab.text)
        isLoadingDocument = false
        refreshTabUI()
        refreshQuickAccessUI()
        updateWindowTitle()
    }

    private func refreshTabUI() {
        tabsStackView.arrangedSubviews.forEach { view in
            tabsStackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        for tab in tabs {
            let tabItem = NSStackView()
            tabItem.orientation = .horizontal
            tabItem.spacing = 4
            tabItem.alignment = .centerY
            tabItem.edgeInsets = NSEdgeInsets(top: 0, left: 6, bottom: 0, right: 8)

            // Close button
            let closeButton = NSButton(title: "×", target: self, action: #selector(tabCloseClicked(_:)))
            closeButton.bezelStyle = .inline
            closeButton.controlSize = .small
            closeButton.setButtonType(.momentaryPushIn)
            closeButton.toolTip = tab.id.uuidString
            closeButton.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
            closeButton.frame.size = NSSize(width: 16, height: 16)

            // Title button
            let titleButton = NSButton(title: tab.title, target: self, action: #selector(tabTitleClicked(_:)))
            titleButton.bezelStyle = .texturedRounded
            titleButton.controlSize = .small
            titleButton.toolTip = tab.id.uuidString
            titleButton.alignment = .left
            titleButton.font = NSFont.systemFont(ofSize: 12)
            titleButton.contentTintColor = (tab.id == currentTabID) ? NSColor.controlAccentColor : NSColor.labelColor

            tabItem.addArrangedSubview(closeButton)
            tabItem.addArrangedSubview(titleButton)
            tabsStackView.addArrangedSubview(tabItem)
        }

        tabsStackView.layoutSubtreeIfNeeded()
        tabsStackView.frame.size.width = tabsStackView.fittingSize.width
    }

    private func refreshQuickAccessUI() {
        recentPopupButton.removeAllItems()
        recentPopupButton.addItem(withTitle: "最近打开")
        recentPopupButton.lastItem?.isEnabled = false
        for url in quickAccessStore.recentURLs {
            recentPopupButton.addItem(withTitle: url.lastPathComponent)
            recentPopupButton.lastItem?.toolTip = url.path
        }

        favoritesPopupButton.removeAllItems()
        favoritesPopupButton.addItem(withTitle: "收藏文件")
        favoritesPopupButton.lastItem?.isEnabled = false
        for url in quickAccessStore.favoriteURLs {
            favoritesPopupButton.addItem(withTitle: url.lastPathComponent)
            favoritesPopupButton.lastItem?.toolTip = url.path
        }

        if let currentURL = currentTab?.url {
            favoriteToggleButton.title = quickAccessStore.isFavorite(url: currentURL) ? "★" : "☆"
            favoriteToggleButton.isEnabled = true
        } else {
            favoriteToggleButton.title = "☆"
            favoriteToggleButton.isEnabled = false
        }
    }

    @objc private func tabTitleClicked(_ sender: NSButton) {
        guard let uuidString = sender.toolTip, let id = UUID(uuidString: uuidString) else { return }
        guard tabs.contains(where: { $0.id == id }) else { return }
        currentTabID = id
        renderCurrentTab()
    }

    @objc private func tabCloseClicked(_ sender: NSButton) {
        guard let uuidString = sender.toolTip, let id = UUID(uuidString: uuidString) else { return }
        closeTab(withID: id)
    }

    @objc private func toggleFavoriteButtonClicked(_ sender: Any?) {
        toggleFavoriteForCurrentTab()
    }

    @objc private func openFromRecent(_ sender: NSPopUpButton) {
        let index = sender.indexOfSelectedItem
        guard index > 0 else { return }
        let urls = quickAccessStore.recentURLs
        guard index - 1 < urls.count else { return }
        openInTab(url: urls[index - 1], shouldSelect: true)
        sender.selectItem(at: 0)
    }

    @objc private func openFromFavorites(_ sender: NSPopUpButton) {
        let index = sender.indexOfSelectedItem
        guard index > 0 else { return }
        let urls = quickAccessStore.favoriteURLs
        guard index - 1 < urls.count else { return }
        openInTab(url: urls[index - 1], shouldSelect: true)
        sender.selectItem(at: 0)
    }

    private func closeTab(withID id: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        let wasCurrent = (currentTabID == id)
        tabs.remove(at: index)

        if tabs.isEmpty {
            addTab(text: "", url: nil, shouldSelect: true, trackRecent: false)
            return
        }

        if wasCurrent {
            let newIndex = min(index, tabs.count - 1)
            currentTabID = tabs[newIndex].id
            renderCurrentTab()
        } else {
            refreshTabUI()
            updateWindowTitle()
        }
    }

    private func openInTab(url: URL, shouldSelect: Bool) {
        do {
            let text = try documentStore.open(url: url)
            addTab(text: text, url: url, shouldSelect: shouldSelect)
        } catch {
            let alert = NSAlert(error: error)
            alert.runModal()
        }
    }

    @objc private func editorDidScroll(_ notification: Notification) {
        syncPreviewScroll()
        lineNumberView?.needsDisplay = true
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
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidResize(_:)),
            name: NSWindow.didResizeNotification,
            object: window
        )
        addTab(text: "# Hello\n\nStart typing...", url: nil, shouldSelect: true, trackRecent: false)
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

    private func updateWindowTitle() {
        let baseName = currentTab?.url?.lastPathComponent ?? "Untitled.md"
        let marker = (currentTab?.isDirty ?? false) ? " •" : ""
        window?.title = "\(baseName)\(marker) - mLink"
    }

    // MARK: - Public Actions

    func newTab() {
        addTab(text: "", url: nil, shouldSelect: true, trackRecent: false)
    }

    func newDocument() {
        // For menu: new tab
        newTab()
    }

    func openDocument() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.plainText, .text]

        guard panel.runModal() == .OK else { return }

        for url in panel.urls {
            openInTab(url: url, shouldSelect: url == panel.urls.last)
        }
    }

    func closeCurrentTab() {
        guard let currentTabID else { return }
        closeTab(withID: currentTabID)
    }

    @discardableResult
    func saveDocument() -> Bool {
        guard let currentTab else { return false }
        if currentTab.url == nil {
            return saveDocumentAs()
        }
        guard let url = currentTab.url else { return false }

        do {
            try documentStore.save(text: textView.string, to: url)
            currentTab.isDirty = false
            quickAccessStore.addRecent(url)
            refreshQuickAccessUI()
            refreshTabUI()
            updateWindowTitle()
            return true
        } catch {
            let alert = NSAlert(error: error)
            alert.runModal()
            return false
        }
    }

    @discardableResult
    func saveDocumentAs() -> Bool {
        guard let currentTab else { return false }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = currentTab.url?.lastPathComponent ?? "Untitled.md"
        panel.allowedContentTypes = [.plainText]

        guard panel.runModal() == .OK, let url = panel.url else { return false }

        do {
            try documentStore.save(text: textView.string, to: url)
            currentTab.url = url
            currentTab.isDirty = false
            quickAccessStore.addRecent(url)
            refreshQuickAccessUI()
            refreshTabUI()
            updateWindowTitle()
            return true
        } catch {
            let alert = NSAlert(error: error)
            alert.runModal()
            return false
        }
    }

    func toggleFavoriteForCurrentTab() {
        guard let url = currentTab?.url else { return }
        _ = quickAccessStore.toggleFavorite(url: url)
        refreshQuickAccessUI()
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
            guard let currentTab else { return }

            currentTab.text = textView.string

            debounceWorkItem?.cancel()
            let work = DispatchWorkItem { [weak self] in
                guard let self else { return }
                self.applyHighlight()
                self.updatePreview(text: self.textView.string)
                self.lineNumberView?.needsDisplay = true
            }
            debounceWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: work)

            if !currentTab.isDirty {
                currentTab.isDirty = true
            }
            refreshTabUI()
            updateWindowTitle()
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
