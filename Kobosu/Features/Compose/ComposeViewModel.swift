//
//  ComposeViewModel.swift
//  Kobosu
//
//  投稿画面の入力と送信。書いている途中の本文とカテゴリは、変わるたびに下書きとして端末に保存する。
//

import Foundation
import Observation

@Observable
final class ComposeViewModel {
    enum SubmitState: Equatable {
        case editing
        case submitting
        case failed
    }

    var body: String
    /// 選んだカテゴリ。最初は何も選んでいない
    var category: PostCategory?
    private(set) var state = SubmitState.editing

    private let repository: any PostRepository
    private let drafts: any ComposeDraftStore

    init(repository: any PostRepository, drafts: any ComposeDraftStore) {
        self.repository = repository
        self.drafts = drafts
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

    /// 投稿できるか。本文が 1 文字以上・上限以内で、カテゴリを選んでいて、送信中でない
    var canSubmit: Bool {
        bodyLength > 0 && !isOverLimit && category != nil && state != .submitting
    }

    var isSubmitting: Bool {
        state == .submitting
    }

    /// 書いている途中の本文とカテゴリを下書きとして保存する
    func saveDraft() {
        drafts.save(ComposeDraft(body: body, category: category))
        if state == .failed {
            state = .editing
        }
    }

    /// 投稿する。投稿できたら下書きを消して投稿を返す。できなかったら下書きを残して nil を返す
    func submit() async -> Post? {
        guard canSubmit, let category else {
            return nil
        }
        state = .submitting
        do {
            let post = try await repository.submit(body: trimmedBody, category: category)
            drafts.clear()
            body = ""
            self.category = nil
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
