import SwiftUI
import WidgetKit

/// How a Live Activity looks for each kind of block: its colors, Pip's mood and what Pip says.
struct ActivityLook {
    let colors: [Color]
    let mood: MascotMood
    let label: String
    let line: String
    /// XP the running focus session gives when it's done.
    var xp: Int?

    var gradient: LinearGradient {
        LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// The brighter color, for accents on the Dynamic Island's black.
    var accent: Color { colors[colors.count - 1] }

    static func of(_ status: PausStatus, health: Int, isStale: Bool) -> ActivityLook {
        // The same line for the whole session, a different one next time.
        let seed = Int((status.start ?? .distantPast).timeIntervalSinceReferenceDate / 60)
        if isStale {
            return ActivityLook(
                colors: [Color(red: 0.03, green: 0.5, blue: 0.37), Color(red: 0.08, green: 0.68, blue: 0.5)],
                mood: .proud,
                label: L("KLART"),
                line: status.finishedText
            )
        }
        if status.stepGoal != nil {
            return ActivityLook(
                colors: [Color(red: 0.02, green: 0.5, blue: 0.48), Color(red: 0.08, green: 0.6, blue: 0.86)],
                mood: .hyped,
                label: L("STEGPASS"),
                line: pick([L("Ut och gå! Pip räknar varje steg."), L("Apparna öppnas när du har gått klart."), L("Frisk luft slår scrollande.")], seed)
            )
        }
        switch status.kind {
        case .focus:
            let minutes = focusMinutes(status)
            return ActivityLook(
                colors: [Color(red: 0.36, green: 0.22, blue: 0.9), Color(red: 0.16, green: 0.42, blue: 0.98)],
                mood: .zen,
                label: minutes.map { L("FOKUS · \($0) MIN") } ?? L("FOKUS"),
                line: pick([L("Pip mediterar med dig. Telefonen kan vänta."), L("Varje minut nu är din."), L("Djupt fokus. Pip håller vakt.")], seed),
                xp: minutes.map { $0 + PlayerProgress.XP.focusBonus }
            )
        case .pause:
            return ActivityLook(
                colors: [Color(red: 1, green: 0.55, blue: 0.2), Color(red: 1, green: 0.34, blue: 0.42)],
                mood: .sad,
                label: status.title.uppercased(),
                line: L("Sedan blockeras apparna igen. Pip tittar på klockan.")
            )
        case .limit:
            return ActivityLook(colors: [Palette.pink, Palette.violet], mood: .sleepy, label: L("SPÄRRAT"), line: L("Dagens tid är slut. Imorgon börjar den om."))
        case .schedule, .free:
            return ActivityLook(colors: [Palette.pink, Palette.violet], mood: health < 40 ? .sad : .happy, label: status.title.uppercased(),
                                line: L("Pip vaktar dina appar."))
        }
    }

    private static func focusMinutes(_ status: PausStatus) -> Int? {
        guard let start = status.start, let end = status.end, end > start else { return nil }
        return Int((end.timeIntervalSince(start) / 60).rounded())
    }

    private static func pick(_ lines: [String], _ seed: Int) -> String {
        lines[abs(seed) % lines.count]
    }
}

/// Pip in a soft circle. When the mood changes with an update, the new face pops in.
struct PipBadge: View {
    let mood: MascotMood
    let level: Int
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(.white.opacity(0.18))
            WidgetPip(mood: mood, level: level)
                .padding(size * 0.08)
                .id(mood)
                .transition(.scale(scale: 0.5).combined(with: .opacity))
        }
        .frame(width: size, height: size)
    }
}

/// A step session's progress, with Pip walking along it toward the flag. Pip moves when the steps are counted again.
struct StepTrack: View {
    let fraction: Double
    let level: Int
    var tint: Color = .white

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let filled = max(10, width * fraction)
            let pipX = min(max(14, width * fraction), width - 14)
            ZStack(alignment: .topLeading) {
                Capsule()
                    .fill(tint.opacity(0.25))
                    .frame(width: width, height: 10)
                    .position(x: width / 2, y: 31)
                Capsule()
                    .fill(tint)
                    .frame(width: filled, height: 10)
                    .position(x: filled / 2, y: 31)
                Image(systemName: "flag.checkered")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(tint)
                    .position(x: width - 9, y: 12)
                WidgetPip(mood: .hyped, level: level)
                    .frame(width: 28, height: 28)
                    .position(x: pipX, y: 13)
            }
            .animation(.spring(duration: 1.2, bounce: 0.35), value: fraction)
        }
        .frame(height: 36)
    }
}

/// The Live Activity on the lock screen: Pip, what is going on, a big countdown or steps left, and progress.
struct LockScreenActivityView: View {
    let state: PausActivityAttributes.ContentState
    let isStale: Bool

    private var status: PausStatus { state.status }
    private var level: Int { state.level ?? 1 }

    var body: some View {
        let look = ActivityLook.of(status, health: state.health, isStale: isStale)
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                PipBadge(mood: look.mood, level: level, size: 50)
                VStack(alignment: .leading, spacing: 2) {
                    Text(look.label)
                        .font(.caption.weight(.heavy))
                        .tracking(1.1)
                        .opacity(0.8)
                    Text(look.line)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 4)
                value
            }
            progress
            footer(look)
        }
        .foregroundStyle(.white)
        .padding(14)
        .background(look.gradient)
    }

    @ViewBuilder
    private var value: some View {
        if isStale {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 34, weight: .bold))
                .transition(.scale.combined(with: .opacity))
        } else if let left = status.stepsLeft {
            VStack(alignment: .trailing, spacing: 0) {
                Text(Format.number(left))
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(left)))
                Text(L("steg kvar"))
                    .font(.caption.weight(.semibold))
                    .opacity(0.8)
            }
        } else if let range = status.countdown(from: .now) {
            Text(timerInterval: range, countsDown: true)
                .font(.system(size: 32, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 116, alignment: .trailing)
        }
    }

    @ViewBuilder
    private var progress: some View {
        if isStale {
            EmptyView()
        } else if status.stepGoal != nil {
            StepTrack(fraction: status.stepFraction, level: level)
        } else if let range = status.countdown(from: .now), status.start != nil {
            ProgressView(timerInterval: range, countsDown: false) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            }
            .tint(.white)
        }
    }

    private func footer(_ look: ActivityLook) -> some View {
        HStack(spacing: 5) {
            if !isStale, status.stepGoal != nil, let checked = status.stepsCheckedAt {
                Text(L("Uppdaterad \(Format.time(checked))"))
            } else if !isStale, let xp = look.xp {
                Image(systemName: "sparkles")
                Text(L("+\(xp) XP när du är klar"))
            }
            Spacer(minLength: 0)
            if let streak = state.streak, streak > 0 {
                Image(systemName: "flame.fill")
                    .foregroundStyle(Palette.orange)
                Text("\(streak)")
                    .monospacedDigit()
            }
        }
        .font(.caption.weight(.semibold))
        .opacity(0.9)
    }
}

/// The Dynamic Island's expanded bottom: progress and Pip's line.
struct IslandBottom: View {
    let state: PausActivityAttributes.ContentState
    let isStale: Bool

    var body: some View {
        let status = state.status
        let look = ActivityLook.of(status, health: state.health, isStale: isStale)
        VStack(alignment: .leading, spacing: 6) {
            if !isStale, status.stepGoal != nil {
                StepTrack(fraction: status.stepFraction, level: state.level ?? 1, tint: look.accent)
            } else if !isStale, let range = status.countdown(from: .now), status.start != nil {
                ProgressView(timerInterval: range, countsDown: false) {
                    EmptyView()
                } currentValueLabel: {
                    EmptyView()
                }
                .tint(look.accent)
            }
            Text(look.line)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}
