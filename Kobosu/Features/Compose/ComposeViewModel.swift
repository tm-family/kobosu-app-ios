//
//  ComposeViewModel.swift
//  Kobosu
//
//  投稿画面の入力と送信。書いている途中の本文とカテゴリは、変わるたびに下書きとして端末に保存する。
//  投稿に要るのは本文だけ。カテゴリは本文から推定 → 前回のカテゴリ → 未分類の順に先に選んでおき（CategorySuggestion）、
//  本文が変わったら少し間をおいて選び直す。本人が選んだあとは推定で上書きしない。推定は端末の中だけで行う。
//  投稿の前に伏せ字の候補を探し、見つかったら review を出して、伏せるかどうかを本人に選んでもらう。
//

import Foundation
import Observation

@Observable
final class ComposeViewModel {
    enum SubmitState: Equatable {
        case editing
        /// 伏せ字の候補を探している
        case checking
        case submitting
        case failed
    }

    /// 本文が変わってから、カテゴリを推定し直すまでの間
    static let estimateDelay = Duration.milliseconds(500)

    var body: String
    /// 投稿するカテゴリ。本人が選ぶまでは、推定・前回・未分類の順に選んでおく
    private(set) var category: PostCategory
    /// category がどうやって選ばれたか（画面の文言を変えるため）
    private(set) var categorySource: CategorySource
    private(set) var state = SubmitState.editing
    /// 伏せ字の確認。候補が見つかったときだけ出す。nil にすると書き直しに戻る
    var review: MaskingReview?

    private let repository: any PostRepository
    private let drafts: any ComposeDraftStore
    private let lastCategories: any LastCategoryStore
    /// 伏せ字の候補を探す。テストでは差し替える
    private let detect: @Sendable (String) -> [MaskingCandidate]
    private let estimateDelay: Duration
    /// 間をおいて推定し直す処理。本文が変わるたびに前のものを取り消す（テストでは終わるのを待つ）。画面からは読まない
    @ObservationIgnored private(set) var pendingEstimate: Task<Void, Never>?

    init(
        repository: any PostRepository,
        drafts: any ComposeDraftStore,
        lastCategories: any LastCategoryStore,
        detect: @escaping @Sendable (String) -> [MaskingCandidate] = { MaskingDetector.candidates(in: $0) },
        estimateDelay: Duration = ComposeViewModel.estimateDelay
    ) {
        self.repository = repository
        self.drafts = drafts
        self.lastCategories = lastCategories
        self.detect = detect
        self.estimateDelay = estimateDelay
        let draft = drafts.load()
        let body = draft?.body ?? ""
        self.body = body
        // 下書きのカテゴリは本人が選んだもの。無ければ本文から選び直す
        if let chosen = draft?.category {
            category = chosen
            categorySource = .chosen
        } else {
            let suggestion = CategorySuggestion.suggest(for: body, lastCategory: lastCategories.load())
            category = suggestion.category
            categorySource = suggestion.source
        }
    }

    /// 投稿する本文の文字数（前後の空白・改行は数えない）
    var bodyLength: Int {
        trimmedBody.count
    }

    /// 本文が上限の文字数を超えている
    var isOverLimit: Bool {
        bodyLength > Post.maxBodyLength
    }

    /// 投稿できるか。本文が 1 文字以上・上限以内で、候補を探している途中・送信中でない（カテゴリは求めない）
    var canSubmit: Bool {
        bodyLength > 0 && !isOverLimit && !isBusy
    }

    /// 候補を探している途中か、送信中。このあいだは入力も閉じることもできない
    var isBusy: Bool {
        state == .checking || state == .submitting
    }

    /// 伏せ字の確認から投稿できるか
    var canSubmitReview: Bool {
        guard let review else {
            return false
        }
        return !review.isOverLimit && !isBusy
    }

    /// 本人がカテゴリを選ぶ（未分類も選べる）。以後は本文を変えても推定で上書きしない
    func choose(_ category: PostCategory) {
        pendingEstimate?.cancel()
        pendingEstimate = nil
        self.category = category
        categorySource = .chosen
    }

    /// 本文が変わったとき。下書きを保存し、本人が選んでいなければ、少し間をおいてカテゴリを選び直す
    func bodyDidChange() {
        saveDraft()
        guard categorySource != .chosen else {
            return
        }
        pendingEstimate?.cancel()
        let delay = estimateDelay
        pendingEstimate = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else {
                return
            }
            self?.refreshSuggestion()
        }
    }

    /// 書いている途中の本文とカテゴリを下書きとして保存する。カテゴリは本人が選んだときだけ残す
    /// （推定・前回のカテゴリは、開き直したときに本文から選び直す）
    func saveDraft() {
        drafts.save(ComposeDraft(body: body, category: categorySource == .chosen ? category : nil))
        if state == .failed {
            state = .editing
        }
    }

    /// 投稿する。先に伏せ字の候補を探し、見つかったら review を出して nil を返す（投稿は submitReview() で行う）。
    /// 候補が無ければそのまま投稿し、投稿できたら下書きを消して投稿を返す。できなかったら下書きを残して nil を返す
    func submit() async -> Post? {
        guard canSubmit else {
            return nil
        }
        // 間をおいた推定がまだなら、今の本文で選び直してから送る
        refreshSuggestion()
        let category = category
        let text = trimmedBody
        state = .checking
        let detect = detect
        let candidates = await Task.detached { detect(text) }.value
        guard text == trimmedBody, category == self.category else {
            // 探しているあいだに書き直された。もう一度押してもらう
            state = .editing
            return nil
        }
        guard candidates.isEmpty else {
            review = MaskingReview(text: text, candidates: candidates)
            state = .editing
            return nil
        }
        return await send(text, category: category)
    }

    /// 伏せ字の確認で選んだとおりに伏せて投稿する
    func submitReview() async -> Post? {
        guard canSubmitReview, let review else {
            return nil
        }
        return await send(review.result, category: category)
    }

    /// 伏せ字の確認で、候補を伏せるかどうかを切り替える
    func setMasked(_ masked: Bool, at index: Int) {
        review?.setMasked(masked, at: index)
    }

    private func send(_ text: String, category: PostCategory) async -> Post? {
        state = .submitting
        do {
            let post = try await repository.submit(body: text, category: category)
            drafts.clear()
            // 次の投稿の初期値にする（未分類は残さない。LastCategoryStore）
            lastCategories.save(category)
            body = ""
            categorySource = .uncategorized
            refreshSuggestion()
            review = nil
            state = .editing
            return post
        } catch {
            state = .failed
            return nil
        }
    }

    /// 本人が選んでいなければ、今の本文と前回のカテゴリからカテゴリを選び直す
    private func refreshSuggestion() {
        pendingEstimate?.cancel()
        pendingEstimate = nil
        guard categorySource != .chosen else {
            return
        }
        let suggestion = CategorySuggestion.suggest(for: body, lastCategory: lastCategories.load())
        category = suggestion.category
        categorySource = suggestion.source
    }

    private var trimmedBody: String {
        body.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
