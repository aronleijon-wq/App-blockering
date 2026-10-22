import Charts
import FamilyControls
import SwiftUI

/// The screen time report. The report extension draws it from real data; the app draws it from sample data in the Simulator.
struct ScreenTimeReportView: View {
    enum Style {
        /// A card for the home screen.
        case compact
        /// The whole report on its own screen.
        case full
    }

    let summary: ScreenTimeSummary
    let style: Style

    var body: some View {
        switch style {
        case .compact:
            compact
        case .full:
            ScrollView {
                full
                    .padding(16)
            }
            .background(ReportPalette.background)
        }
    }

    // MARK: Compact

    private var compact: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Label(L("Skärmtid i dag"), systemImage: "hourglass")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Label("\(summary.pickupsToday)", systemImage: "iphone.radiowaves.left.and.right")
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(L("\(summary.pickupsToday) upplockningar i dag"))
            }
            Text(ReportFormat.duration(summary.today))
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .monospacedDigit()
            comparison
            weekChart(height: 64, showsAxis: false)
        }
        .foregroundStyle(.white)
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(ReportPalette.card, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .environment(\.colorScheme, .dark)
    }

    // MARK: Full

    private var full: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(L("I dag"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(ReportFormat.duration(summary.today))
                    .font(.system(size: 44, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                comparison
            }
            .reportCard()

            VStack(alignment: .leading, spacing: 10) {
                Text(L("Senaste veckan"))
                    .font(.headline)
                weekChart(height: 180, showsAxis: true)
                if let average = summary.weekAverage {
                    Text(L("Streckad linje: snittet \(ReportFormat.duration(average)) per dag."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .reportCard()

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ReportStat(symbol: "chart.bar.fill", value: summary.weekAverage.map(ReportFormat.duration) ?? "–", label: L("Snitt per dag"))
                ReportStat(symbol: "iphone.radiowaves.left.and.right", value: "\(summary.pickupsToday)", label: L("Upplockningar i dag"))
                ReportStat(symbol: "sunrise.fill", value: summary.firstPickupToday.map(ReportFormat.time) ?? "–", label: L("Första upplockningen"))
                ReportStat(symbol: "calendar", value: summary.daysPerYear.map { L("\($0) dygn") } ?? "–", label: L("Per år i den takten"))
            }

            if !summary.topApps.isEmpty {
                VStack(alignment: .leading, spacing: 14) {
                    Text(L("Mest använt i dag"))
                        .font(.headline)
                    let longest = summary.topApps.first?.duration ?? 1
                    ForEach(summary.topApps) { app in
                        ReportAppRow(app: app, fraction: longest > 0 ? app.duration / longest : 0)
                    }
                }
                .reportCard()
            }

            if let days = summary.daysPerYear, days > 0 {
                Text(L("Med \(ReportFormat.duration(summary.weekAverage ?? 0)) om dagen blir det \(days) hela dygn framför skärmen på ett år. Varje fokuspass gör den siffran mindre."))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .foregroundStyle(.white)
        .environment(\.colorScheme, .dark)
    }

    // MARK: Parts

    @ViewBuilder
    private var comparison: some View {
        if let average = summary.weekAverage, let previous = summary.previousWeekAverage {
            let change = average - previous
            let isLess = change <= 0
            Label(
                isLess
                    ? L("Snitt \(ReportFormat.duration(average))/dag, \(ReportFormat.duration(abs(change))) mindre än veckan innan")
                    : L("Snitt \(ReportFormat.duration(average))/dag, \(ReportFormat.duration(abs(change))) mer än veckan innan"),
                systemImage: isLess ? "arrow.down.right" : "arrow.up.right"
            )
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(isLess ? ReportPalette.mint : ReportPalette.orange)
        } else if let average = summary.weekAverage {
            Text(L("Snitt \(ReportFormat.duration(average)) per dag senaste veckan"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }

    private func weekChart(height: CGFloat, showsAxis: Bool) -> some View {
        let today = summary.chartDays.last?.start
        return Chart {
            ForEach(summary.chartDays) { day in
                BarMark(
                    x: .value(L("Dag"), day.start, unit: .day),
                    y: .value(L("Timmar"), day.duration / 3600)
                )
                .foregroundStyle(day.start == today ? ReportPalette.pink : ReportPalette.violet.opacity(0.75))
                .cornerRadius(5)
            }
            if showsAxis, let average = summary.weekAverage {
                RuleMark(y: .value(L("Snitt"), average / 3600))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) { _ in
                AxisValueLabel(format: .dateTime.weekday(.abbreviated), centered: true)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine().foregroundStyle(.white.opacity(0.1))
                AxisValueLabel {
                    if let hours = value.as(Double.self) {
                        Text("\(Int(hours)) h")
                    }
                }
            }
        }
        .chartXAxis(showsAxis ? .visible : .hidden)
        .chartYAxis(showsAxis ? .visible : .hidden)
        .frame(height: height)
        .accessibilityElement()
        .accessibilityLabel(L("Skärmtid per dag senaste veckan"))
        .accessibilityValue(summary.chartDays.map { ReportFormat.duration($0.duration) }.joined(separator: ", "))
    }
}

private struct ReportStat: View {
    let symbol: String
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: symbol)
                .foregroundStyle(ReportPalette.pink)
            Text(value)
                .font(.title3.weight(.bold).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .reportCard()
        .accessibilityElement(children: .combine)
    }
}

private struct ReportAppRow: View {
    let app: ScreenTimeSummary.AppUsage
    let fraction: Double

    var body: some View {
        HStack(spacing: 12) {
            icon
                .frame(width: 34, height: 34)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(app.name)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Spacer()
                    Text(ReportFormat.duration(app.duration))
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                }
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.1))
                        Capsule()
                            .fill(ReportPalette.glow)
                            .frame(width: max(6, proxy.size.width * fraction))
                    }
                }
                .frame(height: 6)
                Text(L("\(app.pickups) upplockningar"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var icon: some View {
        if let token = app.token {
            Label(token)
                .labelStyle(.iconOnly)
                .scaleEffect(1.4)
        } else {
            Text(String(app.name.prefix(1)))
                .font(.headline)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(ReportPalette.cardRaised, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }
}

private extension View {
    func reportCard() -> some View {
        padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(ReportPalette.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
            }
    }
}

#Preview("Kort") {
    ScreenTimeReportView(summary: .sample, style: .compact)
        .frame(height: 210)
        .padding()
        .background(ReportPalette.background)
}

#Preview("Hela rapporten") {
    ScreenTimeReportView(summary: .sample, style: .full)
}
