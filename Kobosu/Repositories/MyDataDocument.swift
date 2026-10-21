//
//  MyDataDocument.swift
//  Kobosu
//
//  「すべてのデータを削除」で Firestore から消すもの。Firebase に依存しない部分だけを置き、テストできるようにする。
//
//  - users/{uid}/ownPosts の目印があるもの: posts/{postId} と目印を消す（2 段目を書けなかった投稿も含める）
//  - users/{uid}/sentStamps/{postId}: 送った共感。投稿の人数から 1 ずつ引いてから、送った記録を消す
//  - users/{uid}/sentReports/{postId}: 通報した目印。投稿の reportCount から 1 引き、posts/{postId}/reports/{uid} と目印を消す
//
//  他の人が自分の投稿に送った共感・通報の記録（相手の sentStamps・reports）は、投稿と同じ expireAt で TTL が消す。
//

import Foundation

nonisolated enum MyDataDocument {
    /// 1 つのバッチに入れられる書き込みの数（Firestore の上限）
    static let batchLimit = 500

    /// 投稿ごとに、取り下げる共感・通報
    struct Withdrawal: Equatable {
        let postID: String
        var stamps: Set<EmpathyStamp> = []
        var reported = false
    }

    /// 送った共感と通報した投稿を、投稿ごとにまとめる（ID の順）
    static func withdrawals(sentStamps: [String: Set<EmpathyStamp>], reportedPostIDs: Set<String>) -> [Withdrawal] {
        var result: [String: Withdrawal] = [:]
        for (postID, stamps) in sentStamps {
            result[postID, default: Withdrawal(postID: postID)].stamps = stamps
        }
        for postID in reportedPostIDs {
            result[postID, default: Withdrawal(postID: postID)].reported = true
        }
        return result.values.sorted { $0.postID < $1.postID }
    }

    /// 投稿の人数から引く値（フィールドのパス → -1）。いま 1 以上のものだけ引き、0 より小さくしない。
    /// 投稿が無い（消えた・TTL で消えた）ときは何も引かない
    static func decrements(post data: [String: Any]?, withdrawal: Withdrawal) -> [String: Int64] {
        guard let data else {
            return [:]
        }
        var result: [String: Int64] = [:]
        let counts = PostDocument.stampCounts(from: data[PostDocument.Field.stampCounts])
        for stamp in withdrawal.stamps where counts[stamp, default: 0] > 0 {
            result[PostDocument.stampCountFieldPath(stamp)] = -1
        }
        if withdrawal.reported, ReportDocument.reportCount(inPost: data) > 0 {
            result[ReportDocument.Field.reportCount] = -1
        }
        return result
    }

    /// バッチの上限に収まるように分ける
    static func chunked<Element>(_ items: [Element], size: Int) -> [[Element]] {
        guard size > 0 else {
            return [items]
        }
        return stride(from: 0, to: items.count, by: size).map { Array(items[$0..<min($0 + size, items.count)]) }
    }
}
