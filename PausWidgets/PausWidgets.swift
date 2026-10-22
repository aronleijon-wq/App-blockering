import ActivityKit
import SwiftUI
import WidgetKit

@main
struct PausWidgetsBundle: WidgetBundle {
    var body: some Widget {
        StatusWidget()
        PausLiveActivity()
    }
}

/// The app's colors, repeated here because the widget extension doesn't include the app's design files.
private enum Palette {
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

private extension PausStatus {
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
}

struct StatusProvider: TimelineProvider {
    func placeholder(in context: Context) -> StatusEntry {
        StatusEntry(date: .now, status: PausStatus(kind: .schedule, title: L("Skola"), start: nil, end: .now.addingTimeInterval(5400)), health: 80, streak: 4)
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
        return StatusEntry(
            date: date,
            status: PausStatus.at(date, rules: SharedStore.effectiveRules, runtime: SharedStore.runtime, calendar: .current),
            health: progress.health,
            streak: progress.currentStreak(at: date, calendar: .current)
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
        if let range = status.countdown(from: entry.date) {
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
        if let range = status.countdown(from: entry.date) {
            ProgressView(timerInterval: range, countsDown: true) {
                Image(systemName: status.symbol)
            } currentValueLabel: {
                Image(systemName: status.symbol)
            }
            .progressViewStyle(.circular)
        } else {
            Gauge(value: Double(entry.health), in: 0...100) {
                Image(systemName: "heart.fill")
            } currentValueLabel: {
                Text("\(entry.health)")
            }
            .gaugeStyle(.accessoryCircular)
        }
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(status.title, systemImage: status.symbol)
                .font(.headline)
                .widgetAccentable()
            if let range = status.countdown(from: entry.date) {
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
            if let range = status.countdown(from: entry.date) {
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
                .activityBackgroundTint(Palette.background.opacity(0.9))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            let status = context.state.status
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: status.symbol)
                        .font(.title2)
                        .foregroundStyle(status.tint)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if let range = status.countdown(from: .now) {
                        Text(timerInterval: range, countsDown: true)
                            .font(.title3.weight(.bold))
                            .monospacedDigit()
                            .foregroundStyle(status.tint)
                            .frame(maxWidth: 90, alignment: .trailing)
                    }
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(status.title)
                        .font(.headline)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.isStale ? status.finishedText : status.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } compactLeading: {
                Image(systemName: status.symbol)
                    .foregroundStyle(status.tint)
            } compactTrailing: {
                if let range = status.countdown(from: .now) {
                    Text(timerInterval: range, countsDown: true)
                        .monospacedDigit()
                        .frame(maxWidth: 48)
                        .foregroundStyle(status.tint)
                }
            } minimal: {
                Image(systemName: status.symbol)
                    .foregroundStyle(status.tint)
            }
        }
    }
}

private struct LockScreenActivityView: View {
    let state: PausActivityAttributes.ContentState
    let isStale: Bool

    private var status: PausStatus { state.status }

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: status.symbol)
                .font(.title)
                .foregroundStyle(.white)
                .frame(width: 52, height: 52)
                .background(status.tint.gradient, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(status.title)
                    .font(.headline)
                if isStale {
                    Text(status.finishedText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text(status.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if let range = status.countdown(from: .now), status.start != nil {
                        ProgressView(timerInterval: range, countsDown: true) {
                            EmptyView()
                        } currentValueLabel: {
                            EmptyView()
                        }
                        .tint(status.tint)
                    }
                }
            }
            Spacer(minLength: 0)
            if !isStale, let range = status.countdown(from: .now) {
                Text(timerInterval: range, countsDown: true)
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(status.tint)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 110, alignment: .trailing)
            }
        }
        .foregroundStyle(.white)
        .padding(16)
    }
}
