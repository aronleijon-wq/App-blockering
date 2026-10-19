import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// What Pip says. Pro users get a fresh line from Apple's on-device model where it is available;
/// everyone else, and every device without it, gets a handwritten line.
enum Coach {
    static func message(mood: MascotMood, progress: PlayerProgress, isPro: Bool, at date: Date) async -> String {
        if isPro, let generated = await generatedMessage(mood: mood, progress: progress, at: date) {
            return generated
        }
        return fallbackMessage(mood: mood, progress: progress, at: date)
    }

    static func fallbackMessage(mood: MascotMood, progress: PlayerProgress, at date: Date) -> String {
        let streak = progress.currentStreak(at: date, calendar: .current)
        let options: [String]
        switch mood {
        case .zen:
            options = ["Andas. Du är i flow just nu.", "Telefonen kan vänta. Det här kan inte.", "Fokusläge på. Jag håller koll åt dig."]
        case .sleepy:
            options = ["Det är sent… sociala medier sover också.", "Lägg undan mobilen, så ses vi i morgon.", "Zzz… din hjärna tackar dig för sömnen."]
        case .sad:
            options = ["Det är okej. I morgon är en ny dag.", "Alla behöver en paus ibland. Vi kör igen snart.", "Jag tror på dig, även idag."]
        case .proud:
            options = ["Alla uppdrag klara! Du är grym.", "Full pott idag. Kolla på dig!", "Det här är din bästa version."]
        case .hyped:
            options = ["\(streak) dagar i rad! Bryt inte kedjan nu.", "Du är on fire. \(streak) dagar och räknar.", "Streak på \(streak) dagar – jag växer av det här!"]
        case .happy:
            options = ["Redo att ta tillbaka lite tid idag?", "Ett fokuspass om dagen håller scrollet borta.", "Jag blir starkare varje gång du stänger TikTok."]
        }
        let day = Calendar.current.ordinality(of: .day, in: .era, for: date) ?? 0
        return options[day % options.count]
    }

    private static func generatedMessage(mood: MascotMood, progress: PlayerProgress, at date: Date) async -> String? {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            guard SystemLanguageModel.default.isAvailable else { return nil }
            let counts = progress.counts(at: date, calendar: .current)
            let session = LanguageModelSession(instructions: """
                Du är Pip, en gullig och peppig maskot i en app som hjälper unga att scrolla mindre på sociala medier. \
                Svara alltid på svenska med en enda kort mening, högst 14 ord. Inga emojis och inga citattecken.
                """)
            let prompt = """
                Skriv ett personligt peppmeddelande till användaren. Ditt humör: \(mood.label). \
                Streak: \(progress.currentStreak(at: date, calendar: .current)) dagar. Nivå: \(progress.level). \
                Fokusminuter idag: \(counts.focusMinutes). Gånger användaren stängt en blockerad app idag: \(counts.closes).
                """
            do {
                let response = try await session.respond(to: prompt)
                let text = response.content.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: "\"”")))
                return text.isEmpty ? nil : text
            } catch {
                return nil
            }
        }
        #endif
        return nil
    }
}
