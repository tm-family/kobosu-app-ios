//
//  ComposeViewModelCategoryTests.swift
//  KobosuTests
//
//  投稿画面で先に選んでおくカテゴリ（推定 → 前回 → 未分類）と、本人が選んだカテゴリの扱い
//

import Foundation
@testable import Kobosu
import Testing

struct ComposeViewModelCategoryTests {
    private let now = Date(timeIntervalSince1970: 1_000_000)

    nonisolated private static let noCandidates: @Sendable (String) -> [MaskingCandidate] = { _ in [] }

    private func makeRepository() -> InMemoryPostRepository {
        InMemoryPostRepository(identity: InMemoryAnonymousIDStore(id: "me"), now: { [now] in now })
    }

    /// 推定し直すまでの間は 0 にする（間をおいて推定し直すことは pendingEstimate を待って確かめる）
    private func makeModel(
        repository: any PostRepository,
        drafts: any ComposeDraftStore = InMemoryComposeDraftStore(),
        lastCategories: any LastCategoryStore = InMemoryLastCategoryStore()
    ) -> ComposeViewModel {
        ComposeViewModel(
            repository: repository,
            drafts: drafts,
            lastCategories: lastCategories,
            detect: Self.noCandidates,
            estimateDelay: .zero
        )
    }

    /// 本文から推定したカテゴリが、間をおいて初期値になる
    @Test
    func estimatedCategoryBecomesInitialValue() async {
        let model = makeModel(repository: makeRepository())
        model.body = "帰省のたびに義母に言われる。"
        model.bodyDidChange()
        await model.pendingEstimate?.value
        #expect(model.category == .inLaws)
        #expect(model.categorySource == .estimated)
    }

    /// 推定できなければ前回のカテゴリ、前回も無ければ未分類になる
    @Test
    func fallsBackToPreviousThenUncategorized() async {
        let withPrevious = makeModel(repository: makeRepository(), lastCategories: InMemoryLastCategoryStore(category: .money))
        #expect(withPrevious.category == .money)
        #expect(withPrevious.categorySource == .previous)
        withPrevious.body = "今日はなんだか疲れた。"
        withPrevious.bodyDidChange()
        await withPrevious.pendingEstimate?.value
        #expect(withPrevious.category == .money)
        #expect(withPrevious.categorySource == .previous)

        let withoutPrevious = makeModel(repository: makeRepository())
        withoutPrevious.body = "今日はなんだか疲れた。"
        withoutPrevious.bodyDidChange()
        await withoutPrevious.pendingEstimate?.value
        #expect(withoutPrevious.category == .uncategorized)
        #expect(withoutPrevious.categorySource == .uncategorized)
    }

    /// 本文を消すと、推定したカテゴリから前回のカテゴリ（無ければ未分類）に戻る
    @Test
    func clearingBodyReturnsToPrevious() async {
        let model = makeModel(repository: makeRepository(), lastCategories: InMemoryLastCategoryStore(category: .parenting))
        model.body = "夫に話しかけても返事がない。"
        model.bodyDidChange()
        await model.pendingEstimate?.value
        #expect(model.category == .partner)
        model.body = ""
        model.bodyDidChange()
        await model.pendingEstimate?.value
        #expect(model.category == .parenting)
        #expect(model.categorySource == .previous)
    }

    /// 本人が選んだあとは、本文を変えても推定で上書きしない
    @Test
    func chosenCategoryIsNotOverwrittenByEstimate() async throws {
        let model = makeModel(repository: makeRepository())
        model.choose(.money)
        #expect(model.categorySource == .chosen)
        model.body = "帰省のたびに義母に言われる。"
        model.bodyDidChange()
        await model.pendingEstimate?.value
        #expect(model.category == .money)
        #expect(model.categorySource == .chosen)
        let post = try #require(await model.submit())
        #expect(post.category == .money)
    }

    /// 間をおいた推定の前に投稿しても、今の本文で選び直してから送る
    @Test
    func submitUsesLatestEstimateBeforeDelay() async throws {
        let model = ComposeViewModel(
            repository: makeRepository(),
            drafts: InMemoryComposeDraftStore(),
            lastCategories: InMemoryLastCategoryStore(),
            detect: Self.noCandidates,
            estimateDelay: .seconds(60)
        )
        model.body = "家計がきつくて、貯金ができない。"
        model.bodyDidChange()
        // まだ間をおいている
        #expect(model.category == .uncategorized)
        let post = try #require(await model.submit())
        #expect(post.category == .money)
    }

    /// 推定できず前回のカテゴリも無ければ、未分類で投稿する。未分類は前回のカテゴリとして残さない
    @Test
    func submitsUncategorizedWithoutEstimateOrPrevious() async throws {
        let lastCategories = InMemoryLastCategoryStore()
        let model = makeModel(repository: makeRepository(), lastCategories: lastCategories)
        model.body = "今日はなんだか疲れた。"
        let post = try #require(await model.submit())
        #expect(post.category == .uncategorized)
        #expect(lastCategories.load() == nil)
        #expect(model.category == .uncategorized)
    }

    /// 投稿できたら、そのカテゴリを前回のカテゴリとして保存する
    @Test
    func submitSavesLastCategory() async throws {
        let lastCategories = InMemoryLastCategoryStore(category: .money)
        let model = makeModel(repository: makeRepository(), lastCategories: lastCategories)
        model.body = "寝かしつけに 2 時間かかった。"
        _ = try #require(await model.submit())
        #expect(lastCategories.load() == .parenting)
    }

    /// 下書きには本人が選んだカテゴリだけを残す。推定・前回のカテゴリは、開き直したときに本文から選び直す
    @Test
    func draftKeepsOnlyChosenCategory() async {
        let drafts = InMemoryComposeDraftStore()
        let model = makeModel(repository: makeRepository(), drafts: drafts, lastCategories: InMemoryLastCategoryStore(category: .money))
        model.body = "帰省のたびに義母に言われる。"
        model.bodyDidChange()
        await model.pendingEstimate?.value
        #expect(drafts.load() == ComposeDraft(body: "帰省のたびに義母に言われる。", category: nil))

        // 開き直すと、本文から推定し直す
        let reopened = makeModel(repository: makeRepository(), drafts: drafts, lastCategories: InMemoryLastCategoryStore(category: .money))
        #expect(reopened.category == .inLaws)
        #expect(reopened.categorySource == .estimated)

        reopened.choose(.partner)
        reopened.saveDraft()
        #expect(drafts.load() == ComposeDraft(body: "帰省のたびに義母に言われる。", category: .partner))
        let chosenAgain = makeModel(repository: makeRepository(), drafts: drafts)
        #expect(chosenAgain.category == .partner)
        #expect(chosenAgain.categorySource == .chosen)
    }

    /// 前の形の下書き（カテゴリを選ばないと投稿できなかったころのもの）のカテゴリは、本人が選んだものとして読む
    @Test
    func legacyDraftCategoryIsChosen() throws {
        let suiteName = "ComposeViewModelTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(Data(#"{"body":"義母に言われた","category":"money"}"#.utf8), forKey: UserDefaultsComposeDraftStore.key)

        let model = makeModel(repository: makeRepository(), drafts: UserDefaultsComposeDraftStore(defaults: defaults))
        #expect(model.category == .money)
        #expect(model.categorySource == .chosen)
    }

    /// 推定は端末の中だけで行い、Repository には投稿のときの本文しか渡さない
    @Test
    func estimateDoesNotTouchRepository() async throws {
        let repository = makeRepository()
        let model = makeModel(repository: repository)
        model.body = "帰省のたびに義母に言われる。"
        model.bodyDidChange()
        await model.pendingEstimate?.value
        #expect(try await repository.timeline(category: nil).isEmpty)
        #expect(try await repository.myPosts().isEmpty)
    }

    /// 「変更」から未分類を選ぶこともでき、本人が選んだものとして下書きに残り、未分類で投稿する
    @Test
    func canChooseUncategorized() async throws {
        let drafts = InMemoryComposeDraftStore()
        let model = makeModel(repository: makeRepository(), drafts: drafts, lastCategories: InMemoryLastCategoryStore(category: .money))
        model.body = "帰省のたびに義母に言われる。"
        model.choose(.uncategorized)
        model.bodyDidChange()
        await model.pendingEstimate?.value
        #expect(model.category == .uncategorized)
        #expect(model.categorySource == .chosen)
        #expect(drafts.load() == ComposeDraft(body: "帰省のたびに義母に言われる。", category: .uncategorized))
        let post = try #require(await model.submit())
        #expect(post.category == .uncategorized)
    }

    /// 今と同じカテゴリを選んでも、本人が選んだものとして下書きに残す（開き直しても推定で上書きしない）
    @Test
    func choosingSameCategoryIsSavedAsChosen() async {
        let drafts = InMemoryComposeDraftStore()
        let model = makeModel(repository: makeRepository(), drafts: drafts)
        model.body = "帰省のたびに義母に言われる。"
        model.bodyDidChange()
        await model.pendingEstimate?.value
        #expect(model.category == .inLaws)
        #expect(drafts.load()?.category == nil)

        model.choose(.inLaws)
        #expect(drafts.load() == ComposeDraft(body: "帰省のたびに義母に言われる。", category: .inLaws))
        let reopened = makeModel(repository: makeRepository(), drafts: drafts)
        #expect(reopened.categorySource == .chosen)
    }

    /// 開いた直後の未分類のまま「未分類」を選んでも、本人が選んだものとして下書きに残す
    @Test
    func choosingUncategorizedWithoutChangeIsSaved() {
        let drafts = InMemoryComposeDraftStore()
        let model = makeModel(repository: makeRepository(), drafts: drafts)
        model.body = "今日はなんだか疲れた。"
        model.choose(.uncategorized)
        #expect(drafts.load() == ComposeDraft(body: "今日はなんだか疲れた。", category: .uncategorized))
    }

    /// 伏せ字の確認を通るときも、推定したカテゴリで送る
    @Test
    func reviewSubmitsEstimatedCategory() async throws {
        let findsTanaka: @Sendable (String) -> [MaskingCandidate] = { text in
            text.range(of: "田中").map { [MaskingCandidate(kind: .personName, range: $0, text: "田中")] } ?? []
        }
        let model = ComposeViewModel(
            repository: makeRepository(),
            drafts: InMemoryComposeDraftStore(),
            lastCategories: InMemoryLastCategoryStore(),
            detect: findsTanaka,
            estimateDelay: .zero
        )
        model.body = "義母の田中さんに、また言われた。"
        #expect(await model.submit() == nil)
        #expect(model.review != nil)
        let post = try #require(await model.submitReview())
        #expect(post.category == .inLaws)
        #expect(post.body == "義母の〇〇さんに、また言われた。")
    }
}
