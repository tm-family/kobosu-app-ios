//
//  PostCompleteViewModel.swift
//  Kobosu
//
//  投稿完了の画面の状態。未分類で投稿したときだけ、カテゴリを付けるようやさしく問いかける（Discussion #76 の Q4）。
//  付けられるのはこの画面からだけで、1 回だけ（付けたら問いかけを消す。閉じたあとは付けられない）。
//  付けたカテゴリは前回のカテゴリにもする（本人が選んだカテゴリなので、次の投稿の初期値にする）。
//

import Foundation
import Observation

@Observable
final class PostCompleteViewModel {
    enum AssignState: Equatable {
        case idle
        case assigning
        /// 付けられた。問いかけを消す
        case assigned
        /// 付けられなかった。やさしい文で伝え、もう一度ためせるようにする
        case failed
    }

    /// 投稿した内容。カテゴリを付けたら、付けたカテゴリの投稿に替わる
    private(set) var post: Post
    private(set) var assignState = AssignState.idle

    private let repository: any PostRepository
    private let lastCategories: any LastCategoryStore

    init(post: Post, repository: any PostRepository, lastCategories: any LastCategoryStore) {
        self.post = post
        self.repository = repository
        self.lastCategories = lastCategories
    }

    /// カテゴリを付けるよう問いかけるか。未分類の投稿で、まだ付けていないときだけ
    var asksForCategory: Bool {
        post.category == .uncategorized && assignState != .assigned
    }

    /// 付けている途中か（ボタンを押せなくする）
    var isAssigning: Bool {
        assignState == .assigning
    }

    /// 選べるカテゴリ（未分類は出さない）
    var assignableCategories: [PostCategory] {
        PostCategory.filterable
    }

    /// カテゴリを付ける。付けられたら true（タイムラインを読み直すため）
    func assign(_ category: PostCategory) async -> Bool {
        guard asksForCategory, !isAssigning, category != .uncategorized else {
            return false
        }
        assignState = .assigning
        do {
            post = try await repository.assignCategory(category, toPostID: post.id)
            lastCategories.save(category)
            assignState = .assigned
            return true
        } catch {
            // ルールにはじかれた・期限切れ・通信など、わけを問わず同じ文で伝える
            assignState = .failed
            return false
        }
    }
}
