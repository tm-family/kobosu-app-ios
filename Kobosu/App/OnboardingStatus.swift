//
//  OnboardingStatus.swift
//  Kobosu
//
//  初回の画面（ようこそ・やさしさの約束）を出すかどうか。同意した約束の版を UserDefaults にだけ保存する。
//

import Foundation

nonisolated enum OnboardingStatus {
    /// 同意した約束の版を保存するキー
    static let agreedVersionKey = "onboarding.agreedPromiseVersion"

    /// UI テスト用の起動引数。同意していない状態で起動する
    static let resetArgument = "-uitest-reset-onboarding"
    /// UI テスト用の起動引数。同意した状態で起動する
    static let skipArgument = "-uitest-skip-onboarding"

    /// 初回の画面を出すか。撮影モードでは出さない
    static func needsOnboarding(agreedVersion: Int, isScreenshotDemo: Bool) -> Bool {
        !isScreenshotDemo && agreedVersion < PromiseRule.currentVersion
    }

    /// UI テストの起動引数に合わせて、同意した版とアプリロックの設定を書き換える。
    /// 値そのものを起動引数で渡すと、アプリが書き込んだ値より引数が優先されてしまうため、起動時に書き換える形にしている。
    /// 同意した状態で起動するときは、アプリロックをオフにする（テストの順番でロック画面に止まらないように）
    static func applyLaunchArguments(_ arguments: [String], to defaults: UserDefaults) {
        if arguments.contains(resetArgument) {
            defaults.removeObject(forKey: agreedVersionKey)
            defaults.removeObject(forKey: AppLockSettings.enabledKey)
        }
        if arguments.contains(skipArgument) {
            defaults.set(PromiseRule.currentVersion, forKey: agreedVersionKey)
            defaults.set(false, forKey: AppLockSettings.enabledKey)
        }
    }
}
