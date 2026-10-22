import SwiftUI

extension PipHealth.Stage {
    var color: Color {
        switch self {
        case .wrecked: return Color(red: 0.55, green: 0.7, blue: 0.35)
        case .sick: return Theme.pink
        case .down: return Theme.orange
        case .okay: return Theme.violet
        case .great: return Theme.mint
        }
    }
}

/// Pip's health as a heart, a word and a bar.
struct HealthBar: View {
    let health: Int

    var body: some View {
        let stage = PipHealth.Stage(health: health)
        HStack(spacing: 12) {
            Image(systemName: stage >= .okay ? "heart.fill" : "heart.slash.fill")
                .font(.title3)
                .foregroundStyle(stage.color)
                .symbolEffect(.pulse, isActive: stage <= .sick)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Pips hälsa")
                        .font(.subheadline.weight(.semibold))
                    Text(stage.label)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(stage.color)
                    Spacer()
                    Text("\(health) %")
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .foregroundStyle(.secondary)
                    Image(systemName: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.1))
                        Capsule()
                            .fill(stage.color)
                            .frame(width: max(8, proxy.size.width * CGFloat(health) / CGFloat(PipHealth.maximum)))
                    }
                }
                .frame(height: 8)
                .animation(.spring(duration: 0.6), value: health)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Pips hälsa: \(health) procent, \(stage.label.lowercased())")
        .accessibilityHint("Visar vad som gör Pip gladare och ledsnare")
    }
}

/// Explains what makes Pip feel better and worse.
struct PipHealthSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    MascotView(mood: model.mood, level: model.progress.level, size: 120)
                    HealthBar(health: model.progress.health)
                        .card()

                    Text("Pip mår som du scrollar. Ju mer tid i Pips appar och ju fler pauser, desto ledsnare blir Pip. Hälsan påverkar inte din XP eller nivå, bara hur Pip mår.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HealthList(title: "Gör Pip ledsen", tint: Theme.pink, rows: [
                        ("iphone.gen3", "Varje halvtimme i Pips appar", "−\(PipHealth.perScrollStep)"),
                        ("cup.and.saucer.fill", "En paus (växer under dagen)", "−\(PipHealth.pauseCost(forPause: 1)) till −\(PipHealth.pauseCost(forPause: 4))"),
                        ("hourglass", "Dagens tid tar slut", "−\(PipHealth.reachedDailyLimit)"),
                        ("power", "Stänga av Paus i Skärmtid", "−\(PipHealth.disabledProtection)"),
                    ])

                    HealthList(title: "Gör Pip glad", tint: Theme.mint, rows: [
                        ("moon.stars.fill", "En natts sömn", "+\(PipHealth.overnight)"),
                        ("scope", "Fokuspass", "+1 per \(PipHealth.focusMinutesPerPoint) min"),
                        ("wind", "Tacka nej till en paus", "+\(PipHealth.declinedPause)"),
                        ("hand.raised.fill", "Stänga en blockerad app", "+\(PipHealth.closedBlockedApp)"),
                        ("gift.fill", "Dagens belöning", "+\(PipHealth.dailyReward)"),
                        ("checkmark.seal.fill", "En hel dag under gränsen", "+\(PipHealth.dayUnderLimit)"),
                    ])
                }
                .padding(20)
            }
            .screenBackground()
            .navigationTitle("Pips hälsa")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Klar") { dismiss() }
                }
            }
        }
    }
}

private struct HealthList: View {
    let title: String
    let tint: Color
    let rows: [(symbol: String, text: String, change: String)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            ForEach(rows, id: \.text) { row in
                HStack(spacing: 12) {
                    Image(systemName: row.symbol)
                        .foregroundStyle(tint)
                        .frame(width: 26)
                        .accessibilityHidden(true)
                    Text(row.text)
                        .font(.subheadline)
                    Spacer()
                    Text(row.change)
                        .font(.subheadline.weight(.bold).monospacedDigit())
                        .foregroundStyle(tint)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .card()
    }
}
