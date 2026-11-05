import SwiftUI

/// A shirt over the lower part of Pip, cut to Pip's form. It's laid out like the body it covers: `size` wide, with the
/// body's radius reaching `reach` of half of it, wobbling along with it.
struct PipShirtView: View {
    let id: String
    let size: CGFloat
    var form: PipForm = .round
    var phase: Double = 0
    var wobble: Double = 0
    var reach: Double = 0.86

    /// Where the shirt starts below Pip's center, as a share of `size`: just under the mouth.
    static let hem: CGFloat = 0.19

    private var outline: BlobShape {
        BlobShape(form: form, phase: phase, wobble: wobble, reach: reach)
    }

    /// The item, so a flag shirt with any country draws as the flag shirt.
    private var base: String {
        WardrobeItem.flagCountry(of: id) == nil ? id : WardrobeItem.flagShirt
    }

    /// Where prints sit below Pip's center: halfway between the hem and the bottom of the body, clear of the collar.
    private var chest: CGFloat {
        let bottom = CGFloat(form.bottom * reach / 2)
        return size * max(Self.hem + 0.085, (Self.hem + bottom) / 2)
    }

    var body: some View {
        ZStack {
            ZStack {
                Rectangle().fill(cloth)
                pattern
            }
            .frame(width: size, height: size)
            .clipShape(outline)
            .mask {
                Rectangle().offset(y: size * (0.5 + Self.hem))
            }
            details
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private var cloth: Color {
        switch base {
        case "shirt-black": return Color(white: 0.13)
        case "shirt-hoodie": return Color(red: 0.62, green: 0.63, blue: 0.69)
        case "shirt-hawaii": return Color(red: 0.98, green: 0.45, blue: 0.36)
        case "shirt-jersey": return Color(red: 0.88, green: 0.13, blue: 0.24)
        case "shirt-leather": return Color(red: 0.16, green: 0.12, blue: 0.11)
        case "shirt-tux": return Color(white: 0.08)
        case "shirt-armor": return Color(white: 0.72)
        default: return Color(white: 0.96)
        }
    }

    // MARK: Cut to the shirt

    @ViewBuilder
    private var pattern: some View {
        switch base {
        case "shirt-stripes": stripes
        case "shirt-hoodie": pocket
        case "shirt-hawaii": flowers
        case "shirt-leather": openJacket
        case "shirt-tux": shirtFront
        case "shirt-armor": plates
        default: EmptyView()
        }
    }

    private var stripes: some View {
        VStack(spacing: size * 0.035) {
            ForEach(0..<6, id: \.self) { _ in
                Rectangle()
                    .fill(Color(red: 0.12, green: 0.2, blue: 0.45))
                    .frame(height: size * 0.035)
            }
        }
        .offset(y: size * 0.38)
    }

    private var pocket: some View {
        RoundedRectangle(cornerRadius: size * 0.03, style: .continuous)
            .fill(Color(red: 0.55, green: 0.56, blue: 0.62))
            .frame(width: size * 0.32, height: size * 0.09)
            .offset(y: chest + size * 0.06)
    }

    private static let flowerSpots: [CGPoint] = [
        CGPoint(x: -0.3, y: 0.27), CGPoint(x: -0.1, y: 0.35), CGPoint(x: 0.13, y: 0.26), CGPoint(x: 0.32, y: 0.33),
        CGPoint(x: -0.22, y: 0.43), CGPoint(x: 0.05, y: 0.45), CGPoint(x: 0.25, y: 0.43), CGPoint(x: -0.4, y: 0.36),
    ]

    private var flowers: some View {
        ZStack {
            ForEach(Self.flowerSpots.indices, id: \.self) { index in
                flower(index: index)
            }
        }
    }

    private func flower(index: Int) -> some View {
        let spot = Self.flowerSpots[index]
        let isFlower = index % 2 == 0
        return Image(systemName: isFlower ? "camera.macro" : "leaf.fill")
            .font(.system(size: size * 0.09, weight: .bold))
            .foregroundStyle(isFlower ? Color(red: 1, green: 0.92, blue: 0.4) : Color(red: 0.2, green: 0.7, blue: 0.45))
            .rotationEffect(.degrees(Double(index) * 40))
            .offset(x: size * spot.x, y: size * spot.y)
    }

    /// An open jacket over a white tee.
    private var openJacket: some View {
        ZStack {
            Rectangle()
                .fill(Color(white: 0.95))
                .frame(width: size * 0.14)
            Rectangle()
                .fill(Color(white: 0.7))
                .frame(width: size * 0.012)
                .offset(x: -size * 0.078)
            Rectangle()
                .fill(Color(white: 0.7))
                .frame(width: size * 0.012)
                .offset(x: size * 0.078)
        }
    }

    private var shirtFront: some View {
        Triangle()
            .fill(Color.white)
            .frame(width: size * 0.22, height: size * 0.22)
            .rotationEffect(.degrees(180))
            .offset(y: Self.hem * size + size * 0.11)
    }

    private var plates: some View {
        ZStack {
            LinearGradient(colors: [Color(white: 0.92), Color(white: 0.5)], startPoint: .top, endPoint: .bottom)
            VStack(spacing: size * 0.06) {
                Rectangle().fill(Color(white: 0.38)).frame(height: size * 0.012)
                Rectangle().fill(Color(white: 0.38)).frame(height: size * 0.012)
                Rectangle().fill(Color(white: 0.38)).frame(height: size * 0.012)
            }
            .offset(y: size * 0.36)
        }
    }

    // MARK: On top

    @ViewBuilder
    private var details: some View {
        switch base {
        case WardrobeItem.flagShirt:
            collar(Color(white: 0.78))
            Text(Country.flag(WardrobeItem.flagCountry(of: id) ?? "SE"))
                .font(.system(size: size * 0.12))
                .offset(y: chest)
        case "shirt-black":
            collar(Color(white: 0.3))
            Image(systemName: "bolt.fill")
                .font(.system(size: size * 0.1, weight: .bold))
                .foregroundStyle(Color(red: 1, green: 0.85, blue: 0.2))
                .offset(y: chest)
        case "shirt-stripes":
            collar(Color(red: 0.12, green: 0.2, blue: 0.45))
        case "shirt-hoodie":
            hood
        case "shirt-hawaii":
            collar(Color(red: 0.85, green: 0.3, blue: 0.25), width: 0.3)
        case "shirt-jersey":
            collar(Color.white)
            Text(verbatim: "10")
                .font(.system(size: size * 0.11, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .offset(y: chest)
        case "shirt-leather":
            collar(Color(red: 0.32, green: 0.24, blue: 0.21), width: 0.32)
        case "shirt-tux":
            bowTie
        case "shirt-armor":
            collar(Self.gold)
            Image(systemName: "star.fill")
                .font(.system(size: size * 0.1, weight: .bold))
                .foregroundStyle(Self.gold)
                .offset(y: chest)
        default:
            collar(Color(white: 0.8))
        }
    }

    private static let gold = LinearGradient(colors: [Color(red: 1, green: 0.9, blue: 0.45), Color(red: 0.85, green: 0.6, blue: 0.15)],
                                             startPoint: .top, endPoint: .bottom)

    /// A wide, shallow neckline at the top of the shirt.
    private func collar<S: ShapeStyle>(_ style: S, width: CGFloat = 0.26) -> some View {
        Ellipse()
            .trim(from: 0, to: 0.5)
            .stroke(style, style: StrokeStyle(lineWidth: size * 0.02, lineCap: .round))
            .frame(width: size * width, height: size * 0.08)
            .offset(y: size * Self.hem)
    }

    private var hood: some View {
        let shade = Color(red: 0.5, green: 0.51, blue: 0.57)
        return ZStack {
            Ellipse()
                .trim(from: 0, to: 0.5)
                .stroke(shade, style: StrokeStyle(lineWidth: size * 0.05, lineCap: .round))
                .frame(width: size * 0.32, height: size * 0.12)
                .offset(y: size * Self.hem)
            Capsule()
                .fill(Color.white)
                .frame(width: size * 0.016, height: size * 0.08)
                .offset(x: -size * 0.045, y: size * (Self.hem + 0.1))
            Capsule()
                .fill(Color.white)
                .frame(width: size * 0.016, height: size * 0.08)
                .offset(x: size * 0.045, y: size * (Self.hem + 0.1))
        }
    }

    private var bowTie: some View {
        HStack(spacing: 0) {
            Triangle()
                .fill(Color.black)
                .frame(width: size * 0.06, height: size * 0.07)
                .rotationEffect(.degrees(90))
            Circle()
                .fill(Color.black)
                .frame(width: size * 0.03)
            Triangle()
                .fill(Color.black)
                .frame(width: size * 0.06, height: size * 0.07)
                .rotationEffect(.degrees(-90))
        }
        .offset(y: size * (Self.hem + 0.03))
    }
}
