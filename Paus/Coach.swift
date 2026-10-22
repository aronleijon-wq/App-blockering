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
            options = [L("Andas. Du är i flow just nu."), L("Telefonen kan vänta. Det här kan inte."), L("Fokusläge på. Jag håller koll åt dig.")]
        case .sleepy:
            options = [L("Det är sent… sociala medier sover också."), L("Lägg undan mobilen, så ses vi i morgon."), L("Zzz… din hjärna tackar dig för sömnen.")]
        case .sad:
            options = [L("Det är okej. I morgon är en ny dag."), L("Alla behöver en paus ibland. Vi kör igen snart."), L("Jag tror på dig, även idag.")]
        case .crying:
            options = [L("Jag mår inte så bra… kan vi köra ett fokuspass ihop?"), L("Allt scrollande gör mig ledsen. Hjälp mig att må bättre?"), L("Säg nej till nästa paus, så piggnar jag till.")]
        case .wrecked:
            options = [L("Jag är helt scrollsjuk. Snälla, lägg undan mobilen en stund."), L("Mitt huvud snurrar av alla klipp… ett fokuspass skulle rädda mig."), L("Jag behöver dig nu. Varje nej gör mig lite friskare.")]
        case .proud:
            options = [L("Alla uppdrag klara! Du är grym."), L("Full pott idag. Kolla på dig!"), L("Det här är din bästa version.")]
        case .hyped:
            options = [L("\(streak) dagar i rad! Bryt inte kedjan nu."), L("Du är on fire. \(streak) dagar och räknar."), L("Streak på \(streak) dagar – jag växer av det här!")]
        case .happy:
            options = [L("Redo att ta tillbaka lite tid idag?"), L("Ett fokuspass om dagen håller scrollet borta."), L("Jag blir starkare varje gång du stänger TikTok.")]
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
                Svara alltid på \(Language.current == .sv ? "svenska" : "engelska") med en enda kort mening, högst 14 ord. \
                Inga emojis och inga citattecken.
                """)
            let prompt = """
                Skriv ett personligt peppmeddelande till användaren. Ditt humör: \(mood.label). \
                Din hälsa: \(progress.health) av 100. Är den låg, be användaren om hjälp att må bättre. \
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
