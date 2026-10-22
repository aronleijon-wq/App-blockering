import XCTest
@testable import PausCore

final class LocalizationTests: XCTestCase {
    override func tearDown() {
        Language.override = nil
        super.tearDown()
    }

    func testSwedishIsTheSource() {
        Language.override = .sv
        XCTAssertEqual(L("Fokuspass"), "Fokuspass")
        let level = 3
        XCTAssertEqual(L("Nivå \(level)"), "Nivå 3")
    }

    func testEnglish() {
        Language.override = .en
        XCTAssertEqual(L("Fokuspass"), "Focus session")
        let level = 3
        XCTAssertEqual(L("Nivå \(level)"), "Level 3")
        XCTAssertEqual(Level.title(for: 1), "Scroll Zombie")
        XCTAssertEqual(PipHealth.Stage.great.label, "Happy and lively")
    }

    func testPercentSigns() {
        let share = 14
        Language.override = .sv
        XCTAssertEqual(L("**\(share) %** mer vaken tid offline, till att \("läsa")."), "**14 %** mer vaken tid offline, till att läsa.")
        Language.override = .en
        XCTAssertEqual(L("30 % mindre skärmtid"), "30 % less screen time")
    }

    func testMissingTranslationFallsBackToSwedish() {
        Language.override = .en
        XCTAssertEqual(L("Den här texten finns inte"), "Den här texten finns inte")
    }

    func testFill() {
        XCTAssertEqual(Translations.fill("%@ av %@", with: ["1", "3"]), "1 av 3")
        XCTAssertEqual(Translations.fill("%2$@ then %1$@", with: ["a", "b"]), "b then a")
        XCTAssertEqual(Translations.fill("100 %%", with: []), "100 %")
    }

    func testEveryTranslationKeepsItsPlaceholders() {
        for (swedish, english) in Translations.english {
            XCTAssertEqual(swedish.components(separatedBy: "%@").count, english.components(separatedBy: "%@").count, swedish)
        }
    }
}
