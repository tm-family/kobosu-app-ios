//
//  UITestApp.swift
//  KobosuUITests
//
//  UI テストでアプリを起動する共通の処理。起動引数の意味はアプリ側の FirebaseSetup・OnboardingStatus・UITestLaunch・ScreenshotDemo を見る。
//

import XCTest

enum UITestApp {
    /// Firebase につながない（FirebaseSetup.uiTestArgument）。UI テストはすべてこれを付けて起動する
    static let withoutFirebase = "-uitest-without-firebase"
    /// 前のテストの下書きを消す（UITestLaunch.clearDraftArgument）
    static let clearDraft = "-uitest-clear-draft"
    /// 同意していない状態で起動する（OnboardingStatus.resetArgument）
    static let resetOnboarding = "-uitest-reset-onboarding"
    /// 同意した状態で、アプリロックをオフにして起動する（OnboardingStatus.skipArgument）
    static let skipOnboarding = "-uitest-skip-onboarding"
    /// 他の人の投稿を置いて起動する（UITestLaunch.seedPostsArgument）
    static let seedPosts = "-uitest-seed-posts"

    /// Firebase につながず、下書きを消してから起動する
    @MainActor
    static func launch(_ arguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [withoutFirebase, clearDraft] + arguments
        app.launch()
        return app
    }

    /// 投稿画面のカテゴリの行の「変更」からシートを開き、category（PostCategory の rawValue）を選ぶ。選ぶとシートは閉じる
    @MainActor
    static func chooseCategory(_ category: String, in app: XCUIApplication) {
        let change = app.buttons["compose.category.change"]
        XCTAssertTrue(change.waitForExistence(timeout: 5))
        change.tap()
        let chip = app.buttons["compose.category.\(category)"]
        XCTAssertTrue(chip.waitForExistence(timeout: 5))
        chip.tap()
        XCTAssertTrue(chip.waitForNonExistence(timeout: 5))
    }

    /// 撮影モードの scene で起動する（ScreenshotDemo.Scene の rawValue）
    @MainActor
    static func launchScreenshotScene(_ scene: String) -> XCUIApplication {
        launch(["-screenshot-demo", "-screenshot-scene", scene])
    }

    /// 共感のシートが開いているときに stamp を送り、送れたことと、2 回は送れないことを確かめる。
    /// 送っている間は、すべてのスタンプが押せなくなる（EmpathySheet の sending）。
    /// ほかのスタンプが押せるように戻ったら送り終えた印なので、そのあとで送ったスタンプを見る
    @MainActor
    static func sendStamp(_ stamp: String, otherStamp: String, in app: XCUIApplication) {
        let button = app.buttons["empathy.\(stamp)"]
        let other = app.buttons["empathy.\(otherStamp)"]
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        XCTAssertTrue(button.isEnabled)
        XCTAssertTrue(other.isEnabled)
        button.tap()

        let finished = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isEnabled == true"), object: other)
        XCTAssertEqual(XCTWaiter.wait(for: [finished], timeout: 5), .completed)
        XCTAssertFalse(button.isEnabled)
        // 送った印（String Catalog の「送りました」。en は Sent）
        XCTAssertTrue(sentStampValues.contains(button.value as? String ?? ""))
    }

    /// 送ったスタンプの accessibilityValue（ja / en）
    static let sentStampValues = ["送りました", "Sent"]
}
