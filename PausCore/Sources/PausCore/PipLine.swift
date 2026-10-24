import Foundation

/// Tidies a line from the on-device model before Pip says it. The model keeps asking the user things
/// and introducing Pip however it is told not to, and Pip can't hear an answer, so questions and
/// introductions are taken out sentence by sentence. Whatever is left must still fit the speech bubble.
enum PipLine {
    static let maxWords = 60
    static let maxCharacters = 360

    /// Sentences with these are about Pip itself rather than the user, or ask for an answer without a question mark.
    static let dropped = [
        "i'm pip", "i am pip", "jag är pip", "let me know", "tell me", "säg till", "berätta för mig",
    ]

    static func cleaned(_ text: String) -> String? {
        let flattened = text
            .trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: "\"“”")))
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
        // A line cut off by the token limit doesn't end like a sentence.
        guard let last = flattened.last, ".!?…".contains(last) else { return nil }

        let kept = sentences(in: flattened).filter { sentence in
            let lowercased = sentence.lowercased()
            return !sentence.hasSuffix("?") && !dropped.contains(where: lowercased.contains)
        }
        let line = kept.joined(separator: " ")
        // A greeting alone, such as "Hej Aron!", says nothing.
        guard kept.count >= 2 || line.split(separator: " ").count > 3,
              line.count <= maxCharacters,
              line.split(separator: " ").count <= maxWords else { return nil }
        return line
    }

    /// Splits after each `.`, `!`, `?` or `…` that ends a sentence.
    static func sentences(in text: String) -> [String] {
        var result: [String] = []
        var current = ""
        for character in text {
            current.append(character)
            if ".!?…".contains(character) {
                let sentence = current.trimmingCharacters(in: .whitespaces)
                if !sentence.isEmpty { result.append(sentence) }
                current = ""
            }
        }
        let rest = current.trimmingCharacters(in: .whitespaces)
        if !rest.isEmpty { result.append(rest) }
        return result
    }
}
