//
//  LastCategoryStoreTests.swift
//  KobosuTests
//

import Foundation
@testable import Kobosu
import Testing

struct LastCategoryStoreTests {
    @Test
    func userDefaultsStoreKeepsCategory() throws {
        let suiteName = "LastCategoryStoreTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = UserDefaultsLastCategoryStore(defaults: defaults)
        #expect(store.load() == nil)
        store.save(.housework)
        // 作り直しても（アプリを起動し直しても）読める
        #expect(UserDefaultsLastCategoryStore(defaults: defaults).load() == .housework)
        #expect(defaults.string(forKey: UserDefaultsLastCategoryStore.key) == "housework")
        // 新しいカテゴリで上書きする
        store.save(.money)
        #expect(store.load() == .money)

        store.clear()
        #expect(store.load() == nil)
        #expect(defaults.object(forKey: UserDefaultsLastCategoryStore.key) == nil)
    }

    /// 未分類は前回のカテゴリにしない。それより前のカテゴリを残す
    @Test
    func uncategorizedIsNotSaved() throws {
        let suiteName = "LastCategoryStoreTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = UserDefaultsLastCategoryStore(defaults: defaults)
        store.save(.uncategorized)
        #expect(store.load() == nil)
        store.save(.partner)
        store.save(.uncategorized)
        #expect(store.load() == .partner)
    }

    /// 読めない値（外したカテゴリ・知らない値・未分類）は、前回のカテゴリが無いものとして扱う
    @Test(arguments: ["caregiving", "work_and_family", "unknown", "", "uncategorized"])
    func unreadableValueIsIgnored(rawValue: String) throws {
        let suiteName = "LastCategoryStoreTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set(rawValue, forKey: UserDefaultsLastCategoryStore.key)
        #expect(UserDefaultsLastCategoryStore(defaults: defaults).load() == nil)
    }

    /// 文字列でない値も読めないものとして扱う
    @Test
    func nonStringValueIsIgnored() throws {
        let suiteName = "LastCategoryStoreTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set(Data([0x01]), forKey: UserDefaultsLastCategoryStore.key)
        #expect(UserDefaultsLastCategoryStore(defaults: defaults).load() == nil)
    }

    @Test
    func inMemoryStoreKeepsCategory() {
        let store = InMemoryLastCategoryStore()
        #expect(store.load() == nil)
        store.save(.parenting)
        store.save(.uncategorized)
        #expect(store.load() == .parenting)
        store.clear()
        #expect(store.load() == nil)
        #expect(InMemoryLastCategoryStore(category: .uncategorized).load() == nil)
        #expect(InMemoryLastCategoryStore(category: .inLaws).load() == .inLaws)
    }
}
