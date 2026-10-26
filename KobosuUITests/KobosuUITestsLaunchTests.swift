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
        // 構成ごとの実行では横向きにもするので、あとのテストが横向きのまま始まらないよう縦向きに戻す
        // （横向きでキーボードが出ると、投稿画面のカテゴリの行が画面の外になって押せない）
        addTeardownBlock { @MainActor in
            XCUIDevice.shared.orientation = .portrait
        }

        // Firebase につながずに起動する
        let app = UITestApp.launch()

        // 起動直後のスクリーンショットをテスト結果に添付する
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
