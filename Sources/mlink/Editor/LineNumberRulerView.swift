import AppKit

final class LineNumberRulerView: NSRulerView {
    weak var textView: NSTextView?

    init(textView: NSTextView) {
        self.textView = textView
        super.init(scrollView: textView.enclosingScrollView, orientation: .verticalRuler)

        ruleThickness = 44
        clientView = textView

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(textDidChange(_:)),
            name: NSText.didChangeNotification,
            object: textView
        )

        textView.enclosingScrollView?.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(boundsDidChange(_:)),
            name: NSView.boundsDidChangeNotification,
            object: textView.enclosingScrollView?.contentView
        )
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func textDidChange(_ notification: Notification) {
        needsDisplay = true
    }

    @objc private func boundsDidChange(_ notification: Notification) {
        needsDisplay = true
    }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard
            let textView,
            let layoutManager = textView.layoutManager,
            let textContainer = textView.textContainer,
            let scrollView = textView.enclosingScrollView
        else {
            return
        }

        Theme.rulerBackgroundColor.setFill()
        rect.fill()

        let visibleRect = scrollView.contentView.bounds
        let glyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: textContainer)
        let charRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)

        let nsText = textView.string as NSString
        var lineNumber = nsText.substring(to: min(charRange.location, nsText.length)).reduce(into: 1) {
            if $1 == "\n" { $0 += 1 }
        }

        var lineRange = nsText.lineRange(for: NSRange(location: charRange.location, length: 0))
        let maxRange = NSMaxRange(charRange)

        while lineRange.location < nsText.length && lineRange.location <= maxRange {
            let glyphLineRange = layoutManager.glyphRange(forCharacterRange: lineRange, actualCharacterRange: nil)
            let lineRect = layoutManager.boundingRect(forGlyphRange: glyphLineRange, in: textContainer)

            let y = lineRect.minY + textView.textContainerInset.height - visibleRect.minY
            draw(lineNumber: lineNumber, y: y)

            lineNumber += 1
            let nextLocation = NSMaxRange(lineRange)
            if nextLocation >= nsText.length { break }
            lineRange = nsText.lineRange(for: NSRange(location: nextLocation, length: 0))
        }
    }

    private func draw(lineNumber: Int, y: CGFloat) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: Theme.rulerFont,
            .foregroundColor: Theme.rulerTextColor
        ]

        let numberString = "\(lineNumber)" as NSString
        let size = numberString.size(withAttributes: attrs)
        let x = ruleThickness - size.width - 8
        numberString.draw(at: NSPoint(x: x, y: y), withAttributes: attrs)
    }
}