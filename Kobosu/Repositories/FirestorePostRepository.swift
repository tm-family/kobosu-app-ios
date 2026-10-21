//
//  FirestorePostRepository.swift
//  Kobosu
//
//  PostRepository の Firestore の実装。GoogleService-Info.plist があって Firebase を設定したときだけ使う。
//  文書の形と、期限をサーバーの時刻から決める手順は PostDocument に書いた。
//

import FirebaseFirestore
import Foundation

nonisolated enum FirestoreRepositoryError: Error, Equatable {
    /// 作った投稿にサーバーの時刻が入っていない
    case missingServerTimestamp
}

final class FirestorePostRepository: PostRepository {
    private let identity: AnonymousIDStore
    private let auth: FirebaseAnonymousAuth
    /// 「この投稿を表示しない」にした投稿（FirestoreReportRepository と同じものを渡す）
    private let hiddenPosts: HiddenPostStore
    private let now: () -> Date

    init(
        identity: AnonymousIDStore,
        auth: FirebaseAnonymousAuth = FirebaseAnonymousAuth(),
        hiddenPosts: HiddenPostStore,
        now: @escaping () -> Date = { Date() }
    ) {
        self.identity = identity
        self.auth = auth
        self.hiddenPosts = hiddenPosts
        self.now = now
    }

    func timeline(category: PostCategory?) async throws -> [Post] {
        // 読み出しもサインインした人だけにする（ルールはタスク 23）
        _ = try await userID()
        let posts = try await FirestorePostAPI.timeline(
            category: category,
            now: now(),
            autoHideThreshold: ReportPolicy.autoHideThreshold
        )
        let hidden = hiddenPosts.hiddenPostIDs()
        return posts.filter { !hidden.contains($0.id) }
    }

    func submit(body: String, category: PostCategory) async throws -> Post {
        let body = try Post.validatedBody(body)
        let uid = try await userID()
        return try await FirestorePostAPI.submit(body: body, category: category, uid: uid)
    }

    func myPosts() async throws -> [Post] {
        let uid = try await userID()
        return try await FirestorePostAPI.myPosts(uid: uid, now: now())
    }

    func delete(postID: Post.ID) async throws {
        let uid = try await userID()
        try await FirestorePostAPI.delete(postID: postID, uid: uid)
    }

    func sendStamp(_ stamp: EmpathyStamp, to postID: Post.ID) async throws {
        let uid = try await userID()
        let check = try await FirestorePostAPI.sendStamp(
            stamp,
            to: postID,
            uid: uid,
            now: now(),
            autoHideThreshold: ReportPolicy.autoHideThreshold
        )
        switch check {
        case .send, .alreadySent:
            return
        case .ownPost:
            throw PostRepositoryError.ownPost
        case .postNotFound:
            throw PostRepositoryError.postNotFound
        }
    }

    func sentStamps(for postID: Post.ID) async throws -> Set<EmpathyStamp> {
        let uid = try await userID()
        return try await FirestorePostAPI.sentStamps(for: postID, uid: uid)
    }

    func myPostIDs() async throws -> Set<Post.ID> {
        let uid = try await userID()
        return try await FirestorePostAPI.myPostIDs(uid: uid, now: now())
    }

    func sentStamps(for postIDs: [Post.ID]) async throws -> [Post.ID: Set<EmpathyStamp>] {
        let uid = try await userID()
        return try await FirestorePostAPI.sentStamps(for: postIDs, uid: uid, now: now())
    }

    /// 自分の投稿・送った共感・通報を消してから、匿名ユーザーを消す。
    /// 途中で失敗しても、消し終わったものはもう無いので、もう一度呼べば残りから消し直せる
    func deleteAllMyData() async throws {
        let uid = try await userID()
        try await FirestorePostAPI.deleteAllMyData(uid: uid, now: now())
        try await auth.deleteUser()
    }

    /// 匿名認証の uid。Keychain の匿名 ID としても控える
    private func userID() async throws -> String {
        let uid = try await auth.userID()
        try identity.replaceID(with: uid)
        return uid
    }
}

/// Firestore を読み書きする部分。Firestore の型は外に出さず、Post にして返す
nonisolated private enum FirestorePostAPI {
    private typealias Field = PostDocument.Field

    private static var database: Firestore {
        Firestore.firestore()
    }

    private static func ownPosts(uid: String) -> CollectionReference {
        database
            .collection(PostDocument.usersCollection)
            .document(uid)
            .collection(PostDocument.ownPostsCollection)
    }

    private static func sentStamps(uid: String) -> CollectionReference {
        database
            .collection(PostDocument.usersCollection)
            .document(uid)
            .collection(PostDocument.sentStampsCollection)
    }

    private static func sentReports(uid: String) -> CollectionReference {
        database
            .collection(PostDocument.usersCollection)
            .document(uid)
            .collection(ReportDocument.sentReportsCollection)
    }

    /// 期限内の投稿を新しい順に。expireAt は createdAt の 24 時間後なので、expireAt の順は作った順と同じ。
    /// 通報が一定数に達した投稿は外す（reportCount が無い文書は Firestore の条件では選べないので、端末で外す）
    static func timeline(category: PostCategory?, now: Date, autoHideThreshold: Int) async throws -> [Post] {
        var query = database
            .collection(PostDocument.postsCollection)
            .whereField(Field.expireAt, isGreaterThan: Timestamp(date: now))
        if let category {
            query = query.whereField(Field.category, isEqualTo: category.rawValue)
        }
        let snapshot = try await query
            .order(by: Field.expireAt, descending: true)
            .limit(to: PostDocument.timelineLimit)
            .getDocuments()
        let posts = snapshot.documents
            .filter { !ReportDocument.isAutoHidden(post: $0.data(), threshold: autoHideThreshold) }
            .compactMap(post(from:))
        return PostDocument.activePosts(posts, at: now)
    }

    /// 2 段で書く（PostDocument のコメント）。投稿と自分の投稿の目印は、どちらも同じバッチで書く
    static func submit(body: String, category: PostCategory, uid: String) async throws -> Post {
        let postRef = database.collection(PostDocument.postsCollection).document()
        let ownRef = ownPosts(uid: uid).document(postRef.documentID)
        let serverTimes: [String: Any] = [
            Field.createdAt: FieldValue.serverTimestamp(),
            Field.expireAt: FieldValue.serverTimestamp()
        ]
        let create = database.batch()
        create.setData(
            PostDocument.newPostFields(body: body, category: category).merging(serverTimes) { $1 },
            forDocument: postRef
        )
        create.setData(serverTimes, forDocument: ownRef)
        try await create.commit()

        let created = try await postRef.getDocument(source: .server)
        guard let createdAt = created.get(Field.createdAt) as? Timestamp else {
            throw FirestoreRepositoryError.missingServerTimestamp
        }
        // Date に直すと端数が丸まるので、Timestamp のまま 24 時間足す（ルールで createdAt + 24 時間と比べるため）
        let expireAt = Timestamp(seconds: createdAt.seconds + Int64(Post.lifetime), nanoseconds: createdAt.nanoseconds)
        let update = database.batch()
        update.updateData([Field.expireAt: expireAt], forDocument: postRef)
        update.updateData([Field.expireAt: expireAt], forDocument: ownRef)
        try await update.commit()

        return Post(
            id: postRef.documentID,
            body: body,
            category: category,
            createdAt: createdAt.dateValue(),
            expireAt: expireAt.dateValue()
        )
    }

    /// 自分の投稿の目印のうち、期限内のものの ID
    static func myPostIDs(uid: String, now: Date) async throws -> Set<String> {
        let marks = try await ownPosts(uid: uid)
            .whereField(Field.expireAt, isGreaterThan: Timestamp(date: now))
            .getDocuments()
        return Set(marks.documents.map(\.documentID))
    }

    /// 自分の投稿の目印から、期限内の投稿を読む
    static func myPosts(uid: String, now: Date) async throws -> [Post] {
        let ids = try await myPostIDs(uid: uid, now: now)
        let posts = try await withThrowingTaskGroup(of: Post?.self) { group in
            for id in ids {
                group.addTask { try await post(id: id) }
            }
            var posts: [Post] = []
            for try await post in group {
                if let post {
                    posts.append(post)
                }
            }
            return posts
        }
        return PostDocument.activePosts(posts, at: now)
    }

    /// 共感を送る。送ってよいときだけ、人数を 1 増やすのと送った記録を、同じバッチで書く。
    /// 送った記録は投稿の下に置かず（投稿者にだれが送ったか分からない）、投稿と同じ expireAt で TTL で消す
    static func sendStamp(
        _ stamp: EmpathyStamp,
        to postID: String,
        uid: String,
        now: Date,
        autoHideThreshold: Int
    ) async throws -> PostDocument.StampSendCheck {
        let postRef = database.collection(PostDocument.postsCollection).document(postID)
        let sentRef = sentStamps(uid: uid).document(postID)
        let postSnapshot = try await postRef.getDocument()
        let isOwnPost = try await ownPosts(uid: uid).document(postID).getDocument().exists
        let sentSnapshot = try await sentRef.getDocument()
        let check = PostDocument.stampSendCheck(
            post: postSnapshot.data().flatMap { post(id: postID, data: $0) },
            isOwnPost: isOwnPost,
            isAutoHidden: ReportDocument.isAutoHidden(post: postSnapshot.data() ?? [:], threshold: autoHideThreshold),
            sentStamps: PostDocument.sentStamps(from: sentSnapshot.get(Field.stamps)),
            stamp: stamp,
            now: now
        )
        guard check == .send else {
            return check
        }
        guard let expireAt = postSnapshot.get(Field.expireAt) as? Timestamp else {
            return .postNotFound
        }
        let batch = database.batch()
        batch.updateData([PostDocument.stampCountFieldPath(stamp): FieldValue.increment(Int64(1))], forDocument: postRef)
        batch.setData(
            [
                Field.stamps: FieldValue.arrayUnion([stamp.rawValue]),
                Field.expireAt: expireAt
            ],
            forDocument: sentRef,
            merge: true
        )
        try await batch.commit()
        return .send
    }

    /// その投稿に自分が送ったスタンプ
    static func sentStamps(for postID: String, uid: String) async throws -> Set<EmpathyStamp> {
        let snapshot = try await sentStamps(uid: uid).document(postID).getDocument()
        return PostDocument.sentStamps(from: snapshot.get(Field.stamps))
    }

    /// 投稿ごとに自分が送ったスタンプ。期限内の送った記録を 1 回で読み、渡された投稿の分だけを返す
    static func sentStamps(for postIDs: [String], uid: String, now: Date) async throws -> [String: Set<EmpathyStamp>] {
        guard !postIDs.isEmpty else {
            return [:]
        }
        let snapshot = try await sentStamps(uid: uid)
            .whereField(Field.expireAt, isGreaterThan: Timestamp(date: now))
            .getDocuments()
        let wanted = Set(postIDs)
        var result: [String: Set<EmpathyStamp>] = [:]
        for document in snapshot.documents where wanted.contains(document.documentID) {
            let stamps = PostDocument.sentStamps(from: document.get(Field.stamps))
            if !stamps.isEmpty {
                result[document.documentID] = stamps
            }
        }
        return result
    }

    /// 自分の投稿を消す。投稿と目印を同じバッチで消す（他の人の送った記録・通報は、投稿と同じ expireAt で TTL が消す）。
    /// 目印が無ければ自分の投稿ではない。期限を過ぎて TTL を待っている投稿も、目印があれば消す
    static func delete(postID: String, uid: String) async throws {
        let postRef = database.collection(PostDocument.postsCollection).document(postID)
        let ownRef = ownPosts(uid: uid).document(postID)
        guard try await ownRef.getDocument(source: .server).exists else {
            let exists = try await postRef.getDocument(source: .server).exists
            throw exists ? PostRepositoryError.notOwner : PostRepositoryError.postNotFound
        }
        let batch = database.batch()
        batch.deleteDocument(postRef)
        batch.deleteDocument(ownRef)
        try await batch.commit()
    }

    /// 「すべてのデータを削除」のサーバー側（MyDataDocument のコメント）
    static func deleteAllMyData(uid: String, now: Date) async throws {
        // 自分の投稿。期限で絞らず、2 段目を書けなかった投稿の目印も含めて消す
        let marks = try await ownPosts(uid: uid).getDocuments(source: .server)
        // 1 件につき投稿と目印の 2 つを消す
        for chunk in MyDataDocument.chunked(marks.documents, size: MyDataDocument.batchLimit / 2) {
            let batch = database.batch()
            for mark in chunk {
                batch.deleteDocument(database.collection(PostDocument.postsCollection).document(mark.documentID))
                batch.deleteDocument(mark.reference)
            }
            try await batch.commit()
        }

        // 送った共感と通報。投稿ごとに、人数を引くのと記録を消すのを同じバッチで書く（途中で止まっても二重に引かない）
        let sent = try await sentStamps(uid: uid).getDocuments(source: .server)
        let reported = try await sentReports(uid: uid).getDocuments(source: .server)
        let withdrawals = MyDataDocument.withdrawals(
            sentStamps: Dictionary(
                sent.documents.map { ($0.documentID, PostDocument.sentStamps(from: $0.get(Field.stamps))) }
            ) { $1 },
            reportedPostIDs: Set(reported.documents.map(\.documentID))
        )
        for withdrawal in withdrawals {
            try await withdraw(withdrawal, uid: uid, now: now)
        }
    }

    private static func withdraw(_ withdrawal: MyDataDocument.Withdrawal, uid: String, now: Date) async throws {
        let postRef = database.collection(PostDocument.postsCollection).document(withdrawal.postID)
        let snapshot = try await postRef.getDocument(source: .server)
        let decrements = MyDataDocument.decrements(
            post: snapshot.data(),
            expireAt: (snapshot.get(Field.expireAt) as? Timestamp)?.dateValue(),
            withdrawal: withdrawal,
            now: now
        )
        let batch = database.batch()
        if !decrements.isEmpty {
            batch.updateData(decrements.mapValues { FieldValue.increment($0) }, forDocument: postRef)
        }
        batch.deleteDocument(sentStamps(uid: uid).document(withdrawal.postID))
        batch.deleteDocument(postRef.collection(ReportDocument.reportsCollection).document(uid))
        batch.deleteDocument(sentReports(uid: uid).document(withdrawal.postID))
        try await batch.commit()
    }

    /// 1 件読む。消えていたら nil
    private static func post(id: String) async throws -> Post? {
        let snapshot = try await database.collection(PostDocument.postsCollection).document(id).getDocument()
        guard let data = snapshot.data() else {
            return nil
        }
        return post(id: snapshot.documentID, data: data)
    }

    private static func post(from document: QueryDocumentSnapshot) -> Post? {
        post(id: document.documentID, data: document.data())
    }

    private static func post(id: String, data: [String: Any]) -> Post? {
        PostDocument.post(
            id: id,
            data: data,
            createdAt: (data[Field.createdAt] as? Timestamp)?.dateValue(),
            expireAt: (data[Field.expireAt] as? Timestamp)?.dateValue()
        )
    }
}
