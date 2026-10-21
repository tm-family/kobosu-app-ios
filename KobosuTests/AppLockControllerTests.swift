//
//  AppLockControllerTests.swift
//  KobosuTests
//

import Foundation
@testable import Kobosu
import Testing

struct AppLockControllerTests {
    /// テストごとに別の UserDefaults を使う
    private struct IsolatedDefaults {
        let suiteName = "AppLockControllerTests.\(UUID().uuidString)"
        let defaults: UserDefaults

        init() throws {
            defaults = try #require(UserDefaults(suiteName: suiteName))
        }

        func clear() {
            defaults.removePersistentDomain(forName: suiteName)
        }
    }

    private func makeController(
        _ isolated: IsolatedDefaults,
        enabled: Bool = true,
        authenticator: StubAppLockAuthenticator = StubAppLockAuthenticator(),
        available: Bool = true
    ) -> AppLockController {
        let settings = AppLockSettings(defaults: isolated.defaults)
        settings.isEnabled = enabled
        return AppLockController(authenticator: authenticator, settings: settings) { available }
    }

    /// アプリロックがオンなら、起動したときからロックし、前に出てきたら一度だけ自動で確かめる
    @Test
    func locksOnLaunchAndUnlocksAutomaticallyOnce() async throws {
        let isolated = try IsolatedDefaults()
        defer { isolated.clear() }
        let authenticator = StubAppLockAuthenticator()
        let controller = makeController(isolated, authenticator: authenticator)
        #expect(controller.isLocked)

        await controller.didBecomeActive(reason: "理由")
        #expect(!controller.isLocked)
        #expect(authenticator.authenticateCount == 1)
        // 確かめた後に前に出てきても（Face ID の確認の後など）、もう確かめない
        await controller.didBecomeActive(reason: "理由")
        #expect(authenticator.authenticateCount == 1)
    }

    /// 取り消したらロックのまま。もう一度出てくるまでは自動で確かめず、「開く」を押したら確かめる
    @Test
    func cancelledAuthenticationStaysLocked() async throws {
        let isolated = try IsolatedDefaults()
        defer { isolated.clear() }
        let authenticator = StubAppLockAuthenticator(succeeds: false)
        let controller = makeController(isolated, authenticator: authenticator)

        await controller.didBecomeActive(reason: "理由")
        #expect(controller.isLocked)
        await controller.didBecomeActive(reason: "理由")
        #expect(authenticator.authenticateCount == 1)

        authenticator.succeeds = true
        await controller.unlock(reason: "理由")
        #expect(!controller.isLocked)
        #expect(authenticator.authenticateCount == 2)
    }

    /// バックグラウンドに入るたびにロックし、また自動で確かめる
    @Test
    func locksWhenEnteringBackground() async throws {
        let isolated = try IsolatedDefaults()
        defer { isolated.clear() }
        let authenticator = StubAppLockAuthenticator()
        let controller = makeController(isolated, authenticator: authenticator)
        await controller.didBecomeActive(reason: "理由")
        #expect(!controller.isLocked)

        controller.didEnterBackground()
        #expect(controller.isLocked)
        await controller.didBecomeActive(reason: "理由")
        #expect(!controller.isLocked)
        #expect(authenticator.authenticateCount == 2)
    }

    /// アプリロックがオフ・初回の画面の途中・撮影モード・ロックを使えない端末では、ロックしない
    @Test(arguments: Self.unavailableCases)
    func doesNotLockWhenUnavailable(condition: UnavailableCase) async throws {
        let isolated = try IsolatedDefaults()
        defer { isolated.clear() }
        let authenticator = StubAppLockAuthenticator(method: condition.hasMethod ? .faceID : nil)
        let controller = makeController(
            isolated,
            enabled: condition.enabled,
            authenticator: authenticator,
            available: condition.available
        )
        #expect(!controller.isLocked)
        controller.didEnterBackground()
        #expect(!controller.isLocked)
        await controller.didBecomeActive(reason: "理由")
        #expect(authenticator.authenticateCount == 0)
    }

    struct UnavailableCase: Sendable, CustomTestStringConvertible {
        let enabled: Bool
        let available: Bool
        let hasMethod: Bool

        var testDescription: String {
            "enabled: \(enabled), available: \(available), hasMethod: \(hasMethod)"
        }
    }

    nonisolated private static let unavailableCases: [UnavailableCase] = [
        UnavailableCase(enabled: false, available: true, hasMethod: true),
        UnavailableCase(enabled: true, available: false, hasMethod: true),
        UnavailableCase(enabled: true, available: true, hasMethod: false)
    ]

    /// ロック中にアプリロックをオフにした（設定から）ときは、確かめずに開く
    @Test
    func unlockWithoutAuthenticationWhenTurnedOff() async throws {
        let isolated = try IsolatedDefaults()
        defer { isolated.clear() }
        let authenticator = StubAppLockAuthenticator()
        let controller = makeController(isolated, authenticator: authenticator)
        AppLockSettings(defaults: isolated.defaults).isEnabled = false
        await controller.unlock(reason: "理由")
        #expect(!controller.isLocked)
        #expect(authenticator.authenticateCount == 0)
    }
}
