import ActivityKit
import SwiftUI
import WidgetKit

@main
struct PausWidgetsBundle: WidgetBundle {
    var body: some Widget {
        StatusWidget()
        PipWidget()
        JourneyWidget()
        PausLiveActivity()
    }
}

/// The app's colors, repeated here because the widget extension doesn't include the app's design files.
enum Palette {
    static let background = Color(red: 0.055, green: 0.043, blue: 0.122)
    static let violet = Color(red: 0.545, green: 0.361, blue: 1.0)
    static let pink = Color(red: 1.0, green: 0.31, blue: 0.64)
    static let orange = Color(red: 1.0, green: 0.71, blue: 0.28)
    static let mint = Color(red: 0.235, green: 0.94, blue: 0.69)
    static let backdrop = LinearGradient(
        colors: [Color(red: 0.13, green: 0.07, blue: 0.27), background],
        startPoint: .top,
        endPoint: .bottom
    )
}

extension PausStatus {
    var symbol: String {
        switch kind {
        case .focus: return "scope"
        case .pause: return "cup.and.saucer.fill"
        case .schedule: return "lock.fill"
        case .limit: return "hourglass"
        case .free: return "checkmark.circle.fill"
        }
    }

    var tint: Color {
        switch kind {
        case .focus: return Palette.violet
        case .pause: return Palette.orange
        case .schedule, .limit: return Palette.pink
        case .free: return Palette.mint
        }
    }

    var subtitle: String {
        switch kind {
        case .focus: return L("Fokus pågår")
        case .pause: return L("Sedan blockeras apparna igen")
        case .schedule: return L("Blockerat enligt schema")
        case .limit: return L("Spärrat till midnatt")
        case .free: return L("Pip vaktar när du vill")
        }
    }

    /// What to say once the countdown has run out but the app hasn't updated yet.
    var finishedText: String {
        switch kind {
        case .focus: return L("Fokuspasset är klart! Öppna Paus och hämta din XP.")
        case .pause: return L("Pausen är slut. Apparna är blockerade igen.")
        case .schedule, .limit, .free: return L("Blockeringen är slut.")
        }
    }

    /// "100 av 2 000 steg" during a step session.
    var stepsLine: String? {
        guard let stepGoal else { return nil }
        return L("\(Format.number(min(steps ?? 0, stepGoal))) av \(Format.number(stepGoal)) steg")
    }

    var stepFraction: Double {
        guard let stepGoal, stepGoal > 0 else { return 0 }
        return min(1, Double(steps ?? 0) / Double(stepGoal))
    }

    /// The countdown range, from `now` or the start, whichever is earlier, to the end.
    func countdown(from now: Date) -> ClosedRange<Date>? {
        guard let end, end > now else { return nil }
        return min(start ?? now, now)...end
    }
}

// MARK: - Widget

struct StatusEntry: TimelineEntry {
    let date: Date
    let status: PausStatus
    let health: Int
    let streak: Int
    var mood: MascotMood = .happy
    var xp = 0
    /// Whether the user has done something in Paus today, which keeps the streak going.
    var activeToday = true
    var hour = 12

    var level: Int { Level.level(forXP: xp) }
}

struct StatusProvider: TimelineProvider {
    func placeholder(in context: Context) -> StatusEntry {
        StatusEntry(date: .now, status: PausStatus(kind: .schedule, title: L("Skola"), start: nil, end: .now.addingTimeInterval(5400)), health: 80, streak: 4, mood: .happy, xp: 1150)
    }

    func getSnapshot(in context: Context, completion: @escaping (StatusEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : entry(at: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StatusEntry>) -> Void) {
        let now = Date.now
        // A quarter-hourly entry for six hours catches schedules starting and ending; the app and its
        // extensions also ask for a reload whenever something changes.
        var dates = (0...24).map { now.addingTimeInterval(Double($0) * 900) }
        if let end = entry(at: now).status.end, end > now {
            dates.append(end.addingTimeInterval(1))
        }
        completion(Timeline(entries: dates.sorted().map(entry(at:)), policy: .atEnd))
    }

    private func entry(at date: Date) -> StatusEntry {
        let progress = SharedStore.progress
        let rules = SharedStore.effectiveRules
        let runtime = SharedStore.runtime
        let engine = BlockEngine(rules: rules, runtime: runtime)
        let calendar = Calendar.current
        let reason = engine.reason(at: date)
        let streak = progress.currentStreak(at: date, calendar: calendar)
        let activeToday = progress.lastActiveDay == DayKey.string(for: date, calendar: calendar)
        let hour = calendar.component(.hour, from: date)
        var mood = MascotMood.current(reason: reason, isPaused: engine.isPaused(at: date), progress: progress, at: date, calendar: calendar)
        // The longer the day goes without Paus, the sadder Pip gets.
        if !activeToday, reason == nil, let missing = MascotMood.missing(hour: hour, streak: streak) {
            mood = missing
        }
        return StatusEntry(
            date: date,
            status: PausStatus.at(date, rules: rules, runtime: runtime, calendar: calendar),
            health: progress.health,
            streak: streak,
            mood: mood,
            xp: progress.xp,
            activeToday: activeToday,
            hour: hour
        )
    }
}

struct StatusWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "PausStatus", provider: StatusProvider()) { entry in
            StatusWidgetView(entry: entry)
        }
        .configurationDisplayName("Paus")
        .description(L("Vad som är blockerat, hur länge till och hur Pip mår."))
        .supportedFamilies([.systemSmall, .accessoryRectangular, .accessoryCircular, .accessoryInline])
    }
}

private struct StatusWidgetView: View {
    let entry: StatusEntry
    @Environment(\.widgetFamily) private var family

    private var status: PausStatus { entry.status }

    var body: some View {
        switch family {
        case .accessoryInline:
            inline
        case .accessoryCircular:
            circular
                .containerBackground(.clear, for: .widget)
        case .accessoryRectangular:
            rectangular
                .containerBackground(.clear, for: .widget)
        default:
            small
                .containerBackground(Palette.backdrop, for: .widget)
        }
    }

    @ViewBuilder
    private var inline: some View {
        if let left = status.stepsLeft {
            Label(L("\(Format.number(left)) steg kvar"), systemImage: "figure.walk")
        } else if let range = status.countdown(from: entry.date) {
            Label {
                Text("\(status.title) ") + Text(timerInterval: range, countsDown: true)
            } icon: {
                Image(systemName: status.symbol)
            }
        } else {
            Label(L("Pip mår \(entry.health) %"), systemImage: "heart.fill")
        }
    }

    @ViewBuilder
    private var circular: some View {
        if status.stepGoal != nil {
            Gauge(value: status.stepFraction) {
                Image(systemName: "figure.walk")
            } currentValueLabel: {
                Image(systemName: "figure.walk")
            }
            .gaugeStyle(.accessoryCircular)
        } else if let range = status.countdown(from: entry.date) {
            ProgressView(timerInterval: range, countsDown: true) {
                Image(systemName: status.symbol)
            } currentValueLabel: {
                Image(systemName: status.symbol)
            }
            .progressViewStyle(.circular)
        } else {
            // Pip's face, with the streak under it.
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 0) {
                    WidgetPip(mood: entry.mood, level: entry.level)
                        .frame(width: 34, height: 34)
                    HStack(spacing: 1) {
                        Image(systemName: "flame.fill")
                        Text("\(entry.streak)")
                            .monospacedDigit()
                    }
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                }
            }
            .widgetAccentable()
        }
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(status.title, systemImage: status.symbol)
                .font(.headline)
                .widgetAccentable()
            if let left = status.stepsLeft {
                Text(L("\(Format.number(left)) steg kvar"))
                    .font(.body.weight(.semibold))
                    .monospacedDigit()
            } else if let range = status.countdown(from: entry.date) {
                HStack(spacing: 4) {
                    Text(timerInterval: range, countsDown: true)
                        .monospacedDigit()
                    Text("kvar")
                }
                .font(.body.weight(.semibold))
            } else {
                Text(status.subtitle)
                    .font(.caption)
            }
            Text(L("Pip \(entry.health) % · 🔥 \(entry.streak)"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: status.symbol)
                    .font(.title2)
                    .foregroundStyle(status.tint)
                Spacer()
                Label("\(entry.streak)", systemImage: "flame.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Palette.orange)
            }
            Spacer(minLength: 0)
            Text(status.title)
                .font(.headline)
                .lineLimit(1)
            if let left = status.stepsLeft {
                Text(Format.number(left))
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(status.tint)
                Text(L("steg kvar"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if let range = status.countdown(from: entry.date) {
                Text(timerInterval: range, countsDown: true)
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(status.tint)
            } else {
                Text(status.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 4) {
                Image(systemName: entry.health >= 60 ? "heart.fill" : "heart.slash.fill")
                    .foregroundStyle(Palette.pink)
                Text(L("Pip \(entry.health) %"))
            }
            .font(.caption.weight(.semibold))
        }
        .foregroundStyle(.white)
    }
}

// MARK: - Live Activity

struct PausLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PausActivityAttributes.self) { context in
            LockScreenActivityView(state: context.state, isStale: context.isStale)
                .activityBackgroundTint(ActivityLook.of(context.state.status, health: context.state.health, isStale: context.isStale).colors[0])
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            let status = context.state.status
            let look = ActivityLook.of(status, health: context.state.health, isStale: context.isStale)
            let level = context.state.level ?? 1
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    PipBadge(mood: look.mood, level: level, size: 50)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if let left = status.stepsLeft {
                        Text(L("\(Format.number(left)) kvar"))
                            .font(.title3.weight(.bold))
                            .monospacedDigit()
                            .contentTransition(.numericText(value: Double(left)))
                            .foregroundStyle(look.accent)
                            .frame(maxWidth: 110, alignment: .trailing)
                    } else if let range = status.countdown(from: .now) {
                        Text(timerInterval: range, countsDown: true)
                            .font(.title3.weight(.bold))
                            .monospacedDigit()
                            .foregroundStyle(look.accent)
                            .frame(maxWidth: 90, alignment: .trailing)
                    }
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 1) {
                        Text(look.label)
                            .font(.caption2.weight(.heavy))
                            .tracking(1)
                            .foregroundStyle(look.accent)
                        Text(status.title)
                            .font(.headline)
                            .lineLimit(1)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    IslandBottom(state: context.state, isStale: context.isStale)
                }
            } compactLeading: {
                WidgetPip(mood: look.mood, level: level)
                    .frame(width: 24, height: 24)
            } compactTrailing: {
                if let left = status.stepsLeft {
                    Text(Format.number(left))
                        .monospacedDigit()
                        .contentTransition(.numericText(value: Double(left)))
                        .frame(maxWidth: 52)
                        .foregroundStyle(look.accent)
                } else if let range = status.countdown(from: .now) {
                    Text(timerInterval: range, countsDown: true)
                        .monospacedDigit()
                        .frame(maxWidth: 48)
                        .foregroundStyle(look.accent)
                }
            } minimal: {
                WidgetPip(mood: look.mood, level: level)
                    .frame(width: 22, height: 22)
            }
        }
    }
}
