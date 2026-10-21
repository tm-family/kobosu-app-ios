//
//  Post.swift
//  Kobosu
//
//  タイムラインに共有された投稿。
//  名前のない場所にするため、投稿者を特定できる値（匿名 ID など）は持たせない。
//  自分の投稿かどうかは、Repository が端末の匿名 ID と照らして別に扱う。
//

import Foundation

nonisolated struct Post: Codable, Hashable, Identifiable, Sendable {
    /// 本文の上限の文字数
    static let maxBodyLength = 400
    /// 作成から消えるまでの時間（24 時間）
    static let lifetime: TimeInterval = 24 * 60 * 60

    let id: String
    let body: String
    let category: PostCategory
    /// 作成日時（サーバーの時刻）
    let createdAt: Date
    /// 消える日時（サーバーの時刻から決める）。この時刻を過ぎた投稿は表示しない
    let expireAt: Date
    /// スタンプごとの人数。送られていないスタンプはキーを持たない
    var stampCounts: [EmpathyStamp: Int]

    init(
        id: String,
        body: String,
        category: PostCategory,
        createdAt: Date,
        expireAt: Date? = nil,
        stampCounts: [EmpathyStamp: Int] = [:]
    ) {
        self.id = id
        self.body = body
        self.category = category
        self.createdAt = createdAt
        self.expireAt = expireAt ?? createdAt.addingTimeInterval(Self.lifetime)
        self.stampCounts = stampCounts
    }

    /// スタンプの人数。送られていなければ 0
    func count(of stamp: EmpathyStamp) -> Int {
        stampCounts[stamp, default: 0]
    }

    /// 「うちも同じ」の人数。強調して見せる数字はこれだけにする
    var sameHereCount: Int {
        count(of: .sameHere)
    }
}
