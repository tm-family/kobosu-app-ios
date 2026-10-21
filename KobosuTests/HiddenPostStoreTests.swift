//
//  HiddenPostStoreTests.swift
//  KobosuTests
//

import Foundation
@testable import Kobosu
import Testing

struct HiddenPostStoreTests {
    private func makeDefaults() throws -> UserDefaults {
        try #require(UserDefaults(suiteName: "KobosuTests.hiddenPosts.\(UUID().uuidString)"))
    }

    @Test
    func keepsHiddenPostsAcrossInstances() throws {
        let defaults = try makeDefaults()
        let store = UserDefaultsHiddenPostStore(defaults: defaults)
        #expect(store.hiddenPostIDs().isEmpty)
        store.hide("a")
        store.hide("b")
        #expect(store.hiddenPostIDs() == ["a", "b"])
        #expect(UserDefaultsHiddenPostStore(defaults: defaults).hiddenPostIDs() == ["a", "b"])
    }

    /// 表示しないにしてから 24 時間たった ID は捨てる（投稿はもう消えている）
    @Test
    func forgetsHiddenPostsAfterLifetime() throws {
        let defaults = try makeDefaults()
        var now = Date(timeIntervalSince1970: 1_000_000)
        let store = UserDefaultsHiddenPostStore(defaults: defaults) { now }
        store.hide("old")
        now = now.addingTimeInterval(60 * 60)
        store.hide("new")
        now = now.addingTimeInterval(Post.lifetime - 60 * 60)
        #expect(store.hiddenPostIDs() == ["new"])
        let stored = defaults.dictionary(forKey: UserDefaultsHiddenPostStore.key) ?? [:]
        #expect(Set(stored.keys) == ["new"])
    }

    @Test
    func clearRemovesAll() throws {
        let store = UserDefaultsHiddenPostStore(defaults: try makeDefaults())
        store.hide("a")
        store.clear()
        #expect(store.hiddenPostIDs().isEmpty)
    }
}
