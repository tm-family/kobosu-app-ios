//
//  PostCompleteViewModelTests.swift
//  KobosuTests
//

import Foundation
@testable import Kobosu
import Testing

struct PostCompleteViewModelTests {
    private let now = Date(timeIntervalSince1970: 1_000_000)

    private func makeRepository() -> InMemoryPostRepository {
        InMemoryPostRepository(identity: InMemoryAnonymousIDStore(id: "me"), now: { [now] in now })
    }

    /// 未分類で投稿したときだけ問いかける。カテゴリありの投稿には出さない
    @Test
    func asksOnlyForUncategorizedPost() async throws {
        let repository = makeRepository()
        let uncategorized = try await repository.submit(body: "本文", category: .uncategorized)
        let categorized = try await repository.submit(body: "本文", category: .money)
        let lastCategories = InMemoryLastCategoryStore()
        #expect(PostCompleteViewModel(post: uncategorized, repository: repository, lastCategories: lastCategories).asksForCategory)
        #expect(!PostCompleteViewModel(post: categorized, repository: repository, lastCategories: lastCategories).asksForCategory)
    }

    /// 選べるのは未分類を除く 6 つ
    @Test
    func assignableCategoriesExcludeUncategorized() async throws {
        let repository = makeRepository()
        let post = try await repository.submit(body: "本文", category: .uncategorized)
        let model = PostCompleteViewModel(post: post, repository: repository, lastCategories: InMemoryLastCategoryStore())
        #expect(model.assignableCategories == PostCategory.filterable)
        #expect(!model.assignableCategories.contains(.uncategorized))
    }

    /// 付けたら投稿のタグが替わり、問いかけを消す。タイムラインにも反映され、前回のカテゴリにもなる
    @Test
    func assignUpdatesPostAndHidesPrompt() async throws {
        let repository = makeRepository()
        let lastCategories = InMemoryLastCategoryStore(category: .money)
        let post = try await repository.submit(body: "本文", category: .uncategorized)
        let model = PostCompleteViewModel(post: post, repository: repository, lastCategories: lastCategories)

        #expect(await model.assign(.partner))
        #expect(model.post.category == .partner)
        #expect(model.post.id == post.id)
        #expect(model.assignState == .assigned)
        #expect(!model.asksForCategory)
        #expect(try await repository.timeline(category: .partner).map(\.id) == [post.id])
        #expect(lastCategories.load() == .partner)

        // 2 回目は付けない（1 回だけ）
        #expect(await !model.assign(.money))
        #expect(model.post.category == .partner)
    }

    /// 付けられなかったら、やさしい文を出して問いかけを残し、もう一度ためせる。前回のカテゴリは変えない
    @Test
    func failedAssignKeepsPrompt() async throws {
        let repository = makeRepository()
        let lastCategories = InMemoryLastCategoryStore(category: .money)
        // Repository に無い投稿（期限切れ・消えた）にする
        let post = Post(id: "missing", body: "本文", category: .uncategorized, createdAt: now)
        let model = PostCompleteViewModel(post: post, repository: repository, lastCategories: lastCategories)

        #expect(await !model.assign(.partner))
        #expect(model.assignState == .failed)
        #expect(model.asksForCategory)
        #expect(model.post.category == .uncategorized)
        #expect(lastCategories.load() == .money)
        #expect(!model.isAssigning)
    }

    /// 未分類は付けない（未分類には戻せない）
    @Test
    func cannotAssignUncategorized() async throws {
        let repository = makeRepository()
        let post = try await repository.submit(body: "本文", category: .uncategorized)
        let model = PostCompleteViewModel(post: post, repository: repository, lastCategories: InMemoryLastCategoryStore())
        #expect(await !model.assign(.uncategorized))
        #expect(model.assignState == .idle)
        #expect(model.asksForCategory)
    }

    /// カテゴリありの投稿には付けない（画面には出さないが、呼ばれても何もしない）
    @Test
    func doesNothingForCategorizedPost() async throws {
        let repository = makeRepository()
        let post = try await repository.submit(body: "本文", category: .housework)
        let model = PostCompleteViewModel(post: post, repository: repository, lastCategories: InMemoryLastCategoryStore())
        #expect(await !model.assign(.money))
        #expect(model.post.category == .housework)
        #expect(model.assignState == .idle)
    }

    /// 付けている途中にもう一度付けても、書き込まない（1 回だけ）
    @Test(.timeLimit(.minutes(1)))
    func secondAssignWhileAssigningDoesNothing() async throws {
        let base = makeRepository()
        let post = try await base.submit(body: "本文", category: .uncategorized)
        let repository = HeldAssignRepository(base: base)
        let model = PostCompleteViewModel(post: post, repository: repository, lastCategories: InMemoryLastCategoryStore())

        let first = Task { await model.assign(.partner) }
        while !repository.isHolding {
            await Task.yield()
        }
        #expect(model.isAssigning)
        #expect(await !model.assign(.money))
        repository.release()
        #expect(await first.value)
        #expect(repository.assignCount == 1)
        #expect(model.post.category == .partner)
    }
}

/// カテゴリを付ける書き込みを、release() されるまで止める Repository。それ以外は base に任せる
private final class HeldAssignRepository: PostRepository {
    let base: InMemoryPostRepository
    private(set) var assignCount = 0
    private var held: CheckedContinuation<Void, Never>?

    init(base: InMemoryPostRepository) {
        self.base = base
    }

    var isHolding: Bool {
        held != nil
    }

    func release() {
        held?.resume()
        held = nil
    }

    func timeline(category: PostCategory?) async throws -> [Post] {
        try await base.timeline(category: category)
    }

    func submit(body: String, category: PostCategory) async throws -> Post {
        try await base.submit(body: body, category: category)
    }

    func myPosts() async throws -> [Post] {
        try await base.myPosts()
    }

    func delete(postID: Post.ID) async throws {
        try await base.delete(postID: postID)
    }

    func assignCategory(_ category: PostCategory, toPostID postID: Post.ID) async throws -> Post {
        assignCount += 1
        await withCheckedContinuation { held = $0 }
        return try await base.assignCategory(category, toPostID: postID)
    }

    func sendStamp(_ stamp: EmpathyStamp, to postID: Post.ID) async throws {
        try await base.sendStamp(stamp, to: postID)
    }

    func sentStamps(for postID: Post.ID) async throws -> Set<EmpathyStamp> {
        try await base.sentStamps(for: postID)
    }
}
