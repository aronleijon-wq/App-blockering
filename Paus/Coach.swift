import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// What Pip says. Pro users get a fresh line from Apple's on-device model where it is available;
/// everyone else, and every device without it, gets a handwritten line.
enum Coach {
    static func message(mood: MascotMood, progress: PlayerProgress, name: String?, isPro: Bool, at date: Date) async -> String {
        if isPro, let generated = await generatedMessage(mood: mood, progress: progress, name: name, at: date) {
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

    private static func generatedMessage(mood: MascotMood, progress: PlayerProgress, name: String?, at date: Date) async -> String? {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            guard SystemLanguageModel.default.isAvailable else { return nil }
            let counts = progress.counts(at: date, calendar: .current)
            let english = Language.current == .en
            let session = LanguageModelSession(instructions: english ? """
                You are Pip, a cute, upbeat mascot in an app that helps young people scroll less. \
                Write one to three short sentences in English, at most 50 words, to the user by name if you know it. \
                You may greet them. Never ask a question and never introduce yourself. Often include one concrete, practical tip for scrolling less, \
                said as a statement. This is a speech bubble, not a chat, so the user can't answer. \
                No emojis, no quotation marks.
                """ : """
                Du är Pip, en gullig och peppig maskot i en app som hjälper unga att scrolla mindre. \
                Skriv en till tre korta meningar på svenska, högst 50 ord, till användaren, gärna med namn om du vet det. \
                Du får hälsa. Ställ aldrig frågor och presentera dig aldrig. Ge ofta ett konkret, praktiskt tips för att scrolla mindre, \
                sagt som ett påstående. Det här är en pratbubbla, ingen chatt, så användaren kan inte svara. \
                Inga emojis och inga citattecken.
                """)
            let prompt = """
                \(name.map { "Name: \($0). " } ?? "")Mood: \(mood.label). Health: \(progress.health)/100 (if low, ask for help feeling better). \
                Streak: \(progress.currentStreak(at: date, calendar: .current)) days. Level: \(progress.level). \
                Focus minutes today: \(counts.focusMinutes). Blocked apps closed today: \(counts.closes).
                """
            do {
                let response = try await session.respond(to: prompt, options: GenerationOptions(maximumResponseTokens: 150))
                return PipLine.cleaned(response.content)
            } catch {
                return nil
            }
        }
        #endif
        return nil
    }
}
