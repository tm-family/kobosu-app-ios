//
//  TimelineViewModel.swift
//  Kobosu
//
//  タイムラインの読み込みとカテゴリの絞り込み。
//

import Foundation
import Observation

@Observable
final class TimelineViewModel {
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case failed
    }

    /// 絞り込み中のカテゴリ。nil なら「すべて」
    private(set) var selectedCategory: PostCategory?
    private(set) var posts: [Post] = []
    /// 投稿ごとに自分が送ったスタンプ
    private(set) var sentStamps: [Post.ID: Set<EmpathyStamp>] = [:]
    private(set) var state = LoadState.idle

    private let repository: any PostRepository
    /// 最後に始めた読み込み。絞り込みを続けて切り替えたとき、古い読み込みの結果で上書きしないため
    private var latestLoad = 0

    init(repository: any PostRepository) {
        self.repository = repository
    }

    func load() async {
        latestLoad += 1
        let loadID = latestLoad
        let category = selectedCategory
        if posts.isEmpty {
            state = .loading
        }
        do {
            let posts = try await repository.timeline(category: category)
            var sentStamps: [Post.ID: Set<EmpathyStamp>] = [:]
            for post in posts {
                // 読み込みのあいだに消えた投稿があっても、一覧は出す
                sentStamps[post.id] = (try? await repository.sentStamps(for: post.id)) ?? []
            }
            guard loadID == latestLoad else {
                return
            }
            self.posts = posts
            self.sentStamps = sentStamps
            state = .loaded
        } catch {
            guard loadID == latestLoad else {
                return
            }
            state = .failed
        }
    }

    func select(_ category: PostCategory?) async {
        guard category != selectedCategory else {
            return
        }
        selectedCategory = category
        posts = []
        sentStamps = [:]
        await load()
    }

    /// その時刻に表示する投稿。読み込んだ後に期限を過ぎた投稿も外す
    func visiblePosts(at date: Date) -> [Post] {
        posts.filter { !$0.isExpired(at: date) }
    }

    func sentStamps(for post: Post) -> Set<EmpathyStamp> {
        sentStamps[post.id] ?? []
    }
}
