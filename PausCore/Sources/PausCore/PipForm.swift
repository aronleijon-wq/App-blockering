import Foundation

/// The shapes Pip's body can take from the wardrobe. Each is an outline around Pip's center in units of Pip's radius,
/// so the same face, wobble and clothes fit them all.
enum PipForm: String, CaseIterable {
    case round, tall, wide, egg, pear, square, drop, ghost, heart

    static let prefix = "shape-"

    /// The form a shape item such as "shape-tall" gives. Pip is round without one.
    init(item id: String?) {
        guard let id, id.hasPrefix(Self.prefix), let form = PipForm(rawValue: String(id.dropFirst(Self.prefix.count))) else {
            self = .round
            return
        }
        self = form
    }

    var itemID: String { Self.prefix + rawValue }

    /// The outline's point at `angle`, in radians clockwise from the right, with y growing downward as on screen.
    func point(at angle: Double) -> (x: Double, y: Double) {
        let c = cos(angle), s = sin(angle)
        switch self {
        case .round: return (c, s * 0.94)
        case .tall: return (c * 0.84, s * 1.06)
        case .wide: return (c * 1.1, s * 0.8)
        case .egg: return (c * (0.9 - 0.1 * s), s * 0.98)
        case .pear: return (c * (0.88 + 0.2 * s), s * 0.98)
        case .square: return (Self.squircle(c) * 0.95, Self.squircle(s) * 0.9)
        case .drop:
            // Round below, coming to a soft point on top.
            return s < 0 ? (c * pow(1 + s * 0.5, 0.8), s * 1.08) : (c, s * 0.94)
        case .ghost:
            // A dome with straight sides and a wavy hem.
            guard s > 0 else { return (c * 0.9, s * 0.98) }
            let x = Self.squircle(c, power: 0.6) * 0.9
            return (x, pow(s, 0.35) * 0.92 + 0.07 * cos(x * 3.2 * .pi) * pow(s, 3))
        case .heart:
            let t = angle + .pi / 2
            let y = 13 * cos(t) - 5 * cos(2 * t) - 2 * cos(3 * t) - cos(4 * t)
            return (pow(sin(t), 3) * 1.05, -y / 16 - 0.13)
        }
    }

    /// Where hats sit: the top of the head, in units of the radius. Round Pip's is -0.94; the heart's is the dip
    /// between its lobes.
    var top: Double {
        self == .heart ? -0.7 : point(at: -.pi / 2).y
    }

    /// Where things for the neck sit: the bottom of the body. Round Pip's is 0.94.
    var bottom: Double {
        self == .heart ? 0.7 : point(at: .pi / 2).y
    }

    /// How far hats move from where they sit on round Pip, in units of the radius. Negative is up.
    var hatShift: Double { top - PipForm.round.top }

    /// How far things for the neck move from where they sit on round Pip, in units of the radius.
    var neckShift: Double { bottom - PipForm.round.bottom }

    /// `v` pushed toward ±1, which squares off a circle's sides.
    private static func squircle(_ v: Double, power: Double = 0.5) -> Double {
        v < 0 ? -pow(-v, power) : pow(v, power)
    }
}
