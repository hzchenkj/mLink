import AppKit

@MainActor
enum Theme {
    static let editorFont = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
    static let codeFont = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
    static let headingFont = NSFont.monospacedSystemFont(ofSize: 14, weight: .semibold)
    static let rulerFont = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)

    static let editorBackgroundColor = NSColor(calibratedWhite: 1.0, alpha: 1.0)
    static let editorTextColor = NSColor.black
    static let currentLineHighlightColor = NSColor.selectedTextBackgroundColor.withAlphaComponent(0.16)

    static let headingColor = NSColor(calibratedRed: 0.08, green: 0.25, blue: 0.43, alpha: 1)
    static let codeColor = NSColor(calibratedRed: 0.50, green: 0.12, blue: 0.16, alpha: 1)
    static let linkColor = NSColor(calibratedRed: 0.00, green: 0.40, blue: 0.64, alpha: 1)
    static let quoteColor = NSColor(calibratedRed: 0.24, green: 0.28, blue: 0.35, alpha: 1)
    static let listColor = NSColor(calibratedRed: 0.20, green: 0.24, blue: 0.30, alpha: 1)

    static let rulerBackgroundColor = NSColor(calibratedWhite: 0.95, alpha: 1.0)
    static let rulerTextColor = NSColor(calibratedWhite: 0.35, alpha: 1.0)
}
