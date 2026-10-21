//
//  ComposeViewModelTests.swift
//  KobosuTests
//

import Foundation
@testable import Kobosu
import Testing

struct ComposeViewModelTests {
    private let now = Date(timeIntervalSince1970: 1_000_000)

    private func makeRepository() -> InMemoryPostRepository {
        InMemoryPostRepository(identity: InMemoryAnonymousIDStore(id: "me"), now: { [now] in now })
    }

    @Test
    func startsEmptyWithoutDraft() {
        let model = ComposeViewModel(repository: makeRepository(), drafts: InMemoryComposeDraftStore())
        #expect(model.body.isEmpty)
        #expect(model.category == nil)
        #expect(!model.canSubmit)
    }

    /// 開き直すと、下書きの続きから書ける
    @Test
    func restoresDraft() {
        let drafts = InMemoryComposeDraftStore(draft: ComposeDraft(body: "書きかけ", category: .partner))
        let model = ComposeViewModel(repository: makeRepository(), drafts: drafts)
        #expect(model.body == "書きかけ")
        #expect(model.category == .partner)
        #expect(model.canSubmit)
    }

    @Test
    func saveDraftKeepsBodyAndCategory() {
        let drafts = InMemoryComposeDraftStore()
        let model = ComposeViewModel(repository: makeRepository(), drafts: drafts)
        model.body = "モヤっとした。"
        model.category = .inLaws
        model.saveDraft()
        #expect(drafts.load() == ComposeDraft(body: "モヤっとした。", category: .inLaws))
    }

    @Test
    func needsBodyAndCategoryToSubmit() {
        let model = ComposeViewModel(repository: makeRepository(), drafts: InMemoryComposeDraftStore())
        model.body = "本文"
        #expect(!model.canSubmit)
        model.category = .money
        #expect(model.canSubmit)
        model.body = " \n "
        #expect(!model.canSubmit)
    }

    /// 上限は前後の空白を除いた文字数で判定する
    @Test
    func cannotSubmitOverLimit() {
        let model = ComposeViewModel(repository: makeRepository(), drafts: InMemoryComposeDraftStore())
        model.category = .other
        model.body = String(repeating: "あ", count: Post.maxBodyLength) + "\n"
        #expect(model.bodyLength == Post.maxBodyLength)
        #expect(!model.isOverLimit)
        #expect(model.canSubmit)
        model.body = String(repeating: "あ", count: Post.maxBodyLength + 1)
        #expect(model.isOverLimit)
        #expect(!model.canSubmit)
    }

    /// 投稿できたら、下書きと入力を消す
    @Test
    func submitClearsDraft() async throws {
        let repository = makeRepository()
        let drafts = InMemoryComposeDraftStore()
        let model = ComposeViewModel(repository: repository, drafts: drafts)
        model.body = "  今日も黙って洗い物をした。\n"
        model.category = .housework
        model.saveDraft()

        let post = try #require(await model.submit())
        #expect(post.body == "今日も黙って洗い物をした。")
        #expect(post.category == .housework)
        #expect(post.expireAt == now.addingTimeInterval(Post.lifetime))
        #expect(try await repository.myPosts().map(\.id) == [post.id])
        #expect(drafts.load() == nil)
        #expect(model.body.isEmpty)
        #expect(model.category == nil)
        #expect(model.state == .editing)
    }

    /// 投稿できなかったら、下書きを残してもう一度送れるようにする
    @Test
    func failedSubmitKeepsDraft() async {
        let drafts = InMemoryComposeDraftStore()
        let model = ComposeViewModel(repository: FailingPostRepository(), drafts: drafts)
        model.body = "本文"
        model.category = .parenting
        model.saveDraft()

        #expect(await model.submit() == nil)
        #expect(model.state == .failed)
        #expect(model.body == "本文")
        #expect(drafts.load() == ComposeDraft(body: "本文", category: .parenting))
        #expect(model.canSubmit)

        // 書き直したら、失敗の表示を消す
        model.body = "本文を直した"
        model.saveDraft()
        #expect(model.state == .editing)
    }

    @Test
    func submitDoesNothingWhenNotReady() async throws {
        let repository = makeRepository()
        let model = ComposeViewModel(repository: repository, drafts: InMemoryComposeDraftStore())
        model.body = "本文"
        #expect(await model.submit() == nil)
        #expect(try await repository.myPosts().isEmpty)
        #expect(model.state == .editing)
    }
}

/// 投稿がいつも失敗する Repository
private final class FailingPostRepository: PostRepository {
    struct Failure: Error {}

    func timeline(category: PostCategory?) async throws -> [Post] {
        throw Failure()
    }

    func submit(body: String, category: PostCategory) async throws -> Post {
        throw Failure()
    }

    func myPosts() async throws -> [Post] {
        throw Failure()
    }

    func delete(postID: Post.ID) async throws {
        throw Failure()
    }

    func sendStamp(_ stamp: EmpathyStamp, to postID: Post.ID) async throws {
        throw Failure()
    }

    func sentStamps(for postID: Post.ID) async throws -> Set<EmpathyStamp> {
        throw Failure()
    }
}
