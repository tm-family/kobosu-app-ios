//
//  HiddenPostStore.swift
//  Kobosu
//
//  「この投稿を表示しない」にした投稿。この端末のタイムラインにだけ効くので、端末の中にだけ保存し、サーバーには送らない。
//  投稿は作成から 24 時間で消えるので、表示しないにしてから 24 時間たった ID は捨てる（あとに残らない）。
//

import Foundation

protocol HiddenPostStore: AnyObject {
    /// 表示しない投稿の ID（期限を過ぎたものは含めない）
    func hiddenPostIDs() -> Set<Post.ID>
    /// 表示しないにする
    func hide(_ postID: Post.ID)
    /// すべて消す（「すべてのデータを削除」）
    func clear()
}

/// ふだんの起動。UserDefaults に「ID → 捨ててよい日時」を保存する
final class UserDefaultsHiddenPostStore: HiddenPostStore {
    /// 保存するキー
    static let key = "timeline.hiddenPosts"

    private let defaults: UserDefaults
    private let now: () -> Date

    init(defaults: UserDefaults = .standard, now: @escaping () -> Date = { Date() }) {
        self.defaults = defaults
        self.now = now
    }

    func hiddenPostIDs() -> Set<Post.ID> {
        Set(activeEntries().keys)
    }

    func hide(_ postID: Post.ID) {
        var entries = activeEntries()
        // 投稿はいまから 24 時間より長くは残らないので、それまで覚えておけば足りる
        entries[postID] = now().addingTimeInterval(Post.lifetime).timeIntervalSince1970
        defaults.set(entries, forKey: Self.key)
    }

    func clear() {
        defaults.removeObject(forKey: Self.key)
    }

    /// 期限を過ぎていないもの。過ぎたものは保存し直して捨てる
    private func activeEntries() -> [Post.ID: TimeInterval] {
        let stored = defaults.dictionary(forKey: Self.key) as? [Post.ID: TimeInterval] ?? [:]
        let date = now().timeIntervalSince1970
        let active = stored.filter { $0.value > date }
        if active.count != stored.count {
            defaults.set(active, forKey: Self.key)
        }
        return active
    }
}
