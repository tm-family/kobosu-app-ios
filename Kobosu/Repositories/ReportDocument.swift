//
//  ReportDocument.swift
//  Kobosu
//
//  Firestore に置く通報の文書の形。Firebase に依存しない部分だけを置き、テストできるようにする。
//
//  - posts/{postId}/reports/{uid}: 通報の理由・createdAt・expireAt（投稿と同じ）。文書 ID を通報した人の uid にして、1 人 1 回にする。
//    通報した本人が「もう通報したか」を確かめる get のほかは、だれも読めない（運営は Firebase コンソールで見る）。投稿者には伝わらない
//  - posts/{postId}.reportCount: 通報した人数。通報と同じバッチで 1 増やす。ReportPolicy.autoHideThreshold 以上ならタイムラインに出さない
//
//  TTL は親の文書を消してもサブコレクションを消さないので、通報にも投稿と同じ expireAt を置き、TTL で一緒に消えるようにする。
//

import Foundation

nonisolated enum ReportDocument {
    /// posts/{postId} の下の、通報
    static let reportsCollection = "reports"

    enum Field {
        static let reason = "reason"
        static let createdAt = "createdAt"
        static let expireAt = "expireAt"
        /// 投稿の文書の、通報した人数
        static let reportCount = "reportCount"
    }

    /// 通報の文書の、時刻以外の値。通報した人が分かる値は文書 ID（uid）だけにし、中身には置かない
    static func reportFields(reason: ReportReason) -> [String: Any] {
        [Field.reason: reason.rawValue]
    }

    /// 投稿の文書の、通報した人数。まだ通報されていなければ 0
    static func reportCount(inPost data: [String: Any]) -> Int {
        (data[Field.reportCount] as? NSNumber)?.intValue ?? 0
    }

    /// 通報が一定数に達して、タイムラインに出さない投稿か
    static func isAutoHidden(post data: [String: Any], threshold: Int) -> Bool {
        reportCount(inPost: data) >= threshold
    }
}
