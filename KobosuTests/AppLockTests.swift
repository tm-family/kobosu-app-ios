//
//  AppLockTests.swift
//  KobosuTests
//

import Foundation
@testable import Kobosu
import Testing

struct AppLockTests {
    /// テストごとに別の UserDefaults を使う
    private struct IsolatedDefaults {
        let suiteName = "AppLockTests.\(UUID().uuidString)"
        let defaults: UserDefaults

        init() throws {
            defaults = try #require(UserDefaults(suiteName: suiteName))
        }

        func clear() {
            defaults.removePersistentDomain(forName: suiteName)
        }
    }

    /// 初期値はオン。選んだ値は保存し、reset で初期値に戻す
    @Test
    func settingsDefaultToOnAndPersist() throws {
        let isolated = try IsolatedDefaults()
        defer { isolated.clear() }
        let settings = AppLockSettings(defaults: isolated.defaults)

        #expect(settings.isEnabled)
        settings.isEnabled = false
        #expect(!AppLockSettings(defaults: isolated.defaults).isEnabled)
        settings.reset()
        #expect(settings.isEnabled)
    }

    /// オンのまま「設定して次へ」を押すと一度確かめ、確かめられたらオンで保存する
    @Test
    func confirmAuthenticatesAndSavesOn() async throws {
        let isolated = try IsolatedDefaults()
        defer { isolated.clear() }
        let settings = AppLockSettings(defaults: isolated.defaults)
        settings.isEnabled = false
        let authenticator = StubAppLockAuthenticator(method: .faceID, succeeds: true)
        let model = AppLockSetupViewModel(authenticator: authenticator, settings: settings)
        #expect(model.isLockOn)

        #expect(await model.confirm(reason: "理由"))
        #expect(authenticator.authenticateCount == 1)
        #expect(settings.isEnabled)
        #expect(model.state == .editing)
    }

    /// 確かめられなかったら先へ進まず、保存もしない
    @Test
    func failedAuthenticationStays() async throws {
        let isolated = try IsolatedDefaults()
        defer { isolated.clear() }
        let settings = AppLockSettings(defaults: isolated.defaults)
        settings.isEnabled = false
        let model = AppLockSetupViewModel(authenticator: StubAppLockAuthenticator(succeeds: false), settings: settings)

        #expect(await model.confirm(reason: "理由") == false)
        #expect(model.state == .failed)
        #expect(!settings.isEnabled)
    }

    /// オフにして「設定して次へ」・「あとで設定する」は、確かめずにオフで保存する
    @Test
    func turningOffOrSkippingSavesOff() async throws {
        let isolated = try IsolatedDefaults()
        defer { isolated.clear() }
        let settings = AppLockSettings(defaults: isolated.defaults)
        let authenticator = StubAppLockAuthenticator()
        let model = AppLockSetupViewModel(authenticator: authenticator, settings: settings)
        model.isLockOn = false
        #expect(await model.confirm(reason: "理由"))
        #expect(!settings.isEnabled)
        #expect(authenticator.authenticateCount == 0)

        settings.reset()
        model.skip()
        #expect(!settings.isEnabled)
    }

    /// パスコードも設定していない端末では、ロックを使えないのでオフで保存する
    @Test
    func deviceWithoutPasscodeCannotUseLock() async throws {
        let isolated = try IsolatedDefaults()
        defer { isolated.clear() }
        let settings = AppLockSettings(defaults: isolated.defaults)
        let model = AppLockSetupViewModel(authenticator: StubAppLockAuthenticator(method: nil), settings: settings)
        #expect(!model.canUseLock)
        #expect(!model.isLockOn)
        #expect(await model.confirm(reason: "理由"))
        #expect(!settings.isEnabled)
    }

    @Test
    func methodTitlesNameTheMethod() {
        #expect(String(localized: AppLockMethod.faceID.title).contains("Face ID"))
        #expect(String(localized: AppLockMethod.touchID.title).contains("Touch ID"))
    }
}
