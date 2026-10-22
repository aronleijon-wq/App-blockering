import XCTest
@testable import PausCore

final class IntroTests: XCTestCase {
    func testMatchesTheAd() {
        // Six hours a day from 15 to 80 is "almost 25 years of your waking life".
        XCTAssertEqual(LifeMath.wakingYears(hoursPerDay: 6, age: 15), 24.375, accuracy: 0.001)
    }

    func testWakingYears() {
        XCTAssertEqual(LifeMath.wakingYears(hoursPerDay: 4, age: 21), 14.75, accuracy: 0.001)
        XCTAssertEqual(LifeMath.wakingYears(hoursPerDay: 4, age: 90), 0)
    }

    func testYearlyNumbers() {
        XCTAssertEqual(LifeMath.hoursPerYear(hoursPerDay: 4.5), 1643)
        XCTAssertEqual(LifeMath.daysPerYear(hoursPerDay: 4.5), 68)
        XCTAssertEqual(LifeMath.shareOfWakingTime(hoursPerDay: 4), 0.25, accuracy: 0.0001)
        XCTAssertEqual(LifeMath.shareOfWakingTime(hoursPerDay: 20), 1)
    }

    func testAnswersRoundTrip() throws {
        let answers = IntroAnswers(name: "Aron", ageGroup: .from25, hoursPerDay: 5.5, apps: ["TikTok"], goals: ["Plugga"])
        let decoded = try JSONDecoder().decode(IntroAnswers.self, from: JSONEncoder().encode(answers))
        XCTAssertEqual(decoded, answers)
    }
}
