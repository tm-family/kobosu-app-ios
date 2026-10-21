//
//  PostDocumentTests.swift
//  KobosuTests
//

import Foundation
@testable import Kobosu
import Testing

struct PostDocumentTests {
    private let createdAt = Date(timeIntervalSince1970: 1_800_000_000)

    @Test
    func newPostFieldsHaveNoAuthor() {
        let fields = PostDocument.newPostFields(body: "今日も黙って洗い物をした。", category: .housework)
        #expect(fields.count == 2)
        #expect(fields[PostDocument.Field.body] as? String == "今日も黙って洗い物をした。")
        #expect(fields[PostDocument.Field.category] as? String == "housework")
    }

    @Test
    func decodesPost() throws {
        let data: [String: Any] = [
            PostDocument.Field.body: "本文",
            PostDocument.Field.category: "in_laws",
            PostDocument.Field.stampCounts: ["same_here": NSNumber(value: 3), "understand": 1]
        ]
        let expireAt = createdAt.addingTimeInterval(Post.lifetime)
        let post = try #require(PostDocument.post(id: "post-1", data: data, createdAt: createdAt, expireAt: expireAt))
        #expect(post.id == "post-1")
        #expect(post.body == "本文")
        #expect(post.category == .inLaws)
        #expect(post.createdAt == createdAt)
        #expect(post.expireAt == expireAt)
        #expect(post.stampCounts == [.sameHere: 3, .understand: 1])
    }

    /// 形が合わない文書・サーバーの時刻がまだ入っていない文書は読まない
    @Test
    func skipsMalformedDocuments() {
        let valid: [String: Any] = [PostDocument.Field.body: "本文", PostDocument.Field.category: "partner"]
        let expireAt = createdAt.addingTimeInterval(Post.lifetime)
        #expect(PostDocument.post(id: "a", data: valid, createdAt: nil, expireAt: expireAt) == nil)
        #expect(PostDocument.post(id: "a", data: valid, createdAt: createdAt, expireAt: nil) == nil)
        let unknownCategory: [String: Any] = [PostDocument.Field.body: "本文", PostDocument.Field.category: "unknown"]
        #expect(PostDocument.post(id: "a", data: unknownCategory, createdAt: createdAt, expireAt: expireAt) == nil)
        let noBody: [String: Any] = [PostDocument.Field.category: "partner"]
        #expect(PostDocument.post(id: "a", data: noBody, createdAt: createdAt, expireAt: expireAt) == nil)
    }

    /// 2 段目を書けなかった投稿（expireAt が createdAt のまま）は、端末の時計がサーバーより遅れていても読まない
    @Test
    func skipsUnfinishedDocumentsEvenWithSlowDeviceClock() {
        let data: [String: Any] = [PostDocument.Field.body: "本文", PostDocument.Field.category: "partner"]
        #expect(PostDocument.post(id: "a", data: data, createdAt: createdAt, expireAt: createdAt) == nil)
        #expect(PostDocument.post(id: "a", data: data, createdAt: createdAt, expireAt: createdAt.addingTimeInterval(-1)) == nil)
        // 端末の時計は 5 分遅れているが、書き終わった投稿は読む
        let finished = PostDocument.post(id: "b", data: data, createdAt: createdAt, expireAt: createdAt.addingTimeInterval(Post.lifetime))
        #expect(PostDocument.activePosts([finished].compactMap(\.self), at: createdAt.addingTimeInterval(-5 * 60)).map(\.id) == ["b"])
    }

    /// 知らないスタンプ・0 以下の人数・数でない値は外す
    @Test
    func stampCountsIgnoreUnknownValues() {
        let raw: [String: Any] = ["same_here": 2, "hard_day": 0, "well_done": -1, "unknown": 5, "understand": "3"]
        #expect(PostDocument.stampCounts(from: raw) == [.sameHere: 2])
        #expect(PostDocument.stampCounts(from: nil).isEmpty)
        #expect(PostDocument.stampCounts(from: "same_here").isEmpty)
    }

    /// 期限切れ（期限ちょうどと、2 段目を書けずに expireAt が createdAt のままのもの）を外し、新しい順に並べる
    @Test
    func activePostsDropExpiredAndSortByNewest() {
        let now = createdAt.addingTimeInterval(60 * 60)
        let older = Post(id: "older", body: "a", category: .other, createdAt: createdAt)
        let newer = Post(id: "newer", body: "b", category: .other, createdAt: createdAt.addingTimeInterval(60))
        let unfinished = Post(id: "unfinished", body: "c", category: .other, createdAt: createdAt, expireAt: createdAt)
        let justExpired = Post(id: "justExpired", body: "d", category: .other, createdAt: now.addingTimeInterval(-Post.lifetime))
        let posts = PostDocument.activePosts([older, unfinished, newer, justExpired], at: now)
        #expect(posts.map(\.id) == ["newer", "older"])
    }
}
