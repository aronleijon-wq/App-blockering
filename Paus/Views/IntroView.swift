import AuthenticationServices
import SwiftUI
import UserNotifications

/// First launch: Pip asks a few questions in a chat, shows what the scrolling costs, offers an account,
/// shows what Paus does and lets the user pick a league nickname.
/// The cross at the top skips everything that is left, without an account.
struct IntroView: View {
    @Environment(AppModel.self) private var model
    @State private var step: Step = Language.chosen == nil ? .language : .hello
    @State private var answers = IntroAnswers()
    @State private var nickname = ""
    @State private var suggestions = Nickname.suggestions(count: 3, seed: Int.random(in: 0..<1_000_000))
    @FocusState private var isTyping: Bool
    @State private var isPaywallPresented = false

    enum Step: Int, CaseIterable {
        case language, hello, name, age, hours, apps, goals, calculating, reveal, plan, account, tour, nickname, friends, trial
    }

    private let appChoices = ["TikTok", "Instagram", "YouTube", "Snapchat", "X", "Reddit", "Netflix", L("Spel"), L("Nyheter"), Self.other]
    private let goalChoices = [L("Plugga"), L("Träna"), L("Sova mer"), L("Umgås med vänner"), L("Familjen"), L("Skapa något"), L("Läsa"), L("Jobba på en idé"), Self.other]
    /// The last choice in both lists, for anything not listed. It names nothing, so Pip leaves it out of sentences.
    private static var other: String { L("Annat") }

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
            .accessibilityLabel(L("Hoppa över introduktionen"))
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case .language:
            LanguageStep { language in
                model.setLanguage(language)
                step = .hello
            }

        case .hello:
            ChatStep(mood: .happy, lines: [
                L("Hej! Jag är **Pip** 👋"),
                L("Jag hjälper dig att ta tillbaka tiden som mobilen äter upp."),
                L("Får jag ställa några snabba frågor först?"),
            ]) {
                Button(L("Kör!")) { step = .name }
                    .buttonStyle(GlowButtonStyle())
            }

        case .name:
            ChatStep(mood: .happy, lines: [L("Vad heter du?")]) {
                TextField(L("Ditt förnamn"), text: $answers.name)
                    .font(.title2.weight(.semibold))
                    .textContentType(.givenName)
                    .submitLabel(.next)
                    .focused($isTyping)
                    .padding(16)
                    .background(Theme.cardRaised, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .onSubmit { submitName() }
                    .onAppear { isTyping = true }
                Text(L("Bara jag använder det. Det syns aldrig för någon annan."))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button(L("Fortsätt")) { submitName() }
                    .buttonStyle(GlowButtonStyle())
                    .disabled(trimmedName.isEmpty)
            }

        case .age:
            ChatStep(mood: .hyped, lines: [L("Kul att träffas, \(trimmedName)! 🎉"), L("Hur gammal är du?")]) {
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
                L("Hur länge är du på mobilen en vanlig dag?"),
                L("Gissa på ett ungefär. Det exakta svaret finns under **Inställningar → Skärmtid**."),
            ]) {
                VStack(spacing: 16) {
                    Text(Self.hours(answers.hoursPerDay))
                        .font(.system(size: 56, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Theme.brand)
                        .contentTransition(.numericText(value: answers.hoursPerDay))
                        .animation(.snappy, value: answers.hoursPerDay)
                    Slider(value: $answers.hoursPerDay, in: 0.5...Self.maxHours, step: 0.5)
                        .tint(Theme.pink)
                        .sensoryFeedback(.selection, trigger: answers.hoursPerDay)
                        .accessibilityLabel(L("Timmar per dag"))
                        .accessibilityValue(Self.hours(answers.hoursPerDay))
                    Button(L("Fortsätt")) { step = .apps }
                        .buttonStyle(GlowButtonStyle())
                }
            }

        case .apps:
            ChatStep(mood: .happy, lines: [L("Vilka appar tar mest tid?"), L("Välj så många du vill.")]) {
                VStack(spacing: 16) {
                    ChoiceGrid(choices: appChoices, selected: $answers.apps)
                    Button(L("Fortsätt")) { step = .goals }
                        .buttonStyle(GlowButtonStyle())
                }
            }

        case .goals:
            ChatStep(mood: .happy, lines: [L("Och om du fick tillbaka tiden…"), L("Vad skulle du hellre göra?")]) {
                VStack(spacing: 16) {
                    ChoiceGrid(choices: goalChoices, selected: $answers.goals)
                    Button(L("Fortsätt")) { step = .calculating }
                        .buttonStyle(GlowButtonStyle())
                }
            }

        case .calculating:
            CalculatingStep { step = .reveal }

        case .reveal:
            ChatStep(mood: .sad, lines: [
                L("Okej… jag har räknat."),
                L("Med **\(Self.hours(answers.hoursPerDay)) om dagen** lägger du resten av livet…"),
            ]) {
                RevealCard(answers: answers)
                Button(L("Det vill jag ändra")) { step = .plan }
                    .buttonStyle(GlowButtonStyle())
            }

        case .plan:
            PlanStep(answers: answers, goalText: goalText) { step = .account }

        case .account:
            ChatStep(mood: .happy, lines: [
                L("Bra, \(trimmedName). Då kör vi!"),
                L("Skapa ett konto så kommer jag ihåg dig och vad du vill uppnå."),
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
                Button(L("Inte nu")) { step = .tour }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

        case .tour:
            ChatStep(mood: .hyped, lines: [L("Så här hjälper jag dig att klara det:")]) {
                TourList(items: [
                    TourItem(symbol: "shield.lefthalf.filled", title: L("Jag vaktar dina appar"), text: L("Jag säger nej till \(appText) när du har bestämt det.")),
                    TourItem(symbol: "scope", title: L("Fokuspass"), text: L("Blockera allt med ett tryck och få XP för varje minut.")),
                    TourItem(symbol: "heart.fill", title: L("Jag mår som du scrollar"), text: L("Pauser och scroll gör mig ledsen. Fokus gör mig glad.")),
                    TourItem(symbol: "chart.bar.fill", title: L("Din skärmtid"), text: L("Se dagen och veckan, och hur mycket du vinner tillbaka.")),
                    TourItem(symbol: "flag.checkered", title: L("Ligor varje vecka"), text: L("Tävla mot andra som också vill scrolla mindre.")),
                ])
                Button(L("Låter bra!")) { step = .nickname }
                    .buttonStyle(GlowButtonStyle())
            }

        case .nickname:
            ChatStep(mood: .happy, lines: [
                L("Sist: välj ett smeknamn för ligan."),
                L("Det syns för andra, så använd inte ditt riktiga namn."),
            ]) {
                TextField(L("Smeknamn"), text: $nickname)
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
                    .accessibilityLabel(L("Nya förslag"))
                }
                if let problem = Nickname.problem(with: nickname), !nickname.isEmpty {
                    Text(NicknameSheet.message(for: problem))
                        .font(.footnote)
                        .foregroundStyle(Theme.pink)
                }
                Button(L("Klar!")) { submitNickname() }
                    .buttonStyle(GlowButtonStyle())
                    .disabled(Nickname.problem(with: nickname) != nil)
                Button(L("Hoppa över ligan")) { step = .friends }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

        case .friends:
            ChatStep(mood: .hyped, lines: [
                L("Allt är roligare tillsammans! 🏆"),
                L("Utmana dina vänner. Den som scrollar minst vinner veckan."),
            ]) {
                InviteCard(nickname: model.league.nickname)
                ShareLink(
                    item: AppInfo.inviteURL,
                    subject: Text(L("Utmana mig i Paus")),
                    message: Text(AppInfo.inviteMessage(nickname: model.league.nickname))
                ) {
                    Label(L("Bjud in vänner"), systemImage: "square.and.arrow.up")
                }
                .buttonStyle(GlowButtonStyle())
                Button(L("Fortsätt")) { goToTrial() }
                    .buttonStyle(ChipButtonStyle())
            }

        case .trial:
            TrialStep(name: trimmedName) { isPaywallPresented = true }
                // Whether the user starts the free week or not, the intro is over once the offer closes.
                .sheet(isPresented: $isPaywallPresented, onDismiss: finish) {
                    PaywallView()
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
        Task { await model.syncLeague(force: true) }
        step = .friends
    }

    /// Offers the free week, unless the user already has Pro.
    private func goToTrial() {
        if model.isPro {
            finish()
        } else {
            step = .trial
        }
    }

    /// Ends the intro. Answers are only kept once the user has started giving them.
    private func finish() {
        model.finishIntro(answers: step.rawValue > Step.name.rawValue ? answers : nil)
    }

    private var goalText: String {
        let goals = answers.goals.filter { $0 != Self.other }
        guard !goals.isEmpty else { return L("leva livet") }
        return Self.list(goals.map { $0.lowercased() })
    }

    private var appText: String {
        let apps = answers.apps.filter { $0 != Self.other }
        return apps.isEmpty ? L("apparna som stjäl din tid") : Self.list(apps)
    }

    /// "a", "a och b", "a, b och c".
    static func list(_ items: [String]) -> String {
        guard items.count > 1, let last = items.last else { return items.first ?? "" }
        return items.dropLast().joined(separator: ", ") + L(" och ") + last
    }

    /// The most the screen time slider goes to; it reads "12+ h" there.
    static let maxHours = 12.0

    static func hours(_ value: Double) -> String {
        let number = value.formatted(.number.precision(.fractionLength(0...1)).locale(Language.current.locale))
        return value >= maxHours ? number + "+ h" : number + " h"
    }

    static func years(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(1)).locale(Language.current.locale)) + L(" år")
    }
}

// MARK: - Language

/// The very first question, asked in both languages.
private struct LanguageStep: View {
    let onChoose: (Language) -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            MascotView(mood: .happy, level: 1, size: 140)
            VStack(spacing: 6) {
                Text("Välj språk")
                Text("Choose your language")
                    .foregroundStyle(.secondary)
            }
            .font(.title2.bold())
            .multilineTextAlignment(.center)
            VStack(spacing: 12) {
                // The phone's language first.
                ForEach([Language.system] + Language.allCases.filter { $0 != Language.system }) { language in
                    Button {
                        onChoose(language)
                    } label: {
                        HStack(spacing: 14) {
                            Text(language.flag)
                                .font(.largeTitle)
                            Text(language.nativeName)
                                .font(.title3.bold())
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                        }
                        .foregroundStyle(.white)
                        .padding(18)
                        .background(Theme.cardRaised, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .strokeBorder(language == Language.system ? AnyShapeStyle(Theme.glow) : AnyShapeStyle(Color.white.opacity(0.1)), lineWidth: 1.5)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 20)
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

/// Text with **bold** parts, as the translations write them.
func markdown(_ text: String) -> AttributedString {
    (try? AttributedString(markdown: text)) ?? AttributedString(text)
}

private struct ChatBubble: View {
    let text: String

    var body: some View {
        Text(markdown(text))
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
        .accessibilityLabel(L("Pip skriver"))
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
    private let messages = [L("Räknar dina timmar…"), L("Lägger ihop resten av livet…"), L("Jämför med dina vakna år…")]

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
            Text(L("av ditt vakna liv på mobilen."))
                .font(.title3.weight(.semibold))
            HStack(spacing: 10) {
                RevealStat(value: "\(LifeMath.hoursPerYear(hoursPerDay: answers.hoursPerDay)) h", label: L("varje år"))
                RevealStat(value: "\(Int((LifeMath.shareOfWakingTime(hoursPerDay: answers.hoursPerDay) * 100).rounded())) %", label: L("av varje vaken dag"))
            }
            Text(L("Räknat på 16 vakna timmar om dagen fram till 80 års ålder."))
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

// MARK: - Friends

/// Pip and a few friendly faces racing up the board.
private struct InviteCard: View {
    let nickname: String?
    @State private var isRaised = false

    var body: some View {
        VStack(spacing: 14) {
            HStack(alignment: .bottom, spacing: 18) {
                podium(height: 52, mood: .happy, place: "2")
                podium(height: 76, mood: .hyped, place: "1")
                podium(height: 38, mood: .sleepy, place: "3")
            }
            Text(markdown(nickname.map { L("Dina vänner hittar dig som **\($0)**.") } ?? L("Dina vänner kan gå med i samma liga.")))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .card(highlighted: true)
        .onAppear {
            withAnimation(.spring(duration: 0.8, bounce: 0.4).delay(0.2)) { isRaised = true }
        }
    }

    private func podium(height: CGFloat, mood: MascotMood, place: String) -> some View {
        VStack(spacing: 6) {
            MascotView(mood: mood, level: place == "1" ? 8 : 3, size: 54)
            Text(place)
                .font(.title3.weight(.heavy))
                .frame(width: 64, height: isRaised ? height : 0)
                .background(Theme.glow, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .clipped()
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Plan

/// The promise: what a 30 % cut gives back, sealed with a fist bump.
private struct PlanStep: View {
    let answers: IntroAnswers
    let goalText: String
    let onDone: () -> Void

    @State private var shownYears = 0.0
    @State private var shownRows = 0
    @State private var isBumping = false

    private var years: Double {
        Plan.yearsBack(hoursPerDay: answers.hoursPerDay, age: answers.ageGroup.typicalAge)
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 28) {
                    VStack(spacing: 6) {
                        if !answers.name.isEmpty {
                            Text("\(answers.name),")
                        }
                        Text(L("Paus ger dig tillbaka"))
                        HStack(spacing: 8) {
                            CountingYears(value: shownYears)
                                .foregroundStyle(Theme.brand)
                            Text(L("av ditt liv"))
                        }
                    }
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .multilineTextAlignment(.center)
                    .monospacedDigit()
                    .padding(.top, 24)

                    VStack(alignment: .leading, spacing: 22) {
                        PlanRow(
                            symbol: "lock.shield.fill",
                            title: L("30 % mindre skärmtid"),
                            text: L("Från \(IntroView.hours(answers.hoursPerDay)) till **\(IntroView.hours(Plan.targetHours(from: answers.hoursPerDay)))** om dagen.")
                        )
                        .planReveal(index: 0, shown: shownRows)
                        PlanRow(
                            symbol: "tree.fill",
                            title: L("Mer tid utanför skärmen"),
                            text: L("**\(Int((Plan.offlineIncrease(hoursPerDay: answers.hoursPerDay) * 100).rounded())) %** mer vaken tid offline, till att \(goalText).")
                        )
                        .planReveal(index: 1, shown: shownRows)
                        PlanRow(
                            symbol: "calendar.badge.clock",
                            title: L("\(Plan.daysBackPerYear(hoursPerDay: answers.hoursPerDay)) dygn tillbaka i år"),
                            text: L("Med fokuspass, scheman och Pip som vaktar.")
                        )
                        .planReveal(index: 2, shown: shownRows)
                    }
                    .padding(.horizontal, 4)
                }
                .padding(.horizontal, 20)
            }

            VStack(spacing: 12) {
                Text(L("Vi skakar hand på det"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button {
                    isBumping = true
                    Task {
                        try? await Task.sleep(for: .milliseconds(650))
                        onDone()
                    }
                } label: {
                    HStack(spacing: 10) {
                        Text("👊")
                            .font(.title)
                            .scaleEffect(isBumping ? 1.6 : 1)
                            .rotationEffect(.degrees(isBumping ? -20 : 0))
                        Text(L("Nu kör vi!"))
                    }
                }
                .buttonStyle(GlowButtonStyle())
                .disabled(isBumping)
                .sensoryFeedback(.impact(weight: .heavy, intensity: 1), trigger: isBumping)
                .animation(.spring(duration: 0.35, bounce: 0.6), value: isBumping)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .task {
            withAnimation(.easeOut(duration: 1.6)) { shownYears = years }
            for index in 0..<3 {
                try? await Task.sleep(for: .milliseconds(450))
                withAnimation(.spring(duration: 0.5, bounce: 0.3)) { shownRows = index + 1 }
            }
        }
    }
}

private struct PlanRow: View {
    let symbol: String
    let title: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: symbol)
                .font(.title)
                .foregroundStyle(LinearGradient(colors: [Theme.mint, Theme.violet], startPoint: .top, endPoint: .bottom))
                .frame(width: 40)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title3.bold())
                Text((try? AttributedString(markdown: text)) ?? AttributedString(text))
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private extension View {
    func planReveal(index: Int, shown: Int) -> some View {
        opacity(shown > index ? 1 : 0)
            .offset(y: shown > index ? 0 : 24)
    }
}

// MARK: - Trial

/// Lets the user pick when Pip reminds them before the free week ends, then shows the offer.
private struct TrialStep: View {
    let name: String
    let onContinue: () -> Void

    @State private var daysBefore = IntroStore.trialReminderDays

    private var trialEnd: Date {
        Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now
    }

    var body: some View {
        VStack(spacing: 20) {
            Text(L("När ska Pip påminna dig innan gratisveckan tar slut?"))
                .font(.title2.bold())
                .multilineTextAlignment(.center)
                .padding(.top, 16)

            NotificationPreview(daysBefore: daysBefore, trialEnd: trialEnd)

            Spacer(minLength: 0)

            VStack(spacing: 0) {
                ForEach(TrialReminder.choices, id: \.self) { days in
                    Button {
                        daysBefore = days
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(L("\(days) dagar innan"))
                                    .font(.headline)
                                Text(reminderDate(days).formatted(.dateTime.weekday(.wide).day().month(.wide).locale(Language.current.locale)))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: daysBefore == days ? "checkmark.circle.fill" : "circle")
                                .font(.title2)
                                .foregroundStyle(daysBefore == days ? Theme.mint : .secondary)
                        }
                        .padding(16)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .sensoryFeedback(.selection, trigger: daysBefore)
                    if days != TrialReminder.choices.last {
                        Divider().overlay(Color.white.opacity(0.08))
                    }
                }
            }
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))

            Button(L("Fortsätt")) {
                IntroStore.trialReminderDays = daysBefore
                Task {
                    // The reminder is a notification, so ask now, while it is clear why.
                    _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
                    onContinue()
                }
            }
            .buttonStyle(GlowButtonStyle())
            Text(L("Slå på notiser för att få påminnelsen. Ingen bindningstid, du säger upp när du vill."))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }

    private func reminderDate(_ days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -days, to: trialEnd) ?? trialEnd
    }
}

/// A lock screen with the reminder as it will look.
private struct NotificationPreview: View {
    let daysBefore: Int
    let trialEnd: Date

    var body: some View {
        VStack(spacing: 10) {
            Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(Language.current.locale)))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.7))
            Text("9:41")
                .font(.system(size: 64, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "pause.fill")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(Theme.glow, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(L("\(daysBefore) dagar kvar av din gratisvecka ⏳"))
                            .font(.subheadline.bold())
                        Spacer()
                        Text("nu")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(L("Säg upp före \(trialEnd.formatted(.dateTime.day().month(.wide).locale(Language.current.locale))) om du vill sluta."))
                        .font(.subheadline)
                }
                .contentTransition(.numericText())
            }
            .padding(14)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .animation(.snappy, value: daysBefore)
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 40, style: .continuous)
                .fill(LinearGradient(colors: [Theme.violet.opacity(0.5), Theme.card], startPoint: .top, endPoint: .bottom))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 40, style: .continuous)
                .strokeBorder(Color.white.opacity(0.15), lineWidth: 2)
        )
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    IntroView()
        .environment(AppModel())
        .preferredColorScheme(.dark)
}
