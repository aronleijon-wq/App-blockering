import SwiftUI

struct TodayView: View {
    @Environment(AppModel.self) private var model

    private let focusLengths = [25, 50, 90]

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                List {
                    statusSection(at: context.date)
                    if model.hasSelection {
                        focusSection(at: context.date)
                        pauseSection(at: context.date)
                        statsSection(at: context.date)
                    }
                }
            }
            .navigationTitle("Idag")
        }
    }

    @ViewBuilder
    private func statusSection(at date: Date) -> some View {
        let engine = model.engine
        Section {
            if !model.hasSelection {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Välj vad som ska blockeras")
                        .font(.headline)
                    Text("Börja med apparna som tar mest av din tid, till exempel TikTok, Instagram och YouTube.")
                        .foregroundStyle(.secondary)
                    Button("Välj appar") { model.selectedTab = .apps }
                        .buttonStyle(.borderedProminent)
                        .padding(.top, 4)
                }
                .padding(.vertical, 4)
            } else if let reason = engine.reason(at: date) {
                if engine.shouldShield(at: date) {
                    StatusRow(symbol: "lock.fill", tint: .accentColor, title: "Blockerat just nu", detail: Format.reason(reason))
                } else if let pausedUntil = model.runtime.pausedUntil {
                    StatusRow(
                        symbol: "cup.and.saucer.fill",
                        tint: .orange,
                        title: "Paus – \(Format.countdown(to: pausedUntil, from: date)) kvar",
                        detail: "Sedan blockeras apparna igen."
                    )
                    Button("Avsluta pausen nu") { model.endPause() }
                }
            } else {
                StatusRow(symbol: "checkmark.circle.fill", tint: .green, title: "Inget blockeras just nu", detail: "Starta ett fokuspass eller lägg till ett schema.")
            }
        }
    }

    @ViewBuilder
    private func focusSection(at date: Date) -> some View {
        Section {
            if let end = model.runtime.focusEndsAt, end > date {
                StatusRow(symbol: "scope", tint: .accentColor, title: "Fokus till \(Format.time(end))", detail: "\(Format.countdown(to: end, from: date)) kvar")
                if model.rules.strictFocus {
                    Text("Strikt fokus är på, så passet går inte att avbryta.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    Button("Avsluta fokus", role: .destructive) { model.stopFocus() }
                }
            } else {
                HStack(spacing: 12) {
                    ForEach(focusLengths, id: \.self) { minutes in
                        Button {
                            model.startFocus(minutes: minutes)
                        } label: {
                            Text(Format.minutes(minutes))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .accessibilityLabel("Starta fokus i \(Format.minutes(minutes))")
                    }
                }
                .padding(.vertical, 4)
            }
        } header: {
            Text("Fokuspass")
        } footer: {
            if model.runtime.focusEndsAt.map({ $0 <= date }) ?? true {
                Text("Blockerar de valda apparna direkt, tills tiden är slut.")
            }
        }
    }

    @ViewBuilder
    private func pauseSection(at date: Date) -> some View {
        let engine = model.engine
        if model.rules.pause.isEnabled, engine.reason(at: date) != nil, !engine.isPaused(at: date) {
            Section {
                Button {
                    model.isPauseSheetPresented = true
                } label: {
                    Label("Ta en paus på \(model.rules.pause.minutes) min", systemImage: "cup.and.saucer")
                }
                .disabled(!engine.canPause(at: date))
            } footer: {
                Text(pauseFooter(engine: engine, at: date))
            }
        }
    }

    private func pauseFooter(engine: BlockEngine, at date: Date) -> String {
        if case .focus = engine.reason(at: date), model.rules.strictFocus {
            return "Under strikt fokus går det inte att ta pauser."
        }
        return "\(engine.pausesLeft(at: date)) av \(model.rules.pause.maxPerDay) pauser kvar idag."
    }

    private func statsSection(at date: Date) -> some View {
        let counts = model.runtime.counts(on: date, calendar: .current)
        return Section("Idag") {
            LabeledContent("Stängde en blockerad app", value: "\(counts.closed) ggr")
            LabeledContent("Pauser", value: "\(counts.pauses)")
        }
    }
}

private struct StatusRow: View {
    let symbol: String
    let tint: Color
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(tint)
                .frame(width: 32)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .monospacedDigit()
                Text(detail)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}
