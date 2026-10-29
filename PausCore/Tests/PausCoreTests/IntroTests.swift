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

    func testCountsFromTheYoungestAgeInTheGroup() {
        XCTAssertEqual(AgeGroup.under18.youngestAge, 13)
        XCTAssertEqual(AgeGroup.from18.youngestAge, 18)
        XCTAssertEqual(AgeGroup.from55.youngestAge, 55)
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

    func testPlan() {
        XCTAssertEqual(Plan.targetHours(from: 5), 2.5, accuracy: 0.001)
        XCTAssertEqual(Plan.yearsBack(hoursPerDay: 6, age: 15), 24.375 * 0.5, accuracy: 0.001)
        XCTAssertEqual(Plan.daysBackPerYear(hoursPerDay: 5), 38)
        // 5 h on the phone leaves 11 waking hours; winning back 2.5 h is about 23 % more offline time.
        XCTAssertEqual(Plan.offlineIncrease(hoursPerDay: 5), 2.5 / 11, accuracy: 0.0001)
        XCTAssertEqual(Plan.offlineIncrease(hoursPerDay: 16), 0)
    }

    func testTrialReminder() {
        let calendar = TestCalendar.stockholm
        let now = TestCalendar.date(2026, 10, 22, 16, 0)
        let trialEnd = TestCalendar.date(2026, 10, 29, 16, 0)
        XCTAssertEqual(TrialReminder.date(trialEnd: trialEnd, daysBefore: 2, now: now, calendar: calendar), TestCalendar.date(2026, 10, 27, 10, 0))
        XCTAssertEqual(TrialReminder.date(trialEnd: trialEnd, daysBefore: 3, now: now, calendar: calendar), TestCalendar.date(2026, 10, 26, 10, 0))
        XCTAssertNil(TrialReminder.date(trialEnd: TestCalendar.date(2026, 10, 23, 16, 0), daysBefore: 2, now: now, calendar: calendar))
    }
}
