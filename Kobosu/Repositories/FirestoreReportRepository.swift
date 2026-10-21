//
//  FirestoreReportRepository.swift
//  Kobosu
//
//  ReportRepository の Firestore の実装。GoogleService-Info.plist があって Firebase を設定したときだけ使う。
//  通報の文書の形は ReportDocument に書いた。「この投稿を表示しない」は端末の中（HiddenPostStore）にだけ保存する。
//

import FirebaseFirestore
import Foundation

final class FirestoreReportRepository: ReportRepository {
    private let identity: AnonymousIDStore
    private let auth: FirebaseAnonymousAuth
    private let hiddenPosts: HiddenPostStore
    private let now: () -> Date

    init(
        identity: AnonymousIDStore,
        auth: FirebaseAnonymousAuth,
        hiddenPosts: HiddenPostStore,
        now: @escaping () -> Date = { Date() }
    ) {
        self.identity = identity
        self.auth = auth
        self.hiddenPosts = hiddenPosts
        self.now = now
    }

    func report(postID: Post.ID, reason: ReportReason) async throws {
        let uid = try await auth.userID()
        try identity.replaceID(with: uid)
        let outcome = try await FirestoreReportAPI.report(
            postID: postID,
            reason: reason,
            uid: uid,
            now: now(),
            threshold: ReportPolicy.autoHideThreshold
        )
        switch outcome {
        case .reported, .alreadyReported:
            return
        case .postNotFound:
            throw PostRepositoryError.postNotFound
        case .ownPost:
            throw PostRepositoryError.ownPost
        }
    }

    func hide(postID: Post.ID) async throws {
        hiddenPosts.hide(postID)
    }
}

/// 通報の結果。Firestore を読み書きする部分から、Repository のエラーに直す前の形で返す
nonisolated enum ReportOutcome: Equatable, Sendable {
    case reported
    /// もう通報していた（2 回目は何もしない）
    case alreadyReported
    /// 無い・期限切れ・通報が一定数に達して出さなくなった
    case postNotFound
    /// 自分の投稿
    case ownPost
}

/// Firestore を読み書きする部分
nonisolated private enum FirestoreReportAPI {
    private static var database: Firestore {
        Firestore.firestore()
    }

    static func report(
        postID: Post.ID,
        reason: ReportReason,
        uid: String,
        now: Date,
        threshold: Int
    ) async throws -> ReportOutcome {
        let postRef = database.collection(PostDocument.postsCollection).document(postID)
        let snapshot = try await postRef.getDocument(source: .server)
        guard
            let data = snapshot.data(),
            let expireAt = data[PostDocument.Field.expireAt] as? Timestamp,
            let post = PostDocument.post(
                id: postID,
                data: data,
                createdAt: (data[PostDocument.Field.createdAt] as? Timestamp)?.dateValue(),
                expireAt: expireAt.dateValue()
            ),
            !post.isExpired(at: now),
            !ReportDocument.isAutoHidden(post: data, threshold: threshold)
        else {
            return .postNotFound
        }

        let ownRef = database
            .collection(PostDocument.usersCollection)
            .document(uid)
            .collection(PostDocument.ownPostsCollection)
            .document(postID)
        if try await ownRef.getDocument(source: .server).exists {
            return .ownPost
        }

        let reportRef = postRef.collection(ReportDocument.reportsCollection).document(uid)
        if try await reportRef.getDocument(source: .server).exists {
            return .alreadyReported
        }

        // 通報の記録と人数は同じバッチで書く（ルールで「通報を新しく作るときだけ 1 増やせる」と確かめるため）。
        // 自分の目印も同じバッチで書き、「すべてのデータを削除」で探せるようにする
        var fields = ReportDocument.reportFields(reason: reason)
        fields[ReportDocument.Field.createdAt] = FieldValue.serverTimestamp()
        fields[ReportDocument.Field.expireAt] = expireAt
        let sentRef = database
            .collection(PostDocument.usersCollection)
            .document(uid)
            .collection(ReportDocument.sentReportsCollection)
            .document(postID)
        let batch = database.batch()
        batch.setData(fields, forDocument: reportRef)
        batch.setData([ReportDocument.Field.expireAt: expireAt], forDocument: sentRef)
        batch.updateData([ReportDocument.Field.reportCount: FieldValue.increment(Int64(1))], forDocument: postRef)
        try await batch.commit()
        return .reported
    }
}
