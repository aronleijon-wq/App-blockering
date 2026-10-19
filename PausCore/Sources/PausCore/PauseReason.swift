import Foundation

/// Why the user wants to open a blocked app. Asking makes the pause a choice instead of a reflex.
enum PauseReason: String, CaseIterable, Identifiable {
    case message, specific, bored, habit, stressed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .message: return "Svara på ett meddelande"
        case .specific: return "Kolla något specifikt"
        case .bored: return "Jag har tråkigt"
        case .habit: return "Vet inte, det är en vana"
        case .stressed: return "Jag är stressad och vill fly"
        }
    }

    var symbol: String {
        switch self {
        case .message: return "bubble.left.and.bubble.right.fill"
        case .specific: return "magnifyingglass"
        case .bored: return "cloud.drizzle.fill"
        case .habit: return "arrow.triangle.2.circlepath"
        case .stressed: return "bolt.heart.fill"
        }
    }

    /// Pip's answer to the reason.
    var reply: String {
        switch self {
        case .message:
            return "Okej! Svara på meddelandet och stäng sedan. Fem minuter räcker gott."
        case .specific:
            return "Bra att du vet vad du letar efter. Hitta det och gå sedan ut direkt."
        case .bored:
            return "Tristess brukar gå över på några minuter. En kort promenad eller ett glas vatten kanske?"
        case .habit:
            return "Fingrarna tog dig hit på autopilot. Det är precis det vi tränar bort. Du behöver nog inte appen just nu."
        case .stressed:
            return "Scrollande dämpar stressen en kort stund men brukar göra den värre efteråt. Andas med mig först."
        }
    }

    /// Reasons where Pip nudges harder toward saying no.
    var isImpulse: Bool {
        switch self {
        case .bored, .habit, .stressed: return true
        case .message, .specific: return false
        }
    }
}

/// Questions shown while breathing before a pause.
enum ReflectionQuestions {
    static let all = [
        "Hur vill du känna dig om 30 minuter?",
        "Vad skulle framtida du vilja att du gör nu?",
        "Är det här värt mer än dina poäng?",
        "Vad hade du tänkt göra innan du tog upp mobilen?",
        "Kommer du minnas det här scrollandet i morgon?",
        "Vad är en sak du kan göra i stället de närmaste fem minuterna?",
    ]

    /// The question to show `seconds` into the breathing, changing every few seconds.
    static func question(at seconds: Double, offset: Int) -> String {
        all[(Int(seconds / 6) + offset) % all.count]
    }
}
