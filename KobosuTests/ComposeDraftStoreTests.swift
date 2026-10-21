//
//  ComposeDraftStoreTests.swift
//  KobosuTests
//

import Foundation
@testable import Kobosu
import Testing

struct ComposeDraftStoreTests {
    @Test
    func userDefaultsStoreKeepsDraft() throws {
        let suiteName = "ComposeDraftStoreTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = UserDefaultsComposeDraftStore(defaults: defaults)
        #expect(store.load() == nil)
        let draft = ComposeDraft(body: "今日も黙って洗い物をした。", category: .housework)
        store.save(draft)
        // 作り直しても（アプリを起動し直しても）読める
        #expect(UserDefaultsComposeDraftStore(defaults: defaults).load() == draft)

        store.clear()
        #expect(store.load() == nil)
    }

    /// 空白だけでカテゴリも選んでいない下書きは、保存せずに消す
    @Test
    func emptyDraftIsCleared() throws {
        let suiteName = "ComposeDraftStoreTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = UserDefaultsComposeDraftStore(defaults: defaults)
        store.save(ComposeDraft(body: "本文", category: nil))
        store.save(ComposeDraft(body: " \n", category: nil))
        #expect(store.load() == nil)
        #expect(defaults.object(forKey: UserDefaultsComposeDraftStore.key) == nil)

        // カテゴリだけ選んだ下書きは残す
        store.save(ComposeDraft(body: "", category: .money))
        #expect(store.load() == ComposeDraft(body: "", category: .money))
    }

    /// 読めないデータ（知らないカテゴリなど）は、下書きが無いものとして扱う
    @Test
    func unreadableDraftIsIgnored() throws {
        let suiteName = "ComposeDraftStoreTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set(Data(#"{"body":"本文","category":"unknown"}"#.utf8), forKey: UserDefaultsComposeDraftStore.key)
        #expect(UserDefaultsComposeDraftStore(defaults: defaults).load() == nil)
    }

    @Test
    func inMemoryStoreKeepsDraft() {
        let store = InMemoryComposeDraftStore()
        store.save(ComposeDraft(body: "本文", category: .partner))
        #expect(store.load() == ComposeDraft(body: "本文", category: .partner))
        store.save(ComposeDraft(body: "", category: nil))
        #expect(store.load() == nil)
    }
}
