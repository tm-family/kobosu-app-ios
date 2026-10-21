//
//  Post+Expiry.swift
//  Kobosu
//
//  投稿の期限（作成から 24 時間）の判定。期限はサーバーの時刻から決めた expireAt を正にし、
//  Firestore の TTL で消えるまでの遅れのあいだも、端末では期限切れを表示から外す。
//

import Foundation

nonisolated extension Post {
    /// 期限を過ぎているか。expireAt ちょうども期限切れとして扱う
    func isExpired(at now: Date) -> Bool {
        expireAt <= now
    }

    /// 消えるまでの残り時間。期限切れなら 0
    func remainingTime(at now: Date) -> TimeInterval {
        max(expireAt.timeIntervalSince(now), 0)
    }
}
