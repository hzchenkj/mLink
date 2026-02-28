import AppKit

final class EditorTextView: NSTextView {
    private var highlightedLineRange: NSRange?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func didChangeText() {
        super.didChangeText()
        refreshCurrentLineHighlight()
    }

    func refreshCurrentLineHighlight() {
        guard let layoutManager, let textStorage else { return }

        if let highlightedLineRange {
            layoutManager.removeTemporaryAttribute(.backgroundColor, forCharacterRange: highlightedLineRange)
        }

        let selected = selectedRange()
        guard textStorage.length > 0, selected.location <= textStorage.length else {
            highlightedLineRange = nil
            return
        }

        let nsText = textStorage.string as NSString
        let safeLocation = min(max(selected.location, 0), max(nsText.length - 1, 0))
        let lineRange = nsText.lineRange(for: NSRange(location: safeLocation, length: 0))

        layoutManager.addTemporaryAttribute(
            .backgroundColor,
            value: Theme.currentLineHighlightColor,
            forCharacterRange: lineRange
        )
        highlightedLineRange = lineRange
    }
}