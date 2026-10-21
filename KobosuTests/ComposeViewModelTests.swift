//
//  ComposeViewModelTests.swift
//  KobosuTests
//

import Foundation
@testable import Kobosu
import Testing

struct ComposeViewModelTests {
    private let now = Date(timeIntervalSince1970: 1_000_000)

    /// 伏せ字の候補を見つけない（検知の結果に左右されずに投稿の流れを確かめる）
    nonisolated private static let noCandidates: @Sendable (String) -> [MaskingCandidate] = { _ in [] }

    /// 本文の「田中」を人の名前の候補にする
    nonisolated private static let findsTanaka: @Sendable (String) -> [MaskingCandidate] = { text in
        guard let range = text.range(of: "田中") else {
            return []
        }
        return [MaskingCandidate(kind: .personName, range: range, text: "田中")]
    }

    private func makeRepository() -> InMemoryPostRepository {
        InMemoryPostRepository(identity: InMemoryAnonymousIDStore(id: "me"), now: { [now] in now })
    }

    @Test
    func startsEmptyWithoutDraft() {
        let model = ComposeViewModel(repository: makeRepository(), drafts: InMemoryComposeDraftStore(), detect: Self.noCandidates)
        #expect(model.body.isEmpty)
        #expect(model.category == nil)
        #expect(!model.canSubmit)
    }

    /// 開き直すと、下書きの続きから書ける
    @Test
    func restoresDraft() {
        let drafts = InMemoryComposeDraftStore(draft: ComposeDraft(body: "書きかけ", category: .partner))
        let model = ComposeViewModel(repository: makeRepository(), drafts: drafts, detect: Self.noCandidates)
        #expect(model.body == "書きかけ")
        #expect(model.category == .partner)
        #expect(model.canSubmit)
    }

    @Test
    func saveDraftKeepsBodyAndCategory() {
        let drafts = InMemoryComposeDraftStore()
        let model = ComposeViewModel(repository: makeRepository(), drafts: drafts, detect: Self.noCandidates)
        model.body = "モヤっとした。"
        model.category = .inLaws
        model.saveDraft()
        #expect(drafts.load() == ComposeDraft(body: "モヤっとした。", category: .inLaws))
    }

    @Test
    func needsBodyAndCategoryToSubmit() {
        let model = ComposeViewModel(repository: makeRepository(), drafts: InMemoryComposeDraftStore(), detect: Self.noCandidates)
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
        let model = ComposeViewModel(repository: makeRepository(), drafts: InMemoryComposeDraftStore(), detect: Self.noCandidates)
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
        let model = ComposeViewModel(repository: repository, drafts: drafts, detect: Self.noCandidates)
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
        let model = ComposeViewModel(repository: FailingPostRepository(), drafts: drafts, detect: Self.noCandidates)
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
        let model = ComposeViewModel(repository: repository, drafts: InMemoryComposeDraftStore(), detect: Self.noCandidates)
        model.body = "本文"
        #expect(await model.submit() == nil)
        #expect(try await repository.myPosts().isEmpty)
        #expect(model.state == .editing)
    }

    /// 伏せ字の候補が見つかったら投稿せずに確認を出し、最初はすべて伏せる
    @Test
    func submitShowsReviewWhenCandidatesFound() async throws {
        let repository = makeRepository()
        let model = ComposeViewModel(repository: repository, drafts: InMemoryComposeDraftStore(), detect: Self.findsTanaka)
        model.body = " 田中さんにまた言われた。"
        model.category = .inLaws

        #expect(await model.submit() == nil)
        let review = try #require(model.review)
        #expect(review.text == "田中さんにまた言われた。")
        #expect(review.isMasked(at: 0))
        #expect(review.result == "〇〇さんにまた言われた。")
        #expect(model.state == .editing)
        #expect(try await repository.myPosts().isEmpty)
    }

    /// 伏せると選んだ候補だけを伏せて投稿し、下書きと確認を消す
    @Test
    func submitReviewPostsMaskedText() async throws {
        let repository = makeRepository()
        let drafts = InMemoryComposeDraftStore()
        let model = ComposeViewModel(repository: repository, drafts: drafts, detect: Self.findsTanaka)
        model.body = "田中さんにまた言われた。"
        model.category = .inLaws
        model.saveDraft()
        _ = await model.submit()

        let post = try #require(await model.submitReview())
        #expect(post.body == "〇〇さんにまた言われた。")
        #expect(model.review == nil)
        #expect(drafts.load() == nil)
        #expect(try await repository.myPosts().map(\.body) == ["〇〇さんにまた言われた。"])
    }

    /// 「そのまま」を選んだ候補は伏せずに投稿する
    @Test
    func submitReviewKeepsUnmaskedCandidates() async throws {
        let model = ComposeViewModel(repository: makeRepository(), drafts: InMemoryComposeDraftStore(), detect: Self.findsTanaka)
        model.body = "田中さんにまた言われた。"
        model.category = .inLaws
        _ = await model.submit()
        model.setMasked(false, at: 0)
        #expect(model.review?.result == "田中さんにまた言われた。")

        let post = try #require(await model.submitReview())
        #expect(post.body == "田中さんにまた言われた。")
    }

    /// 「自分で書き直す」で確認を閉じたら、書き直してもう一度投稿できる
    @Test
    func closingReviewReturnsToEditing() async throws {
        let model = ComposeViewModel(repository: makeRepository(), drafts: InMemoryComposeDraftStore(), detect: Self.findsTanaka)
        model.body = "田中さんにまた言われた。"
        model.category = .inLaws
        _ = await model.submit()
        model.review = nil
        #expect(!model.canSubmitReview)
        #expect(await model.submitReview() == nil)

        model.body = "また言われた。"
        let post = try #require(await model.submit())
        #expect(post.body == "また言われた。")
    }

    /// 伏せ字にすると上限を超えるときは、確認から投稿できない（1 文字の名前を「〇〇」にすると 1 文字増える）
    @Test
    func reviewOverLimitCannotBeSubmitted() async {
        let findsHayashi: @Sendable (String) -> [MaskingCandidate] = { text in
            text.range(of: "林").map { [MaskingCandidate(kind: .personName, range: $0, text: "林")] } ?? []
        }
        let model = ComposeViewModel(repository: makeRepository(), drafts: InMemoryComposeDraftStore(), detect: findsHayashi)
        model.body = String(repeating: "あ", count: Post.maxBodyLength - 1) + "林"
        model.category = .other
        _ = await model.submit()
        #expect(model.review?.isOverLimit == true)
        #expect(!model.canSubmitReview)
        #expect(await model.submitReview() == nil)
        // 伏せないなら投稿できる
        model.setMasked(false, at: 0)
        #expect(model.canSubmitReview)
    }

    /// 送信中は、もう一度押しても投稿しない。送信の途中で下書きを保存しても、送信中のままにする
    @Test(.timeLimit(.minutes(1)))
    func secondSubmitWhileSubmittingDoesNothing() async throws {
        let repository = FlakyPostRepository(base: makeRepository())
        let model = ComposeViewModel(repository: repository, drafts: InMemoryComposeDraftStore(), detect: Self.noCandidates)
        model.body = "本文"
        model.category = .money
        repository.holdsSubmit = true

        let first = Task { await model.submit() }
        // 送信を止めているあいだは、送信中のまま変わらない
        while !repository.isHoldingSubmit {
            await Task.yield()
        }
        #expect(model.state == .submitting)
        #expect(!model.canSubmit)
        #expect(await model.submit() == nil)
        model.saveDraft()
        #expect(model.state == .submitting)

        repository.releaseSubmit()
        #expect(await first.value != nil)
        #expect(try await repository.myPosts().count == 1)
    }

    /// 失敗した後にもう一度押すと、投稿できる
    @Test
    func retryAfterFailureSucceeds() async throws {
        let repository = FlakyPostRepository(base: makeRepository())
        let model = ComposeViewModel(repository: repository, drafts: InMemoryComposeDraftStore(), detect: Self.noCandidates)
        model.body = "本文"
        model.category = .money
        repository.failsSubmit = true
        #expect(await model.submit() == nil)
        #expect(model.state == .failed)

        repository.failsSubmit = false
        let post = try #require(await model.submit())
        #expect(post.body == "本文")
        #expect(model.state == .editing)
    }
}

/// 投稿を失敗させたり、止めたりできる Repository。それ以外は base に任せる
private final class FlakyPostRepository: PostRepository {
    struct Failure: Error {}

    let base: InMemoryPostRepository
    var failsSubmit = false
    /// true のあいだ、submit は releaseSubmit() されるまで返さない
    var holdsSubmit = false
    private var heldSubmit: CheckedContinuation<Void, Never>?

    init(base: InMemoryPostRepository) {
        self.base = base
    }

    var isHoldingSubmit: Bool {
        heldSubmit != nil
    }

    func releaseSubmit() {
        heldSubmit?.resume()
        heldSubmit = nil
    }

    func timeline(category: PostCategory?) async throws -> [Post] {
        try await base.timeline(category: category)
    }

    func submit(body: String, category: PostCategory) async throws -> Post {
        if failsSubmit {
            throw Failure()
        }
        if holdsSubmit {
            await withCheckedContinuation { heldSubmit = $0 }
        }
        return try await base.submit(body: body, category: category)
    }

    func myPosts() async throws -> [Post] {
        try await base.myPosts()
    }

    func delete(postID: Post.ID) async throws {
        try await base.delete(postID: postID)
    }

    func sendStamp(_ stamp: EmpathyStamp, to postID: Post.ID) async throws {
        try await base.sendStamp(stamp, to: postID)
    }

    func sentStamps(for postID: Post.ID) async throws -> Set<EmpathyStamp> {
        try await base.sentStamps(for: postID)
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
