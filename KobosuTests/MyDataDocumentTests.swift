//
//  MyDataDocumentTests.swift
//  KobosuTests
//

import Foundation
@testable import Kobosu
import Testing

struct MyDataDocumentTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    /// 期限内の投稿の人数から引く値
    private func decrements(_ post: [String: Any]?, _ withdrawal: MyDataDocument.Withdrawal) -> [String: Int64] {
        MyDataDocument.decrements(post: post, expireAt: now.addingTimeInterval(60), withdrawal: withdrawal, now: now)
    }

    /// 送った共感と通報を、投稿ごとにまとめる
    @Test
    func groupsWithdrawalsByPost() {
        let withdrawals = MyDataDocument.withdrawals(
            sentStamps: ["b": [.sameHere, .understand], "a": [.wellDone]],
            reportedPostIDs: ["b", "c"]
        )
        #expect(withdrawals == [
            MyDataDocument.Withdrawal(postID: "a", stamps: [.wellDone], reported: false),
            MyDataDocument.Withdrawal(postID: "b", stamps: [.sameHere, .understand], reported: true),
            MyDataDocument.Withdrawal(postID: "c", stamps: [], reported: true)
        ])
    }

    /// 送ったスタンプと通報の人数を 1 ずつ引く
    @Test
    func decrementsSentStampsAndReport() {
        let post: [String: Any] = [
            PostDocument.Field.stampCounts: ["same_here": NSNumber(value: 3), "understand": 1],
            ReportDocument.Field.reportCount: NSNumber(value: 2)
        ]
        let withdrawal = MyDataDocument.Withdrawal(postID: "p", stamps: [.sameHere, .understand], reported: true)
        #expect(decrements(post, withdrawal) == [
            "stampCounts.same_here": -1,
            "stampCounts.understand": -1,
            "reportCount": -1
        ])
    }

    /// 0 より小さくしない（人数が無い・0 のものは引かない）
    @Test
    func doesNotGoBelowZero() {
        let post: [String: Any] = [
            PostDocument.Field.stampCounts: ["same_here": NSNumber(value: 0)]
        ]
        let withdrawal = MyDataDocument.Withdrawal(postID: "p", stamps: [.sameHere, .hardDay], reported: true)
        #expect(decrements(post, withdrawal).isEmpty)
    }

    /// 通報していなければ、reportCount があっても引かない。通報だけなら reportCount だけ引く
    @Test
    func decrementsOnlyWhatWasSent() {
        let post: [String: Any] = [
            PostDocument.Field.stampCounts: ["same_here": NSNumber(value: 3)],
            ReportDocument.Field.reportCount: NSNumber(value: 2)
        ]
        let stampOnly = MyDataDocument.Withdrawal(postID: "p", stamps: [.sameHere], reported: false)
        #expect(decrements(post, stampOnly) == ["stampCounts.same_here": -1])
        let reportOnly = MyDataDocument.Withdrawal(postID: "p", stamps: [], reported: true)
        #expect(decrements(post, reportOnly) == ["reportCount": -1])
    }

    /// 期限を過ぎて TTL を待っている投稿からは引かない（通報の記録が先に消えていても、ルールにはじかれないように）。
    /// 期限ちょうども期限切れ。期限が読めないときも引かない
    @Test
    func skipsExpiredPost() {
        let post: [String: Any] = [
            PostDocument.Field.stampCounts: ["same_here": NSNumber(value: 3)],
            ReportDocument.Field.reportCount: NSNumber(value: 2)
        ]
        let withdrawal = MyDataDocument.Withdrawal(postID: "p", stamps: [.sameHere], reported: true)
        #expect(MyDataDocument.decrements(post: post, expireAt: now, withdrawal: withdrawal, now: now).isEmpty)
        #expect(
            MyDataDocument.decrements(post: post, expireAt: now.addingTimeInterval(-1), withdrawal: withdrawal, now: now)
                .isEmpty
        )
        #expect(MyDataDocument.decrements(post: post, expireAt: nil, withdrawal: withdrawal, now: now).isEmpty)
    }

    /// 投稿が消えていたら何も引かない（送った記録だけ消す）
    @Test
    func skipsMissingPost() {
        let withdrawal = MyDataDocument.Withdrawal(postID: "p", stamps: [.sameHere], reported: true)
        #expect(decrements(nil, withdrawal).isEmpty)
    }

    /// バッチの上限に収まるように分ける
    @Test
    func chunksByLimit() {
        #expect(MyDataDocument.chunked(Array(1...5), size: 2) == [[1, 2], [3, 4], [5]])
        #expect(MyDataDocument.chunked([Int](), size: 2).isEmpty)
        #expect(MyDataDocument.chunked(Array(1...3), size: 3) == [[1, 2, 3]])
    }

    /// 自分の投稿を消すバッチは、ルールの exists()・get() の回数の上限（20）に収まる
    @Test
    func deletionBatchFitsRuleCallLimit() {
        let size = MyDataDocument.postsPerDeletionBatch
        #expect(size * MyDataDocument.ruleCallsPerPostDeletion <= MyDataDocument.ruleCallLimit)
        let chunks = MyDataDocument.chunked(Array(1...21), size: size)
        #expect(chunks.count == 3)
        #expect(chunks.allSatisfy { $0.count * MyDataDocument.ruleCallsPerPostDeletion <= MyDataDocument.ruleCallLimit })
    }
}
