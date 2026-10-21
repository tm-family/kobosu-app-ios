//
//  UITestLaunchTests.swift
//  KobosuTests
//

import Foundation
@testable import Kobosu
import Testing

struct UITestLaunchTests {
    @Test
    func clearDraftArgumentRemovesSavedDraft() throws {
        let suiteName = "UITestLaunchTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = UserDefaultsComposeDraftStore(defaults: defaults)
        store.save(ComposeDraft(body: "下書き", category: .housework))

        // 引数が無ければ下書きは残す
        UITestLaunch.applyLaunchArguments([], to: defaults)
        #expect(store.load() != nil)

        UITestLaunch.applyLaunchArguments([UITestLaunch.clearDraftArgument], to: defaults)
        #expect(store.load() == nil)
    }

    @Test
    func seedPostsArgumentIsDetected() {
        #expect(UITestLaunch.seedsPosts(arguments: [UITestLaunch.seedPostsArgument]))
        #expect(!UITestLaunch.seedsPosts(arguments: []))
        #expect(!UITestLaunch.seedsPosts(arguments: [OnboardingStatus.skipArgument]))
    }
}
