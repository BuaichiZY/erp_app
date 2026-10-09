import XCTest
@testable import ERP

final class ERPRulesTests: XCTestCase {
    func testProfileQRRejectsForeignHosts() {
        XCTAssertEqual(ERPRules.profileID("https://erp.sex/likes?u=abc_123"), "abc_123")
        XCTAssertNil(ERPRules.profileID("https://erp.sex.evil.example/likes?u=abc"))
        XCTAssertNil(ERPRules.profileID("http://erp.sex/likes?u=abc"))
        XCTAssertNil(ERPRules.profileID("https://attacker@erp.sex/likes?u=abc"))
    }
    func testSwipeDirection() {
        XCTAssertEqual(ERPRules.swipe(x: -150, y: 12), "pass")
        XCTAssertEqual(ERPRules.swipe(x: 150, y: 12), "like")
        XCTAssertEqual(ERPRules.swipe(x: 0, y: -150), "superlike")
        XCTAssertNil(ERPRules.swipe(x: 0, y: 150))
    }
    func testLocaleSelection() {
        XCTAssertEqual(LanguageSupport.resolve("auto", preferred: ["zh-TW"]), "zh-Hant")
        XCTAssertEqual(LanguageSupport.resolve("auto", preferred: ["ja-JP"]), "ja")
        XCTAssertEqual(LanguageSupport.resolve("en", preferred: ["ko-KR"]), "en")
    }
    func testReleaseOrdering() {
        XCTAssertTrue(ERPRules.newer("v1.4.0_beta", than: "1.3.0"))
        XCTAssertFalse(ERPRules.newer("v1.2.0_beta", than: "1.3.0"))
    }
}
