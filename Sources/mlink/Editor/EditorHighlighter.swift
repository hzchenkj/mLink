import AppKit

@MainActor
final class EditorHighlighter {
    private struct Rule {
        let regex: NSRegularExpression
        let attributes: [NSAttributedString.Key: Any]
    }

    private let baseAttributes: [NSAttributedString.Key: Any] = [
        .font: Theme.editorFont,
        .foregroundColor: Theme.editorTextColor
    ]

    private lazy var rules: [Rule] = {
        [
            Rule(
                regex: try! NSRegularExpression(pattern: "(?s)```.*?```"),
                attributes: [
                    .foregroundColor: Theme.codeColor,
                    .font: Theme.codeFont
                ]
            ),
            Rule(
                regex: try! NSRegularExpression(pattern: "(?m)^(#{1,6})\\s.*$"),
                attributes: [
                    .foregroundColor: Theme.headingColor,
                    .font: Theme.headingFont
                ]
            ),
            Rule(
                regex: try! NSRegularExpression(pattern: "\\[[^\\]]+\\]\\([^\\)]+\\)"),
                attributes: [
                    .foregroundColor: Theme.linkColor,
                    .underlineStyle: NSUnderlineStyle.single.rawValue
                ]
            ),
            Rule(
                regex: try! NSRegularExpression(pattern: "`[^`\\n]+`"),
                attributes: [
                    .foregroundColor: Theme.codeColor,
                    .font: Theme.codeFont
                ]
            ),
            Rule(
                regex: try! NSRegularExpression(pattern: "(?m)^>\\s.*$"),
                attributes: [
                    .foregroundColor: Theme.quoteColor
                ]
            ),
            Rule(
                regex: try! NSRegularExpression(pattern: "(?m)^\\s*(?:[-+*]|\\d+\\.)\\s+.*$"),
                attributes: [
                    .foregroundColor: Theme.listColor
                ]
            ),
            Rule(
                regex: try! NSRegularExpression(pattern: "\\*\\*[^*]+\\*\\*"),
                attributes: [
                    .font: NSFont.boldSystemFont(ofSize: Theme.editorFont.pointSize)
                ]
            ),
            Rule(
                regex: try! NSRegularExpression(pattern: "(?<!\\*)\\*[^*\\n]+\\*(?!\\*)"),
                attributes: [
                    .font: NSFontManager.shared.convert(Theme.editorFont, toHaveTrait: .italicFontMask)
                ]
            )
        ]
    }()

    func highlight(textStorage: NSTextStorage?, editedRange: NSRange?) {
        guard let textStorage else { return }

        let fullRange = NSRange(location: 0, length: textStorage.length)
        textStorage.beginEditing()
        if textStorage.length > 0 {
            textStorage.addAttributes(baseAttributes, range: fullRange)
        }

        let targetRange = resolveTargetRange(text: textStorage.string as NSString, editedRange: editedRange)
        for rule in rules {
            let matches = rule.regex.matches(in: textStorage.string, range: targetRange)
            for match in matches {
                textStorage.addAttributes(rule.attributes, range: match.range)
            }
        }

        textStorage.endEditing()
    }

    private func resolveTargetRange(text: NSString, editedRange: NSRange?) -> NSRange {
        guard let editedRange else {
            return NSRange(location: 0, length: text.length)
        }
        return text.lineRange(for: editedRange)
    }
}
