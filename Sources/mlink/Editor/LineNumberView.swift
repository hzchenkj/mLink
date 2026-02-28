import AppKit

final class LineNumberView: NSView {
    weak var textView: NSTextView?
    weak var scrollView: NSScrollView?

    override init(frame: NSRect) {
        super.init(frame: frame)
        self.wantsLayer = true
        self.layer?.backgroundColor = NSColor(calibratedWhite: 0.94, alpha: 1.0).cgColor
    }

    override var isFlipped: Bool {
        return true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard let textView = textView,
              let scrollView = scrollView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else { return }

        // Draw separator line
        let path = NSBezierPath()
        path.move(to: NSPoint(x: bounds.maxX - 1, y: bounds.minY))
        path.line(to: NSPoint(x: bounds.maxX - 1, y: bounds.maxY))
        NSColor(calibratedWhite: 0.75, alpha: 1.0).setStroke()
        path.stroke()

        let text = textView.string as NSString
        guard text.length > 0 else { return }

        // Get visible rect
        let visibleRect = scrollView.documentVisibleRect

        // Get glyph range for visible rect
        let visibleGlyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: textContainer)
        var actualGlyphRange = visibleGlyphRange
        let charRange = layoutManager.characterRange(forGlyphRange: visibleGlyphRange, actualGlyphRange: &actualGlyphRange)

        // Find starting line number
        let startLocation = charRange.location
        var lineNumber = 1
        for i in 0..<min(startLocation, text.length) {
            if text.character(at: i) == 10 {
                lineNumber += 1
            }
        }

        // Draw visible line numbers
        var currentLineRange = text.lineRange(for: NSRange(location: startLocation, length: 0))
        let maxChar = NSMaxRange(charRange)

        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .regular),
            .foregroundColor: NSColor(calibratedWhite: 0.4, alpha: 1.0)
        ]

        while currentLineRange.location < text.length && currentLineRange.location <= maxChar {
            let glyphRange = layoutManager.glyphRange(forCharacterRange: currentLineRange, actualCharacterRange: nil)
            let lineRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)

            let y = lineRect.origin.y + textView.textContainerInset.height - visibleRect.origin.y

            if y + lineRect.height >= dirtyRect.minY && y <= dirtyRect.maxY {
                let numberString = "\(lineNumber)" as NSString
                let size = numberString.size(withAttributes: attrs)
                let x = bounds.width - size.width - 8
                let centeredY = y + (lineRect.height - size.height) / 2
                numberString.draw(at: NSPoint(x: x, y: centeredY), withAttributes: attrs)
            }

            lineNumber += 1
            let nextLocation = NSMaxRange(currentLineRange)
            if nextLocation >= text.length { break }
            currentLineRange = text.lineRange(for: NSRange(location: nextLocation, length: 0))
        }
    }
}
