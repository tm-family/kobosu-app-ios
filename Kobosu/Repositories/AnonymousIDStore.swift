//
//  AnonymousIDStore.swift
//  Kobosu
//
//  端末ごとの匿名 ID。アカウント登録の代わりに、自分の投稿・送った共感・通報を見分けるのに使う。
//  ID はサーバーで他の人から読める形には置かない（名前のない場所にするため）。
//

import Foundation

protocol AnonymousIDStore: AnyObject {
    /// 匿名 ID。まだ無ければ作って保存し、以後は同じ値を返す
    func currentID() throws -> String
    /// 匿名 ID を破棄する（「すべてのデータを削除」）。次の currentID() では新しい ID になる
    func deleteID() throws
}

/// テスト・Preview・撮影モード用。メモリ上にだけ持つ
final class InMemoryAnonymousIDStore: AnonymousIDStore {
    private var id: String?
    private let makeID: () -> String

    init(id: String? = nil, makeID: @escaping () -> String = { UUID().uuidString }) {
        self.id = id
        self.makeID = makeID
    }

    func currentID() -> String {
        if let id {
            return id
        }
        let newID = makeID()
        id = newID
        return newID
    }

    func deleteID() {
        id = nil
    }
}
