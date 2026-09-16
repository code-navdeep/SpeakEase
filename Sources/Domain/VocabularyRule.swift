import Foundation

/// A user-defined find→replace correction applied to every transcript before
/// enhancement and injection (e.g. fixing names or jargon the recognizer
/// mishears).
struct VocabularyRule: Codable, Identifiable, Equatable, Hashable {
    let id: UUID
    var find: String
    var replace: String
    /// Match only whole words (the pattern is wrapped in word boundaries).
    var wholeWord: Bool
    var caseSensitive: Bool

    init(id: UUID = UUID(), find: String, replace: String, wholeWord: Bool = true, caseSensitive: Bool = false) {
        self.id = id
        self.find = find
        self.replace = replace
        self.wholeWord = wholeWord
        self.caseSensitive = caseSensitive
    }
}

extension Array where Element == VocabularyRule {
    /// Apply every rule to `text`, in order. Rules with an empty `find` are skipped.
    func apply(to text: String) -> String {
        var result = text
        for rule in self {
            guard !rule.find.isEmpty else { continue }
            let escaped = NSRegularExpression.escapedPattern(for: rule.find)
            let pattern = rule.wholeWord ? "\\b\(escaped)\\b" : escaped
            let options: NSRegularExpression.Options = rule.caseSensitive ? [] : [.caseInsensitive]
            guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { continue }
            let template = NSRegularExpression.escapedTemplate(for: rule.replace)
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: template)
        }
        return result
    }
}
