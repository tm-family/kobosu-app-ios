//
//  MainFlowUITests.swift
//  KobosuUITests
//
//  主要な導線（初回起動 → 投稿 → タイムライン → 共感 → 通報）を、1 本の流れで確かめる。
//  他の人の投稿は、起動引数でローカルの実装に置いたデモデータ（preview-0〜4）を使う。
//  Simulator にはパスコードが無くアプリロックが働かないので、ロックはここでは確かめない。
//

import XCTest

final class MainFlowUITests: XCTestCase {
    /// 長押しのメニューの「通報・表示しない」（ja / en）
    private static let reportMenuLabels = ["通報・表示しない", "Report or hide"]

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testFirstLaunchToPostEmpathyAndReport() throws {
        let app = UITestApp.launch([UITestApp.resetOnboarding, UITestApp.seedPosts])

        // 初回の画面: ようこそ → やさしさの約束に同意 → アプリロックはあとで
        let start = app.buttons["onboarding.start"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        start.tap()
        let promiseCheck = app.descendants(matching: .any)["onboarding.promiseCheck"].firstMatch
        let agree = app.buttons["onboarding.agree"]
        XCTAssertTrue(promiseCheck.waitForExistence(timeout: 5))
        XCTAssertTrue(agree.waitForExistence(timeout: 5))
        promiseCheck.tap()
        XCTAssertTrue(agree.isEnabled)
        agree.tap()
        let later = app.buttons["onboarding.lockLater"]
        XCTAssertTrue(later.waitForExistence(timeout: 5))
        later.tap()

        // 投稿する
        let body = "きょうは ごはんを つくって くたくた"
        Self.post(body, category: "housework", in: app)

        // 自分の投稿がタイムラインに出る。タップしても共感のシートは開かない
        let myPost = Self.myPost(in: app, containing: body)
        XCTAssertTrue(myPost.waitForExistence(timeout: 5))
        myPost.tap()
        XCTAssertFalse(app.buttons["empathy.understand"].waitForExistence(timeout: 2))

        // 他の人の投稿に共感を送る。送ったスタンプは 2 回送れない
        let post = app.buttons["post.preview-0"]
        XCTAssertTrue(post.waitForExistence(timeout: 5))
        post.tap()
        UITestApp.sendStamp("understand", otherStamp: "same_here", in: app)

        // 同じシートから通報すると、その投稿はタイムラインから消える
        app.buttons["empathy.report"].tap()
        let submit = app.buttons["report.submit"]
        XCTAssertTrue(submit.waitForExistence(timeout: 5))
        app.buttons["report.reason.spam"].tap()
        submit.tap()
        XCTAssertTrue(submit.waitForNonExistence(timeout: 5))
        XCTAssertTrue(post.waitForNonExistence(timeout: 5))
        // 自分の投稿と、ほかの人の投稿は残る
        XCTAssertTrue(myPost.exists)
        XCTAssertTrue(app.buttons["post.preview-1"].exists)
    }

    /// 長押しのメニューから「この投稿を表示しない」にすると、その投稿はタイムラインから消える
    @MainActor
    func testHidingFromLongPressMenu() throws {
        let app = UITestApp.launch([UITestApp.skipOnboarding, UITestApp.seedPosts])

        let post = app.buttons["post.preview-1"]
        XCTAssertTrue(post.waitForExistence(timeout: 5))
        post.press(forDuration: 1.0)
        let menu = Self.reportMenuItem(in: app)
        XCTAssertTrue(menu.waitForExistence(timeout: 5))
        menu.tap()

        let hide = app.buttons["report.hide"]
        XCTAssertTrue(hide.waitForExistence(timeout: 5))
        hide.tap()
        XCTAssertTrue(hide.waitForNonExistence(timeout: 5))
        XCTAssertTrue(post.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.buttons["post.preview-0"].exists)
    }

    /// 自分の投稿には、長押しのメニュー（通報・表示しない）が出ない
    @MainActor
    func testOwnPostHasNoReportMenu() throws {
        let app = UITestApp.launch([UITestApp.skipOnboarding, UITestApp.seedPosts])

        let body = "せんたくものを たたんで ひとやすみ"
        Self.post(body, category: "other", in: app)

        let myPost = Self.myPost(in: app, containing: body)
        XCTAssertTrue(myPost.waitForExistence(timeout: 5))
        myPost.press(forDuration: 1.0)
        XCTAssertFalse(Self.reportMenuItem(in: app).waitForExistence(timeout: 2))
        XCTAssertFalse(app.buttons["report.submit"].exists)
    }

    /// 投稿の画面を開いて投稿し、投稿完了の画面から、きくに戻る。
    /// 本文は伏せ字の候補が出ないひらがなにする。確認の画面に進むと本文が伏せられて、自分の投稿を本文で探せなくなるため、
    /// 確認の画面に進んだら失敗にする（伏せ字の検知はユニットテストで確かめる）
    @MainActor
    private static func post(_ body: String, category: String, in app: XCUIApplication) {
        let compose = app.buttons["tab.compose"]
        XCTAssertTrue(compose.waitForExistence(timeout: 5))
        compose.tap()
        let text = app.textViews.firstMatch
        XCTAssertTrue(text.waitForExistence(timeout: 5))
        text.tap()
        text.typeText(body)
        UITestApp.chooseCategory(category, in: app)
        app.buttons["compose.submit"].tap()
        let back = app.buttons["complete.back"]
        XCTAssertTrue(back.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["masking.submit"].exists)
        back.tap()
        XCTAssertTrue(back.waitForNonExistence(timeout: 5))
    }

    /// タイムラインの自分の投稿（ListenView の post.mine.<id>）
    @MainActor
    private static func myPost(in app: XCUIApplication, containing body: String) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'post.mine.' AND label CONTAINS %@", body))
            .firstMatch
    }

    /// 長押しのメニューの「通報・表示しない」。メニューの項目に識別子が付かない OS でも見つかるよう、文言でも探す
    @MainActor
    private static func reportMenuItem(in app: XCUIApplication) -> XCUIElement {
        app.buttons
            .matching(NSPredicate(format: "identifier == 'post.menu.report' OR label IN %@", reportMenuLabels))
            .firstMatch
    }
}
