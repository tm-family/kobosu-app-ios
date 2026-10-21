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
//  - users/{uid}/sentReports/{postId}: 自分が通報した目印（expireAt は投稿と同じ）。本人だけが読める。
//    「すべてのデータを削除」で自分の通報を探して消すのに使う（reports は本人の get しか許さず、探せないため）
//
//  TTL は親の文書を消してもサブコレクションを消さないので、通報にも投稿と同じ expireAt を置き、TTL で一緒に消えるようにする。
//
//  運営は Firebase コンソールの Firestore で確かめる（通知や Cloud Functions は使わない）。posts を reportCount で絞り込み、
//  ReportPolicy.autoHideThreshold 以上のものが自動で非表示になった投稿。理由はその下の reports を見る。
//  どちらも expireAt を過ぎると TTL で消えるので、確かめられるのは投稿が残っている間だけ（手順は docs/firebase.md）
//

import Foundation

nonisolated enum ReportDocument {
    /// posts/{postId} の下の、通報
    static let reportsCollection = "reports"
    /// users/{uid} の下の、自分が通報した目印。posts の下の reports とコレクション ID を分け、ルール・TTL が両方に効かないようにする
    static let sentReportsCollection = "sentReports"

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
