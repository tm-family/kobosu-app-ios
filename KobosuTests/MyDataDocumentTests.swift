//
//  MyDataDocumentTests.swift
//  KobosuTests
//

import Foundation
@testable import Kobosu
import Testing

struct MyDataDocumentTests {
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
        #expect(MyDataDocument.decrements(post: post, withdrawal: withdrawal) == [
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
        #expect(MyDataDocument.decrements(post: post, withdrawal: withdrawal).isEmpty)
    }

    /// 投稿が消えていたら何も引かない（送った記録だけ消す）
    @Test
    func skipsMissingPost() {
        let withdrawal = MyDataDocument.Withdrawal(postID: "p", stamps: [.sameHere], reported: true)
        #expect(MyDataDocument.decrements(post: nil, withdrawal: withdrawal).isEmpty)
    }

    /// バッチの上限に収まるように分ける
    @Test
    func chunksByLimit() {
        #expect(MyDataDocument.chunked(Array(1...5), size: 2) == [[1, 2], [3, 4], [5]])
        #expect(MyDataDocument.chunked([Int](), size: 2).isEmpty)
        #expect(MyDataDocument.chunked(Array(1...3), size: 3) == [[1, 2, 3]])
    }
}
