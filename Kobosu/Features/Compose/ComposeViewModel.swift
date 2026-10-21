//
//  ComposeViewModel.swift
//  Kobosu
//
//  投稿画面の入力と送信。書いている途中の本文とカテゴリは、変わるたびに下書きとして端末に保存する。
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

    var body: String
    /// 選んだカテゴリ。最初は何も選んでいない
    var category: PostCategory?
    private(set) var state = SubmitState.editing
    /// 伏せ字の確認。候補が見つかったときだけ出す。nil にすると書き直しに戻る
    var review: MaskingReview?

    private let repository: any PostRepository
    private let drafts: any ComposeDraftStore
    /// 伏せ字の候補を探す。テストでは差し替える
    private let detect: @Sendable (String) -> [MaskingCandidate]

    init(
        repository: any PostRepository,
        drafts: any ComposeDraftStore,
        detect: @escaping @Sendable (String) -> [MaskingCandidate] = { MaskingDetector.candidates(in: $0) }
    ) {
        self.repository = repository
        self.drafts = drafts
        self.detect = detect
        let draft = drafts.load()
        body = draft?.body ?? ""
        category = draft?.category
    }

    /// 投稿する本文の文字数（前後の空白・改行は数えない）
    var bodyLength: Int {
        trimmedBody.count
    }

    /// 本文が上限の文字数を超えている
    var isOverLimit: Bool {
        bodyLength > Post.maxBodyLength
    }

    /// 投稿できるか。本文が 1 文字以上・上限以内で、カテゴリを選んでいて、候補を探している途中・送信中でない
    var canSubmit: Bool {
        bodyLength > 0 && !isOverLimit && category != nil && !isBusy
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
        return !review.isOverLimit && category != nil && !isBusy
    }

    /// 書いている途中の本文とカテゴリを下書きとして保存する
    func saveDraft() {
        drafts.save(ComposeDraft(body: body, category: category))
        if state == .failed {
            state = .editing
        }
    }

    /// 投稿する。先に伏せ字の候補を探し、見つかったら review を出して nil を返す（投稿は submitReview() で行う）。
    /// 候補が無ければそのまま投稿し、投稿できたら下書きを消して投稿を返す。できなかったら下書きを残して nil を返す
    func submit() async -> Post? {
        guard canSubmit, let category else {
            return nil
        }
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
        guard canSubmitReview, let review, let category else {
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
            body = ""
            self.category = nil
            review = nil
            state = .editing
            return post
        } catch {
            state = .failed
            return nil
        }
    }

    private var trimmedBody: String {
        body.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
