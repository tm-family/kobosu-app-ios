//
//  FirebaseSetupTests.swift
//  KobosuTests
//

import Foundation
@testable import Kobosu
import Testing

struct FirebaseSetupTests {
    /// 設定ファイルがあり、撮影モードでもテスト中・Preview でもないときだけ Firebase につなぐ
    @Test
    func configuresOnlyWithConfigFileOutsideDemoAndTests() {
        #expect(FirebaseSetup.shouldConfigure(hasConfigFile: true, isScreenshotDemo: false, isRunningTestsOrPreviews: false))
        #expect(!FirebaseSetup.shouldConfigure(hasConfigFile: false, isScreenshotDemo: false, isRunningTestsOrPreviews: false))
        #expect(!FirebaseSetup.shouldConfigure(hasConfigFile: true, isScreenshotDemo: true, isRunningTestsOrPreviews: false))
        #expect(!FirebaseSetup.shouldConfigure(hasConfigFile: true, isScreenshotDemo: false, isRunningTestsOrPreviews: true))
    }

    /// ユニットテスト・UI テスト・Preview を見分け、ふつうの起動はテスト中としない
    @Test
    func detectsTestsAndPreviews() {
        #expect(FirebaseSetup.isRunningTestsOrPreviews(
            environment: ["XCTestConfigurationFilePath": "/tmp/Kobosu.xctestconfiguration"],
            arguments: []
        ))
        #expect(FirebaseSetup.isRunningTestsOrPreviews(environment: [:], arguments: [FirebaseSetup.uiTestArgument]))
        #expect(FirebaseSetup.isRunningTestsOrPreviews(environment: ["XCODE_RUNNING_FOR_PREVIEWS": "1"], arguments: []))
        #expect(!FirebaseSetup.isRunningTestsOrPreviews(environment: [:], arguments: []))
        // オンボーディングの起動引数だけでは、テスト中としない（UI テストは専用の引数を付ける）
        #expect(!FirebaseSetup.isRunningTestsOrPreviews(environment: [:], arguments: [OnboardingStatus.skipArgument]))
    }

    /// ユニットテストの中では、設定ファイルが手元にあっても Firebase につながない
    @Test
    func doesNotConfigureWhileRunningTests() {
        #expect(!FirebaseSetup.configureIfAvailable(isScreenshotDemo: false))
    }
}
