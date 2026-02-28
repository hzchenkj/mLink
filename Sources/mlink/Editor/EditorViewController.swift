import AppKit

@MainActor
protocol EditorViewControllerDelegate: AnyObject {
    func editorViewController(_ controller: EditorViewController, didChangeText text: String)
}

@MainActor
final class EditorViewController: NSViewController, NSTextViewDelegate {
    weak var delegate: EditorViewControllerDelegate?

    private let scrollView = NSScrollView()
    private let highlighter = EditorHighlighter()
    private var textView: NSTextView!

    private var debounceWorkItem: DispatchWorkItem?

    var text: String {
        textView.string
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 100, height: 100))
        setupEditor()
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        scrollView.frame = view.bounds
    }

    func setText(_ newValue: String) {
        textView.string = newValue
        highlighter.highlight(textStorage: textView.textStorage, editedRange: nil)
    }

    func textDidChange(_ notification: Notification) {
        debounceWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.highlighter.highlight(textStorage: self.textView.textStorage, editedRange: nil)
            self.delegate?.editorViewController(self, didChangeText: self.textView.string)
        }
        debounceWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: work)
    }

    private func setupEditor() {
        textView = NSTextView()
        textView.delegate = self
        textView.font = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        textView.textColor = .textColor
        textView.backgroundColor = .textBackgroundColor
        textView.insertionPointColor = .textColor

        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true

        view.addSubview(scrollView)
        scrollView.frame = view.bounds
        scrollView.autoresizingMask = [.width, .height]
    }
}
