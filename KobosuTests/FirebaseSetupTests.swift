//
//  FirebaseSetupTests.swift
//  KobosuTests
//

import Foundation
@testable import Kobosu
import Testing

struct FirebaseSetupTests {
    /// 設定ファイルがあり、撮影モードでもテスト中でもないときだけ Firebase につなぐ
    @Test
    func configuresOnlyWithConfigFileOutsideDemoAndTests() {
        #expect(FirebaseSetup.shouldConfigure(hasConfigFile: true, isScreenshotDemo: false, isRunningTests: false))
        #expect(!FirebaseSetup.shouldConfigure(hasConfigFile: false, isScreenshotDemo: false, isRunningTests: false))
        #expect(!FirebaseSetup.shouldConfigure(hasConfigFile: true, isScreenshotDemo: true, isRunningTests: false))
        #expect(!FirebaseSetup.shouldConfigure(hasConfigFile: true, isScreenshotDemo: false, isRunningTests: true))
    }

    /// リポジトリには設定ファイルを入れていないので、テストでは Firebase につながない
    @Test
    func doesNotConfigureWithoutConfigFile() {
        #expect(Bundle.main.path(forResource: FirebaseSetup.configFileName, ofType: "plist") == nil)
        #expect(!FirebaseSetup.configureIfAvailable(isScreenshotDemo: false))
    }
}
