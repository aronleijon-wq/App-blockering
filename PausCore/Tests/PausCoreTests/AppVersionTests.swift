import XCTest
@testable import PausCore

final class AppVersionTests: XCTestCase {
    func testComparesPartByPartAsNumbers() {
        XCTAssertTrue(AppVersion.isOlder("2.9", than: "2.10"))
        XCTAssertTrue(AppVersion.isOlder("2.5", than: "2.6"))
        XCTAssertFalse(AppVersion.isOlder("2.6", than: "2.6.0"))
        XCTAssertFalse(AppVersion.isOlder("3.0", than: "2.12"))
        XCTAssertTrue(AppVersion.isOlder("2.6", than: "2.6.1"))
    }

    func testAMinimumWinsOverANewerVersion() {
        XCTAssertEqual(AppVersion.need(current: "2.6", latest: "2.6", minimum: nil), .none)
        XCTAssertEqual(AppVersion.need(current: "2.6", latest: "2.7", minimum: "2.5"), .optional(latest: "2.7"))
        XCTAssertEqual(AppVersion.need(current: "2.6", latest: "2.8", minimum: "2.7"), .required(minimum: "2.7"))
        XCTAssertEqual(AppVersion.need(current: "2.6", latest: nil, minimum: nil), .none, "offline")
    }
}
