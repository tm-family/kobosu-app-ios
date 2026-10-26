//
//  PostRepository.swift
//  Kobosu
//
//  投稿と共感スタンプの取得・送信。画面はこのプロトコルだけに依存し、
//  テスト・Preview・撮影モードではインメモリ実装、本番では Firebase の実装を渡す。
//

import Foundation

protocol PostRepository: AnyObject {
    /// タイムライン。新しい順に並べ、期限切れ・通報が一定数に達した投稿・「この投稿を表示しない」にした投稿は含めない。
    /// category が nil ならすべてのカテゴリ
    func timeline(category: PostCategory?) async throws -> [Post]

    /// 投稿する。本文は前後の空白を除いて 1 文字以上、Post.maxBodyLength 文字以内
    func submit(body: String, category: PostCategory) async throws -> Post

    /// 自分の投稿（ノートの「共有した」）。新しい順に並べ、期限切れは含めない
    func myPosts() async throws -> [Post]

    /// 自分の投稿をすぐ消す。共感・通報も一緒に消す
    func delete(postID: Post.ID) async throws

    /// 未分類の自分の投稿にカテゴリを付ける（投稿完了画面から 1 回だけ）。カテゴリを付けた投稿を返す。
    /// 付けられるのは期限内・今が未分類のときだけで、付けるカテゴリは未分類以外。未分類には戻せない
    func assignCategory(_ category: PostCategory, toPostID postID: Post.ID) async throws -> Post

    /// 共感スタンプを送る。同じ投稿に同じスタンプは 1 人 1 回まで（2 回目は何もしない）。自分の投稿には送れない
    func sendStamp(_ stamp: EmpathyStamp, to postID: Post.ID) async throws

    /// その投稿に自分が送ったスタンプ
    func sentStamps(for postID: Post.ID) async throws -> Set<EmpathyStamp>

    /// 期限内の自分の投稿の ID。タイムラインで自分の投稿を見分けるのに使う（投稿の本文までは読まない）
    func myPostIDs() async throws -> Set<Post.ID>

    /// 投稿ごとに自分が送ったスタンプ。送っていない投稿はキーを持たない（タイムラインでまとめて読む）
    func sentStamps(for postIDs: [Post.ID]) async throws -> [Post.ID: Set<EmpathyStamp>]

    /// 「すべてのデータを削除」のサーバー側。自分の投稿と、自分が送った共感・通報をすべて消す。
    /// 匿名 ID はこの後に破棄するので、ここでは破棄しない（先に ID を消すと、自分の投稿を消せなくなる）
    func deleteAllMyData() async throws
}

extension PostRepository {
    func myPostIDs() async throws -> Set<Post.ID> {
        Set(try await myPosts().map(\.id))
    }

    /// 1 件ずつ読む。読むあいだに消えた投稿は外す
    func sentStamps(for postIDs: [Post.ID]) async throws -> [Post.ID: Set<EmpathyStamp>] {
        var result: [Post.ID: Set<EmpathyStamp>] = [:]
        for postID in postIDs {
            if let stamps = try? await sentStamps(for: postID), !stamps.isEmpty {
                result[postID] = stamps
            }
        }
        return result
    }

    /// 自分の投稿を 1 件ずつ消す（共感・通報は投稿と一緒に消える）。自分が送った共感・通報も消せる実装は上書きする
    func deleteAllMyData() async throws {
        for post in try await myPosts() {
            do {
                try await delete(postID: post.id)
            } catch PostRepositoryError.postNotFound {
                // 消しているあいだに期限が過ぎた投稿は、もう無いので飛ばす
                continue
            }
        }
    }
}

protocol ReportRepository: AnyObject {
    /// 通報する。同じ投稿への通報は 1 人 1 回まで（2 回目は何もしない）。通報は匿名で、投稿者には伝わらない。自分の投稿は通報できない
    func report(postID: Post.ID, reason: ReportReason) async throws

    /// 「この投稿を表示しない」。この端末のタイムラインにだけ効く
    func hide(postID: Post.ID) async throws
}

enum PostRepositoryError: Error, Equatable {
    /// 本文が空（空白だけ）
    case emptyBody
    /// 本文が Post.maxBodyLength 文字を超えている
    case bodyTooLong
    /// 投稿が無い（消えた・期限切れ）
    case postNotFound
    /// 自分の投稿ではないので消せない
    case notOwner
    /// 自分の投稿には共感を送れない・通報できない
    case ownPost
    /// もうカテゴリが付いている（カテゴリを付けられるのは未分類の投稿に 1 回だけ）
    case alreadyCategorized
    /// 付けようとしたカテゴリが未分類（未分類には戻せない）
    case invalidCategory
}

extension Post {
    /// 投稿する本文。前後の空白を除き、空や Post.maxBodyLength 文字を超えるものは投げる
    static func validatedBody(_ body: String) throws -> String {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw PostRepositoryError.emptyBody
        }
        guard trimmed.count <= maxBodyLength else {
            throw PostRepositoryError.bodyTooLong
        }
        return trimmed
    }

    /// 未分類の投稿に category を付けた投稿。今が未分類でない・category が未分類なら投げる
    nonisolated func assigningCategory(_ category: PostCategory) throws -> Post {
        guard category != .uncategorized else {
            throw PostRepositoryError.invalidCategory
        }
        guard self.category == .uncategorized else {
            throw PostRepositoryError.alreadyCategorized
        }
        return Post(id: id, body: body, category: category, createdAt: createdAt, expireAt: expireAt, stampCounts: stampCounts)
    }
}

/// 通報による自動の非表示
enum ReportPolicy {
    /// この人数から通報されたら、タイムラインに出さない（運営の確認に回す）
    static let autoHideThreshold = 3
}
