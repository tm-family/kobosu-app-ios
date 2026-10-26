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

    /// 本文を書くだけで投稿でき（カテゴリは選ばなくてよい）、投稿するとモーダルが閉じる
    @MainActor
    func testPostingFromCompose() throws {
        let app = Self.launchAfterOnboarding()

        app.buttons["tab.compose"].tap()
        let submit = app.buttons["compose.submit"]
        XCTAssertTrue(submit.waitForExistence(timeout: 5))
        XCTAssertFalse(submit.isEnabled)

        let body = app.textViews.firstMatch
        XCTAssertTrue(body.waitForExistence(timeout: 5))
        body.tap()
        body.typeText("UI test")
        // カテゴリを選ばなくても、本文だけで投稿できる
        XCTAssertTrue(submit.isEnabled)

        submit.tap()
        // 投稿完了の画面から、きくに戻る
        let back = app.buttons["complete.back"]
        XCTAssertTrue(back.waitForExistence(timeout: 5))
        back.tap()
        XCTAssertTrue(back.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.buttons["tab.listen"].isSelected)
    }

    /// カテゴリの行の「変更」でシートを開き、選ぶと行に反映される。未分類も選べる
    @MainActor
    func testChangingCategoryFromRow() throws {
        let app = Self.launchAfterOnboarding()

        app.buttons["tab.compose"].tap()
        let row = app.buttons["compose.category.change"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        // 最初は推定も前回のカテゴリも無いので未分類
        XCTAssertTrue(row.label.contains("未分類") || row.label.contains("Uncategorized"), row.label)

        UITestApp.chooseCategory("money", in: app)
        XCTAssertTrue(row.label.contains("お金") || row.label.contains("Money"), row.label)

        // シートには未分類も出る。閉じるだけなら変わらない
        row.tap()
        XCTAssertTrue(app.buttons["compose.category.uncategorized"].waitForExistence(timeout: 5))
        app.buttons["category.sheet.close"].tap()
        XCTAssertTrue(app.buttons["compose.category.uncategorized"].waitForNonExistence(timeout: 5))
        XCTAssertTrue(row.label.contains("お金") || row.label.contains("Money"), row.label)
    }

    /// 「みんなに共有 · 24時間で消える」の行を押すと説明のシートが開き、閉じると投稿画面に戻る
    @MainActor
    func testOpeningPostSettingsSheet() throws {
        let app = Self.launchAfterOnboarding()

        app.buttons["tab.compose"].tap()
        let row = app.buttons["compose.settings"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        let close = app.buttons["compose.settings.close"]
        XCTAssertTrue(close.waitForExistence(timeout: 5))
        close.tap()
        XCTAssertTrue(close.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.buttons["compose.submit"].exists)
    }

    /// 未分類で投稿すると、投稿完了の画面でカテゴリを付けるよう問いかけ、付けると問いかけが消える。
    /// カテゴリありで投稿したときは問いかけない
    @MainActor
    func testAssigningCategoryFromComplete() throws {
        let app = Self.launchAfterOnboarding()

        // 推定できない本文・前回のカテゴリなし → 未分類で投稿する
        app.buttons["tab.compose"].tap()
        let body = app.textViews.firstMatch
        XCTAssertTrue(body.waitForExistence(timeout: 5))
        body.tap()
        body.typeText("UI test")
        app.buttons["compose.submit"].tap()
        let assign = app.buttons["complete.assign"]
        XCTAssertTrue(assign.waitForExistence(timeout: 5))
        assign.tap()
        // 付けるときは未分類を出さない
        let money = app.buttons["compose.category.money"]
        XCTAssertTrue(money.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["compose.category.uncategorized"].exists)
        money.tap()
        XCTAssertTrue(assign.waitForNonExistence(timeout: 5))

        // 続けてこぼす → 前回のカテゴリ（付けたお金）で投稿するので、問いかけない
        app.buttons["complete.continue"].tap()
        XCTAssertTrue(body.waitForExistence(timeout: 5))
        body.tap()
        body.typeText("UI test 2")
        app.buttons["compose.submit"].tap()
        XCTAssertTrue(app.buttons["complete.back"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["complete.assign"].exists)
    }

    /// 伏せ字の候補（電話番号）があると確認の画面に進み、伏せ字にした本文を見てから投稿できる
    @MainActor
    func testPostingThroughMaskingReview() throws {
        let app = Self.launchAfterOnboarding()

        app.buttons["tab.compose"].tap()
        let body = app.textViews.firstMatch
        XCTAssertTrue(body.waitForExistence(timeout: 5))
        body.tap()
        body.typeText("call 090-1234-5678")
        UITestApp.chooseCategory("other", in: app)
        app.buttons["compose.submit"].tap()

        let submit = app.buttons["masking.submit"]
        XCTAssertTrue(submit.waitForExistence(timeout: 5))
        let preview = app.staticTexts["masking.preview"]
        XCTAssertTrue(preview.label.contains("〇〇"))
        XCTAssertFalse(preview.label.contains("5678"))

        submit.tap()
        // 投稿完了の画面から、きくに戻る
        let back = app.buttons["complete.back"]
        XCTAssertTrue(back.waitForExistence(timeout: 5))
        back.tap()
        XCTAssertTrue(back.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.buttons["tab.listen"].isSelected)
    }

    /// ノートの右上から設定を開き、ライセンス表記を見て閉じる
    @MainActor
    func testOpeningSettingsFromNote() throws {
        let app = Self.launchAfterOnboarding()

        app.buttons["tab.note"].tap()
        let settings = app.buttons["note.settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 5))
        settings.tap()
        XCTAssertTrue(app.buttons["settings.erase"].waitForExistence(timeout: 5))
        app.buttons["settings.license"].tap()
        XCTAssertTrue(app.staticTexts["Zen Maru Gothic"].waitForExistence(timeout: 5))
        // シートの下のノートの画面にも戻るボタンは無いので、戻るボタン（BackButton）は 1 つだけ
        app.navigationBars.buttons["BackButton"].tap()
        let close = app.buttons["settings.close"]
        XCTAssertTrue(close.waitForExistence(timeout: 5))
        close.tap()
        XCTAssertTrue(close.waitForNonExistence(timeout: 5))
    }

    @MainActor
    func testSwitchingTabs() throws {
        let app = Self.launchAfterOnboarding()

        app.buttons["tab.note"].tap()
        XCTAssertTrue(app.buttons["tab.note"].isSelected)
        app.buttons["tab.listen"].tap()
        XCTAssertTrue(app.buttons["tab.listen"].isSelected)
    }

    /// 撮影モードのデモデータで、投稿に共感を送る
    @MainActor
    func testSendingStampFromTimeline() throws {
        let app = UITestApp.launchScreenshotScene("home")

        let post = app.buttons["post.preview-0"]
        XCTAssertTrue(post.waitForExistence(timeout: 5))
        post.tap()
        // 送ったスタンプは 2 回送れない
        UITestApp.sendStamp("understand", otherStamp: "same_here", in: app)
    }

    /// 撮影モードのデモデータで、共感のシートから通報すると、その投稿がタイムラインから消える
    @MainActor
    func testReportingFromEmpathySheet() throws {
        let app = UITestApp.launchScreenshotScene("home")

        let post = app.buttons["post.preview-0"]
        XCTAssertTrue(post.waitForExistence(timeout: 5))
        post.tap()
        let report = app.buttons["empathy.report"]
        XCTAssertTrue(report.waitForExistence(timeout: 5))
        report.tap()

        let submit = app.buttons["report.submit"]
        XCTAssertTrue(submit.waitForExistence(timeout: 5))
        // 理由を選ぶまでは通報できない
        XCTAssertFalse(submit.isEnabled)
        app.buttons["report.reason.spam"].tap()
        XCTAssertTrue(submit.isEnabled)
        submit.tap()

        XCTAssertTrue(submit.waitForNonExistence(timeout: 5))
        XCTAssertTrue(post.waitForNonExistence(timeout: 5))
    }

    @MainActor
    func testOnboardingRequiresAgreement() throws {
        // 初回の画面を出す（同意していない状態にしてから起動する）
        let app = UITestApp.launch([UITestApp.resetOnboarding])

        let start = app.buttons["onboarding.start"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        start.tap()
        let agree = app.buttons["onboarding.agree"]
        XCTAssertTrue(agree.waitForExistence(timeout: 5))
        XCTAssertFalse(agree.isEnabled)
        app.descendants(matching: .any)["onboarding.promiseCheck"].firstMatch.tap()
        XCTAssertTrue(agree.isEnabled)
        agree.tap()
        // アプリロックの設定は、あとで設定する（Simulator では Face ID を確かめられないため）
        let later = app.buttons["onboarding.lockLater"]
        XCTAssertTrue(later.waitForExistence(timeout: 5))
        later.tap()
        XCTAssertTrue(app.buttons["tab.listen"].waitForExistence(timeout: 5))
    }

    /// やさしさの約束に同意した状態で起動する
    @MainActor
    private static func launchAfterOnboarding() -> XCUIApplication {
        UITestApp.launch([UITestApp.skipOnboarding])
    }
}
