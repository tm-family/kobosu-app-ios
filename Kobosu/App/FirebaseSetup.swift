//
//  FirebaseSetup.swift
//  Kobosu
//
//  Firebase（Auth・Firestore）を使う準備。GoogleService-Info.plist はリポジトリに無い（人間が用意する）。
//  plist が無いとき・撮影モード・テスト中は Firebase につながず、ローカル（インメモリ）の実装で動かす。
//

import FirebaseCore
import Foundation

nonisolated enum FirebaseSetup {
    /// Firebase の設定ファイルの名前
    static let configFileName = "GoogleService-Info"

    /// Firebase につなぐか。plist があり、撮影モードでも、テスト中でもないとき
    static func shouldConfigure(
        hasConfigFile: Bool,
        isScreenshotDemo: Bool,
        isRunningTests: Bool
    ) -> Bool {
        hasConfigFile && !isScreenshotDemo && !isRunningTests
    }

    /// つなげるなら Firebase を設定する。設定したら true
    static func configureIfAvailable(
        isScreenshotDemo: Bool,
        bundle: Bundle = .main,
        processInfo: ProcessInfo = .processInfo
    ) -> Bool {
        let hasConfigFile = bundle.path(forResource: configFileName, ofType: "plist") != nil
        // ユニットテスト・UI テストはアプリを起動して流すので、テストの環境変数で見分ける
        let isRunningTests = processInfo.environment["XCTestConfigurationFilePath"] != nil
            || processInfo.arguments.contains(OnboardingStatus.skipArgument)
            || processInfo.arguments.contains(OnboardingStatus.resetArgument)
        guard shouldConfigure(
            hasConfigFile: hasConfigFile,
            isScreenshotDemo: isScreenshotDemo,
            isRunningTests: isRunningTests
        ) else {
            return false
        }
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        return true
    }
}
