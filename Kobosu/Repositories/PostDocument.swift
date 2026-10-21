//
//  PostDocument.swift
//  Kobosu
//
//  Firestore に置く投稿の文書の形。Firebase に依存しない部分だけを置き、テストできるようにする。
//
//  - posts/{postId}: 本文・カテゴリ・createdAt・expireAt・スタンプの人数。だれでも読めるので、投稿者を特定できる値は置かない
//  - users/{uid}/posts/{postId}: 自分の投稿の目印（createdAt・expireAt）。本人だけが読める
//
//  期限はサーバーの時刻から決める。投稿は 2 段で書く:
//  1. createdAt と expireAt をどちらも FieldValue.serverTimestamp() にして作る（この時点ではもう期限切れ）
//  2. サーバーの createdAt を読み、expireAt を createdAt の 24 時間後にする
//  2 が失敗しても期限切れのままなので、表示から外れ、TTL で消える（消えずに残る投稿を作らない）。
//

import Foundation

nonisolated enum PostDocument {
    static let postsCollection = "posts"
    static let usersCollection = "users"
    /// users/{uid} の下の、自分の投稿の目印
    static let ownPostsCollection = "posts"

    enum Field {
        static let body = "body"
        static let category = "category"
        static let createdAt = "createdAt"
        static let expireAt = "expireAt"
        static let stampCounts = "stampCounts"
    }

    /// タイムラインで一度に読む件数
    static let timelineLimit = 100
    /// Firestore の `in` の条件に一度に渡せる数
    static let inQueryLimit = 30

    /// 投稿の文書の、サーバーの時刻以外の値
    static func newPostFields(body: String, category: PostCategory) -> [String: Any] {
        [
            Field.body: body,
            Field.category: category.rawValue
        ]
    }

    /// 文書の値から投稿を作る。日時（Timestamp）は呼ぶ側で Date にして渡す。
    /// 形が合わないもの（知らないカテゴリ・サーバーの時刻がまだ入っていないもの）は nil
    static func post(id: String, data: [String: Any], createdAt: Date?, expireAt: Date?) -> Post? {
        guard
            let body = data[Field.body] as? String,
            let rawCategory = data[Field.category] as? String,
            let category = PostCategory(rawValue: rawCategory),
            let createdAt,
            let expireAt
        else {
            return nil
        }
        return Post(
            id: id,
            body: body,
            category: category,
            createdAt: createdAt,
            expireAt: expireAt,
            stampCounts: stampCounts(from: data[Field.stampCounts])
        )
    }

    /// スタンプの人数。知らないスタンプと 0 以下の人数は外す
    static func stampCounts(from value: Any?) -> [EmpathyStamp: Int] {
        guard let raw = value as? [String: Any] else {
            return [:]
        }
        var counts: [EmpathyStamp: Int] = [:]
        for (key, value) in raw {
            guard let stamp = EmpathyStamp(rawValue: key), let count = (value as? NSNumber)?.intValue, count > 0 else {
                continue
            }
            counts[stamp] = count
        }
        return counts
    }

    /// 期限内の投稿を新しい順に並べる。Firestore の TTL は消えるまで遅れるので、読み出し条件に加えて端末でも外す
    static func activePosts(_ posts: [Post], at now: Date) -> [Post] {
        posts
            .filter { !$0.isExpired(at: now) }
            .sorted { $0.createdAt > $1.createdAt }
    }
}
