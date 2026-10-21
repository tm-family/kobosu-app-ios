//
//  NoteViewModelTests.swift
//  KobosuTests
//

import Foundation
@testable import Kobosu
import Testing

struct NoteViewModelTests {
    private let now = Date(timeIntervalSince1970: 1_000_000)

    private func makeRepository() -> InMemoryPostRepository {
        let repository = InMemoryPostRepository(identity: InMemoryAnonymousIDStore(id: "me"), now: { [now] in now })
        repository.seed(
            Post(id: "old", body: "本文", category: .inLaws, createdAt: now.addingTimeInterval(-3 * 60 * 60), stampCounts: [.sameHere: 2]),
            authorID: "me"
        )
        repository.seed(Post(id: "new", body: "本文", category: .money, createdAt: now.addingTimeInterval(-1 * 60 * 60)), authorID: "me")
        repository.seed(
            Post(id: "soon", body: "本文", category: .partner, createdAt: now.addingTimeInterval(-23.9 * 60 * 60)),
            authorID: "me"
        )
        repository.seed(Post(id: "others", body: "本文", category: .money, createdAt: now))
        return repository
    }

    /// 自分の投稿だけを新しい順に出す
    @Test
    func loadShowsOnlyMyPostsNewestFirst() async {
        let model = NoteViewModel(repository: makeRepository())
        #expect(model.state == .idle)
        await model.load()
        #expect(model.state == .loaded)
        #expect(model.posts.map(\.id) == ["new", "old", "soon"])
        #expect(model.posts.first { $0.id == "old" }?.sameHereCount == 2)
    }

    /// 読み込んだ後に期限を過ぎた投稿は、表示から外す
    @Test
    func visiblePostsExcludeExpiredAtDisplayTime() async {
        let model = NoteViewModel(repository: makeRepository())
        await model.load()
        #expect(model.visiblePosts(at: now.addingTimeInterval(10 * 60)).map(\.id) == ["new", "old"])
    }

    /// 消した投稿は一覧からもサーバーからも消える
    @Test
    func deleteRemovesPost() async throws {
        let repository = makeRepository()
        let model = NoteViewModel(repository: repository)
        await model.load()
        let post = try #require(model.posts.first { $0.id == "old" })
        await model.delete(post)
        #expect(model.posts.map(\.id) == ["new", "soon"])
        #expect(model.failedDeletion == nil)
        #expect(model.deleting == nil)
        #expect(try await repository.myPosts().map(\.id) == ["new", "soon"])
        // 読み直しても戻らない
        await model.load()
        #expect(model.posts.map(\.id) == ["new", "soon"])
    }

    /// すでに消えていた投稿（期限切れなど）は、一覧から外して失敗とは伝えない
    @Test
    func deleteOfMissingPostRemovesItFromList() async throws {
        let repository = makeRepository()
        let model = NoteViewModel(repository: repository)
        await model.load()
        let post = try #require(model.posts.first { $0.id == "new" })
        try await repository.delete(postID: post.id)
        await model.delete(post)
        #expect(model.posts.map(\.id) == ["old", "soon"])
        #expect(model.failedDeletion == nil)
    }

    /// 消せなかったときは一覧に残し、その投稿で消せなかったことを伝える
    @Test
    func failedDeleteKeepsPost() async throws {
        let repository = makeRepository()
        let model = NoteViewModel(repository: repository)
        await model.load()
        let others = Post(id: "others", body: "本文", category: .money, createdAt: now)
        await model.delete(others)
        #expect(model.failedDeletion == "others")
        #expect(model.posts.map(\.id) == ["new", "old", "soon"])
        #expect(try await repository.timeline(category: nil).contains { $0.id == "others" })
    }

    @Test
    func loadShowsNothingWithoutMyPosts() async {
        let repository = InMemoryPostRepository(identity: InMemoryAnonymousIDStore(id: "me"), now: { [now] in now })
        repository.seed(Post(id: "others", body: "本文", category: .money, createdAt: now))
        let model = NoteViewModel(repository: repository)
        await model.load()
        #expect(model.state == .loaded)
        #expect(model.posts.isEmpty)
    }
}
