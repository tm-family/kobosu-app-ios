//
//  TimelineViewModelTests.swift
//  KobosuTests
//

import Foundation
@testable import Kobosu
import Testing

struct TimelineViewModelTests {
    private let now = Date(timeIntervalSince1970: 1_000_000)

    private func makeRepository() -> InMemoryPostRepository {
        let repository = InMemoryPostRepository(identity: InMemoryAnonymousIDStore(id: "me"), now: { [now] in now })
        repository.seed(Post(id: "in-laws", body: "本文", category: .inLaws, createdAt: now.addingTimeInterval(-3 * 60 * 60)))
        repository.seed(Post(id: "money", body: "本文", category: .money, createdAt: now.addingTimeInterval(-2 * 60 * 60)))
        repository.seed(Post(id: "soon", body: "本文", category: .inLaws, createdAt: now.addingTimeInterval(-23.9 * 60 * 60)))
        return repository
    }

    @Test
    func loadShowsNewestFirst() async {
        let model = TimelineViewModel(repository: makeRepository())
        #expect(model.state == .idle)
        await model.load()
        #expect(model.state == .loaded)
        #expect(model.posts.map(\.id) == ["money", "in-laws", "soon"])
    }

    @Test
    func selectFiltersByCategory() async {
        let model = TimelineViewModel(repository: makeRepository())
        await model.load()
        await model.select(.inLaws)
        #expect(model.selectedCategory == .inLaws)
        #expect(model.posts.map(\.id) == ["in-laws", "soon"])
        await model.select(nil)
        #expect(model.posts.count == 3)
    }

    /// 読み込んだ後に期限を過ぎた投稿は、表示から外す
    @Test
    func visiblePostsExcludeExpiredAtDisplayTime() async {
        let model = TimelineViewModel(repository: makeRepository())
        await model.load()
        #expect(model.visiblePosts(at: now).count == 3)
        #expect(model.visiblePosts(at: now.addingTimeInterval(10 * 60)).map(\.id) == ["money", "in-laws"])
    }

    @Test
    func loadsSentStamps() async throws {
        let repository = makeRepository()
        try await repository.sendStamp(.sameHere, to: "money")
        let model = TimelineViewModel(repository: repository)
        await model.load()
        let money = try #require(model.posts.first { $0.id == "money" })
        #expect(model.sentStamps(for: money) == [.sameHere])
        #expect(money.sameHereCount == 1)
    }

    @Test
    func selectingSameCategoryDoesNotReload() async {
        let repository = CountingPostRepository()
        let model = TimelineViewModel(repository: repository)
        await model.select(.money)
        await model.select(.money)
        #expect(repository.timelineCalls == 1)
    }

    /// 更新に失敗しても、表示中の一覧は残す
    @Test
    func failedRefreshKeepsPosts() async {
        let repository = CountingPostRepository()
        let model = TimelineViewModel(repository: repository)
        await model.load()
        #expect(model.posts.count == 1)
        repository.fails = true
        await model.load()
        #expect(model.state == .loaded)
        #expect(model.posts.count == 1)
    }

    /// 取り消されたときは、失敗として出さない
    @Test
    func cancelledLoadIsNotFailure() async {
        let repository = CountingPostRepository()
        repository.error = CancellationError()
        let model = TimelineViewModel(repository: repository)
        await model.load()
        #expect(model.state == .idle)
    }

    @Test
    func sendUpdatesCountAndSentStampsAtOnce() async throws {
        let model = TimelineViewModel(repository: makeRepository())
        await model.load()
        let post = try #require(model.post(id: "money"))
        try await model.send(.sameHere, to: post)
        // 2 回目は何もしない
        try await model.send(.sameHere, to: post)
        let updated = try #require(model.post(id: "money"))
        #expect(updated.sameHereCount == 1)
        #expect(model.sentStamps(for: updated) == [.sameHere])
    }

    @Test
    func ownPostIsMarkedAndCannotReceiveStamp() async throws {
        let repository = makeRepository()
        let mine = try await repository.submit(body: "本文", category: .partner)
        let model = TimelineViewModel(repository: repository)
        await model.load()
        let post = try #require(model.post(id: mine.id))
        #expect(model.isMine(post))
        #expect(!model.isMine(try #require(model.post(id: "money"))))
        await #expect(throws: PostRepositoryError.ownPost) {
            try await model.send(.understand, to: post)
        }
        #expect(model.sentStamps(for: post).isEmpty)
    }

    @Test
    func failedLoadShowsFailure() async {
        let model = TimelineViewModel(repository: FailingPostRepository())
        await model.load()
        #expect(model.state == .failed)
        #expect(model.posts.isEmpty)
    }
}

struct RemainingTimeTests {
    nonisolated private static let hour: TimeInterval = 60 * 60
    nonisolated private static let minute: TimeInterval = 60

    /// 型推論に時間がかからないよう、型を明示する
    nonisolated private static let cases: [(TimeInterval, RemainingTime)] = [
        (24 * hour, .hours(24)),
        (22.5 * hour, .hours(22)),
        (hour, .hours(1)),
        (59 * minute + 1, .minutes(60)),
        (45 * minute, .minutes(45)),
        (1, .minutes(1)),
        (0, .minutes(1)),
        (-10, .minutes(1))
    ]

    @Test(arguments: cases)
    func remainingTime(interval: TimeInterval, expected: RemainingTime) {
        #expect(RemainingTime(interval) == expected)
    }
}

private final class FailingPostRepository: PostRepository {
    struct Failure: Error {}

    func timeline(category: PostCategory?) async throws -> [Post] { throw Failure() }
    func submit(body: String, category: PostCategory) async throws -> Post { throw Failure() }
    func myPosts() async throws -> [Post] { throw Failure() }
    func delete(postID: Post.ID) async throws { throw Failure() }
    func sendStamp(_ stamp: EmpathyStamp, to postID: Post.ID) async throws { throw Failure() }
    func sentStamps(for postID: Post.ID) async throws -> Set<EmpathyStamp> { throw Failure() }
}

/// 呼ばれた回数を数え、失敗させることもできる Repository
private final class CountingPostRepository: PostRepository {
    struct Failure: Error {}

    var timelineCalls = 0
    var fails = false
    var error: (any Error)?

    func timeline(category: PostCategory?) async throws -> [Post] {
        timelineCalls += 1
        if let error {
            throw error
        }
        if fails {
            throw Failure()
        }
        return [Post(id: "a", body: "本文", category: category ?? .other, createdAt: Date())]
    }

    func submit(body: String, category: PostCategory) async throws -> Post { throw Failure() }
    func myPosts() async throws -> [Post] { [] }
    func delete(postID: Post.ID) async throws {}
    func sendStamp(_ stamp: EmpathyStamp, to postID: Post.ID) async throws {}
    func sentStamps(for postID: Post.ID) async throws -> Set<EmpathyStamp> { [] }
}
