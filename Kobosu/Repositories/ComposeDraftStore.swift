//
//  ComposeDraftStore.swift
//  Kobosu
//
//  投稿の下書き。端末の中にだけ保存し、サーバーには送らない。
//  投稿できたら消す。キャンセルやシートを引いて閉じたときは残す（もう一度開くと続きから書ける）。
//

import Foundation

/// 書きかけの本文と、選んだカテゴリ
nonisolated struct ComposeDraft: Codable, Equatable, Sendable {
    var body: String
    var category: PostCategory?

    /// 本文が空白だけで、カテゴリも選んでいない
    var isEmpty: Bool {
        body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && category == nil
    }
}

protocol ComposeDraftStore: AnyObject {
    /// 保存した下書き。無ければ nil
    func load() -> ComposeDraft?
    /// 下書きを保存する。空の下書きは保存せずに消す
    func save(_ draft: ComposeDraft)
    /// 下書きを消す（投稿できたとき・「すべてのデータを削除」）
    func clear()
}

/// ふだんの起動。UserDefaults に JSON で保存する
final class UserDefaultsComposeDraftStore: ComposeDraftStore {
    /// 下書きを保存するキー
    nonisolated static let key = "compose.draft"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> ComposeDraft? {
        guard let data = defaults.data(forKey: Self.key) else {
            return nil
        }
        // 読めない（知らないカテゴリなど）ときは、下書きが無いものとして扱う
        return try? JSONDecoder().decode(ComposeDraft.self, from: data)
    }

    func save(_ draft: ComposeDraft) {
        guard !draft.isEmpty, let data = try? JSONEncoder().encode(draft) else {
            clear()
            return
        }
        defaults.set(data, forKey: Self.key)
    }

    func clear() {
        defaults.removeObject(forKey: Self.key)
    }
}

/// テスト・Preview・撮影モード用。メモリ上にだけ持つ
final class InMemoryComposeDraftStore: ComposeDraftStore {
    private var draft: ComposeDraft?

    init(draft: ComposeDraft? = nil) {
        self.draft = draft
    }

    func load() -> ComposeDraft? {
        draft
    }

    func save(_ draft: ComposeDraft) {
        self.draft = draft.isEmpty ? nil : draft
    }

    func clear() {
        draft = nil
    }
}
