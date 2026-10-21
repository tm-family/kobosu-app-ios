//
//  NoteViewModel.swift
//  Kobosu
//
//  ノート（共有した）の読み込みと、自分の投稿をすぐ消す処理。
//

import Foundation
import Observation

@Observable
final class NoteViewModel {
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case failed
    }

    /// 自分の投稿。新しい順
    private(set) var posts: [Post] = []
    private(set) var state = LoadState.idle
    /// 消せなかった投稿。消せなかったことをその投稿のカードで伝える
    private(set) var failedDeletion: Post.ID?
    /// 消している途中の投稿。消している間は、ほかの投稿も消せない
    private(set) var deleting: Post.ID?

    private let repository: any PostRepository
    /// 最後に始めた読み込み。続けて読み込んだとき、古い読み込みの結果で上書きしないため
    private var latestLoad = 0
    /// この画面で消した投稿。消す前に始めた読み込みの結果に入っていても出さない
    private var deletedIDs: Set<Post.ID> = []

    init(repository: any PostRepository) {
        self.repository = repository
    }

    func load() async {
        latestLoad += 1
        let loadID = latestLoad
        if posts.isEmpty {
            state = .loading
        }
        do {
            let posts = try await repository.myPosts()
            guard loadID == latestLoad else {
                return
            }
            self.posts = posts.filter { !deletedIDs.contains($0.id) }
            // 読み直したら、前に消せなかったことの表示は消す
            failedDeletion = nil
            state = .loaded
        } catch is CancellationError {
            // タブを離れて取り消されたときは、一覧を変えない（読み込み中の表示だけ戻す）
            if loadID == latestLoad, state == .loading {
                state = .idle
            }
        } catch {
            guard loadID == latestLoad else {
                return
            }
            // 表示中の一覧があるときは残す
            state = posts.isEmpty ? .failed : .loaded
        }
    }

    /// 自分の投稿をすぐ消す。共感も一緒に消える。すでに消えていた（期限切れなど）ときも一覧から外す
    func delete(_ post: Post) async {
        guard deleting == nil else {
            return
        }
        deleting = post.id
        failedDeletion = nil
        defer { deleting = nil }
        do {
            try await repository.delete(postID: post.id)
            remove(post)
        } catch PostRepositoryError.postNotFound {
            remove(post)
        } catch {
            failedDeletion = post.id
        }
    }

    private func remove(_ post: Post) {
        deletedIDs.insert(post.id)
        posts.removeAll { $0.id == post.id }
    }

    /// その時刻に表示する投稿。読み込んだ後に期限を過ぎた投稿も外す
    func visiblePosts(at date: Date) -> [Post] {
        posts.filter { !$0.isExpired(at: date) }
    }
}
