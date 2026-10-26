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
}
