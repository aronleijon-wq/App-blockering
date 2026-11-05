import SwiftUI

/// A still Pip in a player's outfit, for lists, where dozens of animated ones would be too heavy.
struct PipAvatar: View {
    let outfit: Outfit
    let level: Int
    var size: CGFloat = 30

    var body: some View {
        let form = PipForm(item: outfit.shape)
        return ZStack {
            if let back = outfit.back {
                PipItemView(id: back, size: size)
            }
            BlobShape(form: form, phase: 0, wobble: 0, reach: 1)
                .fill(LinearGradient(colors: MascotView.bodyColors(level: level, outfit: outfit), startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: size, height: size)
            if let shirt = outfit.shirt {
                PipShirtView(id: shirt, size: size, form: form, reach: 1)
            }
            HStack(spacing: size * 0.2) {
                eye
                eye
            }
            .offset(y: -size * 0.07)
            Circle()
                .trim(from: 0.1, to: 0.4)
                .stroke(Color(red: 0.08, green: 0.06, blue: 0.16), style: StrokeStyle(lineWidth: size * 0.04, lineCap: .round))
                .frame(width: size * 0.24, height: size * 0.24)
                .offset(y: size * 0.04)
            if let neck = outfit.neck {
                PipItemView(id: neck, size: size)
                    .offset(PipItemView.offset(for: .neck, size: size, form: form))
            }
            if let glasses = outfit.glasses {
                PipItemView(id: glasses, size: size)
                    .offset(PipItemView.offset(for: .glasses, size: size))
            }
            if let hat = outfit.hat {
                PipItemView(id: hat, size: size)
                    .offset(PipItemView.offset(for: .hat, size: size, form: form))
            }
        }
        .frame(width: size * 1.4, height: size * 1.4)
        .accessibilityHidden(true)
    }

    private var eye: some View {
        Circle()
            .fill(.white)
            .frame(width: size * 0.18, height: size * 0.18)
            .overlay {
                Circle()
                    .fill(Color(red: 0.08, green: 0.06, blue: 0.16))
                    .frame(width: size * 0.09, height: size * 0.09)
            }
    }
}
