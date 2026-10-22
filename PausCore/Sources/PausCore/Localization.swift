import Foundation

/// The languages Paus speaks. Swedish is the source language; English comes from `Translations`.
enum Language: String, CaseIterable, Codable, Identifiable {
    case sv, en

    var id: Self { self }

    /// The language's own name, so it reads right whichever language is showing.
    var nativeName: String {
        switch self {
        case .sv: return "Svenska"
        case .en: return "English"
        }
    }

    var flag: String {
        switch self {
        case .sv: return "🇸🇪"
        case .en: return "🇬🇧"
        }
    }

    var locale: Locale {
        switch self {
        case .sv: return Locale(identifier: "sv_SE")
        case .en: return Locale(identifier: "en_GB")
        }
    }

    private static let storageKey = "language"

    /// The App Group's defaults, so the app and every extension agree. Nil in tests, where there is no group.
    private static var defaults: UserDefaults? {
        (Bundle.main.object(forInfoDictionaryKey: "PausAppGroup") as? String).flatMap(UserDefaults.init(suiteName:))
    }

    /// The phone's language when it is Swedish, otherwise English.
    static var system: Language {
        Locale.preferredLanguages.first?.hasPrefix("sv") == true ? .sv : .en
    }

    /// The language the user picked, if any.
    static var chosen: Language? {
        get { defaults?.string(forKey: storageKey).flatMap(Language.init(rawValue:)) }
        set { defaults?.set(newValue?.rawValue, forKey: storageKey) }
    }

    /// Set by tests to pin a language.
    static var override: Language?

    /// Read afresh every time, since widgets and extensions live on after the user switches language in the app.
    static var current: Language {
        override ?? chosen ?? system
    }
}

/// A text to translate. Interpolated values become `%@` in the lookup key and are filled in afterwards,
/// and a literal `%` is doubled, so the key matches what `scripts/check_translations.py` finds in the source.
struct LocalizedKey: ExpressibleByStringInterpolation {
    struct StringInterpolation: StringInterpolationProtocol {
        var key = ""
        var arguments: [String] = []

        init(literalCapacity: Int, interpolationCount: Int) {
            key.reserveCapacity(literalCapacity)
        }

        mutating func appendLiteral(_ literal: String) {
            key += literal.replacingOccurrences(of: "%", with: "%%")
        }

        mutating func appendInterpolation<Value>(_ value: Value) {
            key += "%@"
            arguments.append(String(describing: value))
        }
    }

    let key: String
    let arguments: [String]

    init(stringLiteral value: String) {
        key = value.replacingOccurrences(of: "%", with: "%%")
        arguments = []
    }

    init(stringInterpolation: StringInterpolation) {
        key = stringInterpolation.key
        arguments = stringInterpolation.arguments
    }
}

/// The text in the current language. Swedish texts are their own keys.
func L(_ text: LocalizedKey) -> String {
    let template = Language.current == .sv ? text.key : (Translations.english[text.key] ?? text.key)
    return Translations.fill(template, with: text.arguments)
}

enum Translations {
    /// Replaces `%@` with the arguments in order, `%1$@` with a given one, and `%%` with `%`.
    static func fill(_ template: String, with arguments: [String]) -> String {
        var result = ""
        var next = 0
        var index = template.startIndex
        while index < template.endIndex {
            let character = template[index]
            guard character == "%" else {
                result.append(character)
                index = template.index(after: index)
                continue
            }
            let rest = template[template.index(after: index)...]
            if rest.hasPrefix("%") {
                result.append("%")
                index = template.index(index, offsetBy: 2)
            } else if rest.hasPrefix("@") {
                result += next < arguments.count ? arguments[next] : ""
                next += 1
                index = template.index(index, offsetBy: 2)
            } else if let dollar = rest.firstIndex(of: "$"),
                      let position = Int(rest[rest.startIndex..<dollar]),
                      rest[rest.index(after: dollar)...].hasPrefix("@") {
                result += position - 1 < arguments.count && position > 0 ? arguments[position - 1] : ""
                index = template.index(dollar, offsetBy: 2)
            } else {
                result.append(character)
                index = template.index(after: index)
            }
        }
        return result
    }
}
