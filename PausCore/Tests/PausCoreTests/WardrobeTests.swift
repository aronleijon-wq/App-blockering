import XCTest
@testable import PausCore

final class WardrobeTests: XCTestCase {
    func testShirtsAndShapesRideAlongInTheLeagueCode() {
        let outfit = Outfit(hat: "hat-cap", color: "color-neon", shirt: "shirt-flag-NO", shape: "shape-tall")
        XCTAssertEqual(outfit.code, "hat-cap||||color-neon|shirt-flag-NO|shape-tall")
        XCTAssertEqual(Outfit(code: outfit.code), outfit)
        XCTAssertEqual(Outfit(shirt: "shirt-hoodie").code, "|||||shirt-hoodie")
        XCTAssertEqual(Outfit(shape: "shape-heart").code, "||||||shape-heart")
        XCTAssertEqual(Outfit(code: "||||||shape-heart"), Outfit(shape: "shape-heart"))
        XCTAssertEqual(Outfit(hat: "hat-cap").code, "hat-cap||||", "outfits without a shirt or shape keep the code older apps know")

        // Out of place, or a flag of no country: dropped.
        XCTAssertEqual(Outfit(code: "|||||shape-tall|shirt-white"), .none)
        XCTAssertEqual(Outfit(code: "|||||shirt-flag-XYZ"), .none)
        XCTAssertEqual(Outfit(code: "|||||shirt-flag-se"), .none)
    }

    func testOldSavedOutfitsHaveNoShirtOrShape() throws {
        let outfit = try JSONDecoder().decode(Outfit.self, from: Data(#"{"hat": "hat-cap"}"#.utf8))
        XCTAssertEqual(outfit, Outfit(hat: "hat-cap"))
        XCTAssertNil(outfit.shirt)
        XCTAssertNil(outfit.shape)
    }

    func testTheFlagShirtShowsTheCountryItWasPutOnWith() {
        let shirt = WardrobeItem.with(id: WardrobeItem.flagShirt)!
        var progress = PlayerProgress()
        progress.seeds = 1_000
        XCTAssertEqual(progress.buy(shirt, isPro: false), .bought)
        XCTAssertNil(progress.outfit.shirt)

        progress.toggle(shirt, country: "NO")
        XCTAssertEqual(progress.outfit.shirt, "shirt-flag-NO")
        XCTAssertTrue(progress.outfit.wears(shirt))
        XCTAssertEqual(WardrobeItem.with(id: "shirt-flag-NO"), shirt)
        XCTAssertEqual(WardrobeItem.flagCountry(of: progress.outfit.shirt), "NO")
        XCTAssertNil(WardrobeItem.flagCountry(of: "shirt-white"))

        progress.wearFlagShirt(of: "FI")
        XCTAssertEqual(progress.outfit.shirt, "shirt-flag-FI")
        progress.toggle(shirt, country: "SE")
        XCTAssertNil(progress.outfit.shirt, "tapping it again takes it off")

        let hoodie = WardrobeItem.with(id: "shirt-hoodie")!
        _ = progress.buy(hoodie, isPro: false)
        progress.toggle(hoodie)
        XCTAssertFalse(progress.outfit.wears(shirt))
        progress.wearFlagShirt(of: "DK")
        XCTAssertEqual(progress.outfit.shirt, "shirt-flag-DK", "picking a flag puts the flag shirt on")

        var other = PlayerProgress()
        other.wearFlagShirt(of: "DK")
        XCTAssertNil(other.outfit.shirt, "only for those who own it")
    }

    func testEveryShapeItemHasAForm() {
        let shapes = WardrobeItem.all.filter { $0.kind == .shape }
        XCTAssertEqual(Set(shapes.map(\.id)), Set(PipForm.allCases.map(\.itemID)))
        XCTAssertEqual(PipForm(item: nil), .round)
        XCTAssertEqual(PipForm(item: "shape-heart"), .heart)
        XCTAssertEqual(PipForm(item: "hat-cap"), .round)
        XCTAssertTrue(WardrobeItem.with(id: "shape-round")!.isFree)
        XCTAssertEqual(Outfit(wearing: WardrobeItem.with(id: "shape-ghost")!).shape, "shape-ghost")
        XCTAssertEqual(Outfit(wearing: WardrobeItem.with(id: WardrobeItem.flagShirt)!, country: "IS").shirt, "shirt-flag-IS")
    }

    func testEveryFormFitsInPipsFrameAndHoldsTheFace() {
        for form in PipForm.allCases {
            let points = (0..<240).map { form.point(at: Double($0) / 240 * 2 * .pi) }
            let reach = points.map { max(abs($0.x), abs($0.y)) }.max() ?? 0
            XCTAssertLessThanOrEqual(reach, 1.11, "\(form) leaves the frame")
            // The eyes' outer edges, the mouth and the shirt just below it.
            for (x, y) in [(-0.62, -0.16), (0.62, -0.16), (0.0, 0.3), (-0.3, 0.44), (0.3, 0.44)] {
                XCTAssertTrue(contains(points, x: x, y: y), "\(form) leaves out (\(x), \(y))")
            }
            XCTAssertLessThan(form.top, -0.6)
            XCTAssertGreaterThan(form.bottom, 0.6)
        }
        XCTAssertEqual(PipForm.round.hatShift, 0, accuracy: 0.0001)
        XCTAssertEqual(PipForm.round.neckShift, 0, accuracy: 0.0001)
        XCTAssertLessThan(PipForm.tall.hatShift, 0, "hats go up on tall Pip")
        XCTAssertLessThan(PipForm.wide.neckShift, 0, "and things for the neck go up on wide Pip")
    }

    func testEveryItemHasAUniqueID() {
        let ids = WardrobeItem.all.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
        XCTAssertFalse(WardrobeItem.all.filter { $0.kind == .shirt }.isEmpty)
    }

    /// Whether the point is inside the polygon, by counting the edges a ray to the right crosses.
    private func contains(_ polygon: [(x: Double, y: Double)], x: Double, y: Double) -> Bool {
        var inside = false
        var j = polygon.count - 1
        for i in polygon.indices {
            let a = polygon[i], b = polygon[j]
            if (a.y > y) != (b.y > y) && x < (b.x - a.x) * (y - a.y) / (b.y - a.y) + a.x {
                inside.toggle()
            }
            j = i
        }
        return inside
    }
}
