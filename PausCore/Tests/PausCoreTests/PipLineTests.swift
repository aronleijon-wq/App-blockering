import XCTest
@testable import PausCore

final class PipLineTests: XCTestCase {
    func testKeepsAShortLine() {
        XCTAssertEqual(PipLine.cleaned(" \"Ett fokuspass till, så blir jag pigg igen.\"\n"), "Ett fokuspass till, så blir jag pigg igen.")
    }

    func testDropsALongAnswer() {
        let reply = "Hello there! I'm Pip, your friendly social media blocker. I'm feeling a bit under the weather today, with a health score of 34 out of 100."
        XCTAssertNil(PipLine.cleaned(reply))
    }

    func testDropsQuestionsSincePipCantReply() {
        XCTAssertNil(PipLine.cleaned("Would you like some tips?"))
    }

    func testDropsIntroductions() {
        XCTAssertNil(PipLine.cleaned("Jag är Pip och jag mår bra."))
    }

    func testDropsALineCutOffMidSentence() {
        XCTAssertNil(PipLine.cleaned("Tre dagar i rad, bryt inte"))
    }

    func testDropsEmptyLines() {
        XCTAssertNil(PipLine.cleaned("  \n"))
    }
}
