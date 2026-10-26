//
//  LastCategoryStore.swift
//  Kobosu
//
//  前回の投稿で使ったカテゴリ。端末の中にだけ保存し、サーバーには送らない。
//  本文からカテゴリを推定できなかったときの初期値に使う。投稿できたときに保存し、「すべてのデータを削除」で消す。
//  未分類は「前回のカテゴリ」にしない（未分類で投稿しても、それより前のカテゴリを残す）。
//

import Foundation

protocol LastCategoryStore: AnyObject {
    /// 前回のカテゴリ。無いとき・読めない値（外したカテゴリ・知らない値）のときは nil
    func load() -> PostCategory?
    /// 前回のカテゴリとして保存する。未分類は保存しない（前の値を残す）
    func save(_ category: PostCategory)
    /// 消す（「すべてのデータを削除」）
    func clear()
}

/// ふだんの起動。UserDefaults に rawValue で保存する
final class UserDefaultsLastCategoryStore: LastCategoryStore {
    /// 前回のカテゴリを保存するキー
    nonisolated static let key = "compose.lastCategory"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> PostCategory? {
        guard let rawValue = defaults.string(forKey: Self.key),
              let category = PostCategory(rawValue: rawValue),
              category != .uncategorized else {
            return nil
        }
        return category
    }

    func save(_ category: PostCategory) {
        guard category != .uncategorized else {
            return
        }
        defaults.set(category.rawValue, forKey: Self.key)
    }

    func clear() {
        defaults.removeObject(forKey: Self.key)
    }
}

/// テスト・Preview・撮影モード用。メモリ上にだけ持つ
final class InMemoryLastCategoryStore: LastCategoryStore {
    private var category: PostCategory?

    init(category: PostCategory? = nil) {
        self.category = category == .uncategorized ? nil : category
    }

    func load() -> PostCategory? {
        category
    }

    func save(_ category: PostCategory) {
        guard category != .uncategorized else {
            return
        }
        self.category = category
    }

    func clear() {
        category = nil
    }
}
