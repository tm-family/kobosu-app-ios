//
//  OnboardingStatusTests.swift
//  KobosuTests
//

import Foundation
@testable import Kobosu
import Testing

struct OnboardingStatusTests {
    @Test
    func showsOnboardingUntilCurrentVersionIsAgreed() {
        #expect(OnboardingStatus.needsOnboarding(agreedVersion: 0, isScreenshotDemo: false))
        #expect(OnboardingStatus.needsOnboarding(agreedVersion: PromiseRule.currentVersion - 1, isScreenshotDemo: false))
        #expect(!OnboardingStatus.needsOnboarding(agreedVersion: PromiseRule.currentVersion, isScreenshotDemo: false))
    }

    @Test
    func screenshotDemoSkipsOnboarding() {
        #expect(!OnboardingStatus.needsOnboarding(agreedVersion: 0, isScreenshotDemo: true))
    }

    @Test
    func launchArgumentsResetOrSkipOnboarding() throws {
        let suiteName = "OnboardingStatusTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        OnboardingStatus.applyLaunchArguments([OnboardingStatus.skipArgument], to: defaults)
        #expect(defaults.integer(forKey: OnboardingStatus.agreedVersionKey) == PromiseRule.currentVersion)
        // 同意した状態で起動するときは、アプリロックをオフにする
        #expect(!AppLockSettings(defaults: defaults).isEnabled)

        OnboardingStatus.applyLaunchArguments([OnboardingStatus.resetArgument], to: defaults)
        #expect(defaults.object(forKey: OnboardingStatus.agreedVersionKey) == nil)
        #expect(defaults.object(forKey: AppLockSettings.enabledKey) == nil)

        OnboardingStatus.applyLaunchArguments([], to: defaults)
        #expect(defaults.object(forKey: OnboardingStatus.agreedVersionKey) == nil)
    }
}
