//
//  ScreenshotSceneUITests.swift
//  KobosuUITests
//
//  撮影モードの scene（AppStore/screenshots.json）が、それぞれ撮りたい画面で開くことを確かめる。
//  撮影の CI は画像の寸法しか見ないので、違う画面が写っても気づけるようにする。
//

import XCTest

final class ScreenshotSceneUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// きく: デモの投稿が並ぶ
    @MainActor
    func testHomeScene() throws {
        let app = UITestApp.launchScreenshotScene("home")

        XCTAssertTrue(app.buttons["post.preview-0"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["tab.listen"].isSelected)
    }

    /// 共感を送る: 起動するとハーフシートが開いている
    @MainActor
    func testEmpathyScene() throws {
        let app = UITestApp.launchScreenshotScene("empathy")

        XCTAssertTrue(app.buttons["empathy.understand"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["empathy.report"].exists)
    }

    /// 投稿: 起動すると投稿の画面が開き、書きかけの下書きが入っている
    @MainActor
    func testComposeScene() throws {
        let app = UITestApp.launchScreenshotScene("compose")

        let submit = app.buttons["compose.submit"]
        XCTAssertTrue(submit.waitForExistence(timeout: 5))
        // 下書きの本文とカテゴリが入っているので、そのまま投稿できる
        XCTAssertTrue(submit.isEnabled)
    }

    /// ノート: 自分の投稿が出ている
    @MainActor
    func testNoteScene() throws {
        let app = UITestApp.launchScreenshotScene("note")

        XCTAssertTrue(app.buttons["note.settings"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["note.delete.screenshot-demo-mine"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["tab.note"].isSelected)
    }

    /// ようこそ: 初回の画面が開き、ロック画面は出ない
    @MainActor
    func testWelcomeScene() throws {
        let app = UITestApp.launchScreenshotScene("welcome")

        XCTAssertTrue(app.buttons["onboarding.start"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["lock.unlock"].exists)
    }
}
