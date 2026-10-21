//
//  FirebaseSetup.swift
//  Kobosu
//
//  Firebase（Auth・Firestore）を使う準備。GoogleService-Info.plist はリポジトリに無い（人間が用意する）。
//  plist が無いとき・撮影モード・テスト中・Preview は Firebase につながず、ローカル（インメモリ）の実装で動かす。
//

import FirebaseCore
import Foundation

nonisolated enum FirebaseSetup {
    /// Firebase の設定ファイルの名前
    static let configFileName = "GoogleService-Info"
    /// UI テスト用の起動引数。Firebase につながずに起動する（UI テストはすべてこれを付けて起動する）
    static let uiTestArgument = "-uitest-without-firebase"

    /// Firebase につなぐか。plist があり、撮影モードでも、テスト中・Preview でもないとき
    static func shouldConfigure(
        hasConfigFile: Bool,
        isScreenshotDemo: Bool,
        isRunningTestsOrPreviews: Bool
    ) -> Bool {
        hasConfigFile && !isScreenshotDemo && !isRunningTestsOrPreviews
    }

    /// テスト中か Xcode Previews か。ユニットテストはテストの環境変数、UI テストは起動引数で見分ける
    /// （UI テストで起動したアプリには XCTestConfigurationFilePath が付かない）
    static func isRunningTestsOrPreviews(environment: [String: String], arguments: [String]) -> Bool {
        environment["XCTestConfigurationFilePath"] != nil
            || environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
            || arguments.contains(uiTestArgument)
    }

    /// つなげるなら Firebase を設定する。設定したら true
    static func configureIfAvailable(
        isScreenshotDemo: Bool,
        bundle: Bundle = .main,
        processInfo: ProcessInfo = .processInfo
    ) -> Bool {
        let hasConfigFile = bundle.path(forResource: configFileName, ofType: "plist") != nil
        guard shouldConfigure(
            hasConfigFile: hasConfigFile,
            isScreenshotDemo: isScreenshotDemo,
            isRunningTestsOrPreviews: isRunningTestsOrPreviews(
                environment: processInfo.environment,
                arguments: processInfo.arguments
            )
        ) else {
            return false
        }
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        return true
    }
}
