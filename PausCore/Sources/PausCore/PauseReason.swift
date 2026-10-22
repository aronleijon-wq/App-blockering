import Foundation

/// Why the user wants to open a blocked app. Asking makes the pause a choice instead of a reflex.
enum PauseReason: String, CaseIterable, Identifiable {
    case message, specific, bored, habit, stressed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .message: return L("Svara på ett meddelande")
        case .specific: return L("Kolla något specifikt")
        case .bored: return L("Jag har tråkigt")
        case .habit: return L("Vet inte, det är en vana")
        case .stressed: return L("Jag är stressad och vill fly")
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
            return L("Okej! Svara på meddelandet och stäng sedan. Fem minuter räcker gott.")
        case .specific:
            return L("Bra att du vet vad du letar efter. Hitta det och gå sedan ut direkt.")
        case .bored:
            return L("Tristess brukar gå över på några minuter. En kort promenad eller ett glas vatten kanske?")
        case .habit:
            return L("Fingrarna tog dig hit på autopilot. Det är precis det vi tränar bort. Du behöver nog inte appen just nu.")
        case .stressed:
            return L("Scrollande dämpar stressen en kort stund men brukar göra den värre efteråt. Andas med mig först.")
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
    static var all: [String] { [
        L("Hur vill du känna dig om 30 minuter?"),
        L("Vad skulle framtida du vilja att du gör nu?"),
        L("Är det här värt mer än dina poäng?"),
        L("Vad hade du tänkt göra innan du tog upp mobilen?"),
        L("Kommer du minnas det här scrollandet i morgon?"),
        L("Vad är en sak du kan göra i stället de närmaste fem minuterna?"),
    ] }

    /// The question to show `seconds` into the breathing, changing every few seconds.
    static func question(at seconds: Double, offset: Int) -> String {
        all[(Int(seconds / 6) + offset) % all.count]
    }
}
