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

    /// 消せなかったときは一覧に残し、その投稿で消せなかったことを伝える。読み直したら、その表示は消す
    @Test
    func failedDeleteKeepsPost() async throws {
        let repository = GatedPostRepository(base: makeRepository())
        let model = NoteViewModel(repository: repository)
        await model.load()
        let post = try #require(model.posts.first { $0.id == "old" })
        repository.deleteError = GatedPostRepository.Failure()
        await model.delete(post)
        #expect(model.failedDeletion == "old")
        #expect(model.deleting == nil)
        #expect(model.posts.map(\.id) == ["new", "old", "soon"])

        await model.load()
        #expect(model.failedDeletion == nil)
        #expect(model.posts.map(\.id) == ["new", "old", "soon"])
    }

    /// 消す前に始めた読み込みの結果に、消した投稿が入っていても出さない
    @Test
    func loadStartedBeforeDeleteDoesNotBringBackDeletedPost() async throws {
        let repository = GatedPostRepository(base: makeRepository())
        let model = NoteViewModel(repository: repository)
        await model.load()
        let post = try #require(model.posts.first { $0.id == "old" })

        repository.holdsMyPosts = true
        let load = Task { await model.load() }
        await repository.waitForHeldCalls(1)
        repository.holdsMyPosts = false
        await model.delete(post)
        // 消す前に読んだ一覧（"old" を含む）を返す
        repository.release(at: 0)
        await load.value

        #expect(model.posts.map(\.id) == ["new", "soon"])
        #expect(model.state == .loaded)
    }

    /// 続けて読み込んだときは、最後に始めた読み込みの結果だけを使う
    @Test
    func olderLoadDoesNotOverwriteNewerLoad() async throws {
        let repository = GatedPostRepository(base: makeRepository())
        let model = NoteViewModel(repository: repository)
        repository.holdsMyPosts = true

        let older = Task { await model.load() }
        await repository.waitForHeldCalls(1)
        // 別の端末で消したなどで、2 回目の読み込みでは "old" が無い
        try await repository.base.delete(postID: "old")
        let newer = Task { await model.load() }
        await repository.waitForHeldCalls(2)

        repository.release(at: 1)
        await newer.value
        #expect(model.posts.map(\.id) == ["new", "soon"])
        repository.release(at: 0)
        await older.value
        #expect(model.posts.map(\.id) == ["new", "soon"])
        #expect(model.state == .loaded)
    }

    /// 読み込みに失敗したとき、一覧が無ければ失敗を出し、あれば一覧を残す
    @Test
    func failedLoadKeepsShownPosts() async {
        let repository = GatedPostRepository(base: makeRepository())
        let model = NoteViewModel(repository: repository)
        repository.myPostsError = GatedPostRepository.Failure()
        await model.load()
        #expect(model.state == .failed)

        repository.myPostsError = nil
        await model.load()
        #expect(model.posts.count == 3)
        repository.myPostsError = GatedPostRepository.Failure()
        await model.load()
        #expect(model.state == .loaded)
        #expect(model.posts.count == 3)
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

/// 読み込みの結果を返すのを止めたり、失敗させたりできる Repository。それ以外は base に任せる
private final class GatedPostRepository: PostRepository {
    struct Failure: Error {}

    let base: InMemoryPostRepository
    /// true のあいだ、myPosts() は一覧を読んだ後、release(at:) されるまで返さない
    var holdsMyPosts = false
    var myPostsError: (any Error)?
    var deleteError: (any Error)?
    private var held: [CheckedContinuation<Void, Never>?] = []

    init(base: InMemoryPostRepository) {
        self.base = base
    }

    /// 止めている myPosts() の呼び出しが count 件になるまで待つ
    func waitForHeldCalls(_ count: Int) async {
        while held.count < count {
            await Task.yield()
        }
    }

    /// index 番目（呼ばれた順）に止めた myPosts() を返させる
    func release(at index: Int) {
        held[index]?.resume()
        held[index] = nil
    }

    func timeline(category: PostCategory?) async throws -> [Post] {
        try await base.timeline(category: category)
    }

    func submit(body: String, category: PostCategory) async throws -> Post {
        try await base.submit(body: body, category: category)
    }

    func myPosts() async throws -> [Post] {
        if let myPostsError {
            throw myPostsError
        }
        let posts = try await base.myPosts()
        if holdsMyPosts {
            await withCheckedContinuation { held.append($0) }
        }
        return posts
    }

    func delete(postID: Post.ID) async throws {
        if let deleteError {
            throw deleteError
        }
        try await base.delete(postID: postID)
    }

    func sendStamp(_ stamp: EmpathyStamp, to postID: Post.ID) async throws {
        try await base.sendStamp(stamp, to: postID)
    }

    func sentStamps(for postID: Post.ID) async throws -> Set<EmpathyStamp> {
        try await base.sentStamps(for: postID)
    }
}
