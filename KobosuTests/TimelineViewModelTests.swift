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
