import AuthenticationServices
import SwiftUI

/// First launch: Pip asks a few questions in a chat, shows what the scrolling costs, offers an account,
/// shows what Paus does and lets the user pick a league nickname.
/// The cross at the top skips everything that is left, without an account.
struct IntroView: View {
    @Environment(AppModel.self) private var model
    @State private var step: Step = .hello
    @State private var answers = IntroAnswers()
    @State private var nickname = ""
    @State private var suggestions = Nickname.suggestions(count: 3, seed: Int.random(in: 0..<1_000_000))
    @FocusState private var isTyping: Bool

    enum Step: Int, CaseIterable {
        case hello, name, age, hours, apps, goals, calculating, reveal, account, tour, nickname
    }

    private let appChoices = ["TikTok", "Instagram", "YouTube", "Snapchat", "X", "Reddit", "Netflix", "Spel", "Nyheter"]
    private let goalChoices = ["Plugga", "Träna", "Sova mer", "Umgås med vänner", "Familjen", "Skapa något", "Läsa", "Jobba på en idé"]

    var body: some View {
        VStack(spacing: 0) {
            topBar
            content
                .id(step)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .screenBackground()
        .animation(.spring(duration: 0.5), value: step)
    }

    private var topBar: some View {
        HStack(spacing: 14) {
            GradientBar(fraction: Double(step.rawValue + 1) / Double(Step.allCases.count), height: 6)
            Button {
                finish()
            } label: {
                Image(systemName: "xmark")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .frame(width: 36, height: 36)
                    .background(Theme.cardRaised, in: Circle())
            }
            .accessibilityLabel("Hoppa över introduktionen")
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case .hello:
            ChatStep(mood: .happy, lines: [
                "Hej! Jag är **Pip** 👋",
                "Jag hjälper dig att ta tillbaka tiden som mobilen äter upp.",
                "Får jag ställa några snabba frågor först?",
            ]) {
                Button("Kör!") { step = .name }
                    .buttonStyle(GlowButtonStyle())
            }

        case .name:
            ChatStep(mood: .happy, lines: ["Vad heter du?"]) {
                TextField("Ditt förnamn", text: $answers.name)
                    .font(.title2.weight(.semibold))
                    .textContentType(.givenName)
                    .submitLabel(.next)
                    .focused($isTyping)
                    .padding(16)
                    .background(Theme.cardRaised, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .onSubmit { submitName() }
                    .onAppear { isTyping = true }
                Text("Bara jag använder det. Det syns aldrig för någon annan.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button("Fortsätt") { submitName() }
                    .buttonStyle(GlowButtonStyle())
                    .disabled(trimmedName.isEmpty)
            }

        case .age:
            ChatStep(mood: .hyped, lines: ["Kul att träffas, \(trimmedName)! 🎉", "Hur gammal är du?"]) {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(AgeGroup.allCases) { group in
                        ChoiceChip(title: group.label, isSelected: answers.ageGroup == group) {
                            answers.ageGroup = group
                            step = .hours
                        }
                    }
                }
            }

        case .hours:
            ChatStep(mood: .happy, lines: [
                "Hur länge är du på mobilen en vanlig dag?",
                "Gissa på ett ungefär. Det exakta svaret finns under **Inställningar → Skärmtid**.",
            ]) {
                VStack(spacing: 16) {
                    Text(Self.hours(answers.hoursPerDay))
                        .font(.system(size: 56, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Theme.brand)
                        .contentTransition(.numericText(value: answers.hoursPerDay))
                        .animation(.snappy, value: answers.hoursPerDay)
                    Slider(value: $answers.hoursPerDay, in: 0.5...12, step: 0.5)
                        .tint(Theme.pink)
                        .sensoryFeedback(.selection, trigger: answers.hoursPerDay)
                        .accessibilityLabel("Timmar per dag")
                        .accessibilityValue(Self.hours(answers.hoursPerDay))
                    Button("Fortsätt") { step = .apps }
                        .buttonStyle(GlowButtonStyle())
                }
            }

        case .apps:
            ChatStep(mood: .happy, lines: ["Vilka appar tar mest tid?", "Välj så många du vill."]) {
                VStack(spacing: 16) {
                    ChoiceGrid(choices: appChoices, selected: $answers.apps)
                    Button("Fortsätt") { step = .goals }
                        .buttonStyle(GlowButtonStyle())
                }
            }

        case .goals:
            ChatStep(mood: .happy, lines: ["Och om du fick tillbaka tiden…", "Vad skulle du hellre göra?"]) {
                VStack(spacing: 16) {
                    ChoiceGrid(choices: goalChoices, selected: $answers.goals)
                    Button("Fortsätt") { step = .calculating }
                        .buttonStyle(GlowButtonStyle())
                }
            }

        case .calculating:
            CalculatingStep { step = .reveal }

        case .reveal:
            ChatStep(mood: .sad, lines: [
                "Okej… jag har räknat.",
                "Med **\(Self.hours(answers.hoursPerDay)) om dagen** lägger du resten av livet…",
            ]) {
                RevealCard(answers: answers)
                Button("Det vill jag ändra") { step = .account }
                    .buttonStyle(GlowButtonStyle())
            }

        case .account:
            ChatStep(mood: .happy, lines: [
                "Bra, \(trimmedName). Då kör vi!",
                "Skapa ett konto så kommer jag ihåg dig och vad du vill uppnå.",
            ]) {
                SignInWithAppleButton(.signUp) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    if model.signIn(result) {
                        step = .tour
                    }
                }
                .signInWithAppleButtonStyle(.white)
                .frame(height: 54)
                .clipShape(Capsule())
                Button("Inte nu") { step = .tour }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

        case .tour:
            ChatStep(mood: .hyped, lines: [
                "Men det är inte kört!",
                "Halverar du tiden får du tillbaka **\(Self.years(halvedYears))** – till att \(goalText).",
                "Så här gör vi det tillsammans:",
            ]) {
                TourList(items: [
                    TourItem(symbol: "shield.lefthalf.filled", title: "Jag vaktar dina appar", text: "Jag säger nej till \(appText) när du har bestämt det."),
                    TourItem(symbol: "scope", title: "Fokuspass", text: "Blockera allt med ett tryck och få XP för varje minut."),
                    TourItem(symbol: "heart.fill", title: "Jag mår som du scrollar", text: "Pauser och scroll gör mig ledsen. Fokus gör mig glad."),
                    TourItem(symbol: "chart.bar.fill", title: "Din skärmtid", text: "Se dagen och veckan, och hur mycket du vinner tillbaka."),
                    TourItem(symbol: "flag.checkered", title: "Ligor varje vecka", text: "Tävla mot andra som också vill scrolla mindre."),
                ])
                Button("Låter bra!") { step = .nickname }
                    .buttonStyle(GlowButtonStyle())
            }

        case .nickname:
            ChatStep(mood: .happy, lines: [
                "Sist: välj ett smeknamn för ligan.",
                "Det syns för andra, så använd inte ditt riktiga namn.",
            ]) {
                TextField("Smeknamn", text: $nickname)
                    .font(.title2.weight(.semibold))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .padding(16)
                    .background(Theme.cardRaised, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .onSubmit { submitNickname() }
                HStack(spacing: 8) {
                    ForEach(suggestions, id: \.self) { suggestion in
                        Button(suggestion) { nickname = suggestion }
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(Theme.cardRaised, in: Capsule())
                            .foregroundStyle(.white)
                    }
                    Button {
                        suggestions = Nickname.suggestions(count: 3, seed: Int.random(in: 0..<1_000_000))
                    } label: {
                        Image(systemName: "shuffle")
                            .font(.caption.weight(.bold))
                            .padding(8)
                            .background(Theme.cardRaised, in: Circle())
                            .foregroundStyle(.white)
                    }
                    .accessibilityLabel("Nya förslag")
                }
                if let problem = Nickname.problem(with: nickname), !nickname.isEmpty {
                    Text(NicknameSheet.message(for: problem))
                        .font(.footnote)
                        .foregroundStyle(Theme.pink)
                }
                Button("Klar!") { submitNickname() }
                    .buttonStyle(GlowButtonStyle())
                    .disabled(Nickname.problem(with: nickname) != nil)
                Button("Hoppa över ligan") { finish() }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var trimmedName: String {
        answers.name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func submitName() {
        guard !trimmedName.isEmpty else { return }
        answers.name = trimmedName
        isTyping = false
        step = .age
    }

    private func submitNickname() {
        guard Nickname.problem(with: nickname) == nil else { return }
        model.league.setNickname(nickname)
        finish()
        Task { await model.syncLeague(force: true) }
    }

    /// Ends the intro. Answers are only kept once the user has started giving them.
    private func finish() {
        model.finishIntro(answers: step.rawValue > Step.name.rawValue ? answers : nil)
    }

    private var halvedYears: Double {
        LifeMath.wakingYears(hoursPerDay: answers.hoursPerDay, age: answers.ageGroup.typicalAge) / 2
    }

    private var goalText: String {
        guard !answers.goals.isEmpty else { return "leva livet" }
        return Self.list(answers.goals.map { $0.lowercased() })
    }

    private var appText: String {
        answers.apps.isEmpty ? "apparna som stjäl din tid" : Self.list(answers.apps)
    }

    /// "a", "a och b", "a, b och c".
    static func list(_ items: [String]) -> String {
        guard items.count > 1, let last = items.last else { return items.first ?? "" }
        return items.dropLast().joined(separator: ", ") + " och " + last
    }

    static func hours(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...1))) + " h"
    }

    static func years(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(1))) + " år"
    }
}

// MARK: - Chat

/// Pip, then Pip's lines appearing one by one as if typed, then the answer controls.
private struct ChatStep<Actions: View>: View {
    let mood: MascotMood
    let lines: [String]
    let actions: Actions

    @State private var shownLines = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(mood: MascotMood, lines: [String], @ViewBuilder actions: () -> Actions) {
        self.mood = mood
        self.lines = lines
        self.actions = actions()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                MascotView(mood: mood, level: 1, size: 120)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)

                ForEach(Array(lines.prefix(shownLines).enumerated()), id: \.offset) { _, line in
                    ChatBubble(text: line)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                if shownLines < lines.count {
                    TypingBubble()
                }

                if shownLines == lines.count {
                    VStack(spacing: 16) {
                        actions
                    }
                    .padding(.top, 14)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .scrollBounceBehavior(.basedOnSize)
        .sensoryFeedback(.impact(weight: .light), trigger: shownLines)
        .task {
            for (index, line) in lines.enumerated() {
                // Longer lines take longer to "type".
                let delay = reduceMotion ? 100 : min(1400, 350 + line.count * 18)
                try? await Task.sleep(for: .milliseconds(delay))
                withAnimation(.spring(duration: 0.4)) { shownLines = index + 1 }
            }
        }
    }
}

private struct ChatBubble: View {
    let text: String

    var body: some View {
        Text((try? AttributedString(markdown: text)) ?? AttributedString(text))
            .font(.title3.weight(.medium))
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Theme.cardRaised, in: UnevenRoundedRectangle(
                topLeadingRadius: 6, bottomLeadingRadius: 22, bottomTrailingRadius: 22, topTrailingRadius: 22, style: .continuous
            ))
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct TypingBubble: View {
    var body: some View {
        TimelineView(.animation) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(Color.white.opacity(0.7))
                        .frame(width: 8, height: 8)
                        .offset(y: CGFloat(sin(time * 6 - Double(index) * 0.8)) * 3)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(Theme.cardRaised, in: Capsule())
        }
        .accessibilityLabel("Pip skriver")
    }
}

// MARK: - Answers

private struct ChoiceChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    isSelected ? AnyShapeStyle(Theme.glow) : AnyShapeStyle(Theme.cardRaised),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Theme.violet.opacity(isSelected ? 0 : 0.6), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isSelected)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Several choices that can each be turned on and off.
private struct ChoiceGrid: View {
    let choices: [String]
    @Binding var selected: [String]

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            ForEach(choices, id: \.self) { choice in
                ChoiceChip(title: choice, isSelected: selected.contains(choice)) {
                    if let index = selected.firstIndex(of: choice) {
                        selected.remove(at: index)
                    } else {
                        selected.append(choice)
                    }
                }
            }
        }
    }
}

// MARK: - Calculating and reveal

private struct CalculatingStep: View {
    let onDone: () -> Void

    @State private var progress = 0.0
    @State private var message = 0
    private let messages = ["Räknar dina timmar…", "Lägger ihop resten av livet…", "Jämför med dina vakna år…"]

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            ZStack {
                Circle().stroke(Color.white.opacity(0.1), lineWidth: 12)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Theme.glow, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                MascotView(mood: .zen, level: 1, size: 120)
            }
            .frame(width: 190, height: 190)
            Text(messages[message])
                .font(.title3.weight(.semibold))
                .contentTransition(.opacity)
                .id(message)
            Spacer()
            Spacer()
        }
        .padding(20)
        .task {
            withAnimation(.easeInOut(duration: 2.7)) { progress = 1 }
            for index in 1..<messages.count {
                try? await Task.sleep(for: .milliseconds(900))
                withAnimation { message = index }
            }
            try? await Task.sleep(for: .milliseconds(1000))
            onDone()
        }
    }
}

private struct RevealCard: View {
    let answers: IntroAnswers
    @State private var shownYears = 0.0

    private var years: Double {
        LifeMath.wakingYears(hoursPerDay: answers.hoursPerDay, age: answers.ageGroup.typicalAge)
    }

    var body: some View {
        VStack(spacing: 14) {
            CountingYears(value: shownYears)
                .font(.system(size: 64, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Theme.brand)
            Text("av ditt vakna liv på mobilen.")
                .font(.title3.weight(.semibold))
            HStack(spacing: 10) {
                RevealStat(value: "\(LifeMath.hoursPerYear(hoursPerDay: answers.hoursPerDay)) h", label: "varje år")
                RevealStat(value: "\(Int((LifeMath.shareOfWakingTime(hoursPerDay: answers.hoursPerDay) * 100).rounded())) %", label: "av varje vaken dag")
            }
            Text("Räknat på 16 vakna timmar om dagen fram till 80 års ålder.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .card(highlighted: true)
        .sensoryFeedback(.impact(weight: .heavy), trigger: shownYears == years)
        .onAppear {
            withAnimation(.easeOut(duration: 1.8).delay(0.3)) { shownYears = years }
        }
        .accessibilityElement(children: .combine)
    }
}

/// A number of years that counts up when it changes.
private struct CountingYears: View, Animatable {
    var value: Double

    var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    var body: some View {
        Text(IntroView.years(value))
    }
}

private struct RevealStat: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline.monospacedDigit())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Theme.cardRaised, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct TourItem: Identifiable {
    let symbol: String
    let title: String
    let text: String
    var id: String { title }
}

/// What Paus does, one card at a time, each with its icon popping in.
private struct TourList: View {
    let items: [TourItem]
    @State private var shown = 0

    var body: some View {
        VStack(spacing: 10) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                HStack(spacing: 14) {
                    Image(systemName: item.symbol)
                        .font(.title3)
                        .foregroundStyle(.white)
                        .frame(width: 46, height: 46)
                        .background(Theme.glow, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .symbolEffect(.bounce, value: shown > index)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title)
                            .font(.headline)
                        Text(item.text)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                .padding(14)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                }
                .opacity(shown > index ? 1 : 0)
                .offset(x: shown > index ? 0 : 60)
                .scaleEffect(shown > index ? 1 : 0.9)
                .accessibilityElement(children: .combine)
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: shown)
        .task {
            for index in items.indices {
                try? await Task.sleep(for: .milliseconds(index == 0 ? 150 : 380))
                withAnimation(.spring(duration: 0.5, bounce: 0.35)) { shown = index + 1 }
            }
        }
    }
}

#Preview {
    IntroView()
        .environment(AppModel())
        .preferredColorScheme(.dark)
}
