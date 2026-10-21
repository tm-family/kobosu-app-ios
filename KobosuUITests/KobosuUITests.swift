//
//  KobosuUITests.swift
//  KobosuUITests
//
//  Created by 村石 拓海 on 2024/05/12.
//

import XCTest

final class KobosuUITests: XCTestCase {
    override func setUpWithError() throws {
        // UI テストでは失敗した時点で即座に止める
        continueAfterFailure = false
    }

    @MainActor
    func testLaunchShowsTabs() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.buttons["tab.listen"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["tab.note"].exists)
        XCTAssertTrue(app.buttons["tab.compose"].exists)
    }

    @MainActor
    func testComposeButtonOpensAndClosesModal() throws {
        let app = XCUIApplication()
        app.launch()

        app.buttons["tab.compose"].tap()
        let cancel = app.buttons["compose.cancel"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 5))
        cancel.tap()
        XCTAssertTrue(app.buttons["tab.listen"].waitForExistence(timeout: 5))
        XCTAssertFalse(cancel.exists)
    }

    @MainActor
    func testSwitchingTabs() throws {
        let app = XCUIApplication()
        app.launch()

        app.buttons["tab.note"].tap()
        XCTAssertTrue(app.buttons["tab.note"].isSelected)
        app.buttons["tab.listen"].tap()
        XCTAssertTrue(app.buttons["tab.listen"].isSelected)
    }
}
