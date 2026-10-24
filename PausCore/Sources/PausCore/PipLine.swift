import Foundation

/// Checks a line from the on-device model before Pip says it. The model doesn't always keep to the brief,
/// and Pip can't reply, so long lines and questions are dropped in favour of a handwritten line.
enum PipLine {
    static let maxWords = 16
    static let maxCharacters = 110

    static func cleaned(_ text: String) -> String? {
        let line = text.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: "\"“”")))
        guard !line.isEmpty,
              line.count <= maxCharacters,
              line.split(whereSeparator: \.isWhitespace).count <= maxWords,
              !line.contains("?"),
              !line.contains("\n"),
              // A line cut off by the token limit doesn't end like a sentence.
              let last = line.last, ".!…".contains(last) else { return nil }
        let lowercased = line.lowercased()
        // Pip greets nobody: the home screen already says hello.
        let introductions = ["i'm pip", "i am pip", "jag är pip", "hello", "hej!"]
        guard !introductions.contains(where: lowercased.contains) else { return nil }
        return line
    }
}
