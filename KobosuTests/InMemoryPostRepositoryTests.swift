//
//  InMemoryPostRepositoryTests.swift
//  KobosuTests
//

import Foundation
@testable import Kobosu
import Testing

struct InMemoryPostRepositoryTests {
    /// テストで進められる時計
    private final class Clock {
        var now = Date(timeIntervalSince1970: 1_000_000)

        func advance(hours: Double) {
            now = now.addingTimeInterval(hours * 60 * 60)
        }
    }

    private let clock = Clock()
    private let myIdentity = InMemoryAnonymousIDStore(id: "me")

    private func makeRepository(identity: AnonymousIDStore? = nil) -> InMemoryPostRepository {
        var postNumber = 0
        return InMemoryPostRepository(identity: identity ?? myIdentity, now: { [clock] in clock.now }, makePostID: {
            postNumber += 1
            return "post-\(postNumber)"
        })
    }

    private func otherPost(id: String, category: PostCategory = .inLaws, hoursAgo: Double = 1) -> Post {
        Post(id: id, body: "本文", category: category, createdAt: clock.now.addingTimeInterval(-hoursAgo * 60 * 60))
    }

    // MARK: - 期限

    @Test
    func postExpiresAtExpireAt() {
        let post = otherPost(id: "a", hoursAgo: 0)
        #expect(!post.isExpired(at: clock.now))
        #expect(!post.isExpired(at: post.expireAt.addingTimeInterval(-1)))
        #expect(post.isExpired(at: post.expireAt))
        #expect(post.remainingTime(at: clock.now) == 24 * 60 * 60)
        #expect(post.remainingTime(at: post.expireAt.addingTimeInterval(60)) == 0)
    }

    @Test
    func timelineExcludesExpiredPosts() async throws {
        let repository = makeRepository()
        repository.seed(otherPost(id: "old", hoursAgo: 23))
        repository.seed(otherPost(id: "new", hoursAgo: 1))
        #expect(try await repository.timeline(category: nil).map(\.id) == ["new", "old"])
        clock.advance(hours: 1)
        #expect(try await repository.timeline(category: nil).map(\.id) == ["new"])
    }

    // MARK: - タイムライン

    @Test
    func timelineIsNewestFirstAndFiltersByCategory() async throws {
        let repository = makeRepository()
        repository.seed(otherPost(id: "a", category: .inLaws, hoursAgo: 3))
        repository.seed(otherPost(id: "b", category: .money, hoursAgo: 2))
        repository.seed(otherPost(id: "c", category: .inLaws, hoursAgo: 1))
        #expect(try await repository.timeline(category: nil).map(\.id) == ["c", "b", "a"])
        #expect(try await repository.timeline(category: .inLaws).map(\.id) == ["c", "a"])
        #expect(try await repository.timeline(category: .caregiving).isEmpty)
    }

    // MARK: - 投稿

    @Test
    func submitTrimsBodyAndSetsExpiry() async throws {
        let repository = makeRepository()
        let post = try await repository.submit(body: "  今日も黙って洗い物をした。\n", category: .housework)
        #expect(post.body == "今日も黙って洗い物をした。")
        #expect(post.createdAt == clock.now)
        #expect(post.expireAt == clock.now.addingTimeInterval(Post.lifetime))
        #expect(try await repository.myPosts().map(\.id) == [post.id])
        #expect(try await repository.timeline(category: nil).map(\.id) == [post.id])
    }

    @Test
    func submitRejectsEmptyOrTooLongBody() async throws {
        let repository = makeRepository()
        await #expect(throws: PostRepositoryError.emptyBody) {
            try await repository.submit(body: " \n ", category: .other)
        }
        await #expect(throws: PostRepositoryError.bodyTooLong) {
            try await repository.submit(body: String(repeating: "あ", count: Post.maxBodyLength + 1), category: .other)
        }
        let longest = try await repository.submit(body: String(repeating: "あ", count: Post.maxBodyLength), category: .other)
        #expect(longest.body.count == Post.maxBodyLength)
    }

    @Test
    func myPostsContainsOnlyMyActivePosts() async throws {
        let repository = makeRepository()
        repository.seed(otherPost(id: "other"))
        let mine = try await repository.submit(body: "本文", category: .partner)
        #expect(try await repository.myPosts().map(\.id) == [mine.id])
        clock.advance(hours: 24)
        #expect(try await repository.myPosts().isEmpty)
    }

    @Test
    func deleteRemovesOnlyMyPost() async throws {
        let repository = makeRepository()
        repository.seed(otherPost(id: "other"))
        let mine = try await repository.submit(body: "本文", category: .partner)
        await #expect(throws: PostRepositoryError.notOwner) {
            try await repository.delete(postID: "other")
        }
        try await repository.delete(postID: mine.id)
        #expect(try await repository.myPosts().isEmpty)
        #expect(try await repository.timeline(category: nil).map(\.id) == ["other"])
    }

    // MARK: - 共感

    @Test
    func stampIsCountedOncePerPerson() async throws {
        let repository = makeRepository()
        repository.seed(Post(id: "a", body: "本文", category: .inLaws, createdAt: clock.now, stampCounts: [.sameHere: 2]))
        try await repository.sendStamp(.sameHere, to: "a")
        try await repository.sendStamp(.sameHere, to: "a")
        try await repository.sendStamp(.understand, to: "a")
        let post = try #require(try await repository.timeline(category: nil).first)
        #expect(post.sameHereCount == 3)
        #expect(post.count(of: .understand) == 1)
        #expect(try await repository.sentStamps(for: "a") == [.sameHere, .understand])
    }

    /// まとめて読むときは、送った投稿だけを返し、消えた投稿は外す
    @Test
    func sentStampsForManyPostsSkipsUnsentAndMissing() async throws {
        let repository = makeRepository()
        repository.seed(otherPost(id: "a"))
        repository.seed(otherPost(id: "b"))
        try await repository.sendStamp(.sameHere, to: "a")
        try await repository.sendStamp(.wellDone, to: "a")
        #expect(try await repository.sentStamps(for: ["a", "b", "missing"]) == ["a": [.sameHere, .wellDone]])
    }

    @Test
    func myPostIDsContainsOnlyMyActivePosts() async throws {
        let repository = makeRepository()
        repository.seed(otherPost(id: "other"))
        let mine = try await repository.submit(body: "自分の投稿", category: .partner)
        #expect(try await repository.myPostIDs() == [mine.id])
        clock.advance(hours: 24)
        #expect(try await repository.myPostIDs().isEmpty)
    }

    @Test
    func cannotSendStampToOwnOrExpiredPost() async throws {
        let repository = makeRepository()
        let mine = try await repository.submit(body: "本文", category: .partner)
        await #expect(throws: PostRepositoryError.ownPost) {
            try await repository.sendStamp(.understand, to: mine.id)
        }
        repository.seed(otherPost(id: "old", hoursAgo: 23))
        clock.advance(hours: 1)
        await #expect(throws: PostRepositoryError.postNotFound) {
            try await repository.sendStamp(.understand, to: "old")
        }
    }

    // MARK: - 通報・非表示

    @Test
    func postIsHiddenWhenReportsReachThreshold() async throws {
        let repository = makeRepository(identity: InMemoryAnonymousIDStore(id: "reporter-0"))
        repository.seed(otherPost(id: "a"))
        // 同じ人の通報は 1 回として数える
        try await repository.report(postID: "a", reason: .harassment)
        try await repository.report(postID: "a", reason: .spam)
        #expect(try await repository.timeline(category: nil).map(\.id) == ["a"])
    }

    @Test
    func postIsHiddenAfterReportsFromDifferentPeople() async throws {
        let identity = InMemoryAnonymousIDStore()
        let repository = makeRepository(identity: identity)
        repository.seed(otherPost(id: "a"))
        for _ in 0..<ReportPolicy.autoHideThreshold {
            #expect(try await repository.timeline(category: nil).map(\.id) == ["a"])
            try await repository.report(postID: "a", reason: .harassment)
            // 別の人として通報する
            identity.deleteID()
        }
        #expect(try await repository.timeline(category: nil).isEmpty)
    }

    /// 自分の投稿は通報できない
    @Test
    func cannotReportOwnPost() async throws {
        let repository = makeRepository()
        let post = try await repository.submit(body: "本文", category: .money)
        await #expect(throws: PostRepositoryError.ownPost) {
            try await repository.report(postID: post.id, reason: .spam)
        }
    }

    @Test
    func hiddenPostIsExcludedFromTimeline() async throws {
        let repository = makeRepository()
        repository.seed(otherPost(id: "a", hoursAgo: 2))
        repository.seed(otherPost(id: "b", hoursAgo: 1))
        try await repository.hide(postID: "a")
        #expect(try await repository.timeline(category: nil).map(\.id) == ["b"])
    }

    // MARK: - デモデータ

    @Test
    func previewHasActivePosts() async throws {
        let repository = InMemoryPostRepository.preview()
        #expect(try await !repository.timeline(category: nil).isEmpty)
    }
}
