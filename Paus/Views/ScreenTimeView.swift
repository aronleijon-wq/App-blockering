import DeviceActivity
import FamilyControls
import SwiftUI

/// Which screen time the report counts.
enum ScreenTimeScope: String, CaseIterable, Identifiable {
    case everything = "Hela telefonen"
    case guarded = "Pips appar"

    var id: Self { self }
}

/// Shows the report extension's view, or sample data in the Simulator, where Screen Time has none.
struct ScreenTimeReport: View {
    @Environment(AppModel.self) private var model
    let context: DeviceActivityReport.Context
    let style: ScreenTimeReportView.Style
    var scope: ScreenTimeScope = .everything

    var body: some View {
        if model.isSimulatorPreview {
            ScreenTimeReportView(summary: .sample, style: style)
        } else {
            DeviceActivityReport(context, filter: filter)
        }
    }

    private var filter: DeviceActivityFilter {
        let interval = ScreenTimeSummary.interval(endingAt: .now, calendar: .current)
        let devices = DeviceActivityFilter.Devices([.iPhone])
        guard scope == .guarded, model.hasSelection else {
            return DeviceActivityFilter(segment: .daily(during: interval), users: .all, devices: devices)
        }
        let selection = model.selection
        return DeviceActivityFilter(
            segment: .daily(during: interval),
            users: .all,
            devices: devices,
            applications: selection.applicationTokens,
            categories: selection.categoryTokens,
            webDomains: selection.webDomainTokens
        )
    }
}

/// Today's screen time on the home screen, with a way into the whole report.
struct ScreenTimeCard: View {
    var body: some View {
        VStack(spacing: 10) {
            ScreenTimeReport(context: .pausToday, style: .compact)
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            NavigationLink {
                ScreenTimeView()
            } label: {
                Label("Se hela veckan", systemImage: "chart.bar.xaxis")
            }
            .buttonStyle(ChipButtonStyle())
        }
    }
}

/// The whole report, for the phone or only the apps Pip guards.
struct ScreenTimeView: View {
    @Environment(AppModel.self) private var model
    @State private var scope: ScreenTimeScope = .everything

    var body: some View {
        VStack(spacing: 12) {
            if model.hasSelection {
                Picker("Visa", selection: $scope) {
                    ForEach(ScreenTimeScope.allCases) { scope in
                        Text(scope.rawValue).tag(scope)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
            }
            ScreenTimeReport(context: .pausWeek, style: .full, scope: scope)
                .id(scope)
        }
        .padding(.top, 8)
        .background(ReportPalette.background.ignoresSafeArea())
        .navigationTitle("Skärmtid")
        .navigationBarTitleDisplayMode(.inline)
    }
}
