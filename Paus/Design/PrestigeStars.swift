import SwiftUI

/// Gold stars for each round past Legend, so the most dedicated players stand out in the league.
struct PrestigeStars: View {
    let level: Int
    var size: CGFloat = 12

    var body: some View {
        let rounds = Level.prestige(for: level)
        if rounds > 0 {
            HStack(spacing: 1) {
                ForEach(0..<min(rounds, 5), id: \.self) { _ in
                    Image(systemName: "star.fill")
                }
                if rounds > 5 {
                    Text("+\(rounds - 5)")
                        .monospacedDigit()
                }
            }
            .font(.system(size: size, weight: .heavy, design: .rounded))
            .foregroundStyle(LinearGradient(colors: [Color(red: 1, green: 0.88, blue: 0.35), Theme.orange], startPoint: .top, endPoint: .bottom))
            .accessibilityLabel(L("\(rounds) varv efter Legend"))
        }
    }
}
