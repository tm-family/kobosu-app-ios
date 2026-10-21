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

    /// 撮影モードの scene で起動する（ScreenshotDemo.Scene の rawValue）
    @MainActor
    static func launchScreenshotScene(_ scene: String) -> XCUIApplication {
        launch(["-screenshot-demo", "-screenshot-scene", scene])
    }
}
