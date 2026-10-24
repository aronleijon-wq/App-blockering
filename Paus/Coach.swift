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
            let english = Language.current == .en
            let session = LanguageModelSession(instructions: english ? """
                You are Pip, a cute, upbeat mascot in an app that helps young people scroll less. \
                Write exactly one short sentence of at most 12 words, in English. \
                It is a line on the home screen, not a chat: never greet, never introduce yourself, never ask a question. \
                No emojis, no quotation marks. \
                Examples: "Three days in a row, keep the chain going." "I feel a bit weak, a focus session would help."
                """ : """
                Du är Pip, en gullig och peppig maskot i en app som hjälper unga att scrolla mindre. \
                Skriv exakt en kort mening på högst 12 ord, på svenska. \
                Det är en rad på hemskärmen, ingen chatt: hälsa aldrig, presentera dig aldrig och ställ aldrig frågor. \
                Inga emojis och inga citattecken. \
                Exempel: "Tre dagar i rad, bryt inte kedjan nu." "Jag känner mig svag, ett fokuspass skulle hjälpa."
                """)
            let prompt = """
                Mood: \(mood.label). Health: \(progress.health)/100 (if low, ask for help feeling better, without a question). \
                Streak: \(progress.currentStreak(at: date, calendar: .current)) days. Level: \(progress.level). \
                Focus minutes today: \(counts.focusMinutes). Blocked apps closed today: \(counts.closes).
                """
            do {
                let response = try await session.respond(to: prompt, options: GenerationOptions(maximumResponseTokens: 60))
                return PipLine.cleaned(response.content)
            } catch {
                return nil
            }
        }
        #endif
        return nil
    }
}
