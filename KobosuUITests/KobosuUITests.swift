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
        let app = Self.launchAfterOnboarding()

        XCTAssertTrue(app.buttons["tab.listen"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["tab.note"].exists)
        XCTAssertTrue(app.buttons["tab.compose"].exists)
    }

    @MainActor
    func testComposeButtonOpensAndClosesModal() throws {
        let app = Self.launchAfterOnboarding()

        app.buttons["tab.compose"].tap()
        let cancel = app.buttons["compose.cancel"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 5))
        cancel.tap()
        XCTAssertTrue(cancel.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.buttons["tab.listen"].exists)
    }

    @MainActor
    func testSwitchingTabs() throws {
        let app = Self.launchAfterOnboarding()

        app.buttons["tab.note"].tap()
        XCTAssertTrue(app.buttons["tab.note"].isSelected)
        app.buttons["tab.listen"].tap()
        XCTAssertTrue(app.buttons["tab.listen"].isSelected)
    }

    @MainActor
    func testOnboardingRequiresAgreement() throws {
        let app = XCUIApplication()
        // 初回の画面を出す（同意していない状態にしてから起動する）
        app.launchArguments += ["-uitest-reset-onboarding"]
        app.launch()

        let start = app.buttons["onboarding.start"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        start.tap()
        let agree = app.buttons["onboarding.agree"]
        XCTAssertTrue(agree.waitForExistence(timeout: 5))
        XCTAssertFalse(agree.isEnabled)
        app.descendants(matching: .any)["onboarding.promiseCheck"].firstMatch.tap()
        XCTAssertTrue(agree.isEnabled)
        agree.tap()
        XCTAssertTrue(app.buttons["tab.listen"].waitForExistence(timeout: 5))
    }

    /// やさしさの約束に同意した状態で起動する
    @MainActor
    private static func launchAfterOnboarding() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-uitest-skip-onboarding"]
        app.launch()
        return app
    }
}
