//
//  ComposeDraftStore.swift
//  Kobosu
//
//  投稿の下書き。端末の中にだけ保存し、サーバーには送らない。
//  投稿できたら消す。キャンセルやシートを引いて閉じたときは残す（もう一度開くと続きから書ける）。
//

import Foundation

/// 書きかけの本文と、本人が選んだカテゴリ
nonisolated struct ComposeDraft: Codable, Equatable, Sendable {
    var body: String
    /// 本人が選んだカテゴリ。nil なら本人は選んでいない（推定・前回のカテゴリは保存せず、開き直したときに本文から選び直す）。
    /// 前の形の下書きのカテゴリも、本人が選んだもの（カテゴリを選ばないと投稿できなかったため）
    var category: PostCategory?

    /// 本文が空白だけで、カテゴリも選んでいない
    var isEmpty: Bool {
        body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && category == nil
    }
}

nonisolated extension ComposeDraft {
    private enum CodingKeys: String, CodingKey {
        case body
        case category
    }

    /// 知らないカテゴリ（6 種類に減らしたときに外したものなど）は、カテゴリを選んでいないものとして読む。
    /// 本文は書きかけのまま残す
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        body = try container.decode(String.self, forKey: .body)
        let rawCategory = try container.decodeIfPresent(String.self, forKey: .category)
        category = rawCategory.flatMap(PostCategory.init(rawValue:))
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
        // 読めない（形が合わないなど）ときは、下書きが無いものとして扱う
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
