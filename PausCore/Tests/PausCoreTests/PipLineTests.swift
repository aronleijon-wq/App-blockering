import XCTest
@testable import PausCore

final class PipLineTests: XCTestCase {
    func testKeepsAGreetingAndATip() {
        let line = "Hej Aron! Tre dagar i rad nu. Lägg mobilen i ett annat rum när du pluggar."
        XCTAssertEqual(PipLine.cleaned(" \"\(line)\"\n"), line)
    }

    func testTakesOutQuestionsAndIntroductions() {
        let reply = "Hej Aron!\n\n\nJag är Pip. Jag kan se att du är sömnig. Jag vill hjälpa dig att få mer fokus. Hur mår du idag? Vad kan jag göra för att hjälpa dig?"
        XCTAssertEqual(PipLine.cleaned(reply), "Hej Aron! Jag kan se att du är sömnig. Jag vill hjälpa dig att få mer fokus.")
    }

    func testTakesOutOffersInEnglish() {
        let reply = "Hi Aron! I'm Pip, your friendly blocker. You have been scrolling a lot today. Would you like some tips?"
        XCTAssertEqual(PipLine.cleaned(reply), "Hi Aron! You have been scrolling a lot today.")
    }

    func testTakesOutANamePlaceholder() {
        XCTAssertEqual(
            PipLine.cleaned("Hej \\[namn]! Det kan hjälpa dig att fokusera bättre på skolarbetet."),
            "Hej! Det kan hjälpa dig att fokusera bättre på skolarbetet."
        )
        XCTAssertEqual(
            PipLine.cleaned("Hi [name], put your phone in another room while you study."),
            "Hi, put your phone in another room while you study."
        )
    }

    func testDropsALineThatIsOnlyAGreetingOnceQuestionsAreGone() {
        XCTAssertNil(PipLine.cleaned("Hej Aron! Hur mår du?"))
    }

    func testDropsAnAnswerTooLongForTheBubble() {
        let reply = Array(repeating: "Scrolling less is good for you.", count: 15).joined(separator: " ")
        XCTAssertNil(PipLine.cleaned(reply))
    }

    func testDropsALineCutOffMidSentence() {
        XCTAssertNil(PipLine.cleaned("Tre dagar i rad, bryt inte"))
    }

    func testDropsEmptyLines() {
        XCTAssertNil(PipLine.cleaned("  \n"))
    }
}
