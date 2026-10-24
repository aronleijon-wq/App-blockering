import XCTest
@testable import PausCore

final class PipLineTests: XCTestCase {
    func testKeepsAGreetingAndSeveralSentences() {
        let line = "Hej Aron! Tre dagar i rad nu. Vem hade trott det?"
        XCTAssertEqual(PipLine.cleaned(" \"\(line)\"\n"), line)
    }

    func testDropsQuestionsThatWaitForAnAnswer() {
        XCTAssertNil(PipLine.cleaned("Hi Aron! I'm feeling a bit down. Would you like some tips on managing your time?"))
        XCTAssertNil(PipLine.cleaned("Jag mår inte så bra. Vill du att jag ger dig ett tips?"))
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
