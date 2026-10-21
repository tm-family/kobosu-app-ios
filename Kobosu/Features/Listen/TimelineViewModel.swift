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
    /// 自分の投稿の ID。自分の投稿には共感を送れない
    private(set) var myPostIDs: Set<Post.ID> = []
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
            let myPostIDs = Set(try await repository.myPosts().map(\.id))
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
            self.myPostIDs = myPostIDs
            state = .loaded
        } catch is CancellationError {
            // 画面を離れて取り消されたときは、読み込み中の表示だけ元に戻す
            if loadID == latestLoad, state == .loading {
                state = .idle
            }
        } catch {
            guard loadID == latestLoad else {
                return
            }
            // 表示中の一覧があるときは残す（引っぱって更新に失敗しても、読んでいた投稿を消さない）
            state = posts.isEmpty ? .failed : .loaded
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

    func isMine(_ post: Post) -> Bool {
        myPostIDs.contains(post.id)
    }

    /// 共感スタンプを送り、送った人数をすぐ一覧に反映する。送れなかったら throw する
    func send(_ stamp: EmpathyStamp, to post: Post) async throws {
        guard !sentStamps(for: post).contains(stamp) else {
            return
        }
        try await repository.sendStamp(stamp, to: post.id)
        sentStamps[post.id, default: []].insert(stamp)
        if let index = posts.firstIndex(where: { $0.id == post.id }) {
            posts[index].stampCounts[stamp, default: 0] += 1
        }
    }

    /// 一覧の中の最新の投稿（シートで人数を出すため）
    func post(id: Post.ID) -> Post? {
        posts.first { $0.id == id }
    }
}
