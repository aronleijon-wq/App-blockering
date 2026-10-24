import Foundation

/// Checks a line from the on-device model before Pip says it. Pip may greet, write a few sentences and
/// ask questions that need no answer, but can't reply, so a line that asks for one is dropped in favour of a
/// handwritten line, as is one too long for the speech bubble or cut off mid-sentence.
enum PipLine {
    static let maxWords = 60
    static let maxCharacters = 360

    /// Phrases that ask the user to answer or tell Pip something.
    static let replyRequests = [
        "would you like", "do you want", "want me to", "shall i", "should i", "can i help", "how can i help",
        "let me know", "tell me", "what do you think", "what would you",
        "vill du att jag", "vill du ha", "ska jag", "kan jag hjälpa", "hur kan jag", "säg till", "berätta för mig",
        "vad tycker du", "vad vill du",
    ]

    static func cleaned(_ text: String) -> String? {
        let line = text.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: "\"“”")))
        guard !line.isEmpty,
              line.count <= maxCharacters,
              line.split(whereSeparator: \.isWhitespace).count <= maxWords,
              // A line cut off by the token limit doesn't end like a sentence.
              let last = line.last, ".!?…".contains(last) else { return nil }
        let lowercased = line.lowercased()
        guard !replyRequests.contains(where: lowercased.contains) else { return nil }
        return line
    }
}
