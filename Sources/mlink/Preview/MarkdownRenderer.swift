import Foundation

final class MarkdownRenderer {
    private enum ListState {
        case none
        case unordered
        case ordered
    }

    func renderHTML(from markdown: String) -> String {
        let normalized = markdown.replacingOccurrences(of: "\r\n", with: "\n")
        let lines = normalized.components(separatedBy: "\n")

        var html: [String] = []
        var inCodeBlock = false
        var listState: ListState = .none

        for line in lines {
            if line.trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                closeListIfNeeded(&html, &listState)
                if inCodeBlock {
                    html.append("</code></pre>")
                } else {
                    html.append("<pre><code>")
                }
                inCodeBlock.toggle()
                continue
            }

            if inCodeBlock {
                html.append(escapeHTML(line))
                continue
            }

            if line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                closeListIfNeeded(&html, &listState)
                continue
            }

            if let heading = renderHeading(line) {
                closeListIfNeeded(&html, &listState)
                html.append(heading)
                continue
            }

            if let quote = renderBlockquote(line) {
                closeListIfNeeded(&html, &listState)
                html.append(quote)
                continue
            }

            if let unorderedItem = renderUnorderedListItem(line) {
                if listState != .unordered {
                    closeListIfNeeded(&html, &listState)
                    html.append("<ul>")
                    listState = .unordered
                }
                html.append(unorderedItem)
                continue
            }

            if let orderedItem = renderOrderedListItem(line) {
                if listState != .ordered {
                    closeListIfNeeded(&html, &listState)
                    html.append("<ol>")
                    listState = .ordered
                }
                html.append(orderedItem)
                continue
            }

            closeListIfNeeded(&html, &listState)
            html.append("<p>\(renderInline(line))</p>")
        }

        closeListIfNeeded(&html, &listState)
        if inCodeBlock {
            html.append("</code></pre>")
        }

        return html.joined(separator: "\n")
    }

    private func renderHeading(_ line: String) -> String? {
        let pattern = "^(#{1,6})\\s+(.+)$"
        guard let captures = firstMatch(pattern: pattern, in: line) else {
            return nil
        }

        let level = captures[0].count
        let content = renderInline(captures[1])
        return "<h\(level)>\(content)</h\(level)>"
    }

    private func renderBlockquote(_ line: String) -> String? {
        let pattern = "^>\\s?(.*)$"
        guard let captures = firstMatch(pattern: pattern, in: line) else {
            return nil
        }
        return "<blockquote><p>\(renderInline(captures[0]))</p></blockquote>"
    }

    private func renderUnorderedListItem(_ line: String) -> String? {
        let pattern = "^\\s*[-+*]\\s+(.+)$"
        guard let captures = firstMatch(pattern: pattern, in: line) else {
            return nil
        }
        return "<li>\(renderInline(captures[0]))</li>"
    }

    private func renderOrderedListItem(_ line: String) -> String? {
        let pattern = "^\\s*\\d+\\.\\s+(.+)$"
        guard let captures = firstMatch(pattern: pattern, in: line) else {
            return nil
        }
        return "<li>\(renderInline(captures[0]))</li>"
    }

    private func renderInline(_ input: String) -> String {
        var html = escapeHTML(input)
        var codeTokens: [String: String] = [:]

        html = replacing(pattern: "`([^`]+)`", in: html) { groups in
            let token = "__CODE_TOKEN_\(codeTokens.count)__"
            codeTokens[token] = "<code>\(groups[0])</code>"
            return token
        }

        html = replacing(pattern: "\\*\\*(.+?)\\*\\*", in: html) { groups in
            "<strong>\(groups[0])</strong>"
        }

        html = replacing(pattern: "(?<!\\*)\\*(?!\\s)(.+?)(?<!\\s)\\*(?!\\*)", in: html) { groups in
            "<em>\(groups[0])</em>"
        }

        html = replacing(pattern: "\\[([^\\]]+)\\]\\(([^\\)]+)\\)", in: html) { groups in
            let text = groups[0]
            let href = groups[1]
            return "<a href=\"\(href)\">\(text)</a>"
        }

        for (token, value) in codeTokens {
            html = html.replacingOccurrences(of: token, with: value)
        }

        return html
    }

    private func closeListIfNeeded(_ html: inout [String], _ state: inout ListState) {
        switch state {
        case .unordered:
            html.append("</ul>")
        case .ordered:
            html.append("</ol>")
        case .none:
            break
        }
        state = .none
    }

    private func escapeHTML(_ raw: String) -> String {
        raw
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }

    private func replacing(
        pattern: String,
        in source: String,
        transform: ([String]) -> String
    ) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return source
        }

        let nsSource = source as NSString
        let matches = regex.matches(in: source, range: NSRange(location: 0, length: nsSource.length))
        guard !matches.isEmpty else {
            return source
        }

        var result = source
        for match in matches.reversed() {
            var captured: [String] = []
            for i in 1..<match.numberOfRanges {
                let range = match.range(at: i)
                if range.location == NSNotFound {
                    captured.append("")
                    continue
                }
                captured.append(nsSource.substring(with: range))
            }
            let replacement = transform(captured)
            if let swiftRange = Range(match.range, in: result) {
                result.replaceSubrange(swiftRange, with: replacement)
            }
        }

        return result
    }

    private func firstMatch(pattern: String, in source: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }

        let nsSource = source as NSString
        let range = NSRange(location: 0, length: nsSource.length)
        guard let match = regex.firstMatch(in: source, range: range) else {
            return nil
        }

        var captured: [String] = []
        for index in 1..<match.numberOfRanges {
            let captureRange = match.range(at: index)
            guard captureRange.location != NSNotFound else {
                captured.append("")
                continue
            }
            captured.append(nsSource.substring(with: captureRange))
        }

        return captured
    }
}
