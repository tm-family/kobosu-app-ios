//
//  KobosuUITestsLaunchTests.swift
//  KobosuUITests
//
//  Created by 村石 拓海 on 2024/05/12.
//

import XCTest

final class KobosuUITestsLaunchTests: XCTestCase {
    override static var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        // Firebase につながずに起動する（FirebaseSetup.uiTestArgument）
        app.launchArguments += ["-uitest-without-firebase"]
        app.launch()

        // 起動直後のスクリーンショットをテスト結果に添付する
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
